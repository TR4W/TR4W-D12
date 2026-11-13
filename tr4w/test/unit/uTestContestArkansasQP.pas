(* Arkansas #115: current sponsor rules and independently saved county data. *)
unit uTestContestArkansasQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestArkansasQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndPoints;
      procedure Test_TablesAndBonus;
      procedure Test_RealEngineAndExports;
   end;

implementation

uses
   SysUtils, VC, uContestBase, uContestRegistry, uContestFactory,
   uContestStateQSOPartyBase, uContestArkansasQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(AR_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('AR-QSO-PARTY is not registered');
      end;
end;

function ARQSO(const aCall: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'BEN';
   Result.DomesticQTH := 'BEN';
   Result.DomMultQTH := 'BEN';
end;

procedure TContestArkansasQPTests.Test_IdentityAndPoints;
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
   BeginTest('Test_ArkansasIdentityAndPoints');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestArkansasQP, 'registered class');
   CheckTrue(TContestArkansasQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckEquals('AR-QSO-PARTY', party.CabrilloName, 'DXLog Cabrillo identity');
   CheckEquals('AR-QSO-PARTY', party.ADIFContestId, 'independent ADIF identity');
   CheckEquals('Arkansas QSO Party', party.DisplayName, 'display name');
   CheckEquals('Arkansas QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('AR', party.HostState, 'host');
   CheckEquals(132, party.WA7BNMId, 'WA7BNM ref');
   CheckEquals('', party.SubmissionEmail, 'online only; contact email is not log submission');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled], 'overall multipliers');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'received rover county is in dupe key');
   CheckTrue(party.ValidateQTHCount(4, errorMessage), 'sponsor imposes radius, no numeric cap');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckFalse(party.HasDXMultiplier, 'one domestic DX key, no DXCC sheet');
         CheckFalse(party.HasPrefixMultiplier, 'no additional AR state key');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2]), 'eight bands');
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode in [CW, Phone, FM, Digital] then
                  begin
                  expected := 1;
                  end;
               qso := ARQSO('K5ABC', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'fixed entrant one point, any credited mode');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'mode policy');
               qso.Band := Band30;
               party.ScoreQSO(qso);
               CheckEquals(0, Integer(qso.QSOPoints), 'off-band zero points');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestArkansasQPTests.Test_TablesAndBonus;
var
   party: TContestBase;
   station: TStationContext;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_ArkansasTablesAndBonus');
   CheckEquals('', CountyFileDifference('Arkansas', 'arkansas_cty.dom',
      'AR-QSO-PARTY-Counties.txt', 75), 'all 75 sponsor county codes and names');
   CheckEquals('CON', InStateMultiplierOf(PartyHandle, 'CON'), 'Conway county');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'Connecticut distinct');
   CheckEquals('MIS', InStateMultiplierOf(PartyHandle, 'MIS'), 'Mississippi county');
   CheckEquals('MS', InStateMultiplierOf(PartyHandle, 'MS'), 'Mississippi state distinct');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC sends Maryland');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'AR'), 'host state expressly excluded');
   CheckEquals('DX', InStateMultiplierOf(PartyHandle, 'DX'), 'one DX multiplier');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'Newfoundland and Labrador');
   station := WithHostAreaTable(NoStation);
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      CheckEquals(0, party.BonusPoints(totals, view), 'empty log');
      view.Add(ARQSO('WR5P/BEN', Band20, CW, eCW));
      view.Add(ARQSO('WR5P/ARK', Band20, CW, eCW));
      CheckEquals(400, party.BonusPoints(totals, view), 'each valid county QSO pays, same band and mode');
      view.Add(ARQSO('WR5P', Band40, Phone, eLSB));
      view.Add(ARQSO('WR5PX', Band20, CW, eCW));
      view.Add(ARQSO('WR5P/M', Band20, CW, eCW));
      qso := ARQSO('WR5P', Band15, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      view.Add(ARQSO('WR5P', Band30, CW, eCW));
      CheckEquals(600, party.BonusPoints(totals, view), 'dupes, X-QSOs, off-band and different calls excluded');
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 10;
      totals.Mults[AllBands, Both, rmDomestic] := 7;
      CheckEquals(670, party.FinalScore(totals, view), 'points x multipliers plus bonus');
      station.InHostState := True;
      party.SetStation(station);
      CheckEquals(670, party.FinalScore(totals, view), 'same formula inside AR, no power factor');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestArkansasQPTests.Test_RealEngineAndExports;
var
   engine: TQSOPartyEngine;
   party: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   accepted, dupe: boolean;
   line: string;
begin
   BeginTest('Test_ArkansasRealEngineAndExports');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(75, mo.DomList.Count, 'outside counts only 75 counties');
      dupe := engine.Enter('WR5P', '599 BEN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'county accepted');
      CheckFalse(dupe, 'first QSO');
      CheckTrue(rx.DomesticMult, 'first county');
      CheckEquals(1, Integer(rx.QSOPoints), 'CW one point');
      engine.Enter('WR5P', '59 BEN', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'county once across bands and modes');
      dupe := engine.Enter('WR5P', '599 ARK', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'same call, new county');
      CheckTrue(rx.DomesticMult, 'new county');
      dupe := engine.Enter('WR5P', '599 ARK', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'same county repeated');
      CheckEquals(0, Integer(rx.QSOPoints), 'dupe zero points');
      engine.Enter('W1AAA', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work outside');
      engine.Enter('K5BAD', '599 BAD', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'invalid county');
      engine.Enter('K5BAD', '', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'missing exchange');
      ClearPendingCounties;
      engine.Enter('K5LINE', '599 GAR/NEW', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'received county line accepted');
      CheckEquals(1, PendingCountiesCount, 'second county queued as separate QSO');
      ClearPendingCounties;
      engine.Enter('K5WARC', '599 CAL', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'off-band record retained');
      CheckTrue(LoggedQSOIsXQSO(rx), 'automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'off-band earns no county');
      engine.Enter('K5WARC', '599 CAL', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'off-band did not mark county worked');
      engine.Enter('K5DIG', '599 CLE', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'digital full exchange');
      dupe := engine.Enter('K5DIG', '599 CLE', Band20, Digital, ePSK31, accepted, rx);
      CheckTrue(dupe, 'digital submodes one group');

      engine.Activate(True);
      CheckEquals(138, mo.DomList.Count, '75 + 49 + 13 + DX');
      engine.Enter('K5AAA', '599 BEN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'inside works county');
      CheckFalse(rx.PrefixMult, 'no extra AR state');
      engine.Enter('W1AAA', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'inside works state');
      engine.Enter('VE1AAA', '599 NS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'inside works province');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'typed DX accepted and credited');
      engine.Enter('JA1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'second DX accepted');
      CheckFalse(rx.DomesticMult, 'all DX one multiplier');
      engine.Enter('K5BAD', '599 AR', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'AR must send county');

      party := ContestIdentity(PartyHandle);
      rx := ARQSO('W1AW', Band20, CW, eCW);
      rx.QTHString := 'CT';
      rx.DomesticQTH := 'CT';
      rx.DomMultQTH := 'CT';
      my := Default(TMyStationExchange);
      my.MyState := 'BEN';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CT';
      line := 'QSO: 14000 CW 2026-05-16 1400 WR5P ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'W1AW ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2026-05-16 1400 WR5P 599 BEN    W1AW 599 CT     ', line,
         'complete report/location columns');
      rx.RSTSent := 599;
      CheckEquals('599 BEN    ', party.FormatADIFSentExchange(my, rx), 'ADIF full sent exchange');
      my.MyState := '';
      CheckEquals('599 DX     ', party.FormatCabrilloSentExchange(my, rx, ctx), 'DX entrant sends DX');
      engine.Activate(True);
      rx := ARQSO('K5IMPORT/GAR', Band20, CW, eCW);
      rx.QTHString := 'GAR';
      rx.DomesticQTH := 'GAR';
      rx.DomMultQTH := 'GAR';
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals(1, Integer(rx.QSOPoints), 'rescore replaces imported stale points');
      CheckTrue(rx.DomesticMult, 'rescore county credit');
      CheckFalse(rx.PrefixMult, 'rescore does not invent AR state credit');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'rescored X-QSO zero points');
      CheckFalse(rx.DomesticMult, 'rescored X-QSO no multiplier');
   finally
      engine.Free;
   end;
end;

procedure TContestArkansasQPTests.RunAllTests;
begin
   Test_IdentityAndPoints;
   Test_TablesAndBonus;
   Test_RealEngineAndExports;
end;

end.
