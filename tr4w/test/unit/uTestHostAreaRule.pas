(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* A QSO PARTY'S HOST-AREA RULE, ON BOTH SIDES -- Q107 (NY4I, 2026-10-16:
  "yes, go with your recommendation").

  "An out-of-state station works only the host state" was enforced only when
  a QSO was TYPED (the M5b refusal, design 7.10). A QSO that arrived any other
  way -- an ADIF import, a network peer, a rescore -- scored against it:
  measured in the frozen contest matrix, an out-of-state (Kansas) entrant's
  W1AW sending CT scored 2-3 points and counted CT as a multiplier in Idaho,
  Delaware, Florida and Nebraska alike. Since Q107 an out-of-area entrant's
  QSO whose received QTH the session's domestic table does not know is
  logged, scores 0 and earns no multiplier.

  WHAT IS PINNED HERE
    * two single-state parties (Idaho, Nebraska) and the multi-state ones
      (7QP, New England, the IN7QPNE composite): out of area, a host county
      scores and is credited; another state's QTH and a DX station's empty
      QTH score 0 and are not; in area, another state still scores;
    * the operator's QSO POINTS overrides cannot score an uncredited QSO
      (the rule runs before them, as the band rule does);
    * THE ONE PREDICATE: for every contest, station and QTH, a typed
      exchange is refused exactly when the logged record is not credited;
    * THE RESCORE: MainUnit.RecomputeQSOScoring -- the body of the rescore
      loop the Rescore menu item, /RESCORE and the contest matrix all run --
      over the real engine and its domestic table gives the out-of-state x
      out-of-state QSO 0 points and no multiplier.

  THE TABLE IS A STUB in all but the last: StubHostTable knows the keys in
  GHostKeys, as an out-of-state session's county file knows its counties.
  The stub is handed to BOTH sides -- the typed session and the station --
  exactly as the engine hands LOGDUPE.DomesticTableKnowsQTH to both. *)
unit uTestHostAreaRule;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   uTR4WTestFramework;

type
   THostAreaRuleTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_SingleStatePartiesCreditOnlyTheHostOutOfState;
      procedure Test_MultiStatePartiesCreditOnlyTheirAreaOutOfArea;
      procedure Test_OverridesCannotScoreAnUncreditedQSO;
      procedure Test_EntryRefusalAndScoringGiveOneAnswer;
      procedure Test_RescoreGivesAnOutOfStateQSOZero;
      procedure Test_ALogsOwnMyStateDecidesInStateAtOpen;
      procedure CheckParty(aContest: ContestType; const aHostCounty: string);
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   SysUtils,
   uSettingsModel,
   uMults,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   LogDupe,
   LogDom,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit,
   (* The open's replay and the test log -- Test_ALogsOwnMyStateDecidesInStateAtOpen *)
   uLogStore,
   uLogDatabase,
   uLogRepository,
   uDomFileKeys,
   uCabrillo,
   utils_text,
   uTestLatestContest,
   uTestContestObjects,
   uTestExchangeParserStub;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

var
   (* The keys the stubbed domestic table knows, comma-separated, uppercase. *)
   GHostKeys: string;
   (* The QTH the stubbed parser writes into the exchange. *)
   GTypedQTH: string;

const
   (* One host county per party, as the stub table knows them: Idaho's Ada,
      Nebraska's Adams, a 7th-area county, a New England county and an
      Indiana county as in7qpne_cty.dom spells it. *)
   HOST_KEYS = 'ADA,ADMS,AZAPH,MEAND,INADA';

function StubHostTable(const aQTH: string): boolean;
begin
   Result := (aQTH <> '') and
             (Pos(',' + UpperCase(aQTH) + ',', ',' + GHostKeys + ',') > 0);
end;

(* An entrant: in or out of the host area. MY STATE 'MA' is in New England
   (NEQP's in-area test); InHostState is set-up's answer every other party
   reads. Out of area is a Kansas station. *)
function Entrant(aInArea: boolean): TStationContext;
begin
   Result := NoStation;
   Result.InHostState := aInArea;
   if aInArea then
      begin
      Result.MyState := 'MA';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
   Result.IsDomesticQTH := @StubHostTable;
end;

(* A logged QSO with a station that sent aQTH -- '' for a DX station that
   sent none -- carrying it as typed and as the table resolved it, as an
   imported record does. *)
function Worked(const aQTH: string): ContestExchange;
begin
   FillChar(Result, SizeOf(ContestExchange), 0);
   Result.Band := Band20;
   Result.Mode := CW;
   Result.QTHString := ShortString(aQTH);
   Result.DomesticQTH := ShortString(aQTH);
   Result.DomMultQTH := ShortString(aQTH);
end;

function PointsOf(aContest: ContestType; const aStation: TStationContext;
                  const aQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(aContest, aStation);
   try
      qso := Worked(aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* What the multiplier sheet asks (logdupe's SetMultFlags). *)
function Credited(aContest: ContestType; const aStation: TStationContext;
                  const aQTH: string): boolean;
var
   contestObject: TContestBase;
begin
   contestObject := Make(aContest, aStation);
   try
      Result := ContestCreditsWorkedStation(contestObject, Worked(aQTH));
   finally
      contestObject.Free;
   end;
end;

(* The engine's parser, as far as these tests need it: the typed QTH goes in
   the record, and -- as FoundDomesticQTH does -- the domestic QTH is the
   table's key when the table knows it, else empty. IN7QPNE routes on it. *)
function StubParser(const aHelper: string; const aText: string;
                    var aExch: ContestExchange): boolean;
begin
   aExch.QTHString := ShortString(GTypedQTH);
   if StubHostTable(GTypedQTH) then
      begin
      aExch.DomesticQTH := ShortString(GTypedQTH);
      end
   else
      begin
      aExch.DomesticQTH := '';
      end;
   Result := True;
end;

function Session: TReceivedExchangeSession;
begin
   FillChar(Result, SizeOf(TReceivedExchangeSession), 0);
   Result.Parsers := StubExchangeParsers(@StubParser);
   Result.IsDomesticQTH := @StubHostTable;
   Result.CallWindowHasCall := True;
end;

function ContestName(aContest: ContestType): string;
begin
   Result := string(ContestTypeSA[aContest]);
end;

(* Out of area: the host county scores and is credited; another state's QTH
   and a DX station's empty one score 0 and are not. In area: another state
   scores. *)
procedure THostAreaRuleTests.CheckParty(aContest: ContestType; const aHostCounty: string);
var
   who: string;
begin
   who := ContestName(aContest);
   CheckTrue(PointsOf(aContest, Entrant(False), aHostCounty) > 0,
                   who + ': out of area, a host county scores');
   CheckTrue(Credited(aContest, Entrant(False), aHostCounty),
                   who + ': out of area, a host county is credited');
   CheckEquals(0, PointsOf(aContest, Entrant(False), 'CT'),
                     who + ': out of area, another state scores 0');
   CheckFalse(Credited(aContest, Entrant(False), 'CT'),
                    who + ': out of area, another state earns no multiplier');
   CheckEquals(0, PointsOf(aContest, Entrant(False), ''),
                     who + ': out of area, a DX station with no host QTH scores 0');
   CheckFalse(Credited(aContest, Entrant(False), ''),
                    who + ': out of area, a DX station earns no multiplier');
   CheckTrue(PointsOf(aContest, Entrant(True), 'ON') > 0,
                   who + ': in area, another state or province still scores');
   CheckTrue(Credited(aContest, Entrant(True), 'ON'),
                   who + ': in area, every station is credited');
end;

(* ---------------------------------------------------------------------------
   THE TESTS
   --------------------------------------------------------------------------- *)

procedure THostAreaRuleTests.Test_SingleStatePartiesCreditOnlyTheHostOutOfState;
begin
   BeginTest('Test_SingleStatePartiesCreditOnlyTheHostOutOfState');
   GHostKeys := HOST_KEYS;
   CheckParty(IDAHOQSOPARTY, 'ADA');
   CheckParty(NEBRASKAQSO, 'ADMS');
end;

(* The 7QP and New England state the rule themselves (they are not on the
   state-party base); IN7QPNE asks the party that judges the QSO. Every
   IN7QPNE entrant is out of all four areas (Q104), so only that side is
   asked of it. *)
procedure THostAreaRuleTests.Test_MultiStatePartiesCreditOnlyTheirAreaOutOfArea;
begin
   BeginTest('Test_MultiStatePartiesCreditOnlyTheirAreaOutOfArea');
   GHostKeys := HOST_KEYS;
   CheckParty(SEVENQP, 'AZAPH');
   CheckParty(NEWENGLANDQSO, 'MEAND');

   CheckTrue(PointsOf(IN7QPNE, Entrant(False), 'INADA') > 0,
             'IN7QPNE: an Indiana county scores for an out-of-area entrant');
   CheckTrue(Credited(IN7QPNE, Entrant(False), 'INADA'),
             'IN7QPNE: and is credited');
   CheckEquals(0, PointsOf(IN7QPNE, Entrant(False), 'CT'),
               'IN7QPNE: a state in no party scores 0');
   CheckFalse(Credited(IN7QPNE, Entrant(False), 'CT'),
              'IN7QPNE: and earns no multiplier');
end;

procedure THostAreaRuleTests.Test_OverridesCannotScoreAnUncreditedQSO;
var
   station: TStationContext;
begin
   BeginTest('Test_OverridesCannotScoreAnUncreditedQSO');
   GHostKeys := HOST_KEYS;
   station := Entrant(False);
   station.PointOverrides.DomesticCW.Stated := True;
   station.PointOverrides.DomesticCW.Points := 7;
   station.PointOverrides.DXCW.Stated := True;
   station.PointOverrides.DXCW.Points := 9;
   CheckEquals(7, PointsOf(IDAHOQSOPARTY, station, 'ADA'),
               'the override scores a host county (the control)');
   CheckEquals(0, PointsOf(IDAHOQSOPARTY, station, 'CT'),
               'and cannot score another state: the rule runs first');
   CheckEquals(0, PointsOf(IDAHOQSOPARTY, station, ''),
               'nor a DX station');
end;

(* THE ONE PREDICATE. For every party, at both kinds of entrant, for host
   counties, states, a province, a DX country and nothing: the typed
   exchange is refused (with the host-area reason) exactly when the record
   it leaves is not credited. Both sides are handed one table, as the engine
   hands both LOGDUPE.DomesticTableKnowsQTH. *)
procedure THostAreaRuleTests.Test_EntryRefusalAndScoringGiveOneAnswer;
const
   CONTESTS: array[0..6] of ContestType = (IDAHOQSOPARTY, NEBRASKAQSO,
      FLORIDAQSOPARTY, DELAWAREQSOPARTY, SEVENQP, NEWENGLANDQSO, IN7QPNE);
   QTHS: array[0..7] of string = ('ADA', 'ADMS', 'AZAPH', 'MEAND', 'INADA',
                                  'CT', 'ON', 'JA');
var
   c: integer;
   q: integer;
   inArea: boolean;
   contestObject: TContestBase;
   exch: ContestExchange;
   accepted: boolean;
   msg: string;
   who: string;
   compared: integer;
begin
   BeginTest('Test_EntryRefusalAndScoringGiveOneAnswer');
   GHostKeys := HOST_KEYS;
   compared := 0;
   for c := Low(CONTESTS) to High(CONTESTS) do
      begin
      for inArea := False to True do
         begin
         (* IN7QPNE has no in-area entrant (Q104). *)
         if inArea and (CONTESTS[c] = IN7QPNE) then
            begin
            Continue;
            end;
         for q := Low(QTHS) to High(QTHS) do
            begin
            who := ContestName(CONTESTS[c]) + ' in area ' + BoolToStr(inArea, True) +
                   ' QTH ' + QTHS[q];
            GTypedQTH := QTHS[q];
            contestObject := Make(CONTESTS[c], Entrant(inArea));
            try
               exch := Worked('');
               accepted := contestObject.ParseReceivedExchange('599 ' + QTHS[q],
                                                               Session, exch, msg);
               (* The record the typed exchange leaves is the one scored. *)
               CheckTrue(accepted = ContestCreditsWorkedStation(contestObject, exch),
                         who + ': refused when typed exactly when not credited');
               if not accepted then
                  begin
                  CheckTrue(Pos('Out of state', msg) = 1,
                            who + ': refused for the host-area rule, "' + msg + '"');
                  end;
               Inc(compared);
            finally
               contestObject.Free;
            end;
            end;
         end;
      end;
   CheckEquals(13 * Length(QTHS), compared, 'every contest, entrant and QTH compared');
end;

(* THE RESCORE, THROUGH THE REAL ENGINE -- NY4I, 2026-10-16: "selecting
   rescore contest in the menu should rescore too". The menu's Rescore is
   MainUnit.RescoreLog -> tUpdateLog(actRescore), whose loop body is
   RecomputeQSOScoring (lifted so the contest matrix runs exactly it). It
   reaches the rule through Sheet.SetMultFlags and LOGSTUFF's
   CalculateQSOPoints -> ScoreQSO on ActiveContest, whose station is
   uContestFactory.CurrentStation: StationInHostState, and the domestic table
   through LOGDUPE.DomesticTableKnowsQTH. Nothing stored on the record is
   trusted: the flags are cleared and the points zeroed first.

   The table holds Ada, the one line of idaho_cty.dom this needs, as
   uTestOffBandCredit adds it; it is taken out again. *)
procedure THostAreaRuleTests.Test_RescoreGivesAnOutOfStateQSOZero;
var
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   ctyPath: string;
   (* Whether Ada was in the domestic table before this test put it there. *)
   hadAda: boolean;
   rx: ContestExchange;

   function Logged(const aCall: string; const aQTH: string): ContestExchange;
   begin
      FillChar(Result, SizeOf(ContestExchange), 0);
      Result.ceRecordKind := rkQSO;
      Result.Callsign := CallString(aCall);
      Result.Band := Band20;
      Result.Mode := CW;
      Result.Zone := DUMMYZONE;
      Result.QTHString := ShortString(aQTH);
      Result.DomesticQTH := ShortString(aQTH);
      Result.DomMultQTH := ShortString(aQTH);
      (* As stored before the rule: points and a multiplier flag. *)
      Result.QSOPoints := 2;
      Result.DomesticMult := True;
   end;

begin
   BeginTest('Test_RescoreGivesAnOutOfStateQSOZero');

   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   hadAda := DomQTHTable.HasPrefix('ADA');
   try
      Contest := ContestHandleOf(IDAHOQSOPARTY);
      StationInHostState := False;
      Settings.Mult.ByBand := False;
      Settings.Mult.ByMode := True;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;
      DomQTHTable.AddNewPrefixRecord('ADA', 'ADA', 'ADA');

      (* Out of state x out of state: W1AW in Connecticut, as an import or a
         peer would log it. *)
      rx := Logged('W1AW', 'CT');
      RecomputeQSOScoring(rx);
      CheckEquals(0, Integer(rx.QSOPoints), 'rescored, the CT QSO scores 0');
      CheckFalse(rx.DomesticMult, 'rescored, CT is no multiplier');
      Sheet.AddQSOToSheets(@rx, False);
      CheckEquals(0, Integer(mo.MTotals[AllBands, Both, rmDomestic]),
                  'and the sheet counts no domestic multiplier');

      (* THE CONTROL: a host county still scores and counts. *)
      rx := Logged('K7ABC', 'ADA');
      RecomputeQSOScoring(rx);
      CheckTrue(rx.QSOPoints > 0, 'rescored, Ada scores');
      CheckTrue(rx.DomesticMult, 'rescored, Ada is a new multiplier');

      (* AN IDAHO ENTRANT works everyone: the same CT record scores. *)
      StationInHostState := True;
      rx := Logged('W1AW', 'CT');
      RecomputeQSOScoring(rx);
      CheckTrue(rx.QSOPoints > 0, 'in state, the CT QSO scores');
   finally
      (* The table as it was. *)
      if not hadAda then
         begin
         DomQTHTable.RemovePrefix('ADA');
         end;
      mo.ClearAllMults;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedByMode;
      Settings.Mult.ByBand := savedByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

(* ---------------------------------------------------------------------------
   THE LOG'S OWN MY STATE DECIDES IN STATE, AT OPEN -- 2026-10-23
   --------------------------------------------------------------------------- *)

var
   (* What the test's contest set-up saw, and decided. *)
   GSetUpResolvedState: string;
   GSetUpCalls: integer;

(* THE TEST'S CONTEST SET-UP for LogStoreApplyContestConfigWith: the one
   decision of FoundContest's this is about -- StationInHostState from the
   RESOLVED MY STATE against the party's county file (FoundMyStateInDomFile's
   rule, read from the tree's dom folder) -- and the Contest handle. Nothing
   else of the session is rewritten. *)
function SetUpMichiganAsFoundContestDecides(const aContestId: ShortString): boolean;
var
   h: TContestHandle;
begin
   Inc(GSetUpCalls);
   Result := FindContestById(string(aContestId), h);
   if not Result then
      begin
      Exit;
      end;
   Contest := h;
   GSetUpResolvedState := Settings.My.ResolvedState;
   StationInHostState := DomFileOnDiskDeclaresKey(
      ShippedDomDir + ContestIdentity(h).DomesticFileName + '.dom',
      Settings.My.ResolvedState);
end;

(* THE CORPUS'S michigan_qp_2026_ny4i, REDUCED: a database-only Michigan log
   whose OWN MY STATE (source 'contest') is WAYN -- a Michigan county -- on a
   station whose MY STATE is something else. Opened through the replay every
   start-up and /EXPORT runs (LogStoreApplyContestConfigWith, the body of
   LogStoreApplyContestConfig), the contest must be set up with WAYN in
   force: an in-state entrant, who works anyone. The corpus exported its DC,
   MD, VA and OH QSOs as X-QSO: once the X-QSO predicate asked the host-area
   rule (Q119), because CONTEST was replayed before MY STATE and the set-up
   read the station's value. *)
procedure THostAreaRuleTests.Test_ALogsOwnMyStateDecidesInStateAtOpen;
var
   savedContest: TContestHandle;
   savedInHostState: boolean;
   savedSilent: boolean;
   savedLogName: string;
   savedStation: string;
   hadOverride: boolean;
   savedOverride: string;
   trw: string;
   dbName: string;
   db: TLogDatabase;
   repo: TLogRepository;
   michigan: TContestHandle;
   rx: ContestExchange;
begin
   BeginTest('Test_ALogsOwnMyStateDecidesInStateAtOpen');
   michigan := ContestHandleOf(MICHQSOPARTY);
   savedContest := Contest;
   savedInHostState := StationInHostState;
   savedSilent := tSilentExport;
   savedLogName := CharBufferText(TR4W_LOG_FILENAME);
   savedStation := Settings.My.State;
   hadOverride := Settings.My.HasContestOverride(sfState);
   savedOverride := Settings.My.ContestOverride(sfState);
   trw := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_hostarea_' +
          IntToStr(GetProcessID) + '.trw';
   dbName := LogDatabaseFileName(trw);
   try
      (* No capture at close, and whatever an earlier suite left open shut. *)
      tSilentExport := True;
      LogStoreClose;

      MakeTestContestLog(dbName, michigan, 'NY4I');
      db := TLogDatabase.Create;
      try
         db.Open(dbName);
         repo := TLogRepository.Create(db);
         try
            repo.SaveConfigValue('MY STATE', 'WAYN', 'contest');
            repo.Commit;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
      SetCharBuffer(TR4W_LOG_FILENAME, trw);

      (* THE STATION IS ELSEWHERE, and no contest override is in force yet:
         only the log can say WAYN. Contest is NoContest, so the replay sets
         the log's own contest up. *)
      Settings.My.ClearContestOverride(sfState);
      Settings.My.State := 'FL';
      Contest := NoContest;
      ReleaseActiveContest;
      StationInHostState := False;

      GSetUpCalls := 0;
      GSetUpResolvedState := '';
      LogStoreApplyContestConfigWith(@SetUpMichiganAsFoundContestDecides);
      CheckEquals(1, GSetUpCalls, 'the open set the log''s contest up');
      CheckEquals('WAYN', GSetUpResolvedState,
                  'with the log''s own MY STATE in force at set-up');
      CheckTrue(StationInHostState, 'so a WAYN entrant is IN STATE');

      (* AND THE X-QSO PREDICATE READS THAT ONE ANSWER: DC, worked by an
         in-state entrant, is a plain QSO -- the export's own Cabrillo line. *)
      ActiveContest(Contest);
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W3ED';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14020000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'DC';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 4;
      rx.tSysTime.qtDay := 8;
      CheckFalse(LoggedQSOIsXQSO(rx), 'in state, W3ED in DC is not an X-QSO');
      CheckEquals('QSO: ', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 5),
                  'and its Cabrillo line is a plain QSO:');
   finally
      LogStoreClose;
      SetCharBuffer(TR4W_LOG_FILENAME, savedLogName);
      ScrubTestLog(dbName);
      Settings.My.State := savedStation;
      if hadOverride then
         begin
         Settings.My.SetContestOverride(sfState, savedOverride);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfState);
         end;
      tSilentExport := savedSilent;
      StationInHostState := savedInHostState;
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure THostAreaRuleTests.RunAllTests;
begin
   Test_SingleStatePartiesCreditOnlyTheHostOutOfState;
   Test_MultiStatePartiesCreditOnlyTheirAreaOutOfArea;
   Test_OverridesCannotScoreAnUncreditedQSO;
   Test_EntryRefusalAndScoringGiveOneAnswer;
   Test_RescoreGivesAnOutOfStateQSOZero;
   Test_ALogsOwnMyStateDecidesInStateAtOpen;
end;

end.
