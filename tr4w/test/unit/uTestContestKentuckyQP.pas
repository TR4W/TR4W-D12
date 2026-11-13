(* Kentucky #110: NY4I-approved 2027 draft; extra KY state belongs to #317. *)
unit uTestContestKentuckyQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestKentuckyQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndScoring;
      procedure Test_PowerAndBonus;
      procedure Test_RealEngineAndExports;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestKentuckyQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(KY_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('KY-QSO-PARTY is not registered');
      end;
end;

function KYQSO(const aCall: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'FAY';
   Result.DomesticQTH := 'FAY';
   Result.DomMultQTH := 'FAY';
end;

procedure TContestKentuckyQPTests.Test_IdentityAndScoring;
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
   BeginTest('Test_KentuckyIdentityAndScoring');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestKentuckyQP, 'registered Kentucky class');
   CheckTrue(TContestKentuckyQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum');
   CheckEquals('KY-QSO-PARTY', party.CabrilloName, 'DXLog Cabrillo identity');
   CheckEquals('KY-QSO-PARTY', party.ADIFContestId, 'independent ADIF identity');
   CheckEquals('Kentucky QSO Party', party.DisplayName, 'display');
   CheckEquals('Kentucky QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('KY', party.HostState, 'host');
   CheckEquals(371, party.WA7BNMId, 'WA7BNM ref');
   CheckEquals('', party.SubmissionEmail, 'online submission');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'received county in dupe key');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled], 'multipliers overall');
   CheckTrue(party.ValidateQTHCount(3, errorMessage), 'no numeric received county-line cap stated');
   CheckEquals('', CountyFileDifference('Kentucky', 'kentucky_cty.dom',
      'KY-QSO-PARTY-Counties.txt', 120), 'all sponsor county codes and names');
   CheckEquals('DC', InStateMultiplierOf(PartyHandle, 'DC'), 'DC separate from Maryland');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), '13-province list');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'KY'), 'KY must send county');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX points only, not a multiplier');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckFalse(party.HasDXMultiplier, 'no DXCC multipliers');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band80, Band40, Band20, Band15, Band10, Band6, Band2]), 'draft seven bands, no 160');
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode = CW then
                  begin
                  expected := 2;
                  end;
               if mode in [Phone, FM] then
                  begin
                  expected := 1;
                  end;
               qso := KYQSO('N4TY', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'draft CW two, phone one, no digital');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'all mode/submode eligibility');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestKentuckyQPTests.Test_PowerAndBonus;
var
   party: TContestBase;
   station: TStationContext;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_KentuckyPowerAndBonus');
   LoadCountyTable('kentucky_cty.dom', False);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 10;
      totals.Mults[AllBands, Both, rmDomestic] := 7;
      CheckEquals(0, party.BonusPoints(totals, view), 'no automatic submission bonus');
      view.Add(KYQSO('K4KCG/FAY', Band20, CW, eCW));
      view.Add(KYQSO('K4KCG/SCO', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'same band/mode, two counties, one bonus');
      view.Add(KYQSO('K4KCG', Band40, CW, eCW));
      view.Add(KYQSO('K4KCG', Band20, Phone, eUSB));
      view.Add(KYQSO('K4KCG', Band20, FM, eFM));
      view.Add(KYQSO('K4KCG', Band20, Digital, eFT8));
      view.Add(KYQSO('K4KCG', Band160, CW, eCW));
      view.Add(KYQSO('K4KCGX', Band15, CW, eCW));
      qso := KYQSO('K4KCG', Band15, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      CheckEquals(300, party.BonusPoints(totals, view), 'three credited band/mode pairs only');
      station.MyPower := cpHIGH;
      party.SetStation(station);
      CheckEquals(370, party.FinalScore(totals, view), 'HP factor one, bonus after multiplication');
      station.MyPower := cpLOW;
      party.SetStation(station);
      CheckEquals(440, party.FinalScore(totals, view), 'LP factor two');
      station.MyPower := cpQRP;
      party.SetStation(station);
      CheckEquals(510, party.FinalScore(totals, view), 'QRP factor three');
   finally
      view.Free;
      party.Free;
      FreeCountyTable;
   end;
end;

procedure TContestKentuckyQPTests.Test_RealEngineAndExports;
var
   engine: TQSOPartyEngine;
   party: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   accepted, dupe: boolean;
   line: string;
begin
   BeginTest('Test_KentuckyRealEngineAndExports');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(120, mo.DomList.Count, 'outside county count');
      engine.Enter('K4KCG', '599 FAY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW two points');
      engine.Enter('K4KCG', '59 FAY', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'county once across bands and modes');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone one point');
      dupe := engine.Enter('K4KCG', '599 SCO', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'same bare call, different county');
      dupe := engine.Enter('K4KCG', '599 SCO', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'same county repeated');
      engine.Enter('N4ROV/FAY', '599 FAY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'suffixed rover county accepted');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside entrant cannot work CT');
      engine.Enter('N4BAD', '599 BAD', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'invalid county');
      ClearPendingCounties;
      engine.Enter('N4LINE', '599 ADA/ALL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'received county line accepted');
      CheckEquals(1, PendingCountiesCount, 'second county queued separately');
      ClearPendingCounties;
      engine.Enter('N4DIG', '599 AND', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'digital record may be retained');
      CheckTrue(LoggedQSOIsXQSO(rx), 'digital is an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'digital earns no county');
      engine.Enter('N4DIG', '599 AND', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'digital did not mark county worked');
      engine.Enter('N4OFF', '599 BAL', Band160, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '160 m excluded by draft');
      engine.Enter('N4OFF', '599 BAL', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'off-band did not mark county');

      engine.Activate(True);
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in-state works CT');
      engine.Enter('VE1AAA', '599 NS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in-state works province');
      engine.Enter('W3AAA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC independent multiplier');
      engine.Enter('W3BBB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Maryland distinct');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'typed DX accepted for points');
      CheckEquals(2, Integer(rx.QSOPoints), 'DX CW points');
      CheckFalse(rx.DomesticMult, 'no DX multiplier');
      CheckFalse(rx.DXMult, 'no DXCC multiplier');

      party := ContestIdentity(PartyHandle);
      rx := KYQSO('K4KCG', Band20, CW, eCW);
      rx.RSTSent := 599;
      my := Default(TMyStationExchange);
      my.MyState := 'PA';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'FAY';
      line := 'QSO: 14000 CW 2027-06-05 1300 W3AAA ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'K4KCG ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2027-06-05 1300 W3AAA 599 PA     K4KCG 599 FAY    ',
         line, 'complete Cabrillo columns');
      CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF sent');
      engine.Activate(True);
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals(2, Integer(rx.QSOPoints), 'imported points recomputed');
      CheckTrue(rx.DomesticMult, 'imported county credit');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'X-QSO rescores to zero');
      CheckFalse(rx.DomesticMult, 'X-QSO earns no county');
   finally
      engine.Free;
   end;
end;

procedure TContestKentuckyQPTests.RunAllTests;
begin
   Test_IdentityAndScoring;
   Test_PowerAndBonus;
   Test_RealEngineAndExports;
end;

end.
