(* New Jersey QSO Party, #124. Assertions follow the sponsor's 2026 rev0.5
   rules, multiplier images and FT8 FAQ saved with the contest. *)
unit uTestContestNewJerseyQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNewJerseyQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_BandsModesAndPoints;
      procedure Test_SponsorTables;
      procedure Test_PowerScore;
      procedure Test_ExchangeExport;
      procedure Test_RealEngine;
   end;

implementation

uses
   uSettingsModel, Classes, SysUtils, VC, uContestBase, uContestRegistry,
   uContestFactory, uContestStateQSOPartyBase, uContestNewJerseyQP,
   uTestContestObjects, uTestRegisteredContests, uTestQSOPartyRules,
   uTestQSOPartyEngine, uTestShippedDom, uDomFileKeys, uMults, uCallsigns, uCTYDAT, ZoneCont,
   LogDom, LogDupe, LogEdit, LogWind, LogStuff, PostUnit, FCONTEST,
   uPendingCounties, uCabrillo, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(NJ_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('NJ-QSO-PARTY is not registered');
      end;
end;

procedure TContestNewJerseyQPTests.Test_Identity;
var
   identity: TContestBase;
   legacy: integer;
   member: ContestType;
   found: TContestHandle;
begin
   BeginTest('Test_NewJerseyIdentity');
   identity := ContestIdentity(PartyHandle);
   CheckTrue(identity is TContestNewJerseyQP, 'registered class');
   CheckTrue(TContestNewJerseyQP.ClassParent = TContestStateQSOPartyBase,
      'directly on the party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no legacy number');
   CheckFalse(TryLegacyContestOf(identity, member), 'no frozen enum member');
   CheckEquals('NJ-QSO-PARTY', ContestId(PartyHandle), 'stored id');
   CheckEquals('New Jersey QSO Party', identity.DisplayName, 'display');
   CheckEquals('New Jersey QSO Party', identity.FriendlyName, 'friendly name');
   CheckEquals('NJ-QSO-PARTY', identity.CabrilloName, 'sponsor Cabrillo name');
   CheckEquals('NJ-QSO-PARTY', identity.ADIFContestId, 'independent ADIF id');
   CheckEquals(92, identity.WA7BNMId, 'verified WA7BNM ref');
   CheckTrue(FindContestByADIFContestId('NJ-QSO-PARTY', found), 'ADIF import id');
   CheckTrue(found = PartyHandle, 'ADIF resolves this contest');
   CheckEquals('NJ', identity.HostState, 'host');
   CheckEquals('newjersey_cty', identity.DomesticFileName, 'county file');
   CheckEquals('newjersey', identity.InStateDomesticFileName, 'in-state file');
   CheckEquals('NewJerseyQSOParty@gmail.com', identity.SubmissionEmail, 'log address');
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode],
      'QSO per band/mode, multipliers once overall');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH, 'rover county rework');
   CheckTrue(identity.StripsRoverCountyFromCall, 'rover suffix lookup');
   CheckTrue(identity.SplitsRoverCallOnExport, 'rover export');
   CheckEquals(0, TContestStateQSOPartyBase(identity).CountyLineCountiesMax,
      'no simultaneous operation in more than one county');
   CheckFalse(identity.HasDXMultiplier, 'DX is one domestic table entry');
   CheckFalse(identity.HasZoneMultiplier, 'no zones');
   CheckFalse(identity.HasPrefixMultiplier, 'no prefixes');
end;

procedure TContestNewJerseyQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   station: TStationContext;
   band: BandType;
   mode: ModeType;
   extMode: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
   inState: boolean;
begin
   BeginTest('Test_NewJerseyBandsModesAndPoints');
   for inState := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inState;
      party := Make(PartyHandle, station);
      try
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in [Band80, Band40, Band20, Band15, Band10]),
               'only the five sponsor bands, band ' + IntToStr(Ord(band)));
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for extMode := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               qso := Default(ContestExchange);
               qso.ceRecordKind := rkQSO;
               qso.Callsign := 'K2ABC';
               qso.QTHString := 'BURL';
               qso.Band := Band20;
               qso.Mode := mode;
               qso.ExtMode := extMode;
               expected := 0;
               case mode of
                  CW:
                     begin
                     expected := 2;
                     end;
                  Phone, FM:
                     begin
                     expected := 1;
                     end;
                  Digital:
                     begin
                     if extMode <> eFT8 then
                        begin
                        expected := 2;
                        end;
                     end;
                  end;
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'public scoring by mode/submode');
               CheckTrue(party.UsesMode(mode, extMode) = (expected > 0), 'mode eligibility');
               qso.Band := Band30;
               party.ScoreQSO(qso);
               CheckEquals(0, Integer(qso.QSOPoints), 'WARC scores zero');
               CheckTrue(QSOIsXQSO(party, qso) = (mode <> NoMode),
                  'WARC is an X-QSO for records with an operating mode');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestNewJerseyQPTests.Test_SponsorTables;
begin
   BeginTest('Test_NewJerseySponsorTables');
   CheckEquals('', CountyFileDifference('NewJersey', 'newjersey_cty.dom',
      'NJ-QSO-PARTY-Counties.txt', 21), 'exact sponsor county table');
   LoadCountyTable('newjersey_cty.dom', False);
   try
      CheckEquals(21, mo.DomList.Count, '21 distinct host multipliers');
      CheckEquals('BURL', MultiplierOf(CountyTable, 'BURL'), 'Burlington');
      CheckEquals('', MultiplierOf(CountyTable, 'NJ'), 'NJ is not a county');
      CheckEquals('', MultiplierOf(CountyTable, 'PA'), 'outside state absent');
   finally
      FreeCountyTable;
   end;
   CheckEquals('BURL', InStateMultiplierOf(PartyHandle, 'BURL'), 'county stands alone');
   CheckEquals('PA', InStateMultiplierOf(PartyHandle, 'PA'), 'state');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'Louisiana, no province alias clash');
   CheckEquals('NF', InStateMultiplierOf(PartyHandle, 'NF'), 'sponsor province code');
   CheckEquals('NF', InStateMultiplierOf(PartyHandle, 'NL'), 'standard alias');
   CheckEquals('DX', InStateMultiplierOf(PartyHandle, 'DX'), 'one DX');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'NJ'), '49 states excludes NJ');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DC'), 'DC absent from sponsor table');
end;

procedure TContestNewJerseyQPTests.Test_PowerScore;
var
   totals: TScoreTotals;
   view: TLoggedQSOList;
   party: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NewJerseyPowerScore');
   totals := Default(TScoreTotals);
   totals.ScoredBand := AllBands;
   totals.SessionCountsMultipliers := True;
   view := TLoggedQSOList.Create;
   station := NoStation;
   station.MyPower := cpLOW;
   party := Make(PartyHandle, station);
   try
      (* Sponsor's outside-NJ example: 13 phone + 10 CW + 3 digital = 39. *)
      totals.QSOPoints := 39;
      totals.Mults[AllBands, Both, rmDomestic] := 9;
      CheckEquals(702, party.FinalScore(totals, view), 'sponsor LP example');
      station.MyPower := cpQRP;
      station.InHostState := True;
      party.SetStation(station);
      totals.QSOPoints := 23;
      totals.Mults[AllBands, Both, rmDomestic] := 14;
      CheckEquals(1288, party.FinalScore(totals, view), 'sponsor in-NJ QRP example');
      station.MyPower := cpHIGH;
      party.SetStation(station);
      CheckEquals(322, party.FinalScore(totals, view), 'HP factor one');
      totals.Mults[AllBands, Both, rmDomestic] := 0;
      CheckEquals(0, party.FinalScore(totals, view), 'no multipliers, no score');
   finally
      party.Free;
      view.Free;
   end;
end;

procedure TContestNewJerseyQPTests.Test_ExchangeExport;
var
   party: TContestBase;
   station: TStationContext;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   line, errorMessage: string;
begin
   BeginTest('Test_NewJerseyExchangeExport');
   station := NoStation;
   party := Make(PartyHandle, station);
   try
      my := Default(TMyStationExchange);
      my.MyState := 'PA';
      qso := Default(ContestExchange);
      qso.ceRecordKind := rkQSO;
      qso.Band := Band20;
      qso.Mode := CW;
      qso.RSTSent := 599;
      qso.RSTReceived := 599;
      qso.QTHString := 'BURL';
      qso.DomesticQTH := 'BURL';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'BURL';
      line := 'QSO: 14000 CW 2026-09-12 1400 W3AAA ' +
         party.FormatCabrilloSentExchange(my, qso, ctx) + 'K2TD ' +
         party.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('QSO: 14000 CW 2026-09-12 1400 W3AAA 599 PA     K2TD 599 BURL   ',
         line, 'complete line: sponsor-required RST and location fields');
      CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, qso), 'ADIF sent');
      CheckEquals('NJ', party.ADIFCountyState(qso), 'county STATE');
      qso.QTHString := 'NF';
      qso.DomesticQTH := 'NF';
      CheckEquals('NL', party.ADIFCountyState(qso), 'NF exports ADIF NL');
      my.MyState := '';
      CheckEquals('599 DX     ', party.FormatCabrilloSentExchange(my, qso, ctx), 'DX sent');
      CheckEquals('599 DX     ', party.FormatADIFSentExchange(my, qso), 'ADIF DX sent');
      CheckEquals(' 5NN DX', party.CQExchangeDefault(station), 'DX CW exchange');
      CheckTrue(party.ValidateQTHCount(1, errorMessage), 'one county accepted');
      CheckFalse(party.ValidateQTHCount(2, errorMessage), 'two counties refused');
   finally
      party.Free;
   end;
end;

(* Real-engine fixture and save/restore pattern from the newer state parties.
   Both entrant locations use shipped data through the actual parser/sheets. *)
procedure TContestNewJerseyQPTests.Test_RealEngine;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted, dupe: boolean;
begin
   BeginTest('Test_NewJerseyRealEngine');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      dupe := engine.Enter('K2TD', '599 BURL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'BURL taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'first contact');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW two points');
      CheckTrue(rx.DomesticMult, 'first county');
      dupe := engine.Enter('K2TD', '599 BURL', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'new band');
      CheckFalse(rx.DomesticMult, 'county once overall');
      dupe := engine.Enter('K2TD', '59 BURL', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'new mode');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone one point');
      CheckFalse(rx.DomesticMult, 'no new multiplier in phone');
      dupe := engine.Enter('K2TD', '599 BURL', Band20, Digital, eRTTY, accepted, rx);
      CheckFalse(dupe, 'digital separate from CW');
      CheckEquals(2, Integer(rx.QSOPoints), 'digital two points');
      dupe := engine.Enter('K2TD', '599 BURL', Band20, Digital, ePSK31, accepted, rx);
      CheckTrue(dupe, 'digital submodes one dupe group');
      CheckEquals(0, Integer(rx.QSOPoints), 'duplicate zero points');
      dupe := engine.Enter('K2TD', '599 OCEA', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'same unsuffixed call, new county');
      CheckTrue(rx.DomesticMult, 'new county multiplier');
      dupe := engine.Enter('K2TD', '599 OCEA', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'same county repeated');
      CheckFalse(rx.DomesticMult, 'duplicate earns no multiplier');
      dupe := engine.Enter('K2ROV/BURL', '599 BURL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'suffixed rover accepted');
      CheckFalse(dupe, 'new rover');
      dupe := engine.Enter('K2ROV/OCEA', '599 OCEA', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'suffixed rover new county');

      engine.Enter('W3AAA', '599 PA', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work PA');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work DX');
      engine.Enter('K2AAA', '599 XXXX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'invalid county');
      engine.Enter('K2AAA', '', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'missing exchange');
      ClearPendingCounties;
      engine.Enter('K2LINE', '599 BURL/OCEA', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'county-line operation forbidden');
      CheckEquals(0, PendingCountiesCount, 'no second contact queued');

      engine.Enter('K2FT', '599 MERC', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'FT8 record can be logged');
      CheckTrue(LoggedQSOIsXQSO(rx), 'sponsor FAQ makes FT8 an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'FT8 zero points');
      CheckFalse(rx.DomesticMult, 'FT8 earns no multiplier');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx), 'no FT8 total');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
         'FT8 exported as X-QSO');
      engine.Enter('K2FT', '599 MERC', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'FT8 did not mark Mercer worked');
      engine.Enter('K2WARC', '599 HUNT', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'off-band record can be logged');
      CheckTrue(LoggedQSOIsXQSO(rx), 'off-band X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'off-band zero points');
      CheckFalse(rx.DomesticMult, 'off-band no multiplier');
      engine.Enter('K2WARC', '599 HUNT', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'off-band did not mark Hunterdon worked');

      (* NJ entrant: 21 counties + 49 states + 13 provinces + one DX. *)
      engine.Activate(True);
      CheckEquals(84, mo.DomList.Count, 'exact sponsor in-state maximum');
      engine.Enter('W3AAA', '599 PA', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'NJ entrant works PA');
      CheckTrue(rx.DomesticMult, 'PA new');
      engine.Enter('W3AAA', '59 PA', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'PA once across modes and bands');
      engine.Enter('VE1AAA', '599 NS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Nova Scotia');
      CheckTrue(rx.DomesticMult, 'province new');
      engine.Enter('VO1AAA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'sponsor NF accepted');
      CheckEquals('NF', UpperCase(string(rx.DomMultQTH)), 'NF canonical');
      engine.Enter('VO1BBB', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'standard NL alias accepted');
      CheckFalse(rx.DomesticMult, 'NL same province as NF');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'typed DX accepted');
      CheckTrue(rx.DomesticMult, 'one DX domestic multiplier');
      CheckFalse(rx.DXMult, 'no country multiplier');
      engine.Enter('JA1AAA', '599 DX', Band40, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'second DX country');
      CheckFalse(rx.DomesticMult, 'still the same one DX multiplier');
      CheckEquals(1, Integer(rx.QSOPoints), 'DX phone scores');
      engine.Enter('K2AAA', '599 BURL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'NJ entrant works county');
      CheckTrue(rx.DomesticMult, 'county remains distinct');
      engine.Enter('K2AAA', '599 NJ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'NJ literal cannot replace required county');
   finally
      engine.Free;
   end;
end;

procedure TContestNewJerseyQPTests.RunAllTests;
begin
   Test_Identity;
   Test_BandsModesAndPoints;
   Test_SponsorTables;
   Test_PowerScore;
   Test_ExchangeExport;
   Test_RealEngine;
end;

end.
