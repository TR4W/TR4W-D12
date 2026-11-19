(* THE ILLINOIS QSO PARTY -- issue #119 (2026-11-18). The sponsor's 2026 rules
   (docs/ContestRules/QSOParties/Illinois) and NY4I's rulings: an Illinois
   entrant's county QSO also earns IL as a state (#317), and a station
   logged as IL is IL; DC counts as Maryland; the third full weekend of
   October; FM is phone. Each test names the rule it holds; the class header
   says where each landed. *)
unit uTestContestIllinoisQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestIllinoisQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_CountyFileAndInStateFile;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_ScoreCapAndBonus;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineInState;
      procedure Test_ExportColumns;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestIllinoisQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults,
   LogStuff, uPendingCounties, uADIF, uContestSchedule,
   (* TC_TOOMANYCOUNTIES *)
   uTR4WStrings,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(IL_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('IL-QSO-PARTY is not registered');
      end;
end;

(* An Illinois station in county aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function ILQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
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
      Result.MyState := 'COOK';
      end
   else
      begin
      Result.MyState := 'PA';
      end;
   Result.MyCountry := 'K';
end;

procedure TContestIllinoisQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;
   key: TDateTime;
begin
   BeginTest('Test_IllinoisIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestIllinoisQP, 'the registered class');
   CheckTrue(TContestIllinoisQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('IL-QSO-PARTY', party.CabrilloName, 'DXLog''s Cabrillo name');
   CheckEquals('IL QSO PARTY', party.ADIFContestId,
               'the ADIF Contest_ID enumeration''s spelling, with blanks');
   CheckEquals('Illinois QSO Party', party.DisplayName, 'display');
   CheckEquals('Illinois QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('IL', party.HostState, 'host');
   CheckEquals('n9jf@arrl.net', party.SubmissionEmail,
               '"Electronic logs should be sent as attachments to n9jf@arrl.net"');
   CheckEquals(0, party.WA7BNMId, 'not looked up');
   CheckEquals('illinois_cty', party.DomesticFileName, 'the county file');
   CheckEquals('illinois', party.InStateDomesticFileName, 'the in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             '"once per band and mode"; multipliers once overall; 6 m and 2 m');
   CheckEquals(4, (party as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"the border of 2/3/4 counties"');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, '"once per band/mode/county for IL Mobile and Rover"');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');

   (* "phone and CW/digital" -- two dupe modes. *)
   CheckTrue(ContestDupeModeOf(party, Digital) = CW, 'digital is CW for dupes');
   CheckTrue(ContestDupeModeOf(party, CW) = CW, 'CW is CW');
   CheckTrue(ContestDupeModeOf(party, Phone) = Phone, 'phone is its own');

   (* "1700 UTC October 18, 2026 to 0100 UTC October 19, 2026" -- the Sunday
      of the third full weekend of October (NY4I, issue 119). 2028 tells it
      from "the third Sunday": October 1 is a Sunday, so the third full
      weekend is the 21st-22nd, the third Sunday the 15th. *)
   CheckEquals('3rd full weekend of October +1d at 17:00 UTC for 8h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2026, 1, 1), key), '2026 has a date');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDate(2026, 10, 18) + EncodeTime(17, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), '2026: Sunday October 18, 1700 UTC');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2027, 1, 1), key), '2027 has a date');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDate(2027, 10, 17) + EncodeTime(17, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), '2027: Sunday October 17');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2028, 1, 1), key), '2028 has a date');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDate(2028, 10, 22) + EncodeTime(17, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), '2028: Sunday October 22, not the 15th');
   CheckTrue(TryScheduleSortKey(s, EncodeDate(2026, 10, 19) + EncodeTime(1, 0, 0, 0), key),
             'after the 2026 running, the next year');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDate(2027, 10, 17) + EncodeTime(17, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), 'the 2027 running is next');
end;

procedure TContestIllinoisQPTests.Test_CountyFileAndInStateFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_IllinoisCountyFileAndInStateFile');
   CheckEquals('', CountyFileDifference('Illinois', 'illinois_cty.dom',
      'IL-QSO-PARTY-Counties.txt', 102), 'all 102 sponsor county codes and names');

   (* THE IN-STATE LIST: counties first, DC as Maryland, the states (IL
      included -- NY4I's ruling), the 13 provinces, NF and LB as NL. *)
   CheckEquals('COOK', InStateMultiplierOf(PartyHandle, 'COOK'), 'a county is its own multiplier');
   CheckEquals('ROCK', InStateMultiplierOf(PartyHandle, 'ROCK'), 'Rock Island');
   CheckEquals('SCLA', InStateMultiplierOf(PartyHandle, 'SCLA'), 'St. Clair');
   CheckEquals('LEE', InStateMultiplierOf(PartyHandle, 'LEE'), 'Lee, the one three-letter code');
   CheckEquals('IL', InStateMultiplierOf(PartyHandle, 'IL'), 'IL is a state for an Illinois station (NY4I)');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC counts as Maryland (NY4I)');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'a state');
   CheckEquals('AK', InStateMultiplierOf(PartyHandle, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(PartyHandle, 'HI'), 'Hawaii is a state');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'LA is Louisiana, s50 before p13');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is NL');
   CheckEquals('NS', InStateMultiplierOf(PartyHandle, 'NS'), 'a province');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is the DXCC multiplier, not an entry');

   (* THE FILES AS TEXT: the in-state include list, and no "=" in either
      header. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'illinois.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE illinois_cty.dom') >= 0, 'includes the counties');
      CheckTrue(lines.IndexOf('INCLUDE FILE illinois_cty.dom') <
                lines.IndexOf('INCLUDE FILE s50.dom'), 'counties first');
      CheckTrue(lines.IndexOf('Dc > Md = DC') < lines.IndexOf('INCLUDE FILE s50.dom'),
                'DC folded before the states');
      CheckTrue(lines.IndexOf('INCLUDE FILE p13.dom') >= 0, 'the provinces');
      CheckTrue(lines.IndexOf('INCLUDE FILE dc.dom') < 0, 'DC is no multiplier of its own');
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', string(lines[i])) = 1 then
            begin
            Break;
            end;
         CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" in the header: ' + string(lines[i]));
         end;
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'illinois_cty.dom'));
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the county file includes nothing');
         end;
   finally
      lines.Free;
   end;
end;

procedure TContestIllinoisQPTests.Test_BandsModesAndPoints;
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
   BeginTest('Test_IllinoisBandsModesAndPoints');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         (* "160 through 2 meters, excluding WARC bands (60, 30, 17 and 12
            meters)". *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2]),
               'the rules'' bands');
            end;
         (* "Phone QSO: 1 point; CW/digital QSO 2 points" and "FT4 and FT8
            contacts will receive no contact credit". *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               credited := (mode in [CW, Phone, FM]) or
                           ((mode = Digital) and not (ext in [eFT8, eFT4]));
               expected := 0;
               if credited and (mode in [CW, Digital]) then
                  begin
                  expected := 2;
                  end;
               if credited and (mode in [Phone, FM]) then
                  begin
                  expected := 1;
                  end;
               qso := ILQSO('W9AAA', 'COOK', Band20, mode, ext);
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'CW/digital 2, phone/FM 1, FT8/FT4 none');
               CheckTrue(party.UsesMode(mode, ext) = credited, 'every submode but FT8 and FT4');
               end;
            end;
         CheckFalse(party.UsesMode(Digital, eFT8), 'FT8 is an automatic X-QSO');
         CheckFalse(party.UsesMode(Digital, eFT4), 'FT4 is an automatic X-QSO');
         CheckTrue(party.UsesMode(Digital, eRTTY), '"Other digital modes are encouraged"');
         CheckTrue(party.UsesMode(Digital, eNoMode), 'an unknown submode is never proven off-mode');
         CheckEquals('RY', party.CabrilloModeString(Digital, eRTTY), 'RTTY is RY');
         CheckEquals('DG', party.CabrilloModeString(Digital, ePSK31), 'another digital mode is DG');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestIllinoisQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   inHost: boolean;
   dxKey: DXMultiplierString;
   qso: ContestExchange;
   station: TStationContext;
   extra: string;
begin
   BeginTest('Test_IllinoisMultiplierAnswers');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         CheckTrue(party.HasDXMultiplier = inHost, 'DXCC for an Illinois entrant only');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckFalse(party.HasPrefixMultiplier, 'no prefixes');
         if inHost then
            begin
            CheckTrue(party.CountryMode = ARRLCountryMode, 'DXCC is the ARRL list');
            end;

         (* "Canada, KH6 and KL7 do not count as DX entities." *)
         qso := ILQSO('DL1AAA', 'DL', Band20, CW, eCW);
         qso.QTH.CountryID := 'DL';
         dxKey := '';
         party.DXMultiplierKey(qso, dxKey);
         if inHost then
            begin
            CheckEquals('DL', string(dxKey), 'Germany is a DXCC multiplier in state');
            qso.QTH.CountryID := 'VE';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Canada is none');
            qso.QTH.CountryID := 'KH6';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Hawaii is none');
            qso.QTH.CountryID := 'KL';
            party.DXMultiplierKey(qso, dxKey);
            CheckEquals('', string(dxKey), 'Alaska is none');
            end;

         (* NY4I's ruling: nothing refuses IL as a state multiplier. *)
         CheckTrue(party.CountsAsMultiplier(ILQSO('W9IL', 'IL', Band20, CW, eCW), rmDomestic),
                   'IL counts');

         (* NY4I's ruling (#317): an Illinois entrant's county QSO also
            earns IL; a state earns nothing more, nor does anything outside. *)
         extra := 'stale';
         CheckTrue(party.AdditionalDomesticMultiplierKey(ILQSO('W9AAA', 'COOK', Band20, CW, eCW), extra)
                   = inHost, 'a county earns IL in state only');
         if inHost then
            begin
            CheckEquals('IL', extra, 'the second key is IL');
            CheckTrue(party.AdditionalDomesticMultiplierKey(ILQSO('W9AAA', 'LEE', Band20, CW, eCW), extra),
                      'Lee too');
            end;
         CheckFalse(party.AdditionalDomesticMultiplierKey(ILQSO('W1AW', 'CT', Band20, CW, eCW), extra),
                    'a state earns no second key');
         CheckFalse(party.AdditionalDomesticMultiplierKey(ILQSO('W9IL', 'IL', Band20, CW, eCW), extra),
                    'IL itself earns no second key');
      finally
         party.Free;
      end;
      end;

   (* THE HOST-AREA RULE -- judged by the SHIPPED county file
      (WithHostAreaTable knows every QTH, so it cannot show a refusal). *)
   LoadCountyTable('illinois_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(ILQSO('W1AW', 'CT', Band20, CW, eCW)),
                 'outside Illinois a QSO with CT is not credited');
      CheckTrue(party.CreditsWorkedStation(ILQSO('W9AAA', 'COOK', Band20, CW, eCW)),
                'a county is');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* POINTS x (COUNTIES + STATES + PROVINCES + AT MOST 5 DXCC) + W9AWE + W9OAB. *)
procedure TContestIllinoisQPTests.Test_ScoreCapAndBonus;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;
   qso: ContestExchange;
begin
   BeginTest('Test_IllinoisScoreCapAndBonus');
   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      totals.ScoredBand := AllBands;
      totals.SessionCountsMultipliers := True;
      totals.QSOPoints := 100;
      totals.Mults[AllBands, Both, rmDomestic] := 10;
      totals.Mults[AllBands, Both, rmDX] := 5;
      CheckEquals(100 * 15, party.CombineScore(totals), '5 DXCC count');
      totals.Mults[AllBands, Both, rmDX] := 7;
      CheckEquals(100 * 15, party.CombineScore(totals), '"DXCC countries (maximum 5)"');
      totals.Mults[AllBands, Both, rmDX] := 4;
      CheckEquals(100 * 14, party.CombineScore(totals), 'under the cap, every one');

      (* "any entrant contacting these stations will have a 100 point bonus
         added to the final score. Total of 200 points possible." *)
      view.Add(ILQSO('W9AWE', 'ADAM', Band20, CW, eCW));
      CheckEquals(100, party.BonusPoints(totals, view), 'W9AWE');
      view.Add(ILQSO('W9AWE', 'ADAM', Band40, Phone, eUSB));
      CheckEquals(100, party.BonusPoints(totals, view), 'W9AWE once');
      view.Add(ILQSO('W9OAB', 'ADAM', Band40, Phone, eUSB));
      view.Add(ILQSO('W9OAB', 'ADAM', Band80, Phone, eLSB));
      CheckEquals(200, party.BonusPoints(totals, view), 'both, once each: 200');
      CheckEquals(100 * 14 + 200, party.FinalScore(totals, view), 'the bonus after multiplication');

      view.Free;
      view := TLoggedQSOList.Create;
      qso := ILQSO('W9AWE', 'ADAM', Band20, CW, eCW);
      qso.ceDupe := True;
      view.Add(qso);
      qso.ceDupe := False;
      qso.ceXQSO := True;
      view.Add(qso);
      CheckEquals(0, party.BonusPoints(totals, view), 'a dupe or X-QSO earns no bonus');

      totals.SessionCountsMultipliers := False;
      CheckEquals(100, party.CombineScore(totals), 'the base''s points-alone rule');
   finally
      view.Free;
      party.Free;
   end;
end;

procedure TContestIllinoisQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_IllinoisRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(102, mo.DomList.Count, 'outside Illinois: the 102 counties');
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('W9AAA', '599 COOK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW 2');
      dupe := engine.Enter('W9AAA', '59 COOK', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(dupe, 'another band and mode');
      CheckFalse(rx.DomesticMult, 'Cook once overall');
      CheckEquals(1, Integer(rx.QSOPoints), 'phone 1');
      dupe := engine.Enter('W9AAA', '599 COOK', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, '"once per band and mode"');
      dupe := engine.Enter('W9AAA', '599 COOK', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(dupe, '"(phone and CW/digital)": RTTY after CW on one band is a dupe');
      dupe := engine.Enter('W9AAA', '59 COOK', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'phone is the other mode');
      dupe := engine.Enter('W9AAA', '599 LAKE', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, '"once per band/mode/county for IL Mobile and Rover stations"');

      engine.Enter('W9RY', '599 PEOR', Band15, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'an RTTY county');
      CheckEquals(2, Integer(rx.QSOPoints), 'digital 2');
      CheckFalse(LoggedQSOIsXQSO(rx), 'RTTY is credited');
      (* Q98: an off-mode QSO is LOGGED, scores 0 and is an X-QSO. *)
      engine.Enter('W9FT', '599 KANE', Band15, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged: ' + string(ExchangeErrorMessage));
      CheckTrue(LoggedQSOIsXQSO(rx), '"FT4 and FT8 contacts will receive no contact credit"');
      CheckEquals(0, Integer(rx.QSOPoints), 'FT8 scores 0');
      CheckFalse(rx.DomesticMult, 'and no multiplier');
      engine.Enter('W9FU', '599 KANE', Band15, Digital, eFT4, accepted, rx);
      CheckTrue(accepted, 'an FT4 QSO is logged');
      CheckTrue(LoggedQSOIsXQSO(rx), 'FT4 likewise');
      CheckEquals(0, Integer(rx.QSOPoints), 'FT4 scores 0');
      engine.Enter('W9FM', '59 WILL', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'FM on 2 m');
      CheckEquals(1, Integer(rx.QSOPoints), 'FM is phone: 1');

      (* THE HOST-AREA RULE, typed. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside Illinois, work Illinois stations only');
      engine.Enter('W9BAD', '599 XYZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'not a county');

      (* OFF-BAND: an automatic X-QSO. *)
      engine.Enter('W9OFF', '599 BOND', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 30 m QSO is logged');
      CheckTrue(LoggedQSOIsXQSO(rx), '30 m is a WARC band: an automatic X-QSO');
      engine.Enter('W9OFF', '599 BOND', Band6, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '6 m counts, and the X-QSO marked nothing');

      (* COUNTY LINES: "the border of 2/3/4 counties". *)
      ClearPendingCounties;
      engine.Enter('W9LN', '599 ADAM/BROW/PIKE/SCHY', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a four-county corner: ' + string(ExchangeErrorMessage));
      CheckEquals(3, PendingCountiesCount, 'each further county its own QSO');
      ClearPendingCounties;
      accepted := True;
      engine.Enter('W9LN', '599 ADAM/BROW/PIKE/SCHY/CASS', Band10, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'five counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [4]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;
   finally
      engine.Free;
   end;
end;

procedure TContestIllinoisQPTests.Test_RealEngineInState;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_IllinoisRealEngineInState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a state');
      CheckEquals(1, mo.MTotals[AllBands, Both, rmDomestic], 'a state alone earns no IL');
      engine.Enter('W1AW', '599 CT', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'CT once');
      (* NY4I's ruling (issue 119, #317): an Illinois entrant's QSO with an
         Illinois county also earns IL as a state. *)
      engine.Enter('W9AAA', '599 COOK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'an Illinois county is a multiplier in state too');
      CheckEquals(3, mo.MTotals[AllBands, Both, rmDomestic], 'Cook AND IL');
      engine.Enter('W9BBB', '59 PEOR', Band40, Phone, eLSB, accepted, rx);
      CheckEquals(4, mo.MTotals[AllBands, Both, rmDomestic], 'Peoria; IL once overall');
      engine.Enter('W9IL', '599 IL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a station may send IL itself');
      CheckFalse(rx.DomesticMult, 'IL is already worked through Cook');
      CheckEquals(4, mo.MTotals[AllBands, Both, rmDomestic], 'IL is not counted twice');
      engine.Enter('VE3AA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC accepted, as Maryland (NY4I)');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland already counted through DC');

      (* "DXCC countries": a DX station sends its prefix; its entity counts. *)
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
      CheckFalse(rx.DXMult, '"KL7 do not count as DX entities"');

      (* IL SENT FIRST: the station's IL is the multiplier, and a county
         after it earns the county alone. *)
      engine.Activate(True);
      engine.Enter('W9IL', '599 IL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'IL is a state multiplier for an Illinois station (NY4I)');
      CheckEquals(1, mo.MTotals[AllBands, Both, rmDomestic], 'IL');
      engine.Enter('W9AAA', '599 LEE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Lee, the three-letter code, is a county');
      CheckEquals(2, mo.MTotals[AllBands, Both, rmDomestic], 'Lee; IL already worked');

      (* OUTSIDE ILLINOIS a county earns the county only. *)
      engine.Activate(False);
      engine.Enter('W9AAA', '599 COOK', Band20, CW, eCW, accepted, rx);
      CheckEquals(1, mo.MTotals[AllBands, Both, rmDomestic], 'outside entrant: the county only');
   finally
      engine.Free;
   end;
end;

procedure TContestIllinoisQPTests.Test_ExportColumns;
var
   party, stationed: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;
   text: string;
begin
   BeginTest('Test_IllinoisExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';

   (* THE RULES' FIELDS, IN THEIR ORDER (no example line is printed): "the
      RS(T) sent; the location of your station; the call sign of the station
      contacted; the RS(T) received; and the location of the station
      contacted". A Pennsylvania entrant works Cook. *)
   rx := ILQSO('W9AAA', 'COOK', Band20, CW, eCW);
   my := Default(TMyStationExchange);
   my.MyState := 'PA';
   ctx.HisQTH := 'COOK';
   line := 'QSO: 14000 CW 2026-10-18 1700 W3AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W9AAA ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2026-10-18 1700 W3AAA 599 PA     W9AAA 599 COOK   ',
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
                  '"others give RS/T and ... country"');
      CheckEquals('599 DL     ', stationed.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
      CheckEquals(' 5NN DL', stationed.CQExchangeDefault(station), 'and in the CQ exchange');
   finally
      stationed.Free;
   end;
   CheckEquals(' 5NN COOK', party.CQExchangeDefault(StationAt(True)), 'an Illinois station its county');

   (* ADIF: the enumeration's CONTEST_ID, and STATE IL for a county. *)
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<CONTEST_ID:12>IL QSO PARTY', text) > 0, 'CONTEST_ID: ' + text);
   CheckTrue(Pos('<STATE:2>IL', text) > 0, 'a county is in Illinois: ' + text);
end;

procedure TContestIllinoisQPTests.RunAllTests;
begin
   Test_Identity;
   Test_CountyFileAndInStateFile;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_ScoreCapAndBonus;
   Test_RealEngineOutOfState;
   Test_RealEngineInState;
   Test_ExportColumns;
end;

end.
