(* Kansas QSO Party, issue 121: the sponsor's 2026 rules, saved in
   docs/ContestRules/QSOParties/Kansas/. Each assertion names the rule it
   holds; the class header quotes them. *)
unit uTestContestKansasQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestKansasQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndScoring;
      procedure Test_InStateTable;
      procedure Test_ScoreAndBonus;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineInStateAndExports;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestKansasQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(KS_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('KS-QSO-PARTY is not registered');
      end;
end;

function KSQSO(const aCall: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'ALL';
   Result.DomesticQTH := 'ALL';
   Result.DomMultQTH := 'ALL';
end;

procedure TContestKansasQPTests.Test_IdentityAndScoring;
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
   BeginTest('Test_KansasIdentityAndScoring');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestKansasQP, 'registered Kansas class');
   CheckTrue(TContestKansasQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum');
   CheckEquals('KS-QSO-PARTY', party.CabrilloName, 'DXLog KSQP.txt Cabrillo identity');
   CheckEquals('KS-QSO-PARTY', party.ADIFContestId, 'ADIF identity');
   CheckEquals('Kansas QSO Party', party.DisplayName, 'display');
   CheckEquals('Kansas QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('KS', party.HostState, 'host');
   CheckEquals('', party.SubmissionEmail, 'logs are uploaded, not e-mailed');
   CheckTrue(party.DupeKeyIncludesReceivedQTH,
      'rule 10: a Kansas station that changes county is a new station');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
      '"Multipliers are counted only once": no band or mode repeat');
   CheckTrue(party.ValidateQTHCount(3, errorMessage), 'rule 11: no county-line limit stated');
   CheckEquals('', CountyFileDifference('Kansas', 'kansas_cty.dom',
      'KS-QSO-PARTY-Counties.txt', 105, 'Ks'), 'all 105 sponsor county codes and names, each mapped to Ks');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckFalse(party.HasDXMultiplier, 'the one DX multiplier is a domestic entry');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band80, Band40, Band20, Band15, Band10, Band6]),
               '80, 40, 20, 15, 10 and 6 m; no WARC, 160 or 2 m');
            end;
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode = CW then
                  begin
                  expected := 3;
                  end;
               if mode in [Phone, FM] then
                  begin
                  expected := 2;
                  end;
               if (mode = Digital) and
                  (ext in [eNoMode, eData, eData_R, eRTTY, eRTTY_R]) then
                  begin
                  expected := 3;
                  end;
               qso := KSQSO('K0AAA', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints),
                  'phone 2, CW and RTTY 3; FT4/8 is a separate log');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'mode and submode eligibility');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestKansasQPTests.Test_InStateTable;
begin
   BeginTest('Test_KansasInStateTable');
   CheckEquals('KS', InStateMultiplierOf(PartyHandle, 'ALL'),
      'the first Kansas county logged counts as the Kansas multiplier');
   CheckEquals('KS', InStateMultiplierOf(PartyHandle, 'WYA'), 'every county is Kansas in state');
   CheckEquals('KS', InStateMultiplierOf(PartyHandle, 'LAB'), 'Labette, not Labrador');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'KS'), '"The KS abbreviation is not used"');
   CheckEquals('CO', InStateMultiplierOf(PartyHandle, 'CO'), 'a state');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'the 13 provinces, NL spelled as the rules');
   CheckEquals('YT', InStateMultiplierOf(PartyHandle, 'YT'), 'territories count');
   CheckEquals('DX', InStateMultiplierOf(PartyHandle, 'DX'), 'DX (1)');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DC'), 'the rules count 50 states; DC is not one');
end;

procedure TContestKansasQPTests.Test_ScoreAndBonus;
var
   party: TContestBase;
   station: TStationContext;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_KansasScoreAndBonus');
   LoadCountyTable('kansas_cty.dom', True);
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
      CheckEquals(70, party.FinalScore(totals, view), 'QSO points x multipliers, no power factor');
      qso := KSQSO('KS0KS', Band15, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      CheckEquals(0, party.BonusPoints(totals, view), 'a dupe or X-QSO with KS0KS pays nothing');
      view.Add(KSQSO('KS0KSX', Band20, CW, eCW));
      CheckEquals(0, party.BonusPoints(totals, view), 'only KS0KS itself');
      view.Add(KSQSO('KS0KS', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'KS0KS pays 100');
      view.Add(KSQSO('KS0KS', Band40, Phone, eUSB));
      view.Add(KSQSO('KS0KS', Band20, Digital, eRTTY));
      CheckEquals(100, party.BonusPoints(totals, view), '"a one-time bonus ... maximum 100"');
      station.MyPower := cpQRP;
      party.SetStation(station);
      CheckEquals(170, party.FinalScore(totals, view), 'bonus added after multiplying; QRP has no factor');
   finally
      view.Free;
      party.Free;
      FreeCountyTable;
   end;
end;

procedure TContestKansasQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted, dupe: boolean;
begin
   BeginTest('Test_KansasRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(105, mo.DomList.Count, 'each of the 105 counties is a multiplier outside Kansas');
      engine.Enter('K0AAA', '599 ALL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'county accepted and credited');
      CheckEquals(3, Integer(rx.QSOPoints), 'CW 3 points');
      dupe := engine.Enter('K0AAA', '599 ALL', Band20, Digital, eRTTY, accepted, rx);
      CheckFalse(dupe, 'once on CW and once on RTTY per band');
      CheckTrue(accepted, 'RTTY accepted');
      CheckEquals(3, Integer(rx.QSOPoints), 'RTTY 3 points');
      CheckFalse(rx.DomesticMult, 'a county counts only once, whatever the mode');
      engine.Enter('K0AAA', '59 ALL', Band40, Phone, eLSB, accepted, rx);
      CheckEquals(2, Integer(rx.QSOPoints), 'phone 2 points');
      CheckFalse(rx.DomesticMult, 'a county counts only once, whatever the band');
      dupe := engine.Enter('K0AAA', '599 ALL', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'the same county on the same band and mode is a dupe');
      dupe := engine.Enter('K0AAA', '599 AND', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'rule 10: in a new county the station is new');
      engine.Enter('K0ROV/ATC', '599 ATC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a county-suffixed rover call');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside Kansas, work Kansas stations only');
      engine.Enter('K0KS', '599 KS', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, '"The KS abbreviation is not used"');
      engine.Enter('K0BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a Kansas county');
      ClearPendingCounties;
      engine.Enter('K0LINE', '599 BAR/BUT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'rule 11: a county line is accepted');
      CheckEquals(1, PendingCountiesCount, 'and the second county is its own QSO');
      ClearPendingCounties;
      engine.Enter('K0FT', '599 BRO', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'FT8 belongs in the separate FT4/8 log: an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'and it earns no county');
      engine.Enter('K0OFF', '599 BRO', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'WARC contacts do not count');
      engine.Enter('K0OFF', '599 BRO', Band2, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '2 m is not a Kansas QSO Party band');
      engine.Enter('K0OFF', '599 BRO', Band6, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '6 m counts; the off-mode and off-band QSOs marked nothing');
   finally
      engine.Free;
   end;
end;

procedure TContestKansasQPTests.Test_RealEngineInStateAndExports;
var
   engine: TQSOPartyEngine;
   party: TContestBase;
   station: TStationContext;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   accepted: boolean;
   line: string;
begin
   BeginTest('Test_KansasRealEngineInStateAndExports');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckEquals(64, mo.DomList.Count, '"maximum of 64 multipliers": 50 states, 13 provinces, DX');
      engine.Enter('K0AAA', '599 ALL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'the first Kansas county is the Kansas multiplier');
      engine.Enter('K0BBB', '599 AND', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a second county is accepted');
      CheckFalse(rx.DomesticMult, 'but is not another multiplier in state');
      engine.Enter('K0CCC', '599 KS', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a Kansas station sends its county, never KS');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in state works everyone: a state');
      engine.Enter('VE3AAA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DX is one multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), 'DX CW 3 points');
      engine.Enter('G3AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'DX counts once');
      CheckFalse(rx.DXMult, 'no DXCC multiplier');
      engine.Enter('W3AAA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'DC is not on the sponsor list');

      party := ContestIdentity(PartyHandle);
      rx := KSQSO('K0AAA', Band20, CW, eCW);
      rx.RSTSent := 599;
      my := Default(TMyStationExchange);
      my.MyState := 'PA';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'ALL';
      line := 'QSO: 14000 CW 2026-08-29 1400 W3AAA ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'K0AAA ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2026-08-29 1400 W3AAA 599 PA     K0AAA 599 ALL    ',
         line, 'complete Cabrillo columns');
      CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF sent');
      station := NoStation;
      station.MyState := '';
      CheckEquals(' 5NN DX', party.CQExchangeDefault(station), 'a DX station sends DX');
      station.MyState := 'ALL';
      CheckEquals(' 5NN ALL', party.CQExchangeDefault(station), 'a Kansas station sends its county');
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals(3, Integer(rx.QSOPoints), 'imported points recomputed');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'X-QSO rescores to zero');
      CheckFalse(rx.DomesticMult, 'X-QSO earns no multiplier');
   finally
      engine.Free;
   end;
end;

procedure TContestKansasQPTests.RunAllTests;
begin
   Test_IdentityAndScoring;
   Test_InStateTable;
   Test_ScoreAndBonus;
   Test_RealEngineOutOfState;
   Test_RealEngineInStateAndExports;
end;

end.
