(* Alabama QSO Party #114. Sponsor 2026 rules and NY4I's additional state
   credit ruling are saved in docs/ContestRules/QSOParties/Alabama. *)
unit uTestContestAlabamaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestAlabamaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndEligibility;
      procedure Test_DataAndStateKey;
      procedure Test_ScoreAndExport;
      procedure Test_RealEngine;
      procedure Test_RefusedExchangeKeepsCallKey;
   end;

implementation

uses
   uSettingsModel, SysUtils, VC, uContestBase, uContestRegistry,
   uContestFactory, uContestStateQSOPartyBase, uContestAlabamaQP,
   uTestContestObjects, uTestQSOPartyRules, uTestQSOPartyEngine,
   uTestShippedDom, uTestRegisteredContests, uMults, LogDom, LogDupe,
   LogEdit, LogStuff, uPendingCounties, uCabrillo, MainUnit, PostUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(AL_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('AL-QSO-PARTY is not registered');
      end;
end;

procedure TContestAlabamaQPTests.Test_IdentityAndEligibility;
var
   party: TContestBase;
   station: TStationContext;
   band: BandType;
   mode: ModeType;
   extMode: ExtendedModeType;
   qso: ContestExchange;
   expected, legacy: integer;
   inHost: boolean;
   member: ContestType;
begin
   BeginTest('Test_AlabamaIdentityAndEligibility');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestAlabamaQP, 'registered class');
   CheckTrue(TContestAlabamaQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no legacy number');
   CheckFalse(TryLegacyContestOf(party, member), 'no enum member');
   CheckEquals('AL-QSO-PARTY', ContestId(PartyHandle), 'stored id');
   CheckEquals('Alabama QSO Party', party.DisplayName, 'display');
   CheckEquals('Alabama QSO Party', party.FriendlyName, 'friendly');
   CheckEquals('AL-QSO-PARTY', party.CabrilloName, 'WA7BNM Cabrillo identity');
   CheckEquals('AL-QSO-PARTY', party.ADIFContestId, 'ADIF identity');
   CheckEquals(134, party.WA7BNMId, 'WA7BNM ref');
   CheckEquals('logs@alabamaqsoparty.org', party.SubmissionEmail, 'sponsor log address');
   CheckEquals('AL', party.HostState, 'host state');
   CheckEquals('alabama_cty', party.DomesticFileName, 'county file');
   CheckEquals('alabama', party.InStateDomesticFileName, 'in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByMode],
      'multipliers per mode, dupes per band/mode/county');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'received rover county rework');
   CheckEquals(0, TContestStateQSOPartyBase(party).CountyLineCountiesMax, 'county lines forbidden');

   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckTrue(party.HasDXMultiplier = inHost, 'DXCC only inside Alabama');
         CheckFalse(party.HasPrefixMultiplier, '#317: the AL state is a domestic key, no prefix sheet');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in [Band80, Band40, Band20, Band15, Band10]),
               'five HF bands only');
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for extMode := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode in [CW, Phone, FM] then
                  begin
                  expected := 2;
                  end;
               qso := Default(ContestExchange);
               qso.ceRecordKind := rkQSO;
               qso.Callsign := 'K4ABC';
               qso.QTHString := 'AUTA';
               qso.Band := Band20;
               qso.Mode := mode;
               qso.ExtMode := extMode;
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'two points CW/phone, no digital');
               CheckTrue(party.UsesMode(mode, extMode) = (expected > 0), 'explicit mode eligibility');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestAlabamaQPTests.Test_DataAndStateKey;
var
   party: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
   key: string;
begin
   BeginTest('Test_AlabamaDataAndStateKey');
   CheckEquals('', CountyFileDifference('Alabama', 'alabama_cty.dom',
      'AL-QSO-PARTY-CountyTable.txt', 67), '67 sponsor counties and names');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC folds into MD');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MDC'), 'rules MDC alias');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), '13-province standard NL');
   CheckEquals('AUTA', InStateMultiplierOf(PartyHandle, 'AUTA'), 'county not collapsed to AL');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'AL'), 'AL is not the required county exchange');
   LoadCountyTable('alabama_cty.dom', False);
   try
      CheckEquals(67, mo.DomList.Count, '67 distinct counties');
      station := NoStation;
      station.InHostState := True;
      station.IsDomesticQTH := @CountyFileKnowsQTH;
      party := Make(PartyHandle, station);
      try
         qso := Default(ContestExchange);
         qso.DomesticQTH := 'AUTA';
         CheckTrue(party.AdditionalDomesticMultiplierKey(qso, key), '#317: a second domestic key');
         CheckEquals('AL', key, 'NY4I: county ALSO earns AL');
         qso.DomesticQTH := 'LEE';
         party.AdditionalDomesticMultiplierKey(qso, key);
         CheckEquals('AL', key, 'three-letter Lee county also earns AL');
         qso.DomesticQTH := '';
         qso.DomMultQTH := 'BALD';
         party.AdditionalDomesticMultiplierKey(qso, key);
         CheckEquals('AL', key, 'a rover row: the credited key, no DomesticQTH');
         qso.DomMultQTH := '';
         qso.QTHString := 'BALD';
         CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key),
            '#317: the typed QTH alone is not the credited key');
         qso.DomesticQTH := 'PA';
         party.AdditionalDomesticMultiplierKey(qso, key);
         CheckEquals('', key, 'other state no AL');
         qso.DomesticQTH := 'KP4';
         party.AdditionalDomesticMultiplierKey(qso, key);
         CheckEquals('', key, 'DX prefix is no county');
         qso.DomesticQTH := 'XXXX';
         party.AdditionalDomesticMultiplierKey(qso, key);
         CheckEquals('', key, 'unknown location no AL');
         CheckTrue(party.TotalsDisplay.PrefixMultsCaption <> 'AL', 'the interim AL totals row is gone');
         station.InHostState := False;
         party.SetStation(station);
         qso.DomesticQTH := 'AUTA';
         CheckFalse(party.AdditionalDomesticMultiplierKey(qso, key), 'outside entrant earns no extra state');
      finally
         party.Free;
      end;
   finally
      FreeCountyTable;
   end;
end;

procedure TContestAlabamaQPTests.Test_ScoreAndExport;
var
   station: TStationContext;
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   qso: ContestExchange;
   power: tCategoryPower;
begin
   BeginTest('Test_AlabamaScoreAndExport');
   station := NoStation;
   station.InHostState := True;
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 100;
      (* 9 counties/states per mode plus AL in each -- all domestic (#317). *)
      totals.Mults[AllBands, CW, rmDomestic] := 10;
      totals.Mults[AllBands, Phone, rmDomestic] := 10;
      totals.Mults[AllBands, Both, rmDomestic] := 20;
      for power := Low(tCategoryPower) to High(tCategoryPower) do
         begin
         station.MyPower := power;
         party.SetStation(station);
         CheckEquals(2000, party.FinalScore(totals, view),
            'sponsor 25 CW/25 phone example, no power factor');
         end;
      my := Default(TMyStationExchange);
      my.MyState := 'AUTA';
      qso := Default(ContestExchange);
      qso.ceRecordKind := rkQSO;
      qso.Band := Band20;
      qso.Mode := CW;
      qso.RSTSent := 599;
      qso.RSTReceived := 599;
      qso.QTHString := 'DL';
      qso.DXQTH := 'DL';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DL';
      CheckEquals('599 AUTA   ', party.FormatCabrilloSentExchange(my, qso, ctx), 'county sent');
      CheckEquals('599 DL     ', party.FormatCabrilloReceivedExchange(my, qso, ctx), 'DX country received');
      CheckEquals('599 AUTA   ', party.FormatADIFSentExchange(my, qso), 'ADIF county sent');
      station.MyCountry := 'DL';
      station.InHostState := False;
      party.SetStation(station);
      my.MyState := '';
      CheckEquals('599 DL     ', party.FormatCabrilloSentExchange(my, qso, ctx), 'DX sends its prefix');
      CheckEquals('599 DL     ', party.FormatADIFSentExchange(my, qso), 'ADIF agrees');
      CheckEquals(' 5NN DL', party.CQExchangeDefault(station), 'CW exchange agrees');
      my.MyState := 'PA';
      CheckEquals('599 PA     ', party.FormatCabrilloSentExchange(my, qso, ctx), 'stated state kept');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestAlabamaQPTests.Test_RealEngine;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted, dupe: boolean;
begin
   BeginTest('Test_AlabamaRealEngine');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckEquals(130, mo.DomList.Count, '67 counties, AL, 49 other states, 13 provinces (#317)');
      engine.Enter('K4UNKNOWN', '599 XXX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'engine unknown-QTH placeholder can be logged');
      CheckFalse(rx.DomesticMult, 'unknown QTH earns no county');
      CheckEquals(0, mo.MTotals[AllBands, CW, rmDomestic], 'and cannot earn Alabama state credit');
      dupe := engine.Enter('K4AAA', '599 AUTA', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'county exchange accepted');
      CheckFalse(dupe, 'first county QSO');
      CheckTrue(rx.DomesticMult, 'first county multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), 'two CW points');
      CheckEquals(2, mo.MTotals[AllBands, CW, rmDomestic], 'county AND the AL state, both domestic');
      CheckFalse(mo.IsDmMult('AL', AllBands, CW, False), 'AL is worked in CW');
      CheckTrue(mo.IsDmMult('AL', AllBands, Phone, False), 'but not in phone');
      CheckEquals(0, mo.MTotals[AllBands, CW, rmPrefix], 'no prefix sheet any more');
      engine.Enter('K4BBB', '599 BALD', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'second county earns its own multiplier');
      CheckEquals(3, mo.MTotals[AllBands, CW, rmDomestic], 'but not AL again in CW');
      engine.Enter('K4AAA', '599 AUTA', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'county not again on new band');
      CheckEquals(3, mo.MTotals[AllBands, CW, rmDomestic], 'nor AL state');
      engine.Enter('K4AAA', '59 AUTA', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(rx.DomesticMult, 'county again in phone');
      CheckEquals(2, mo.MTotals[AllBands, Phone, rmDomestic], 'AL again in phone');
      dupe := engine.Enter('K4AAA', '59 AUTA', Band20, FM, eFM, accepted, rx);
      CheckTrue(dupe, 'FM after SSB is a phone dupe');
      CheckEquals(2, mo.MTotals[AllBands, Phone, rmDomestic], 'dupe no AL credit');
      engine.Enter('W3AAA', '599 PA', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'other state accepted');
      CheckTrue(rx.DomesticMult, 'PA multiplier');
      CheckEquals(4, mo.MTotals[AllBands, CW, rmDomestic], 'PA alone, no additional AL state');
      engine.Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'DC folded into Maryland');
      engine.Enter('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland same as DC');
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'DX prefix accepted');
      CheckTrue(rx.DXMult, 'DXCC multiplier');
      CheckEquals(5, mo.MTotals[AllBands, CW, rmDomestic], 'no AL for a DX prefix');
      engine.Enter('K4BAD', '599 AL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'literal AL cannot replace county (its .dom line has no alias)');
      ClearPendingCounties;
      engine.Enter('K4LINE', '599 AUTA/BALD', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'county-line sitting forbidden');
      CheckEquals(0, PendingCountiesCount, 'nothing queued');

      engine.Activate(False);
      dupe := engine.Enter('K4ROV', '599 LEE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'outside entrant works Lee');
      CheckTrue(rx.DomesticMult, 'county multiplier');
      CheckEquals(1, mo.MTotals[AllBands, CW, rmDomestic], 'outside entrant no extra AL state');
      CheckFalse(rx.DXMult, 'outside entrant no DXCC');
      dupe := engine.Enter('K4ROV', '599 AUTA', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'received rover new county');
      dupe := engine.Enter('K4ROV', '599 AUTA', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'same county repeats');
      engine.Enter('W3AAA', '599 PA', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work PA');
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work DX');
      engine.Enter('K4DIG', '599 CULM', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'digital record logged');
      CheckTrue(LoggedQSOIsXQSO(rx), 'digital automatic X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'digital zero points');
      CheckFalse(rx.DomesticMult, 'digital no county multiplier');
      engine.Enter('K4DIG', '599 CULM', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'digital did not mark county');

      (* Imported X-QSO in-state must not mark either county or state. *)
      engine.Activate(True);
      engine.Enter('K4WARC', '599 JEFF', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'off-band automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'off-band no county');
      CheckEquals(0, mo.MTotals[AllBands, CW, rmDomestic], 'off-band no AL state');
      engine.Enter('K4WARC', '599 JEFF', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'valid QSO still earns county');
      CheckEquals(2, mo.MTotals[AllBands, CW, rmDomestic], 'and AL state');
      CheckEquals(1, mo.WorkedCount(rmDomestic, 'AL', AllBands, CW), 'state worked count');
      engine.Enter('K4WAR2', '599 AUTA', Band20, CW, eCW, accepted, rx);
      CheckEquals(2, mo.WorkedCount(rmDomestic, 'AL', AllBands, CW),
         'the state is COUNTED on every county QSO, new or not');
      CheckEquals(3, mo.MTotals[AllBands, CW, rmDomestic], 'but totalled once');

      (* Import/rescore starts with a complete received record, not the
         typed exchange. Stale stored keys must be derived again. *)
      engine.Activate(True);
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := PartyHandle;
      rx.Callsign := 'K4IMPORTED/AUTA';
      rx.QTHString := 'AUTA';
      rx.DomMultQTH := 'AUTA';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals(2, Integer(rx.QSOPoints), 'rescore replaces stale points');
      CheckTrue(rx.DomesticMult, 'rescore gives county credit');
      CheckFalse(rx.PrefixMult, 'no prefix credit any more');
      Sheet.AddQSOToSheets(@rx, False);
      CheckEquals(2, mo.MTotals[AllBands, CW, rmDomestic],
         'the sheet derives AL from the credited rover county');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'explicit X-QSO rescored to zero');
      CheckFalse(rx.DomesticMult, 'explicit X-QSO no county');
      mo.ClearAllMults;
      Sheet.AddQSOToSheets(@rx, False);
      CheckEquals(0, mo.MTotals[AllBands, CW, rmDomestic], 'explicit X-QSO no state');
   finally
      engine.Free;
   end;
end;

procedure TContestAlabamaQPTests.Test_RefusedExchangeKeepsCallKey;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_RefusedExchangeKeepsCallKey');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      (* The matrix exposed this compatibility boundary in the existing
         prefix contests when key derivation moved after parsing. *)
      Contest := ContestHandleOf(CQWPXCW);
      ReleaseActiveContest;
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'CQ WPX requires a serial');
      CheckEquals('W1', string(rx.Prefix), 'a refused exchange retains its call key');
      Contest := ContestHandleOf(SOUTHAMERICANWW);
      ReleaseActiveContest;
      engine.Enter('PY2ABC', '599 SP', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'South American WW refuses this malformed exchange');
      CheckTrue(rx.QTH.Continent = UnknownContinent, 'refusal leaves a partially parsed continent');
      CheckEquals('PY2', string(rx.Prefix), 'key uses the original country lookup on refusal');
   finally
      engine.Free;
   end;
end;

procedure TContestAlabamaQPTests.RunAllTests;
begin
   Test_IdentityAndEligibility;
   Test_DataAndStateKey;
   Test_ScoreAndExport;
   Test_RealEngine;
   Test_RefusedExchangeKeepsCallKey;
end;

end.
