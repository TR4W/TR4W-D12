(* West Virginia QSO Party #131: sponsor 2026 rules, county table and
   NY4I's overall multiplier scope and DXLog naming rulings. *)
unit uTestContestWestVirginiaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestWestVirginiaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndPoints;
      procedure Test_TablesAndExchange;
      procedure Test_BonusAndFinalScore;
      procedure Test_RealEngine;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry, uContestFactory,
   uContestStateQSOPartyBase, uContestWestVirginiaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(WV_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('WV-QSO-PARTY is not registered');
      end;
end;

function WVQSO(const aCall: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'BAR';
   Result.DomesticQTH := 'BAR';
   Result.DomMultQTH := 'BAR';
end;

procedure TContestWestVirginiaQPTests.Test_IdentityAndPoints;
var
   party: TContestBase;
   station: TStationContext;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   inHost: boolean;
   expected, legacy: integer;
   errorMessage: string;
begin
   BeginTest('Test_WestVirginiaIdentityAndPoints');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestWestVirginiaQP, 'registered class');
   CheckTrue(TContestWestVirginiaQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckEquals('WV-QSO-PARTY', ContestId(PartyHandle), 'stored identity');
   CheckEquals('WV-QSO-PARTY', party.CabrilloName, 'DXLog Cabrillo identity');
   CheckEquals('WV-QSO-PARTY', party.ADIFContestId, 'ADIF identity');
   CheckEquals('West Virginia QSO Party', party.DisplayName, 'display name');
   CheckEquals('West Virginia QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('WV', party.HostState, 'host');
   CheckEquals(49, party.WA7BNMId, 'WA7BNM ref');
   CheckEquals('wvqplogs@gmail.com', party.SubmissionEmail, 'sponsor log address');
   CheckEquals('westvirginia_cty', party.DomesticFileName, 'county file');
   CheckEquals('westvirginia', party.InStateDomesticFileName, 'in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode], 'dupes per band/mode, multipliers overall');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'bare-call rover county reworks');
   CheckEquals(2, TContestStateQSOPartyBase(party).CountyLineCountiesMax, 'two-county line');
   CheckTrue(party.ValidateQTHCount(2, errorMessage), 'two allowed');
   CheckFalse(party.ValidateQTHCount(3, errorMessage), 'three refused');
   CheckTrue(errorMessage <> '', 'county limit refusal explains why');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckTrue(party.HasDXMultiplier = inHost, 'DXCC for WV entrant only');
         CheckTrue(party.HasPrefixMultiplier = inHost, 'extra WV state only inside');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in [Band80, Band40, Band20, Band15, Band10]),
               'five sponsor HF bands');
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode in [Phone, FM] then
                  begin
                  expected := 1;
                  end;
               if mode in [CW, Digital] then
                  begin
                  expected := 2;
                  end;
               qso := WVQSO('W8ABC', Band20, mode, ext);
               qso.QSOPoints := 99;
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'CW/digital two, phone one');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'explicit mode/submode eligibility');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestWestVirginiaQPTests.Test_TablesAndExchange;
var
   party: TContestBase;
   station: TStationContext;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   qso: ContestExchange;
   key: PrefixMultiplierString;
begin
   BeginTest('Test_WestVirginiaTablesAndExchange');
   CheckEquals('', CountyFileDifference('WestVirginia', 'westvirginia_cty.dom',
      'WV-QSO-PARTY-CountyTable.txt', 55), 'every sponsor county code and name');
   CheckEquals('MIN', InStateMultiplierOf(PartyHandle, 'MIN'), 'Mineral does not become Minnesota');
   CheckEquals('MN', InStateMultiplierOf(PartyHandle, 'MN'), 'Minnesota distinct from Mineral');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'Louisiana not a province alias');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'Newfoundland and Labrador');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC is Maryland');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'WV'), 'WV stations must send county');
   LoadCountyTable('westvirginia_cty.dom', False);
   try
      CheckEquals(55, mo.DomList.Count, '55 distinct counties');
      station := NoStation;
      station.InHostState := True;
      station.IsDomesticQTH := @CountyFileKnowsQTH;
      party := Make(PartyHandle, station);
      try
         qso := WVQSO('W8ABC', Band20, CW, eCW);
         CheckTrue(party.PrefixMultiplierKey(qso, key), 'additional state key supplied');
         CheckEquals('WV', string(key), 'county also earns WV state');
         qso.DomesticQTH := '';
         qso.QTHString := 'MIN';
         party.PrefixMultiplierKey(qso, key);
         CheckEquals('WV', string(key), 'received rover county without stored domestic field');
         qso.QTHString := 'XXX';
         party.PrefixMultiplierKey(qso, key);
         CheckEquals('', string(key), 'unknown placeholder no state credit');
         qso.QTHString := 'KP4';
         party.PrefixMultiplierKey(qso, key);
         CheckEquals('', string(key), 'DX prefix is not a county');
         CheckEquals('WV', party.TotalsDisplay.PrefixMultsCaption, 'extra state totals caption');
         qso := WVQSO('W8ABC', Band20, CW, eCW);
         qso.RSTSent := 599;
         qso.RSTReceived := 599;
         my := Default(TMyStationExchange);
         my.MyState := 'PA';
         ctx := Default(TCabrilloQSOContext);
         ctx.RSTSent := '599';
         ctx.RSTReceived := '599';
         ctx.HisQTH := 'BAR';
         CheckEquals('599 PA     ', party.FormatCabrilloSentExchange(my, qso, ctx), 'RST and state sent');
         CheckEquals('599 BAR    ', party.FormatCabrilloReceivedExchange(my, qso, ctx), 'RST and county received');
         CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, qso), 'ADIF sent exchange');
         CheckEquals('WV', party.ADIFCountyState(qso), 'county exports WV STATE');
         station.MyCountry := 'DL';
         station.InHostState := False;
         party.SetStation(station);
         my.MyState := '';
         CheckEquals('599 DL     ', party.FormatCabrilloSentExchange(my, qso, ctx), 'DX sends prefix');
         CheckEquals('599 DL     ', party.FormatADIFSentExchange(my, qso), 'ADIF DX prefix');
         CheckEquals(' 5NN DL', party.CQExchangeDefault(station), 'default DX exchange agrees');
         CheckFalse(party.PrefixMultiplierKey(qso, key), 'outside entrant earns county only');
      finally
         party.Free;
      end;
   finally
      FreeCountyTable;
   end;
end;

procedure TContestWestVirginiaQPTests.Test_BonusAndFinalScore;
var
   party: TContestBase;
   station: TStationContext;
   view: TLoggedQSOList;
   totals: TScoreTotals;
   qso: ContestExchange;
   power: tCategoryPower;
begin
   BeginTest('Test_WestVirginiaBonusAndFinalScore');
   station := WithHostAreaTable(NoStation);
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      CheckEquals(0, party.BonusPoints(totals, view), 'empty log');
      view.Add(WVQSO('W8WVA', Band20, CW, eCW));
      view.Add(WVQSO('W8WVA', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'same band/mode only once');
      view.Add(WVQSO('W8WVA', Band40, CW, eCW));
      view.Add(WVQSO('W8WVA', Band20, Phone, eUSB));
      view.Add(WVQSO('W8WVA', Band20, FM, eFM));
      view.Add(WVQSO('W8WVA', Band20, Digital, eRTTY));
      view.Add(WVQSO('W8WVA', Band20, Digital, ePSK31));
      CheckEquals(400, party.BonusPoints(totals, view), 'per band/mode; FM phone and digital submodes grouped');
      qso := WVQSO('W8WVA', Band15, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso := WVQSO('W8WVA', Band10, CW, eCW);
      qso.ceXQSO := True;
      view.Add(qso);
      view.Add(WVQSO('W8WVA', Band30, CW, eCW));
      view.Add(WVQSO('W8WVA', Band6, CW, eCW));
      view.Add(WVQSO('W8WVAX', Band15, CW, eCW));
      CheckEquals(400, party.BonusPoints(totals, view), 'dupes, explicit/automatic X-QSOs and other calls excluded');
      view.Clear;
      view.Add(WVQSO('W8WVA/BAR', Band20, CW, eCW));
      view.Add(WVQSO('W8WVA/MIN', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'county rework still one band/mode bonus');
      view.Add(WVQSO('W8WVA/MIN', Band40, CW, eCW));
      view.Add(WVQSO('W8WVA/M', Band15, CW, eCW));
      CheckEquals(200, party.BonusPoints(totals, view), 'county suffix pays; portable suffix stays');
      view.Add(WVQSO('W8WVA', Band20, Phone, eUSB));
      view.Add(WVQSO('W8WVA', Band20, Digital, eRTTY));
      totals.QSOPoints := 100;
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.Mults[AllBands, Both, rmDomestic] := 12;
      totals.Mults[AllBands, Both, rmPrefix] := 1;
      totals.Mults[AllBands, Both, rmDX] := 2;
      for power := Low(tCategoryPower) to High(tCategoryPower) do
         begin
         station.MyPower := power;
         party.SetStation(station);
         CheckEquals(1900, party.FinalScore(totals, view), '100 x 15 plus 400 bonus, no power factor');
         end;
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestWestVirginiaQPTests.Test_RealEngine;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted, dupe: boolean;
begin
   BeginTest('Test_WestVirginiaRealEngine');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckEquals(117, mo.DomList.Count, '55 counties plus 49 other states plus 13 provinces');
      engine.Enter('W8UNKNOWN', '599 XXX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'unknown QTH placeholder can be logged');
      CheckFalse(rx.DomesticMult, 'unknown no county');
      CheckFalse(rx.PrefixMult, 'unknown no WV state');
      dupe := engine.Enter('W8AAA', '599 BAR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'county accepted');
      CheckFalse(dupe, 'first contact');
      CheckTrue(rx.DomesticMult, 'county multiplier');
      CheckTrue(rx.PrefixMult, 'WV state at the same contact');
      CheckEquals('WV', string(rx.Prefix), 'extra state key');
      engine.Enter('W8AAA', '599 BAR', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'county not repeated per band');
      CheckFalse(rx.PrefixMult, 'state not repeated per band');
      engine.Enter('W8AAA', '59 BAR', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'county not repeated per mode');
      CheckFalse(rx.PrefixMult, 'state not repeated per mode');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone one point');
      dupe := engine.Enter('W8AAA', '59 BAR', Band20, FM, eFM, accepted, rx);
      CheckTrue(dupe, 'FM and SSB share phone dupe group');
      engine.Enter('W8AAA', '599 BAR', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'digital exchange accepted');
      CheckEquals(2, Integer(rx.QSOPoints), 'digital two points');
      CheckFalse(rx.DomesticMult, 'digital no repeated county');
      CheckFalse(rx.PrefixMult, 'digital no repeated state');
      dupe := engine.Enter('W8AAA', '599 BAR', Band20, Digital, ePSK31, accepted, rx);
      CheckTrue(dupe, 'non-CW digital submodes one dupe group');
      engine.Enter('W8MIN', '599 MIN', Band20, CW, eCW, accepted, rx);
      CheckEquals('MIN', UpperCase(string(rx.DomMultQTH)), 'Mineral county');
      engine.Enter('W0MN', '599 MN', Band20, CW, eCW, accepted, rx);
      CheckEquals('MN', UpperCase(string(rx.DomMultQTH)), 'Minnesota state');
      CheckTrue(rx.DomesticMult, 'Minnesota separate multiplier');
      engine.Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'DC maps to MD');
      engine.Enter('W3MD', '599 MD', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland not repeated by band or mode');
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'DX prefix accepted');
      CheckTrue(rx.DXMult, 'DXCC multiplier');
      CheckFalse(rx.PrefixMult, 'DX prefix not WV county');
      engine.Enter('DL1AAA', '59 DL', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(rx.DXMult, 'DXCC not repeated per band/mode');
      engine.Enter('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DXMult, 'Hawaii excluded from DXCC');
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier');
      engine.Enter('W8BAD', '599 WV', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'county required instead of literal WV');
      engine.Enter('W8LINE', '599 BAR/BER', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'two-county contact accepted');
      CheckEquals('BAR', string(rx.QTHString), 'first county in this QSO');
      CheckEquals(1, PendingCountiesCount, 'one separate county queued');
      CheckEquals('BER', DequeuePendingCounty, 'second county is Berkeley');
      engine.Enter('W8LINE', '599 BER', Band15, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'second county earns separate credit');
      CheckFalse(rx.PrefixMult, 'WV state still once');
      engine.Enter('W8THREE', '599 BAR/BER/BOO', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three counties refused');
      CheckEquals(0, PendingCountiesCount, 'refusal leaves no county queue');

      engine.Activate(False);
      engine.Enter('W8ROV', '599 BAR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'outside entrant works county');
      CheckFalse(rx.PrefixMult, 'outside no separate WV state');
      dupe := engine.Enter('W8ROV', '599 BER', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'bare-call rover new county is new QSO');
      dupe := engine.Enter('W8ROV', '599 BAR', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'repeat same county is dupe');
      engine.Enter('W3AAA', '599 PA', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant refuses other state');
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant refuses DX');
      engine.Enter('W8WARC', '599 BOO', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'off-band automatic X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'off-band zero points');
      CheckFalse(rx.DomesticMult, 'off-band no county');
      engine.Enter('W8WARC', '599 BOO', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'off-band did not mark county');
      engine.Activate(True);
      rx := WVQSO('W8IMPORT/MIN', Band20, CW, eCW);
      rx.DomesticQTH := '';
      rx.QTHString := 'MIN';
      rx.DomMultQTH := 'MIN';
      rx.Prefix := 'BAD';
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals('WV', string(rx.Prefix), 'rescore derives WV from received rover county');
      CheckEquals(2, Integer(rx.QSOPoints), 'rescore replaces stale points');
      CheckTrue(rx.DomesticMult, 'rescore county credit');
      CheckTrue(rx.PrefixMult, 'rescore separate state credit');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckFalse(rx.DomesticMult, 'X-QSO no county');
      CheckFalse(rx.PrefixMult, 'X-QSO no state');
      CheckEquals(0, Integer(rx.QSOPoints), 'X-QSO zero');
   finally
      engine.Free;
   end;
end;

procedure TContestWestVirginiaQPTests.RunAllTests;
begin
   Test_IdentityAndPoints;
   Test_TablesAndExchange;
   Test_BonusAndFinalScore;
   Test_RealEngine;
end;

end.
