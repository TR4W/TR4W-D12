(* South Carolina QSO Party, issue 111: the sponsor's rules rev. 2.2.26,
   saved in docs/ContestRules/QSOParties/SouthCarolina/. Each assertion
   names the rule it holds. The extra SC state on an in-state county QSO is
   issue 317's second domestic key, pinned with the other parties in
   uTestAdditionalDomesticMultiplier. *)
unit uTestContestSouthCarolinaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestSouthCarolinaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityBandsAndModes;
      procedure Test_PointsByWhoWasWorked;
      procedure Test_InStateTable;
      procedure Test_BonusStations;
      procedure Test_RealEngineAndExports;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestSouthCarolinaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(SC_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('SC-QSO-PARTY is not registered');
      end;
end;

function SCQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := aQTH;
   Result.DomesticQTH := aQTH;
   Result.DomMultQTH := aQTH;
end;

procedure TContestSouthCarolinaQPTests.Test_IdentityBandsAndModes;
var
   party: TContestBase;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   legacy: integer;
   errorMessage: string;
begin
   BeginTest('Test_SouthCarolinaIdentityBandsAndModes');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestSouthCarolinaQP, 'registered South Carolina class');
   CheckTrue(TContestSouthCarolinaQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum');
   CheckEquals('SC-QSO-PARTY', party.CabrilloName, 'rules 15: CONTEST: SC-QSO-PARTY');
   CheckEquals('SC-QSO-PARTY', party.ADIFContestId, 'ADIF identity');
   CheckEquals('South Carolina QSO Party', party.DisplayName, 'display');
   CheckEquals('South Carolina QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('SC', party.HostState, 'host');
   CheckEquals(123, party.WA7BNMId, 'WA7BNM ref');
   CheckEquals('', party.SubmissionEmail, 'rules 13: web upload only');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, '9.2.3: a mobile in a new county is a new station');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode, cfVHFBandsEnabled],
      '9.2: "Multipliers are counted ONCE PER MODE PER BAND"');
   CheckTrue(party.ValidateQTHCount(2, errorMessage), 'a two-county line');
   CheckFalse(party.ValidateQTHCount(3, errorMessage), 'no third county');
   CheckEquals('', CountyFileDifference('SouthCarolina', 'southcarolina_cty.dom',
      'SC-QSO-PARTY-Counties.txt', 46), 'rules 14.1: all 46 county codes and names');
   CheckFalse(party.HasDXMultiplier, '9.2.1: DX is QSO points only');
   CheckFalse(party.HasZoneMultiplier, 'no zones');
   CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
   for band := Low(BandType) to High(BandType) do
      begin
      CheckTrue(party.UsesBand(band) = (band in
         [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2]),
         'rules 3: 160, 80, 40, 20, 15, 10, 6 and 2 m only');
      end;
   for mode := Low(ModeType) to High(ModeType) do
      begin
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         CheckTrue(party.UsesMode(mode, ext) = (mode in [CW, Phone, FM, Digital]),
            '4.3: every digital mode counts, FT8 and FT4 included');
         end;
      end;
   CheckEquals('PH', party.CabrilloModeString(FM, eFM), '4.1: phone is PH, FM included');
   CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), '4.1: PH');
   CheckEquals('CW', party.CabrilloModeString(CW, eCW), '4.2: CW');
   CheckEquals('RY', party.CabrilloModeString(Digital, eFT8), '4.3: RY for digital');
end;

procedure TContestSouthCarolinaQPTests.Test_PointsByWhoWasWorked;
var
   party: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
   mode: ModeType;
begin
   BeginTest('Test_SouthCarolinaPointsByWhoWasWorked');
   station := WithHostAreaTable(NoStation);
   for mode := Low(ModeType) to High(ModeType) do
      begin
      if not (mode in [CW, Phone, FM, Digital]) then
         begin
         Continue;
         end;
      station.InHostState := True;
      party := Make(PartyHandle, station);
      try
         qso := SCQSO('W4CCC', 'CHAR', Band20, mode, eNoMode);
         party.ScoreQSO(qso);
         CheckEquals(2, Integer(qso.QSOPoints), '9.1.1/9.1.2: SC entrant with an SC station, 2');
         qso := SCQSO('W1AW', 'CT', Band20, mode, eNoMode);
         party.ScoreQSO(qso);
         CheckEquals(4, Integer(qso.QSOPoints), '9.1.1/9.1.2: SC entrant with a state, 4');
         qso := SCQSO('VE3AAA', 'ON', Band20, mode, eNoMode);
         party.ScoreQSO(qso);
         CheckEquals(4, Integer(qso.QSOPoints), 'with a province, 4');
         qso := SCQSO('DL1AAA', '', Band20, mode, eNoMode);
         qso.QTHString := 'DX';
         party.ScoreQSO(qso);
         CheckEquals(4, Integer(qso.QSOPoints), 'with DX, 4');
      finally
         party.Free;
      end;
      station.InHostState := False;
      party := Make(PartyHandle, station);
      try
         qso := SCQSO('W4CCC', 'CHAR', Band20, mode, eNoMode);
         party.ScoreQSO(qso);
         CheckEquals(2, Integer(qso.QSOPoints), '9.1.3/9.1.4: out of state, 2 in every mode');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestSouthCarolinaQPTests.Test_InStateTable;
begin
   BeginTest('Test_SouthCarolinaInStateTable');
   CheckEquals('CHAR', InStateMultiplierOf(PartyHandle, 'CHAR'), '9.2.1: each SC county');
   CheckEquals('LEE', InStateMultiplierOf(PartyHandle, 'LEE'), 'Lee, the one three-letter code');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'SC'), '"enter the SC County as the exchange (not SC)"');
   CheckEquals('DC', InStateMultiplierOf(PartyHandle, 'DC'), '5.2: "Washington, D.C. is a multiplier"');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland is its own');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), '14.3: the provinces and territories');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), '9.2.1: DX is QSO points only');
end;

procedure TContestSouthCarolinaQPTests.Test_BonusStations;
var
   party: TContestBase;
   station: TStationContext;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_SouthCarolinaBonusStations');
   LoadCountyTable('southcarolina_cty.dom', True);
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
      CheckEquals(70, party.FinalScore(totals, view), '9.4: QSO points x multipliers');
      (* 9.3's own example: four counties on 40 m CW pay once. *)
      view.Add(SCQSO('WW4SF/CHAR', 'CHAR', Band40, CW, eCW));
      view.Add(SCQSO('WW4SF/GVIL', 'GVIL', Band40, CW, eCW));
      view.Add(SCQSO('WW4SF/JASP', 'JASP', Band40, CW, eCW));
      view.Add(SCQSO('WW4SF/HORR', 'HORR', Band40, CW, eCW));
      CheckEquals(250, party.BonusPoints(totals, view), '9.3: WW4SF once on 40 m CW');
      view.Add(SCQSO('WW4SF', 'CHAR', Band40, Phone, eLSB));
      view.Add(SCQSO('WW4SF', 'CHAR', Band40, Digital, eFT8));
      CheckEquals(750, party.BonusPoints(totals, view), '"Likewise for all three modes"');
      view.Add(SCQSO('W4CAE', 'RICH', Band20, CW, eCW));
      view.Add(SCQSO('K4YTZ', 'YORK', Band20, CW, eCW));
      CheckEquals(1350, party.BonusPoints(totals, view), 'W4CAE 350, K4YTZ 250');
      qso := SCQSO('W4CAE', 'RICH', Band15, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      view.Add(SCQSO('W4CAE', 'RICH', Band30, CW, eCW));
      view.Add(SCQSO('W4CAE/M', 'RICH', Band10, CW, eCW));
      CheckEquals(1350, party.BonusPoints(totals, view),
         'no pay for a dupe, an X-QSO, an off-band QSO or a /M call');
      CheckEquals(1420, party.FinalScore(totals, view), '9.4: bonus points added after multiplying');
   finally
      view.Free;
      party.Free;
      FreeCountyTable;
   end;
end;

procedure TContestSouthCarolinaQPTests.Test_RealEngineAndExports;
var
   engine: TQSOPartyEngine;
   party: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   accepted, dupe: boolean;
   line: string;
begin
   BeginTest('Test_SouthCarolinaRealEngineAndExports');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(46, mo.DomList.Count, 'outside SC: the 46 counties');
      engine.Enter('W4AAA', '599 CHAR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'out of state, 2');
      engine.Enter('W4AAA', '599 CHAR', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'per mode: the county again on digital');
      dupe := engine.Enter('W4AAA', '599 CHAR', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(dupe, '9.1.2: FT8 after RTTY on one band is a dupe');
      engine.Enter('W4AAA', '599 CHAR', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'per band: the county again on 40 m');
      dupe := engine.Enter('W4AAA', '599 RICH', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, '9.2.3: a mobile in a new county is a new station');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, '9.5: outside SC, work SC stations only');
      ClearPendingCounties;
      engine.Enter('W4LINE', '599 YORK/UNIO', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '12: a county line, logged as separate contacts');
      CheckEquals(1, PendingCountiesCount, 'the second county queued');
      ClearPendingCounties;
      engine.Enter('W4OFF', '599 SUMT', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'rules 3: 30 m is not an SC band');

      engine.Activate(True);
      CheckEquals(110, mo.DomList.Count, '46 counties + 50 states + DC + 13 provinces');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in state works everyone: a state');
      CheckEquals(4, Integer(rx.QSOPoints), 'a station outside SC, 4');
      engine.Enter('W4BBB', '599 CHAR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'an SC county');
      CheckEquals(2, Integer(rx.QSOPoints), 'another SC station, 2');
      engine.Enter('W4CCC', '599 SC', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an SC station sends its county, not SC');
      engine.Enter('W3AAA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC is a multiplier');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'DX accepted');
      CheckEquals(4, Integer(rx.QSOPoints), 'DX outside SC, 4');
      CheckFalse(rx.DomesticMult, 'DX is QSO points only');
      CheckFalse(rx.DXMult, 'no DXCC multiplier');
      (* THE DX ROW EXPORTED (review H4): the record the engine logged, the
         exporter's own HisQTH. 5.4: DX sends "Signal report and DX" -- the
         column was EMPTY while the class used CabrilloReceivedRSTQTHDX. *)
      my := Default(TMyStationExchange);
      my.MyState := 'MARI';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := CabrilloReceivedQTH(True, rx);
      party := ContestIdentity(PartyHandle);
      line := 'QSO: 14000 CW 2026-02-28 1813 KN4QD ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'DL1AAA ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2026-02-28 1813 KN4QD 599 MARI   DL1AAA 599 DX     ',
         line, 'a DX station''s received column is DX, typed ' + string(rx.QTHString));

      party := ContestIdentity(PartyHandle);
      rx := SCQSO('KI4HPX', 'RICH', Band20, CW, eCW);
      rx.RSTSent := 599;
      my := Default(TMyStationExchange);
      my.MyState := 'MARI';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'RICH';
      line := 'QSO: 14000 CW 2026-02-28 1813 KN4QD ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'KI4HPX ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2026-02-28 1813 KN4QD 599 MARI   KI4HPX 599 RICH   ',
         line, 'complete Cabrillo columns, as rules 15');
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals(2, Integer(rx.QSOPoints), 'imported points recomputed');
      rx.ceXQSO := True;
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'X-QSO rescores to zero');
      CheckFalse(rx.DomesticMult, 'X-QSO earns no multiplier');
   finally
      engine.Free;
   end;
end;

procedure TContestSouthCarolinaQPTests.RunAllTests;
begin
   Test_IdentityBandsAndModes;
   Test_PointsByWhoWasWorked;
   Test_InStateTable;
   Test_BonusStations;
   Test_RealEngineAndExports;
end;

end.
