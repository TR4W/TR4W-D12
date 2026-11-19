(* THE LOUISIANA QSO PARTY -- issue #122 (2026-11-18). The sponsor's rules
   (docs/ContestRules/QSOParties/Louisiana, revised February 18, 2026) and
   NY4I's defaults on the issue: DC counts as Maryland; rule 9.6 is the
   sponsor's checker's. Each test names the rule it holds; the class header
   says where each landed. The multiplier-mode seam rule 9.1 needed is pinned
   for every contest in uTestMultiplierMode; here it is driven through the
   real engine. *)
unit uTestContestLouisianaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestLouisianaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_ParishFileAndInStateFile;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_ScoreAndBonus;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineInState;
      procedure Test_CWAndDigitalAreOneMultiplierMode;
      procedure Test_ExportColumns;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestLouisianaQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults,
   LogStuff, LogDupe, uPendingCounties, uADIF, uContestSchedule,
   (* TC_TOOMANYCOUNTIES *)
   uTR4WStrings,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(LA_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('LA-QSO-PARTY is not registered');
      end;
end;

(* A Louisiana station in parish aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function LAQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
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

function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'ORLE';
      end
   else
      begin
      Result.MyState := 'PA';
      end;
   Result.MyCountry := 'K';
end;

procedure TContestLouisianaQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;
   key: TDateTime;
   overlays: TArray<string>;
begin
   BeginTest('Test_LouisianaIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestLouisianaQP, 'the registered class');
   CheckTrue(TContestLouisianaQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('LA-QSO-PARTY', party.CabrilloName, 'DXLog''s Cabrillo name');
   CheckEquals('LA-QSO-PARTY', party.ADIFContestId, 'the ADIF Contest_ID enumeration''s');
   CheckEquals('Louisiana QSO Party', party.DisplayName, 'display');
   CheckEquals('Louisiana QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('LA', party.HostState, 'host');
   CheckEquals('', party.SubmissionEmail, '10.1: logs are uploaded, not e-mailed');
   CheckEquals(250, party.WA7BNMId, 'issue 122''s research');
   CheckEquals('louisiana_cty', party.DomesticFileName, 'the parish file');
   CheckEquals('louisiana', party.InStateDomesticFileName, 'the in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode, cfVHFBandsEnabled],
             '9.4 per band and mode; 8.2 multipliers "per band/mode"; 6 m and 2 m');
   CheckEquals(2, (party as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '9.4.3 "contacts for both parishes"');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, '9.4.1 rovers "in EACH parish activated"');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');

   (* 9.4 "once on CW/Digital and once on Phone PER BAND" -- two dupe modes;
      9.1 the same two multiplier modes. *)
   CheckTrue(ContestDupeModeOf(party, Digital) = CW, 'digital is CW for dupes');
   CheckTrue(ContestDupeModeOf(party, Phone) = Phone, 'phone is its own');
   CheckTrue(ContestMultiplierModeOf(party, Digital) = CW, 'digital is CW for multipliers');
   CheckTrue(ContestMultiplierModeOf(party, Phone) = Phone, 'phone is its own');

   (* Rule 2: "14:00 UTC April 4, 2026 to 02:00 UTC April 5, 2026"; NY4I,
      issue 122, 2026-11-18: "first weekend of April". 2029 opens April on a
      Sunday: its first weekend is the 7th-8th, never March 31. *)
   CheckEquals('1st Saturday of April at 14:00 UTC for 12h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2026, 1, 1), key), '2026 has a date');
   CheckEquals(DateTimeToStr(EncodeDate(2026, 4, 4) + EncodeTime(14, 0, 0, 0)),
               DateTimeToStr(key), 'rule 2''s 2026 date');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2027, 1, 1), key), '2027 has a date');
   CheckEquals(DateTimeToStr(EncodeDate(2027, 4, 3) + EncodeTime(14, 0, 0, 0)),
               DateTimeToStr(key), '2027: Saturday April 3');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2029, 1, 1), key), '2029 has a date');
   CheckEquals(DateTimeToStr(EncodeDate(2029, 4, 7) + EncodeTime(14, 0, 0, 0)),
               DateTimeToStr(key), '2029: Saturday April 7 (April 1 is a Sunday)');

   (* 5.4: WIRES, TB-WIRES, POTA -- the sponsor's three, in its order
      (NY4I, issue 122, 2026-11-18: "we have to honor it for this contest"). *)
   overlays := party.CabrilloOverlayCategories;
   CheckEquals(3, Length(overlays), '5.4 names three overlays');
   if Length(overlays) = 3 then
      begin
      CheckEquals('WIRES', overlays[0], '5.4.1');
      CheckEquals('TB-WIRES', overlays[1], '5.4.2');
      CheckEquals('POTA', overlays[2], '5.4.3');
      end;
end;

procedure TContestLouisianaQPTests.Test_ParishFileAndInStateFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_LouisianaParishFileAndInStateFile');
   CheckEquals('', CountyFileDifference('Louisiana', 'louisiana_cty.dom',
      'LA-QSO-PARTY-Parishes.txt', 64), 'all 64 sponsor parish codes and names');

   (* THE IN-STATE LIST: parishes first, DC as Maryland, the states, the 13
      provinces, NF and LB as NL. *)
   CheckEquals('ORLE', InStateMultiplierOf(PartyHandle, 'ORLE'), 'a parish is its own multiplier');
   CheckEquals('EBR', InStateMultiplierOf(PartyHandle, 'EBR'), 'East Baton Rouge, a three-letter code');
   CheckEquals('PCP', InStateMultiplierOf(PartyHandle, 'PCP'), 'Pointe Coupee');
   CheckEquals('SJB', InStateMultiplierOf(PartyHandle, 'SJB'), 'St. John Baptist');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC counts as Maryland (NY4I, issue 122, 2026-11-19)');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('TX', InStateMultiplierOf(PartyHandle, 'TX'), 'a state');
   CheckEquals('AK', InStateMultiplierOf(PartyHandle, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(PartyHandle, 'HI'), 'Hawaii is a state');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'),
               'LA is Louisiana, s50 before p13 (the class refuses it as a multiplier)');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NL'), '8.2.3 NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is NL');
   CheckEquals('NS', InStateMultiplierOf(PartyHandle, 'NS'), 'a province');
   CheckEquals('YT', InStateMultiplierOf(PartyHandle, 'YT'), 'a territory');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is the DXCC multiplier, not an entry');

   (* THE FILES AS TEXT: the in-state include list, and no "=" in either
      header. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'louisiana.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE louisiana_cty.dom') >= 0, 'includes the parishes');
      CheckTrue(lines.IndexOf('INCLUDE FILE louisiana_cty.dom') <
                lines.IndexOf('INCLUDE FILE s50.dom'), 'parishes first');
      CheckTrue(lines.IndexOf('Dc > Md = DC') < lines.IndexOf('INCLUDE FILE s50.dom'),
                'DC folded before the states');
      CheckTrue(lines.IndexOf('INCLUDE FILE s50.dom') < lines.IndexOf('INCLUDE FILE p13.dom'),
                's50 before p13, so LA stays Louisiana');
      CheckTrue(lines.IndexOf('Nl = NF,LB') > lines.IndexOf('INCLUDE FILE p13.dom'),
                'NF and LB after the provinces');
      CheckTrue(lines.IndexOf('INCLUDE FILE dc.dom') < 0, 'DC is no multiplier of its own');
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', string(lines[i])) = 1 then
            begin
            Break;
            end;
         CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" in the header: ' + string(lines[i]));
         end;
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'louisiana_cty.dom'));
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the parish file includes nothing');
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestLouisianaQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inHost: boolean;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
   credited: boolean;
begin
   BeginTest('Test_LouisianaBandsModesAndPoints');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         (* 1: "the 160, 80, 40, 20, 15, 10, 6 and 2 meter bands"; 3.4 "No
            WARC band contacts". *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2]),
               'the rules'' bands');
            end;
         (* 8.1 "two (2) points for each complete PHONE QSO", "four (4) points
            for each complete CW/Digital QSO"; 3.3 "any digital mode that
            supports the required exchange". *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               credited := (mode in [CW, Phone, FM]) or
                           ((mode = Digital) and
                            (ext in [eNoMode, eData, eRTTY, eRTTY_R, eJTTY, ePSK31]));
               expected := 0;
               if credited and (mode in [CW, Digital]) then
                  begin
                  expected := 4;
                  end;
               if credited and (mode in [Phone, FM]) then
                  begin
                  expected := 2;
                  end;
               qso := LAQSO('W5AAA', 'ORLE', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'CW/digital 4, phone/FM 2, a digital mode not allowed none');
               CheckTrue(party.UsesMode(mode, ext) = credited,
                         'CW, phone, FM; RTTY, JTTY and PSK31 only (NY4I, 2026-11-19)');
               end;
            end;
         CheckFalse(party.UsesMode(Digital, eFT8), 'FT8 cannot send the exchange');
         CheckFalse(party.UsesMode(Digital, eJT65), 'nor JT65');
         CheckTrue(party.UsesMode(Digital, eRTTY), '3.3 "includes RTTY"');
         CheckTrue(party.UsesMode(Digital, ePSK31), 'PSK31 can send it');
         CheckTrue(party.UsesMode(Digital, eJTTY), 'JTTY is on NY4I''s list');
         CheckTrue(party.UsesMode(Digital, eRTTY_R), 'reversed RTTY is RTTY');
         CheckFalse(party.UsesMode(Digital, eJS8), 'JS8 is not on NY4I''s list');
         CheckFalse(party.UsesMode(Digital, ePSK63), 'nor PSK63');
         CheckFalse(party.UsesMode(Digital, eMFSK), 'nor MFSK');
         CheckFalse(party.UsesMode(Digital, eData_R), 'a radio data mode with no recorded submode is not "some submode"');
         CheckTrue(party.UsesMode(Digital, eNoMode), 'an unknown submode is never proven off-mode');
         CheckEquals('RY', party.CabrilloModeString(Digital, eRTTY), 'RTTY is RY');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestLouisianaQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   inHost: boolean;
   dxKey: DXMultiplierString;
   qso: ContestExchange;
   station: TStationContext;
begin
   BeginTest('Test_LouisianaMultiplierAnswers');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         CheckTrue(party.HasDXMultiplier = inHost, '8.2 DXCC for a Louisiana entrant only');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
         if inHost then
            begin
            CheckTrue(party.CountryMode = ARRLCountryMode, 'DXCC is the ARRL list');
            end;

         qso := LAQSO('DL1AAA', 'DL', Band20, CW, eCW);
         qso.QTH.CountryID := 'DL';
         dxKey := '';
         party.DXMultiplierKey(qso, dxKey);
         if inHost then
            begin
            CheckEquals('DL', string(dxKey), 'Germany is a DXCC multiplier in state');
            qso.QTH.CountryID := 'VE';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Canada is its provinces');
            qso.QTH.CountryID := 'KH6';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Hawaii is a state');
            qso.QTH.CountryID := 'KL';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Alaska is a state');
            end;

         (* 8.2.2 "States (other than Louisiana)": an in-state entrant's LA
            earns no multiplier; a parish and another state do. *)
         CheckTrue(party.CountsAsMultiplier(LAQSO('W5LA', 'La', Band20, CW, eCW), rmDomestic) = not inHost,
                   'LA is no state multiplier for a Louisiana station');
         CheckTrue(party.CountsAsMultiplier(LAQSO('W5AAA', 'ORLE', Band20, CW, eCW), rmDomestic),
                   'a parish is');
         CheckTrue(party.CountsAsMultiplier(LAQSO('W5TX', 'Tx', Band20, CW, eCW), rmDomestic),
                   'another state is');
      finally
         party.Free;
      end;
      end;

   (* THE HOST-AREA RULE (1.2 "Non-Louisiana stations work Louisiana stations
      only") -- judged by the SHIPPED parish file. *)
   LoadCountyTable('louisiana_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(LAQSO('W1AW', 'CT', Band20, CW, eCW)),
                 'outside Louisiana a QSO with CT is not credited');
      CheckTrue(party.CreditsWorkedStation(LAQSO('W5AAA', 'ORLE', Band20, CW, eCW)),
                'a parish is');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* 8.3 POINTS x THE SUM OF THE MULTIPLIERS; 9.5 N5LCC, ONCE. *)
procedure TContestLouisianaQPTests.Test_ScoreAndBonus;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_LouisianaScoreAndBonus');
   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 100;
      totals.Mults[AllBands, Both, rmDomestic] := 10;
      totals.Mults[AllBands, Both, rmDX] := 7;
      CheckEquals(100 * 17, party.CombineScore(totals), 'parishes + states + provinces + DXCC, no cap');
      totals.DigitalQSOPoints := 40;
      CheckEquals(100 * 17, party.CombineScore(totals), 'the digital share changes nothing');

      (* 9.5 "a one-time 100 POINT BONUS. You may contact N5LCC additional
         times but will not receive additional points." *)
      view.Add(LAQSO('N5LCC', 'JEFF', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'N5LCC');
      view.Add(LAQSO('N5LCC', 'JEFF', Band40, Phone, eUSB));
      view.Add(LAQSO('N5LCC', 'JEFF', Band40, Digital, eRTTY));
      CheckEquals(100, party.BonusPoints(totals, view), 'once');
      CheckEquals(100 * 17 + 100, party.FinalScore(totals, view), 'the bonus after multiplication');

      view.Free;
      view := TLoggedQSOList.Create;
      qso := LAQSO('N5LCC', 'JEFF', Band20, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      CheckEquals(0, party.BonusPoints(totals, view), 'a dupe or X-QSO earns no bonus');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestLouisianaQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_LouisianaRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(64, mo.DomList.Count, 'outside Louisiana: the 64 parishes');
      CheckTrue(Settings.Mult.ByBand and Settings.Mult.ByMode, 'multipliers per band and mode');

      engine.Enter('W5AAA', '599 ORLE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a parish accepted and credited');
      CheckEquals(4, Integer(rx.QSOPoints), 'CW 4');
      dupe := engine.Enter('W5AAA', '59 ORLE', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'phone is the other mode');
      CheckTrue(rx.DomesticMult, '9.1 Orleans again on phone: a separate multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), 'phone 2');
      dupe := engine.Enter('W5AAA', '599 ORLE', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, '9.4 once per band and mode');
      dupe := engine.Enter('W5AAA', '599 ORLE', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(dupe, '9.4 "once on CW/Digital": RTTY after CW on one band is a dupe');
      dupe := engine.Enter('W5AAA', '599 ORLE', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'another band');
      CheckTrue(rx.DomesticMult, 'Orleans per band');
      dupe := engine.Enter('W5AAA', '599 JEFF', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, '9.4.1 a rover in each parish activated');

      engine.Enter('W5RY', '599 CADD', Band15, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'an RTTY parish');
      CheckEquals(4, Integer(rx.QSOPoints), 'digital 4');
      CheckFalse(LoggedQSOIsXQSO(rx), 'RTTY is credited');
      (* Q98: an off-mode QSO is LOGGED, scores 0 and is an X-QSO. *)
      engine.Enter('W5FT', '599 BOSS', Band15, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged: ' + string(ExchangeErrorMessage));
      CheckTrue(LoggedQSOIsXQSO(rx), '3.3 FT8 cannot send the exchange');
      CheckEquals(0, Integer(rx.QSOPoints), 'FT8 scores 0');
      CheckFalse(rx.DomesticMult, 'and no multiplier');
      engine.Enter('W5FM', '59 LAFA', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'FM on 2 m');
      CheckEquals(2, Integer(rx.QSOPoints), 'FM is phone: 2');

      (* THE HOST-AREA RULE, typed. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, '1.2 outside Louisiana, work Louisiana stations only');
      engine.Enter('W5BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a parish');

      (* OFF-BAND: an automatic X-QSO. *)
      engine.Enter('W5OFF', '599 WINN', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 30 m QSO is logged');
      CheckTrue(LoggedQSOIsXQSO(rx), '3.4 no WARC: an automatic X-QSO');
      engine.Enter('W5OFF', '599 WINN', Band6, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '6 m counts, and the X-QSO marked nothing');

      (* PARISH LINES: 9.4.3 "both parishes". *)
      ClearPendingCounties;
      engine.Enter('W5LN', '599 ACAD/ALLE', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a parish line: ' + string(ExchangeErrorMessage));
      CheckEquals(1, PendingCountiesCount, 'the second parish its own QSO');
      ClearPendingCounties;
      accepted := True;
      engine.Enter('W5LN', '599 ACAD/ALLE/ASCE', Band10, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three parishes are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;
   finally
      engine.Free;
   end;
end;

procedure TContestLouisianaQPTests.Test_RealEngineInState;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_LouisianaRealEngineInState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckTrue(Settings.Mult.ByBand and Settings.Mult.ByMode, 'multipliers per band and mode');

      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a state');
      CheckEquals(4, Integer(rx.QSOPoints), 'CW 4');
      engine.Enter('W1AW', '599 CT', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'CT again on another band');
      engine.Enter('W5AAA', '599 ORLE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a parish is a multiplier in state too');
      engine.Enter('W5LA', '599 LA', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a station logged as LA is accepted');
      CheckFalse(rx.DomesticMult, '8.2.2 "States (other than Louisiana)": no multiplier');
      CheckEquals(4, Integer(rx.QSOPoints), 'but its points count');
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('VO1AA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'NF is NL');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC accepted, as Maryland');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland already counted through DC');

      (* 7.1 a DX station sends its country; 8.2.2 its entity counts. *)
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station sends its country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckFalse(rx.DomesticMult, 'and no domestic one');
      CheckEquals(4, Integer(rx.QSOPoints), 'DX CW 4');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column is its country');
      engine.Enter('DL1AAA', '59 DL', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(rx.DXMult, 'DL again on phone, per mode');
      engine.Enter('DL2BBB', '599 DL', Band20, Digital, eRTTY, accepted, rx);
      CheckFalse(rx.DXMult, '9.1 DL on RTTY after CW on one band: the same multiplier');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'KL is no DXCC multiplier');

      (* THE ALLOWED DIGITAL MODES (NY4I, 2026-11-19): JTTY is one; JS8 is
         not on his list, so it is an automatic X-QSO. *)
      engine.Enter('W5JS', '599 CADD', Band40, Digital, eJS8, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), 'JS8 is not an allowed mode: an X-QSO');
      CheckFalse(rx.DomesticMult, 'and it earns no parish');
      engine.Enter('W5JT', '599 CADD', Band40, Digital, eJTTY, accepted, rx);
      CheckFalse(LoggedQSOIsXQSO(rx), 'JTTY is allowed');
      CheckTrue(accepted and rx.DomesticMult, 'and earns the parish the JS8 QSO did not');
      CheckEquals(4, Integer(rx.QSOPoints), 'JTTY is digital: 4');
   finally
      engine.Free;
   end;
end;

(* 9.1 "CW/Digital and Phone contacts count as separate multipliers" --
   through the real engine, then again from the stored records the way the
   loader and the rescore build the sheet (clear it, then SetMultFlags and
   AddQSOToSheets in log order), which must agree. *)
procedure TContestLouisianaQPTests.Test_CWAndDigitalAreOneMultiplierMode;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
   logged: array of ContestExchange;
   live: array of boolean;
   i: integer;
   liveTotal: integer;

   procedure Keep;
   begin
      SetLength(logged, Length(logged) + 1);
      logged[High(logged)] := rx;
      SetLength(live, Length(live) + 1);
      live[High(live)] := rx.DomesticMult;
   end;

begin
   BeginTest('Test_LouisianaCWAndDigitalAreOneMultiplierMode');
   logged := nil;
   live := nil;
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      engine.Enter('W5AAA', '599 ACAD', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Acadia on 20 m CW');
      Keep;
      engine.Enter('W5BBB', '599 ACAD', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'another Acadia station on 20 m RTTY');
      CheckFalse(rx.DomesticMult, '9.1: the same multiplier as CW');
      CheckEquals(4, Integer(rx.QSOPoints), 'its points still count');
      Keep;
      engine.Enter('W5CCC', '59 ACAD', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'phone is a separate multiplier');
      Keep;
      engine.Enter('W5DDD', '599 ACAD', Band40, Digital, ePSK31, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '40 m digital is new');
      Keep;
      engine.Enter('W5EEE', '599 ACAD', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'and 40 m CW then is not');
      Keep;
      CheckEquals(1, integer(mo.MTotals[Band20, CW, rmDomestic]), '20 m CW/digital: one');
      CheckEquals(1, integer(mo.MTotals[Band20, Phone, rmDomestic]), '20 m phone: one');
      CheckEquals(3, integer(mo.MTotals[AllBands, Both, rmDomestic]), 'three in the score');
      liveTotal := mo.MTotals[AllBands, Both, rmDomestic];

      (* THE STORED RECORDS AGAIN, as a reload or the rescore does. *)
      mo.ClearAllMults;
      for i := 0 to High(logged) do
         begin
         rx := logged[i];
         Sheet.SetMultFlags(rx);
         Sheet.AddQSOToSheets(@rx, False);
         CheckTrue(rx.DomesticMult = live[i], 'the rescore agrees with live entry, QSO ' + IntToStr(i + 1));
         end;
      CheckEquals(liveTotal, integer(mo.MTotals[AllBands, Both, rmDomestic]), 'and the total');
   finally
      engine.Free;
   end;
end;

procedure TContestLouisianaQPTests.Test_ExportColumns;
var
   party, stationed: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;
   text: string;
begin
   BeginTest('Test_LouisianaExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';

   (* The rules print no example line; 7.1 and 7.2 name the fields: signal
      report and state/province/country, or signal report and parish. A
      Pennsylvania entrant works Orleans. *)
   rx := LAQSO('W5AAA', 'ORLE', Band20, CW, eCW);
   my := Default(TMyStationExchange);
   my.MyState := 'PA';
   ctx.HisQTH := 'ORLE';
   line := 'QSO: 14000 CW 2026-04-04 1400 W3AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W5AAA ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2026-04-04 1400 W3AAA 599 PA     W5AAA 599 ORLE   ',
      line, 'RST + state sent, RST + parish received');
   CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF STX_STRING');

   (* A DX ENTRANT SENDS ITS COUNTRY -- the station's, through SentLocation. *)
   station := StationAt(False);
   station.MyState := '';
   station.MyCountry := 'DL';
   stationed := Make(PartyHandle, station);
   try
      my.MyState := '';
      CheckEquals('599 DL     ', stationed.FormatCabrilloSentExchange(my, rx, ctx),
                  '7.1 "state/province/country"');
      CheckEquals('599 DL     ', stationed.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
      CheckEquals(' 5NN DL', stationed.CQExchangeDefault(station), 'and in the CQ exchange');
   finally
      stationed.Free;
   end;
   CheckEquals(' 5NN ORLE', party.CQExchangeDefault(StationAt(True)), '7.2 a Louisiana station its parish');

   (* ADIF: the enumeration's CONTEST_ID, STATE LA for a parish, and the
      CNTY name ADIF knows. *)
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<CONTEST_ID:12>LA-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);
   CheckTrue(Pos('<STATE:2>LA', text) > 0, 'a parish is in Louisiana: ' + text);
   CheckEquals('Orleans', party.ADIFCountyName(rx, 'Orleans'), 'a parish name is ADIF''s');
   rx := LAQSO('W5SJB', 'SJB', Band20, CW, eCW);
   CheckEquals('St John the Baptist', party.ADIFCountyName(rx, 'St. John Baptist'),
               'the sponsor''s St. John Baptist is ADIF''s St John the Baptist');
end;

procedure TContestLouisianaQPTests.RunAllTests;
begin
   Test_Identity;
   Test_ParishFileAndInStateFile;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_ScoreAndBonus;
   Test_RealEngineOutOfState;
   Test_RealEngineInState;
   Test_CWAndDigitalAreOneMultiplierMode;
   Test_ExportColumns;
end;

end.
