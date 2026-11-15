(* Iowa QSO Party, issue 120: the sponsor's 2026 rules, saved in
   docs/ContestRules/QSOParties/Iowa/. The extra IA state on an in-state
   county QSO is issue 317's second domestic key, pinned with the other
   parties in uTestAdditionalDomesticMultiplier. *)
unit uTestContestIowaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestIowaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IdentityAndScoring;
      procedure Test_InStateTable;
      procedure Test_Score;
      procedure Test_RealEngineAndExports;
   end;

implementation

uses
   SysUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestIowaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uMults, LogEdit, LogStuff,
   uPendingCounties, PostUnit, MainUnit;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(IA_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('IA-QSO-PARTY is not registered');
      end;
end;

function IAQSO(const aCall: string; aBand: BandType; aMode: ModeType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := PartyHandle;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'STR';
   Result.DomesticQTH := 'STR';
   Result.DomMultQTH := 'STR';
end;

procedure TContestIowaQPTests.Test_IdentityAndScoring;
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
   BeginTest('Test_IowaIdentityAndScoring');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestIowaQP, 'registered Iowa class');
   CheckTrue(TContestIowaQP.ClassParent = TContestStateQSOPartyBase, 'direct party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum');
   CheckEquals('IA-QSO-PARTY', party.CabrilloName, 'DXLog IAQP.txt Cabrillo identity');
   CheckEquals('IA-QSO-PARTY', party.ADIFContestId, 'ADIF identity');
   CheckEquals('Iowa QSO Party', party.DisplayName, 'display');
   CheckEquals('Iowa QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('IA', party.HostState, 'host');
   CheckEquals('', party.SubmissionEmail, 'logs are uploaded');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, '"ONCE per MODE per BAND per COUNTY"');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
      '"Multipliers are applied one time only, NOT per Band, and NOT per Mode"');
   CheckTrue(party.ValidateQTHCount(4, errorMessage),
      '"All intersecting counties may be worked in a single exchange"');
   CheckEquals('', CountyFileDifference('Iowa', 'iowa_cty.dom',
      'IA-QSO-PARTY-Counties.txt', 99), 'all 99 sponsor county codes and names');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      party := Make(PartyHandle, station);
      try
         CheckFalse(party.HasDXMultiplier, '"No multiplier for working DX stations"');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2, Band222, Band432,
                Band902, Band1296, Band2304, Band3456, Band5760, Band10G, Band24G]),
               '"any amateur band EXCEPT the 60m, 30m, 17m, and 12m bands"');
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
               if (mode = Digital) and
                  not (ext in [eFT8, eFT4, eJT65, eFST4, eFST4W]) then
                  begin
                  expected := 2;
                  end;
               qso := IAQSO('K0AAA', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints),
                  'phone 1, CW and digital 2, no WSJT-X');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'mode and submode eligibility');
               end;
            end;
      finally
         party.Free;
      end;
      end;
end;

procedure TContestIowaQPTests.Test_InStateTable;
begin
   BeginTest('Test_IowaInStateTable');
   CheckEquals('STR', InStateMultiplierOf(PartyHandle, 'STR'), 'an Iowa county is its own multiplier');
   CheckEquals('IOW', InStateMultiplierOf(PartyHandle, 'IOW'), 'Iowa County, not the state');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'IA'), 'an Iowa station sends its county, never IA');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'the sponsor list: "MD Maryland and DC"');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), 'the 13 provinces');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is points only');
end;

procedure TContestIowaQPTests.Test_Score;
var
   party: TContestBase;
   station: TStationContext;
   totals: TScoreTotals;
   view: TLoggedQSOList;
begin
   BeginTest('Test_IowaScore');
   station := WithHostAreaTable(NoStation);
   party := Make(PartyHandle, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 10;
      totals.Mults[AllBands, Both, rmDomestic] := 7;
      view.Add(IAQSO('W0YL', Band20, CW, eCW));
      CheckEquals(70, party.FinalScore(totals, view), 'QSO points x multipliers, no bonus');
      station.MyPower := cpQRP;
      party.SetStation(station);
      CheckEquals(70, party.FinalScore(totals, view), 'QRP is a class, not a factor');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestIowaQPTests.Test_RealEngineAndExports;
var
   engine: TQSOPartyEngine;
   party: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   accepted, dupe: boolean;
   line: string;
begin
   BeginTest('Test_IowaRealEngineAndExports');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(99, mo.DomList.Count, 'outside Iowa: the 99 counties');
      engine.Enter('W0YL', '599 STR', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW 2 points');
      engine.Enter('W0YL', '59 STR', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(rx.DomesticMult, 'a county once, not per band or mode');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone 1 point');
      dupe := engine.Enter('W0YL', '599 MSL', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'a mobile in a new county is a new station');
      dupe := engine.Enter('W0YL', '599 MSL', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'the same county, band and mode again is a dupe');
      engine.Enter('W0ROV/HDN', '599 HDN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a county-suffixed rover call');
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside Iowa, work Iowa stations only');
      engine.Enter('W0BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not an Iowa county');
      ClearPendingCounties;
      engine.Enter('W0LINE', '599 STR/MSL/HDN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'the rules'' own three-county example');
      CheckEquals(2, PendingCountiesCount, 'each further county is its own QSO');
      ClearPendingCounties;
      engine.Enter('W0FT', '599 POL', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'WSJT-X FT8 cannot pass the exchange: an automatic X-QSO');
      CheckFalse(rx.DomesticMult, 'and it earns no county');
      engine.Enter('W0JS', '599 POL', Band20, Digital, eJS8, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'JS8 counts, and the FT8 QSO marked nothing');
      CheckEquals(2, Integer(rx.QSOPoints), 'digital 2 points');
      engine.Enter('W0OFF', '599 LIN', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '30 m is excluded');
      engine.Enter('W0OFF', '599 LIN', Band432, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '70 cm counts');

      engine.Activate(True);
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'in state works everyone: a state');
      engine.Enter('VE3AAA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('W3AAA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC is Maryland');
      engine.Enter('W3BBB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'Maryland accepted');
      CheckFalse(rx.DomesticMult, 'and already worked as DC');
      engine.Enter('W0CCC', '599 IA', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an Iowa station sends its county');
      engine.Enter('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'DX accepted');
      CheckEquals(2, Integer(rx.QSOPoints), 'DX CW 2 points');
      CheckFalse(rx.DomesticMult, 'no multiplier for DX');
      CheckFalse(rx.DXMult, 'no DXCC multiplier');

      party := ContestIdentity(PartyHandle);
      rx := IAQSO('W0YL', Band20, CW, eCW);
      rx.RSTSent := 599;
      my := Default(TMyStationExchange);
      my.MyState := 'PA';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'STR';
      line := 'QSO: 14000 CW 2026-09-19 1400 W3AAA ' +
         party.FormatCabrilloSentExchange(my, rx, ctx) + 'W0YL ' +
         party.FormatCabrilloReceivedExchange(my, rx, ctx);
      CheckEquals('QSO: 14000 CW 2026-09-19 1400 W3AAA 599 PA     W0YL 599 STR    ',
         line, 'complete Cabrillo columns');
      CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF sent');
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

procedure TContestIowaQPTests.RunAllTests;
begin
   Test_IdentityAndScoring;
   Test_InStateTable;
   Test_Score;
   Test_RealEngineAndExports;
end;

end.
