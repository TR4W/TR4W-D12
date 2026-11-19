(* THE MISSISSIPPI QSO PARTY -- issue #123 (2026-11-18). The sponsor's 2026
   rules (docs/ContestRules/QSOParties/Mississippi) and NY4I's rulings on the
   issue: the rules over DXLog; no FM or AM; DC counts as Maryland;
   out-of-state entrants score only Mississippi stations; a rover in a new
   county is a new station; county lines by DXLog's evidence. Each test names
   the rule it holds; the class header says where each landed.

   WHAT THIS CONTEST NEEDED FROM THE ENGINE, AND DID NOT GET:
     * FOUR DUPE MODES (CW, SSB, RTTY, FT4/8): the dupe sheet has one
       digital slot, so DupeModeOf cannot split RTTY from FT. The party
       base's received-QTH dupe key already does -- an FT QSO's QTH is a
       grid, an RTTY QSO's a county, state or country -- and
       Test_RealEngineFourDupeModes drives it through the real engine;
     * THE GRIDS / 4: the grids are the prefix kind's count in TScoreTotals,
       read by the class's own CombineWithMultipliers.
   The one shared routine it lifted, uGridShape.FourCharacterGridSquareOf
   (from the South Dakota class), is pinned in Test_FourCharacterGridSquare. *)
unit uTestContestMississippiQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestMississippiQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Identity;
      procedure Test_CountyFileAndInStateFile;
      procedure Test_FourCharacterGridSquare;
      procedure Test_BandsModesAndPoints;
      procedure Test_MultiplierAnswers;
      procedure Test_ScoreGridsDividedByFour;
      procedure Test_RealEngineOutOfState;
      procedure Test_RealEngineFourDupeModes;
      procedure Test_RealEngineInState;
      procedure Test_ExportColumns;
      procedure Test_ADIFImport;
   end;

implementation

uses
   SysUtils, Classes, DateUtils, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestMississippiQP, uTestContestObjects,
   uTestQSOPartyRules, uTestQSOPartyEngine, uTestShippedDom, uMults, LogEdit,
   LogStuff, uPendingCounties, PostUnit, MainUnit, uADIF, uAppStrings,
   uContestSchedule, uGridShape,
   (* TC_TOOMANYCOUNTIES *)
   uTR4WStrings,
   (* TryLegacyContestOf -- a by-id contest has no legacy member. *)
   uTestRegisteredContests;

function PartyHandle: TContestHandle;
begin
   if not FindContestById(MS_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('MS-QSO-PARTY is not registered');
      end;
end;

(* A Mississippi station in county aQTH (DomesticQTH resolved, as the parse
   leaves it), on aBand in aMode. *)
function MSQSO(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
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

(* AN FT QSO: Digital in aExtMode, the grid as the received QTH, no domestic
   key. *)
function FTQSO(const aCall, aGrid: string; aBand: BandType;
   aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := MSQSO(aCall, aGrid, aBand, Digital, aExtMode);
   Result.DomesticQTH := '';
   Result.DomMultQTH := '';
   Result.RSTReceived := -10;
end;

function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'HIN';
      end
   else
      begin
      Result.MyState := 'PA';
      end;
   Result.MyCountry := 'K';
end;

procedure TContestMississippiQPTests.Test_Identity;
var
   party: TContestBase;
   legacy: integer;
   member: ContestType;
   s: TContestSchedule;
   err: string;

   (* THE PERIOD TO COME FROM 1 JANUARY OF aYear: 1400Z on April aStartDay
      to 0200Z on April aEndDay. *)
   procedure CheckPeriod(const aSchedule: TContestSchedule;
                         aYear, aMonth, aStartDay, aEndDay: word);
   var
      startUTC, endUTC: TDateTime;
   begin
      CheckTrue(TryNextSchedulePeriod(aSchedule.Clauses[0],
                                      EncodeDateTime(aYear, 1, 1, 0, 0, 0, 0),
                                      startUTC, endUTC),
                'a period in ' + IntToStr(aYear));
      CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(aYear, aMonth, aStartDay, 14, 0, 0, 0)),
                  FormatDateTime('yyyy-mm-dd hh:nn', startUTC), 'the start in ' + IntToStr(aYear));
      CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(aYear, aMonth, aEndDay, 2, 0, 0, 0)),
                  FormatDateTime('yyyy-mm-dd hh:nn', endUTC), 'the end in ' + IntToStr(aYear));
   end;

begin
   BeginTest('Test_MississippiIdentity');
   party := ContestIdentity(PartyHandle);
   CheckTrue(party is TContestMississippiQP, 'the registered class');
   CheckTrue(TContestMississippiQP.ClassParent = TContestStateQSOPartyBase,
             'directly on the state-party base');
   CheckFalse(ContestLegacyNumber(PartyHandle, legacy), 'no frozen enum number');
   CheckFalse(TryLegacyContestOf(party, member), 'no legacy member');
   CheckEquals('MS-QSO-PARTY', party.CabrilloName, 'DXLog''s Cabrillo name');
   CheckEquals('MS-QSO-PARTY', party.ADIFContestId, 'the ADIF Contest_ID');
   CheckEquals('Mississippi QSO Party', party.DisplayName, 'display');
   CheckEquals('Mississippi QSO Party', party.FriendlyName, 'friendly name');
   CheckEquals('MS', party.HostState, 'host');
   CheckEquals('w5xx@arrl.net', party.SubmissionEmail, '"E-mail entries to W5XX at ARRL.NET"');
   CheckEquals(308, party.WA7BNMId, 'confirmed by NY4I, issue 123');
   CheckEquals('mississippi_cty', party.DomesticFileName, 'the county file');
   CheckEquals('mississippi', party.InStateDomesticFileName, 'the in-state file');
   CheckTrue(party.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             '"each separate band/mode"; multipliers "Earned ONCE regardless of band/mode"; 6 m and 2 m');
   CheckTrue(party.DupeKeyIncludesReceivedQTH, 'a rover in a new county is a new station (NY4I)');
   CheckTrue(party.StripsRoverCountyFromCall and party.SplitsRoverCallOnExport,
             'the party base''s rover rules');
   CheckEquals(STotalsGridMults, party.TotalsDisplay.PrefixMultsCaption,
               'the prefix row counts grids');

   (* "Starts: 1400z /4April 2026 Ends: 0200z /5April 2026 Duration: 12
      Hours"; NY4I (issue 123, 2026-11-18): the first weekend of April, and
      these four years' dates. *)
   CheckEquals('1st Saturday of April at 14:00 UTC for 12h', party.Schedule, 'the schedule');
   CheckTrue(TryParseContestSchedule(party.Schedule, s, err), 'it parses (' + err + ')');
   CheckPeriod(s, 2026, 4, 4, 5);
   CheckPeriod(s, 2027, 4, 3, 4);
   CheckPeriod(s, 2028, 4, 1, 2);
   CheckPeriod(s, 2029, 4, 7, 8);
end;

procedure TContestMississippiQPTests.Test_CountyFileAndInStateFile;
var
   lines: TStringList;
   i: integer;
begin
   BeginTest('Test_MississippiCountyFileAndInStateFile');
   CheckEquals('', CountyFileDifference('Mississippi', 'mississippi_cty.dom',
      'MS-QSO-PARTY-Counties.txt', 82), 'all 82 county codes and names');

   (* THE IN-STATE LIST: counties first, DC as Maryland, the states, the 13
      provinces, NF and LB as NL. *)
   CheckEquals('HIN', InStateMultiplierOf(PartyHandle, 'HIN'), 'a county is its own multiplier');
   CheckEquals('JDV', InStateMultiplierOf(PartyHandle, 'JDV'), 'Jefferson Davis');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'DC'), 'DC counts as Maryland (NY4I)');
   CheckEquals('MD', InStateMultiplierOf(PartyHandle, 'MD'), 'Maryland');
   CheckEquals('CT', InStateMultiplierOf(PartyHandle, 'CT'), 'a state');
   CheckEquals('MS', InStateMultiplierOf(PartyHandle, 'MS'), 'MS is on the file -- the class refuses it');
   CheckEquals('LA', InStateMultiplierOf(PartyHandle, 'LA'), 'LA is Louisiana, s50 before p13');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'NF'), 'NF is NL');
   CheckEquals('NL', InStateMultiplierOf(PartyHandle, 'LB'), 'LB is NL');
   CheckEquals('YT', InStateMultiplierOf(PartyHandle, 'YT'), 'a territory');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'DX'), 'DX is the DXCC multiplier, not an entry');
   CheckEquals('', InStateMultiplierOf(PartyHandle, 'EM52'), 'a grid is no entry: it is the prefix multiplier');

   (* THE FILES AS TEXT: the in-state include list, and no "=" in either
      header. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'mississippi.dom'));
      CheckTrue(lines.IndexOf('INCLUDE FILE mississippi_cty.dom') >= 0, 'includes the counties');
      CheckTrue(lines.IndexOf('INCLUDE FILE mississippi_cty.dom') <
                lines.IndexOf('INCLUDE FILE s50.dom'), 'counties first');
      CheckTrue(lines.IndexOf('Dc > Md = DC') < lines.IndexOf('INCLUDE FILE s50.dom'),
                'DC folded before the states');
      CheckTrue(lines.IndexOf('INCLUDE FILE s50.dom') < lines.IndexOf('INCLUDE FILE p13.dom'),
                's50 before p13');
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', string(lines[i])) = 1 then
            begin
            Break;
            end;
         CheckTrue(Pos('=', string(lines[i])) = 0, 'no "=" in the header: ' + string(lines[i]));
         end;
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'mississippi_cty.dom'));
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) <> 1,
                   'the county file includes nothing');
         end;
   finally
      lines.Free;
   end;
end;

(* THE LEAF ROUTINE LIFTED FROM THE SOUTH DAKOTA CLASS -- both contests key
   their grid multiplier on it. *)
procedure TContestMississippiQPTests.Test_FourCharacterGridSquare;
begin
   BeginTest('Test_FourCharacterGridSquare');
   CheckEquals('EM52', FourCharacterGridSquareOf('EM52'), 'four characters');
   CheckEquals('EM52', FourCharacterGridSquareOf(' em52ab '), 'six, any case, blanks trimmed');
   CheckEquals('', FourCharacterGridSquareOf('ZZ00'), 'ZZ00 is no Maidenhead square');
   CheckEquals('', FourCharacterGridSquareOf('EM52A'), 'five characters');
   CheckEquals('', FourCharacterGridSquareOf('EM5299'), 'a six-character grid ends in letters');
   CheckEquals('', FourCharacterGridSquareOf('HIN'), 'a county');
   CheckEquals('', FourCharacterGridSquareOf(''), 'nothing');
   CheckTrue(IsMississippiQPGrid('em41') and IsMississippiQPGrid('EM44') and
             IsMississippiQPGrid('EM50') and IsMississippiQPGrid('EM54'),
             'EM41-44 and EM50-54');
   CheckFalse(IsMississippiQPGrid('EM40') or IsMississippiQPGrid('EM45') or
              IsMississippiQPGrid('EM49') or IsMississippiQPGrid('EM55') or
              IsMississippiQPGrid('FN31'), 'nothing else');
end;

procedure TContestMississippiQPTests.Test_BandsModesAndPoints;
var
   party: TContestBase;
   inHost: boolean;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_MississippiBandsModesAndPoints');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         (* "160m, 80m, 40m, 20m, 15m, 10m, 6m, 2m". *)
         for band := Low(BandType) to High(BandType) do
            begin
            CheckTrue(party.UsesBand(band) = (band in
               [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2]),
               'the rules'' bands');
            end;
         (* "CW, SSB, RTTY, FT4/8" (NY4I: no FM, no AM); "SSB = 1; CW = 2;
            RTTY = 2; FT4/8 = 2". *)
         for mode := Low(ModeType) to High(ModeType) do
            begin
            for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
               begin
               expected := 0;
               if mode = CW then
                  begin
                  expected := 2;
                  end;
               if (mode = Phone) and (ext in [eNoMode, eData, eSSB, eUSB, eLSB]) then
                  begin
                  expected := 1;
                  end;
               if (mode = Digital) and (ext in [eNoMode, eData, eRTTY, eRTTY_R, eFT8, eFT4]) then
                  begin
                  expected := 2;
                  end;
               if (mode = Digital) and not (ext in [eRTTY, eRTTY_R]) then
                  begin
                  qso := FTQSO('W5XX', 'EM52', Band20, ext);
                  end
               else
                  begin
                  qso := MSQSO('W5XX', 'HIN', Band20, mode, ext);
                  end;
               party.ScoreQSO(qso);
               CheckEquals(expected, Integer(qso.QSOPoints), 'SSB 1, CW/RTTY/FT 2, nothing else');
               CheckTrue(party.UsesMode(mode, ext) = (expected > 0), 'CW, SSB, RTTY, FT4/8');
               end;
            end;
         (* "NO grid is a zero point qso" (NY4I, 2026-11-18): FT8 and FT4 by
            submode; an unknown digital submode with no grid is no FT QSO. *)
         qso := MSQSO('W5XX', 'HIN', Band20, Digital, eFT8);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'FT8 with no grid: 0');
         qso := MSQSO('W5XX', 'HIN', Band20, Digital, eFT4);
         party.ScoreQSO(qso);
         CheckEquals(0, Integer(qso.QSOPoints), 'FT4 with no grid: 0');
         qso := MSQSO('W5XX', 'HIN', Band20, Digital, eData);
         party.ScoreQSO(qso);
         CheckEquals(2, Integer(qso.QSOPoints), 'an unknown digital submode with a county: 2, as RTTY');
         CheckEquals('CW', party.CabrilloModeString(CW, eCW), 'CW');
         CheckEquals('PH', party.CabrilloModeString(Phone, eUSB), 'PH');
         CheckEquals('RY', party.CabrilloModeString(Digital, eRTTY), 'RTTY is RY (DXLog)');
         CheckEquals('DG', party.CabrilloModeString(Digital, eFT8), 'FT8 is DG (DXLog)');
         CheckEquals('DG', party.CabrilloModeString(Digital, eFT4), 'FT4 is DG');
      finally
         party.Free;
      end;
      end;
end;

procedure TContestMississippiQPTests.Test_MultiplierAnswers;
var
   party: TContestBase;
   inHost: boolean;
   key: PrefixMultiplierString;
   dxKey: DXMultiplierString;
   qso: ContestExchange;
   kind: RemainingMultiplierType;
   station: TStationContext;
begin
   BeginTest('Test_MississippiMultiplierAnswers');
   for inHost := False to True do
      begin
      party := Make(PartyHandle, StationAt(inHost));
      try
         CheckTrue(party.HasDXMultiplier = inHost, 'DXCC for a Mississippi entrant only');
         CheckFalse(party.HasZoneMultiplier, 'no zones');
         CheckTrue(party.HasPrefixMultiplier, 'the FT grids, everywhere');
         if inHost then
            begin
            CheckTrue(party.CountryMode = ARRLCountryMode, 'DXCC is the ARRL list');
            end;

         (* THE GRID KEY: an FT QSO's four-character square; '' (an answer)
            for anything else. *)
         CheckTrue(party.PrefixMultiplierKey(FTQSO('W5XX', 'EM52', Band20, eFT8), key), 'answers');
         CheckEquals('EM52', string(key), 'the grid');
         CheckTrue(party.PrefixMultiplierKey(FTQSO('W5XX', 'em52ab', Band20, eFT4), key), 'answers');
         CheckEquals('EM52', string(key), 'FT4, a six-character grid');
         CheckTrue(party.PrefixMultiplierKey(FTQSO('W5XX', 'EM52', Band20, eData), key), 'answers');
         CheckEquals('EM52', string(key), 'an unknown digital submode with a grid is an FT QSO');
         CheckTrue(party.PrefixMultiplierKey(FTQSO('W5XX', 'EM52', Band20, eRTTY), key), 'answers');
         CheckEquals('', string(key), 'RTTY is never an FT QSO');
         CheckTrue(party.PrefixMultiplierKey(MSQSO('W5XX', 'EM52', Band20, CW, eCW), key), 'answers');
         CheckEquals('', string(key), 'a CW QSO has no grid key');
         CheckTrue(party.PrefixMultiplierKey(MSQSO('W5XX', 'HIN', Band20, Digital, eFT8), key), 'answers');
         CheckEquals('', string(key), 'an FT QSO holding no grid has no key');

         (* AN FT QSO EARNS ONLY ITS GRID; CW, PHONE AND RTTY NEVER ONE. *)
         for kind := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
            begin
            CheckTrue(party.CountsAsMultiplier(FTQSO('W5XX', 'EM52', Band20, eFT8), kind) =
                      (kind = rmPrefix), 'FT: the grid only');
            CheckTrue(party.CountsAsMultiplier(MSQSO('W5XX', 'HIN', Band20, Digital, eRTTY), kind) =
                      (kind <> rmPrefix), 'RTTY: never a grid');
            CheckTrue(party.CountsAsMultiplier(MSQSO('W5XX', 'HIN', Band20, CW, eCW), kind) =
                      (kind <> rmPrefix), 'CW: never a grid');
            end;

         (* "remaining States": an in-state entrant's MS is none. *)
         CheckTrue(party.CountsAsMultiplier(MSQSO('W5MS', 'MS', Band20, CW, eCW), rmDomestic) =
                   (not inHost), 'MS is no state for a Mississippi entrant');

         (* AN FT QSO'S HOST AREA IS THE NINE MISSISSIPPI GRIDS. *)
         CheckTrue(party.CreditsWorkedStation(FTQSO('W5XX', 'EM52', Band20, eFT8)),
                   'a Mississippi grid is credited');
         CheckTrue(party.CreditsWorkedStation(FTQSO('W1AW', 'FN31', Band20, eFT8)) = inHost,
                   'any other grid in state only');

         (* DXCC: every entity but K, VE, KH6, KL, in state. *)
         qso := MSQSO('DL1AAA', 'DL', Band20, CW, eCW);
         qso.QTH.CountryID := 'DL';
         party.DXMultiplierKey(qso, dxKey);
         if inHost then
            begin
            CheckEquals('DL', string(dxKey), 'Germany is a DXCC multiplier in state');
            end;
      finally
         party.Free;
      end;
      end;

   (* CW, PHONE AND RTTY KEEP THE HOST-AREA RULE -- judged by the SHIPPED
      county file (WithHostAreaTable knows every QTH). *)
   LoadCountyTable('mississippi_cty.dom', True);
   station := NoStation;
   station.IsDomesticQTH := @CountyFileKnowsQTH;
   party := Make(PartyHandle, station);
   try
      CheckFalse(party.CreditsWorkedStation(MSQSO('W1AW', 'CT', Band20, CW, eCW)),
                 'outside Mississippi a CW QSO with CT is not credited');
      CheckTrue(party.CreditsWorkedStation(MSQSO('W5XX', 'HIN', Band20, CW, eCW)),
                'a county is');
      CheckFalse(party.CreditsWorkedStation(MSQSO('W5XX', 'EM52', Band20, Digital, eRTTY)),
                 'an RTTY QSO is judged by the county file: a grid is no county');
      CheckTrue(party.CreditsWorkedStation(FTQSO('W5XX', 'EM52', Band20, eFT8)),
                'an FT QSO by its grid');
      CheckFalse(party.CreditsWorkedStation(FTQSO('W1AW', 'FN31', Band20, eFT8)),
                 'and only a Mississippi grid');
      CheckTrue(party.CreditsWorkedStation(MSQSO('W5XX', 'HIN', Band20, Digital, eFT8)),
                'an FT QSO with no grid by the county file: a county');
      CheckFalse(party.CreditsWorkedStation(MSQSO('W1AW', 'CT', Band20, Digital, eFT8)),
                 'and not a state');
   finally
      party.Free;
      FreeCountyTable;
   end;
end;

(* POINTS x (DOMESTIC + DXCC + GRIDS), A MISSISSIPPI ENTRANT'S GRIDS DIVIDED
   BY FOUR AND ROUNDED UP. *)
procedure TContestMississippiQPTests.Test_ScoreGridsDividedByFour;
var
   party: TContestBase;
   totals: TScoreTotals;
   view: TLoggedQSOList;

   function ScoreWithGrids(aGrids: longint): longint;
   begin
      totals.Mults[AllBands, Both, rmPrefix] := aGrids;
      Result := party.CombineScore(totals);
   end;

begin
   BeginTest('Test_MississippiScoreGridsDividedByFour');
   totals := Default(TScoreTotals);
   totals.ScoredBand := AllBands;
   totals.SessionCountsMultipliers := True;
   totals.QSOPoints := 10;
   totals.Mults[AllBands, Both, rmDomestic] := 5;
   totals.Mults[AllBands, Both, rmDX] := 2;

   party := Make(PartyHandle, StationAt(True));
   view := TLoggedQSOList.Create;
   try
      (* "taking the total number of Grid Squares worked in FT8/4 and dividing
         by 4 ... (Round up to nearest whole number.)" *)
      CheckEquals(10 * 7, ScoreWithGrids(0), 'no grids: no grid multiplier');
      CheckEquals(10 * 8, ScoreWithGrids(1), 'one grid is one multiplier');
      CheckEquals(10 * 8, ScoreWithGrids(4), 'four grids are one');
      CheckEquals(10 * 9, ScoreWithGrids(5), 'five are two');
      CheckEquals(10 * 32, ScoreWithGrids(100), '"100 Grid Squares worked, divided by 4, equals 25 multipliers"');
      CheckEquals(10 * 33, ScoreWithGrids(101), '101 are 26');
      CheckEquals(10 * 33, party.FinalScore(totals, view), 'no bonus: the final score is the product');
      totals.SessionCountsMultipliers := False;
      CheckEquals(10, party.CombineScore(totals), 'the base''s points-alone rule');
      totals.SessionCountsMultipliers := True;
   finally
      view.Free;
      party.Free;
   end;

   (* OUTSIDE MISSISSIPPI: counties + the nine grids, each grid one. *)
   totals.Mults[AllBands, Both, rmDX] := 0;
   party := Make(PartyHandle, StationAt(False));
   try
      CheckEquals(10 * (5 + 3), ScoreWithGrids(3), 'out of state each grid is a multiplier');
      CheckEquals(10 * (5 + 9), ScoreWithGrids(9), 'all nine');
   finally
      party.Free;
   end;
end;

procedure TContestMississippiQPTests.Test_RealEngineOutOfState;
var
   engine: TQSOPartyEngine;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_MississippiRealEngineOutOfState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(False);
      CheckEquals(82, mo.DomList.Count, 'outside Mississippi: the 82 counties');
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('W5XX', '599 HIN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a county accepted and credited');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW 2');
      CheckFalse(rx.PrefixMult, 'a CW QSO earns no grid');
      dupe := engine.Enter('W5XX', '59 HIN', Band40, Phone, eLSB, accepted, rx);
      CheckFalse(dupe, 'another band and mode');
      CheckFalse(rx.DomesticMult, 'a county once, "regardless of band/mode"');
      CheckEquals(1, Integer(rx.QSOPoints), 'SSB 1');
      dupe := engine.Enter('W5XX', '599 HIN', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'the same band and mode is a dupe');
      dupe := engine.Enter('W5XX', '599 RAN', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'a rover in a new county is a new station (NY4I)');

      (* NO FM, NO AM (NY4I): logged, an automatic X-QSO. *)
      engine.Enter('W5FM', '59 YAZ', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, 'an FM QSO is logged: ' + string(ExchangeErrorMessage));
      CheckTrue(LoggedQSOIsXQSO(rx), 'FM is no mode of this contest');
      CheckFalse(rx.DomesticMult, 'and earns nothing');

      (* RTTY: a county, 2 points. *)
      engine.Enter('W5RY', '599 LEE', Band15, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'an RTTY county');
      CheckEquals(2, Integer(rx.QSOPoints), 'RTTY 2');
      CheckFalse(rx.PrefixMult, 'RTTY earns no grid');
      engine.Enter('W5RZ', '599 EM52', Band15, Digital, eRTTY, accepted, rx);
      CheckFalse(accepted, 'a grid on RTTY is no county: refused');

      (* FT4/FT8: "ALL FT4/8 stations send signal report and Grid Square". *)
      engine.Enter('W5FT', '-10 EM52', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'report and grid taken: ' + string(ExchangeErrorMessage));
      CheckEquals('EM52', string(rx.QTHString), 'the grid is the received QTH');
      CheckEquals(-10, Integer(rx.RSTReceived), 'the signed report');
      CheckEquals('EM52', string(rx.Prefix), 'the grid key, set at the parse');
      CheckTrue(rx.PrefixMult, 'a Mississippi grid is a multiplier');
      CheckFalse(rx.DomesticMult, 'no county from an FT QSO');
      CheckEquals(2, Integer(rx.QSOPoints), 'FT8 2');
      CheckFalse(LoggedQSOIsXQSO(rx), 'not an X-QSO');
      engine.Enter('W5FU', 'em52ab', Band40, Digital, eFT4, accepted, rx);
      CheckTrue(accepted, 'a six-character grid alone, FT4');
      CheckEquals('EM52', string(rx.QTHString), 'kept as its square');
      CheckFalse(rx.PrefixMult, 'the same grid, once overall');
      engine.Enter('W1FT', '-05 FN31', Band20, Digital, eFT8, accepted, rx);
      CheckFalse(accepted, 'outside Mississippi only the nine Mississippi grids');
      CheckEquals(UnicodeFormat(SExchangeOutOfStateWorksHostOnly, ['MS']),
                  string(ExchangeErrorMessage), 'with the host-area message');
      (* AN FT QSO WITH NO GRID IS NOT REFUSED (WSJT-X's hand-off runs this
         parse): judged by the host-area rule as RTTY would be, and "NO grid
         is a zero point qso" (NY4I, 2026-11-18). *)
      engine.Enter('W5FV', 'HIN', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'FT8 with a county and no grid is logged: ' + string(ExchangeErrorMessage));
      CheckFalse(LoggedQSOIsXQSO(rx), 'a Mississippi county: not an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'FT8 with no grid: 0 points');
      CheckFalse(rx.DomesticMult or rx.PrefixMult, 'and no multiplier: an FT QSO earns only a grid');
      engine.Enter('W1FV', 'CT', Band20, Digital, eFT8, accepted, rx);
      CheckFalse(accepted, 'FT8 with a state outside Mississippi: the host-area rule');

      (* OFF-BAND: an automatic X-QSO. *)
      engine.Enter('W5OFF', '599 PIK', Band30, CW, eCW, accepted, rx);
      CheckTrue(LoggedQSOIsXQSO(rx), '30 m is no band of this contest: an automatic X-QSO');
      engine.Enter('W5OFF', '599 PIK', Band2, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, '2 m counts, and the X-QSO marked nothing');

      (* THE HOST-AREA RULE, typed. *)
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'outside Mississippi, work Mississippi stations only');

      (* COUNTY LINES: one county or two (DXLog). *)
      ClearPendingCounties;
      engine.Enter('W5LN', '599 ADA/ALC', Band10, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a county line: ' + string(ExchangeErrorMessage));
      CheckEquals(1, PendingCountiesCount, 'the second county its own QSO');
      ClearPendingCounties;
      accepted := True;
      engine.Enter('W5LN', '599 ADA/ALC/AMI', Band10, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      ClearPendingCounties;

      (* THE RESCORE KEEPS THE GRID KEY. *)
      rx := FTQSO('W5RS', 'EM43', Band20, eFT8);
      rx.Prefix := '';
      rx.QSOPoints := 99;
      RecomputeQSOScoring(rx);
      CheckEquals('EM43', string(rx.Prefix), 'the stored grid re-keyed');
      CheckEquals(2, Integer(rx.QSOPoints), 'and rescored');
      rx.ExtMode := eRTTY;
      RecomputeQSOScoring(rx);
      CheckEquals('', string(rx.Prefix), 'an edit to RTTY drops a stale grid');
   finally
      engine.Free;
   end;
end;

(* "Same station can be worked on each separate band/mode. Example, W5XX can
   work W1AW on 20m CW, 20m SSB, 20m RTTY, 20m FT4/8." -- FOUR dupe modes per
   band, through the real engine: the dupe sheet's one digital slot is split
   into RTTY and FT by the received-QTH dupe key (the class header). *)
procedure TContestMississippiQPTests.Test_RealEngineFourDupeModes;
var
   engine: TQSOPartyEngine;
   inHost: boolean;
   accepted, dupe: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_MississippiRealEngineFourDupeModes');
   for inHost := False to True do
      begin
      engine := TQSOPartyEngine.Create(PartyHandle);
      try
         engine.Activate(inHost);
         dupe := engine.Enter('W5XX', '599 HIN', Band20, CW, eCW, accepted, rx);
         CheckTrue(accepted and not dupe, '20 m CW');
         dupe := engine.Enter('W5XX', '59 HIN', Band20, Phone, eUSB, accepted, rx);
         CheckTrue(accepted and not dupe, '20 m SSB');
         dupe := engine.Enter('W5XX', '599 HIN', Band20, Digital, eRTTY, accepted, rx);
         CheckTrue(accepted and not dupe, '20 m RTTY');
         dupe := engine.Enter('W5XX', '-10 EM42', Band20, Digital, eFT8, accepted, rx);
         CheckTrue(accepted, '20 m FT8 accepted');
         CheckFalse(dupe, '20 m FT8 is not a dupe of 20 m RTTY');
         dupe := engine.Enter('W5XX', '-12 EM42', Band20, Digital, eFT4, accepted, rx);
         CheckTrue(dupe, 'FT4 after FT8 on 20 m is a dupe: "FT4/8" is one mode');
         dupe := engine.Enter('W5XX', '599 HIN', Band20, Digital, eRTTY, accepted, rx);
         CheckTrue(dupe, 'RTTY again on 20 m is a dupe');
         dupe := engine.Enter('W5XX', '599 HIN', Band20, CW, eCW, accepted, rx);
         CheckTrue(dupe, 'CW again on 20 m is a dupe');
         dupe := engine.Enter('W5XX', '-10 EM42', Band40, Digital, eFT8, accepted, rx);
         CheckFalse(dupe, 'FT8 on another band');
      finally
         engine.Free;
      end;
      end;
end;

procedure TContestMississippiQPTests.Test_RealEngineInState;
var
   engine: TQSOPartyEngine;
   accepted: boolean;
   rx: ContestExchange;
begin
   BeginTest('Test_MississippiRealEngineInState');
   engine := TQSOPartyEngine.Create(PartyHandle);
   try
      engine.Activate(True);
      CheckFalse(Settings.Mult.ByBand or Settings.Mult.ByMode, 'multipliers once overall');

      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a remaining state');
      engine.Enter('W1AW', '599 CT', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'CT once');
      engine.Enter('W5XX', '599 HIN', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a Mississippi county is a multiplier in state too');
      engine.Enter('W5MS', '599 MS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a station logged as MS is accepted');
      CheckFalse(rx.DomesticMult, '"remaining States": MS is no multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), 'but its points count');
      engine.Enter('VE4AA', '599 MB', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a province');
      engine.Enter('VO1AA', '599 NF', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'NF is NL');
      engine.Enter('W3AA', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'DC accepted, as Maryland');
      engine.Enter('W3AB', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland already counted through DC (NY4I)');

      (* "1 for each remaining DX Country/Entity worked". *)
      engine.Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a DX station sends its country');
      CheckTrue(rx.DXMult, 'its entity is a DXCC multiplier');
      CheckFalse(rx.DomesticMult, 'and no domestic one');
      CheckEquals('599 DL     ', PartyReceivedCabrilloColumn(PartyHandle, rx),
                  'the received column is its country');
      engine.Enter('DL1AAA', '599 DL', Band40, Digital, eRTTY, accepted, rx);
      CheckFalse(rx.DXMult, 'DL once overall');
      engine.Enter('KL7AA', '599 AK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'Alaska is a state');
      CheckFalse(rx.DXMult, 'KL is no DXCC multiplier');

      (* FT: ANY GRID, the total counted divided by four. *)
      engine.Enter('JA1FT', '-15 PM95', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'a JA''s FT8 grid, in state');
      CheckTrue(rx.PrefixMult, 'its grid counts');
      CheckFalse(rx.DXMult, 'its entity does not, from an FT QSO');
      engine.Enter('JA1FT', '599 JA', Band20, CW, eCW, accepted, rx);
      CheckTrue(rx.DXMult, 'JA is still new on CW');
      engine.Enter('W5FT', '-10 EM52', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(rx.PrefixMult, 'a Mississippi grid counts in the total too (NY4I, 2026-11-18)');
   finally
      engine.Free;
   end;
end;

procedure TContestMississippiQPTests.Test_ExportColumns;
var
   party, stationed: TContestBase;
   rx: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   line: string;
   station: TStationContext;
   text: string;
begin
   BeginTest('Test_MississippiExportColumns');
   party := ContestIdentity(PartyHandle);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';

   (* AN OUT-OF-STATE ENTRANT (PA) WORKS HINDS -- the standard line. *)
   rx := MSQSO('W5XX', 'HIN', Band20, CW, eCW);
   my := Default(TMyStationExchange);
   my.MyState := 'PA';
   my.MyGrid := 'FN20';
   ctx.HisQTH := 'HIN';
   line := 'QSO: 14000 CW 2026-04-04 1400 W3AAA ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W5XX ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14000 CW 2026-04-04 1400 W3AAA 599 PA     W5XX 599 HIN    ',
      line, 'RST + state sent, RST + county received');
   CheckEquals('599 PA     ', party.FormatADIFSentExchange(my, rx), 'ADIF STX_STRING');

   (* A DX ENTRANT SENDS ITS COUNTRY (NY4I: not "DX"). *)
   station := StationAt(False);
   station.MyState := '';
   station.MyCountry := 'DL';
   stationed := Make(PartyHandle, station);
   try
      my.MyState := '';
      CheckEquals('599 DL     ', stationed.FormatCabrilloSentExchange(my, rx, ctx),
                  '"DX stations send signal report and Country"');
      CheckEquals('599 DL     ', stationed.FormatADIFSentExchange(my, rx), 'and in STX_STRING');
      CheckEquals(' 5NN DL', stationed.CQExchangeDefault(station), 'and in the CQ exchange');
   finally
      stationed.Free;
   end;
   CheckEquals(' 5NN HIN', party.CQExchangeDefault(StationAt(True)), 'a Mississippi station its county');

   (* AN FT QSO: DG, its grid received, OUR grid sent -- "ALL FT4/8 stations
      send signal report and Grid Square". *)
   my.MyState := 'HIN';
   my.MyGrid := 'em42xx';
   rx := FTQSO('W5FT', 'EM52', Band20, eFT8);
   rx.RSTSent := -4;
   ctx.RSTSent := '-04';
   ctx.RSTReceived := '-10';
   ctx.HisQTH := '';
   line := 'QSO: 14074 ' + party.CabrilloModeString(rx.Mode, rx.ExtMode) +
      ' 2026-04-04 1400 W5XX ' +
      party.FormatCabrilloSentExchange(my, rx, ctx) + 'W5FT ' +
      party.FormatCabrilloReceivedExchange(my, rx, ctx);
   CheckEquals('QSO: 14074 DG 2026-04-04 1400 W5XX -04 EM42   W5FT -10 EM52   ',
      line, 'an FT QSO''s line');
   CheckEquals('-4  EM42   ', party.FormatADIFSentExchange(my, rx), 'STX_STRING: report and our grid');
   CheckEquals('-10 EM52', party.FormatADIFReceivedExchange(rx, True), 'SRX_STRING: report and grid');
   my.MyGrid := '';
   CheckEquals('-04 HIN    ', party.FormatCabrilloSentExchange(my, rx, ctx),
               'no grid recorded: the county (NOT APPROVED -- awaits NY4I)');
   rx.DomesticQTH := 'EM52';
   CheckEquals('', party.ADIFCountyState(rx), 'a grid is no county, even in DomesticQTH');
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<STATE:', text) = 0, 'no STATE for an FT QSO: ' + text);
   CheckTrue(Pos('<CONTEST_ID:12>MS-QSO-PARTY', text) > 0, 'CONTEST_ID: ' + text);

   (* AN RTTY QSO: RY, the county, STATE MS. *)
   rx := MSQSO('W5RY', 'HIN', Band20, Digital, eRTTY);
   CheckEquals('RY', party.CabrilloModeString(rx.Mode, rx.ExtMode), 'RTTY is RY');
   text := EmitADIFRecord(rx);
   CheckTrue(Pos('<STATE:2>MS', text) > 0, 'a county is in Mississippi: ' + text);
end;

(* A WSJT-X OR ADIF QSO: an FT QSO's GRIDSQUARE is its grid; RTTY keeps its
   county; an unknown digital submode takes the grid only when it carried no
   other QTH. *)
procedure TContestMississippiQPTests.Test_ADIFImport;
var
   temps: TADIFRecordTemps;
   exch: ContestExchange;

   function Imported(aMode: ModeType; aExtMode: ExtendedModeType; const aQTH: string): string;
   begin
      exch := Default(ContestExchange);
      exch.ceContest := PartyHandle;
      exch.Mode := aMode;
      exch.ExtMode := aExtMode;
      exch.QTHString := ShortString(aQTH);
      ContestIdentity(PartyHandle).ApplyADIFImport(temps, NeutralADIFImportSession, exch);
      Result := string(exch.QTHString);
   end;

begin
   BeginTest('Test_MississippiADIFImport');
   temps := Default(TADIFRecordTemps);
   temps.GridSquare := 'em52ab';
   CheckEquals('EM52', Imported(Digital, eFT8, 'MS'), 'FT8: the GRIDSQUARE, four characters, over the STATE');
   CheckEquals('', string(exch.DomesticQTH), 'no domestic key');
   CheckEquals('EM52', Imported(Digital, eFT4, ''), 'FT4');
   CheckEquals('HIN', Imported(Digital, eRTTY, 'HIN'), 'RTTY keeps its county');
   CheckEquals('EM52', Imported(Digital, eData, ''), 'an unknown digital submode with no QTH takes the grid');
   CheckEquals('HIN', Imported(Digital, eData, 'HIN'), 'and keeps a QTH it carried');
   CheckEquals('', Imported(CW, eCW, ''), 'a CW QSO''s GRIDSQUARE is no received QTH');
   temps.GridSquare := 'EM52ab12';
   CheckEquals('EM52', Imported(Digital, eFT8, ''), 'an eight-character grid is its square');
   temps.GridSquare := 'ZZ00';
   CheckEquals('', Imported(Digital, eFT8, ''), 'ZZ00 is no grid');
end;

procedure TContestMississippiQPTests.RunAllTests;
begin
   Test_Identity;
   Test_CountyFileAndInStateFile;
   Test_FourCharacterGridSquare;
   Test_BandsModesAndPoints;
   Test_MultiplierAnswers;
   Test_ScoreGridsDividedByFour;
   Test_RealEngineOutOfState;
   Test_RealEngineFourDupeModes;
   Test_RealEngineInState;
   Test_ExportColumns;
   Test_ADIFImport;
end;

end.
