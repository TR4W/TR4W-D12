unit uTestStationFactOverrides;

(* A STATION FACT IS A DEFAULT A CONTEST MAY OVERRIDE -- design 7.12 (NY4I,
  2026-10-13): "I take my laptop to CQ zone 3 in Utah for a contest, so just
  that contest is CQ zone 3. So just as with things like state and section,
  we use station config as a default but allow the override at contest
  selection time."

  WHAT THESE PIN, in the order the ruling is stated:

    the resolver   no override -> the station's value; an override wins;
                   a cleared override falls back; MY QTH is MY STATE; a value
                   the station's property would refuse is refused here too;

    the station    an override never touches the station's property, its
                   ZoneWasSet flag or the settings file -- and a Preferences
                   edit DURING the contest changes the station while the
                   contest's override still wins for that contest;

    the log        the capture writes the override as 'contest' and the
                   station's value as 'station'; a reopen makes the row the
                   override again, never the station's value; a log written
                   BEFORE 7.12 (a 'contest' MY STATE row from a .cfg or the
                   dialog, unmarked) reads exactly as it did, and one with no
                   such row resolves to the station's value;

    the readers    the station context a contest class is handed carries MY
                   CQ ZONE resolved, and the state sent falls back to the
                   resolved MY STATE.

  THE LOG'S APPLY IS MODELLED, NOT CALLED, as uTestLogContestStatements does
  and for the same reason (uLogStore links MainUnit): ApplyStoredRows routes a
  station fact to TryOverrideForContest and anything else to TrySetByCommand
  -- the pair uLogStore runs through uCFG.ApplyContestStatement. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TStationFactOverrideTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
   protected
      procedure Test_EveryFactIsAPublishedStationProperty;
      procedure Test_NoOverrideResolvesToTheStation;
      procedure Test_AnOverrideWinsAndLeavesTheStationAlone;
      procedure Test_MyQthIsMyState;
      procedure Test_AClearedOverrideFallsBackToTheStation;
      procedure Test_PreferencesEditDuringTheContest;
      procedure Test_RefusedValuesAndNamesThatAreNotFacts;
      procedure Test_CaptureWritesTheOverrideAsTheContests;
      procedure Test_ReopenMakesTheRowTheOverrideAgain;
      procedure Test_ALogWrittenBefore712;
      procedure Test_StationContextCarriesTheResolvedCQZone;
      procedure Test_TheStateSentFallsBackToTheResolvedState;
      procedure Test_ContestResetClearsTheOverrides;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, TypInfo, fpjson,
   uSettingsModel,
   uCFG,              (* ClearContestCFGCommands *)
   uLogDatabase,
   uLogRepository,
   uLogContestStatements,
   uContestBase,      (* TStationContext *)
   uContestFactory,   (* CurrentStation *)
   FCONTEST;          (* SentMyState, ClearContestSentState *)

function TStationFactOverrideTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_facts_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TStationFactOverrideTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '-wal') then
      begin
      DeleteFile(aFileName + '-wal');
      end;
   if FileExists(aFileName + '-shm') then
      begin
      DeleteFile(aFileName + '-shm');
      end;
end;

(* uLogStore's apply, minus its logging: a station fact becomes the contest's
  override, anything else is a statement by name. *)
procedure ApplyStoredRows(aSettings: TR4WSettings; aRepository: TLogRepository);
var
   rows: TStringList;
   i: integer;
   cmd, val: string;
begin
   rows := TStringList.Create;
   try
      aRepository.LoadContestConfig(rows);
      KeepOnlyStatements(rows, LogHoldsStatementsOnly(aRepository), nil);
      for i := 0 to rows.Count - 1 do
         begin
         cmd := string(rows.Names[i]);
         val := string(rows.ValueFromIndex[i]);
         if aSettings.CommandIsContestOverridable(cmd) then
            begin
            aSettings.TryOverrideForContest(cmd, val);
            end
         else
            begin
            aSettings.TrySetByCommand(cmd, val);
            end;
         end;
   finally
      rows.Free;
   end;
end;

(* The stored value of one command as the REOPEN sees it -- through
  LoadContestConfig, which returns 'contest' rows only. aSource is 'contest'
  when the row is one the reopen applies, and '' when there is no such row
  (absent, or a 'station' record, which nothing applies). *)
function StoredRow(aRepository: TLogRepository; const aCommand: string;
                   out aSource: string): string;
var
   rows: TStringList;
   i: integer;
begin
   Result := '';
   aSource := '';
   rows := TStringList.Create;
   try
      aRepository.LoadContestConfig(rows);
      i := rows.IndexOfName(AnsiString(aCommand));
      if i >= 0 then
         begin
         Result := string(rows.ValueFromIndex[i]);
         aSource := 'contest';
         end;
   finally
      rows.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_EveryFactIsAPublishedStationProperty;
var
   s: TR4WSettings;
   fact: TStationFact;
   found: TStationFact;
   names: TStringList;
   i: integer;
   seen: array[TStationFact] of boolean;
begin
   BeginTest('every station fact names a published TMySettings property, and a command reaches it');
   s := TR4WSettings.Create;
   names := s.CommandNames;
   try
      for fact := Low(TStationFact) to High(TStationFact) do
         begin
         CheckTrue(GetPropInfo(TMySettings, AnsiString(STATION_FACT_PROPERTY[fact])) <> nil,
                   STATION_FACT_PROPERTY[fact] + ' is a published property of the station group');
         seen[fact] := False;
         end;

      for i := 0 to names.Count - 1 do
         begin
         if s.StationFactOfCommand(string(names[i]), found) then
            begin
            seen[found] := True;
            end;
         end;

      for fact := Low(TStationFact) to High(TStationFact) do
         begin
         CheckTrue(seen[fact], STATION_FACT_PROPERTY[fact] + ' is reachable by a command name');
         end;

      CheckFalse(s.CommandIsContestOverridable('MY CALL'), 'MY CALL is not one (Q65)');
      CheckFalse(s.CommandIsContestOverridable('MY COUNTRY'), 'nor MY COUNTRY');
      CheckFalse(s.CommandIsContestOverridable('MAIN CALLSIGN'), 'nor MAIN CALLSIGN');
      CheckFalse(s.CommandIsContestOverridable('QSO POINT METHOD'), 'nor a contest setting');
   finally
      names.Free;
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_NoOverrideResolvesToTheStation;
var
   s: TR4WSettings;
   fact: TStationFact;
begin
   BeginTest('with no override every fact resolves to the station''s value');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('MY STATE', 'FL'), 'the station''s state');
      CheckTrue(s.TrySetByCommand('MY ZONE', '5'), 'the station''s CQ zone');
      CheckTrue(s.TrySetByCommand('MY ITU ZONE', '8'), 'the station''s ITU zone');
      CheckTrue(s.TrySetByCommand('MY GRID', 'EL88'), 'the station''s grid');

      for fact := Low(TStationFact) to High(TStationFact) do
         begin
         CheckFalse(s.My.HasContestOverride(fact),
                    STATION_FACT_PROPERTY[fact] + ' has no override by construction');
         end;
      CheckEquals('FL', s.My.ResolvedState, 'MY STATE');
      CheckEquals('5', s.My.ResolvedZone, 'MY CQ ZONE');
      CheckEquals(8, s.My.ResolvedItuZone, 'MY ITU ZONE');
      CheckEquals('EL88', s.My.ResolvedGrid, 'MY GRID');
      CheckEquals('', s.My.ResolvedSection, 'an unset fact resolves to the station''s empty value');
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_AnOverrideWinsAndLeavesTheStationAlone;
var
   s: TR4WSettings;
   doc: TJSONObject;
begin
   BeginTest('NY4I''s case: zone 3 for one contest; the station keeps zone 5, unlatched, and on disk');
   s := TR4WSettings.Create;
   try
      (* A zone DERIVED from MY CALL, the ordinary station: not stated. *)
      s.My.DeriveZone('5');
      CheckFalse(s.My.ZoneWasSet, 'the station''s zone follows MY CALL');

      CheckTrue(s.TryOverrideForContest('MY ZONE', '3'), 'the contest states zone 3');
      CheckEquals('3', s.My.ResolvedZone, 'this contest is CQ zone 3');
      CheckEquals('5', s.My.Zone, 'the station is still zone 5');
      CheckFalse(s.My.ZoneWasSet,
                 'and still follows MY CALL -- an override is not the station''s statement');

      doc := s.ToJSON;
      try
         CheckEquals('5', doc.FindPath('My.Zone').AsString,
                     'what settings\tr4w.json would receive is the station''s zone');
      finally
         doc.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_MyQthIsMyState;
var
   s: TR4WSettings;
   v: string;
begin
   BeginTest('MY QTH and MY STATE are one fact, as they are one setting');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TryOverrideForContest('MY QTH', 'UT'), 'stated through the alias');
      CheckEquals('UT', s.My.ResolvedState, 'resolved under either name');
      CheckTrue(s.TryGetContestOverride('MY STATE', v), 'the other name sees it');
      CheckEquals('UT', v, 'with the same value');
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_AClearedOverrideFallsBackToTheStation;
var
   s: TR4WSettings;
   v: string;
begin
   BeginTest('a cleared override hands the fact back to the station');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('MY SECTION', 'NFL'), 'the station''s section');
      CheckTrue(s.TryOverrideForContest('MY SECTION', 'UT'), 'this contest''s');
      CheckEquals('UT', s.My.ResolvedSection, 'the override wins');

      s.My.ClearContestOverride(sfSection);
      CheckEquals('NFL', s.My.ResolvedSection, 'cleared: the station''s again');
      CheckFalse(s.TryGetContestOverride('MY SECTION', v), 'and nothing is stated');

      (* AN OVERRIDE OF '' IS A REAL STATEMENT, not "no override": Canada
        Day's blank is the contest's rule (SentState), but an operator may
        state an empty value too, and it must not fall back. *)
      CheckTrue(s.TryOverrideForContest('MY SECTION', ''), 'an empty statement is accepted');
      CheckEquals('', s.My.ResolvedSection, 'and stands');
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_PreferencesEditDuringTheContest;
var
   s: TR4WSettings;
begin
   BeginTest('a Preferences edit mid-contest changes the station; the contest''s override still wins');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('MY ZONE', '5'), 'the station');
      CheckTrue(s.TryOverrideForContest('MY ZONE', '3'), 'the contest');

      (* Preferences is TModelSetting.TrySetText -> TrySetByCommand. *)
      CheckTrue(s.TrySetByCommand('MY ZONE', '4'), 'the operator edits the station''s zone');
      CheckEquals('4', s.My.Zone, 'the station is zone 4 now');
      CheckEquals('3', s.My.ResolvedZone, 'this contest is still zone 3');

      CheckTrue(s.TrySetByCommand('MY STATE', 'GA'), 'a fact this contest did NOT override');
      CheckEquals('GA', s.My.ResolvedState, 'follows the edit at once');

      s.My.ClearContestOverride(sfZone);
      CheckEquals('4', s.My.ResolvedZone, 'cleared: the edited station value');
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_RefusedValuesAndNamesThatAreNotFacts;
var
   s: TR4WSettings;
begin
   BeginTest('a value the station would refuse is refused, and only facts are overridden');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('MY ITU ZONE', '8'), 'the station''s ITU zone');
      CheckFalse(s.TryOverrideForContest('MY ITU ZONE', '91'), '91 is outside 0..90');
      CheckFalse(s.TryOverrideForContest('MY ITU ZONE', 'X'), 'X is not a number');
      CheckEquals(8, s.My.ResolvedItuZone, 'a refusal changes nothing');
      CheckTrue(s.TryOverrideForContest('MY ITU ZONE', ' 6 '), 'a padded number is read');
      CheckEquals(6, s.My.ResolvedItuZone, 'and is in force');
      CheckEquals(8, s.My.ItuZone, 'beside the station''s');

      CheckFalse(s.TryOverrideForContest('MY CALL', 'W4TA'), 'MY CALL is not overridden here');
      CheckEquals('', s.My.Call, 'and is not written either');
      CheckFalse(s.TryOverrideForContest('QSO POINT METHOD', 'ONE POINT PER QSO'),
                 'a contest-scoped setting is not a station fact');
      CheckFalse(s.TryOverrideForContest('NO SUCH COMMAND', 'X'), 'nor is an unknown name');
   finally
      s.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_CaptureWritesTheOverrideAsTheContests;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn, v, src: string;
begin
   BeginTest('the capture writes an override as ''contest'' and the station''s value as ''station''');
   fn := TempLogName('capture.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         CheckTrue(s.TrySetByCommand('MY STATE', 'FL'), 'the station''s state');
         CheckTrue(s.TrySetByCommand('MY ZONE', '5'), 'the station''s zone');
         CheckTrue(s.TryOverrideForContest('MY ZONE', '3'), 'this contest''s zone');

         CheckTrue(StationFactRow(s, 'MY ZONE', v, src), 'MY ZONE is a fact row');
         CheckEquals('3', v, 'the row holds the override');
         CheckEquals('contest', src, 'as the contest''s');
         CheckTrue(StationFactRow(s, 'MY STATE', v, src), 'MY STATE is a fact row');
         CheckEquals('FL', v, 'an un-overridden fact records the station');
         CheckEquals('station', src, 'as the station''s');
         CheckFalse(StationFactRow(s, 'MY CALL', v, src), 'MY CALL is not a fact row');

         CheckTrue(CaptureStationFactRows(s, repo) > 0, 'the capture writes rows');
         repo.Commit;

         v := StoredRow(repo, 'MY ZONE', src);
         CheckEquals('contest', src, 'the override is a row the reopen applies');
         CheckEquals('3', v, 'holding zone 3');
         v := StoredRow(repo, 'MY STATE', src);
         CheckEquals('', src, 'the station''s state is a record, not applied on reopen');

         (* WITHDRAWN: rewritten as the station's record, so the reopen no
           longer applies it. *)
         s.My.ClearContestOverride(sfZone);
         CaptureStationFactRows(s, repo);
         repo.Commit;
         StoredRow(repo, 'MY ZONE', src);
         CheckEquals('', src, 'a withdrawn override is no longer the contest''s row');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TStationFactOverrideTests.Test_ReopenMakesTheRowTheOverrideAgain;
var
   db: TLogDatabase;
   repo: TLogRepository;
   before, after: TR4WSettings;
   fn, v, src: string;
begin
   BeginTest('a reopen restores the override, never the station''s value, and does not demote it');
   fn := TempLogName('reopen.db');
   Scrub(fn);
   before := TR4WSettings.Create;
   after := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         before.TryOverrideForContest('MY ZONE', '3');
         before.TryOverrideForContest('MY STATE', 'UT');
         CaptureContestStatements(before, repo);
         CaptureStationFactRows(before, repo);
         repo.Commit;

         (* The next session: the station is zone 5, Florida. *)
         after.TrySetByCommand('MY ZONE', '5');
         after.TrySetByCommand('MY STATE', 'FL');
         ApplyStoredRows(after, repo);
         CheckEquals('3', after.My.ResolvedZone, 'this contest is zone 3 again');
         CheckEquals('UT', after.My.ResolvedState, 'and in Utah');
         CheckEquals('5', after.My.Zone, 'the station was not written');
         CheckEquals('FL', after.My.State, 'nor its state');

         (* And the next capture keeps it the contest's -- the demotion the
           settings agent records as open for station rows does not happen
           to a fact. *)
         CaptureStationFactRows(after, repo);
         repo.Commit;
         v := StoredRow(repo, 'MY ZONE', src);
         CheckEquals('contest', src, 'still the contest''s row after a second session');
         CheckEquals('3', v, 'still zone 3');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      after.Free;
      before.Free;
   end;
   Scrub(fn);
end;

procedure TStationFactOverrideTests.Test_ALogWrittenBefore712;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
begin
   BeginTest('a log written before 7.12 reads as it did: its contest row wins, no row means the station');
   fn := TempLogName('pre712.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* WHAT THE OLD CAPTURE WROTE: a .cfg or New Contest MY STATE as
           'contest' (CommandCameFromContestCFG), the station's zone as
           'station', and no statements-only mark. *)
         repo.SaveConfigValue('MY STATE', 'UT', 'contest');
         repo.SaveConfigValue('MY ZONE', '5', 'station');
         repo.Commit;
         CheckFalse(LogHoldsStatementsOnly(repo), 'an old log carries no mark');

         s.TrySetByCommand('MY STATE', 'FL');
         s.My.DeriveZone('4');
         ApplyStoredRows(s, repo);

         CheckEquals('UT', s.My.ResolvedState,
                     'the old contest row is this contest''s state -- as it was in force before');
         CheckEquals('FL', s.My.State, 'and is no longer written into the station');
         CheckEquals('4', s.My.ResolvedZone,
                     'no contest row for the zone: the station''s value, as before');
         CheckFalse(s.My.HasContestOverride(sfZone), 'nothing is overridden there');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TStationFactOverrideTests.Test_StationContextCarriesTheResolvedCQZone;
var
   snapshot: TJSONObject;
   station: TStationContext;
begin
   BeginTest('MY CQ ZONE reaches a contest class through the station context, resolved');
   snapshot := Settings.ToJSON;
   try
      Settings.My.ClearContestOverrides;
      Settings.My.DeriveZone('5');

      station := CurrentStation;
      CheckTrue(station.MyZoneValid, 'the station''s zone is a zone');
      CheckEquals(5, station.MyZone, 'no override: the station''s CQ zone');

      CheckTrue(Settings.TryOverrideForContest('MY ZONE', '3'), 'this contest is zone 3');
      CheckTrue(Settings.TryOverrideForContest('MY GRID', 'DN40'), 'and grid DN40');
      station := CurrentStation;
      CheckEquals(3, station.MyZone, 'the class sees zone 3');
      CheckEquals('3', station.MyZoneText, 'and sends it');
      CheckEquals('DN40', station.MyGrid, 'and the contest''s grid');
      CheckEquals('5', Settings.My.Zone, 'while the station is zone 5');
   finally
      Settings.My.ClearContestOverrides;
      Settings.FromJSON(snapshot);
      snapshot.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_TheStateSentFallsBackToTheResolvedState;
var
   snapshot: TJSONObject;
begin
   BeginTest('with no contest sent state, the state sent is the RESOLVED MY STATE (7.11 over 7.12)');
   snapshot := Settings.ToJSON;
   try
      ClearContestSentState;
      Settings.My.ClearContestOverrides;
      CheckTrue(Settings.TrySetByCommand('MY STATE', 'FL'), 'the station is in Florida');
      CheckEquals('FL', SentMyState, 'no override: the station''s state is sent');

      CheckTrue(Settings.TryOverrideForContest('MY STATE', 'UT'), 'this contest is in Utah');
      CheckEquals('UT', SentMyState, 'the operator''s override is sent');
      CheckEquals('UT', CurrentStation.MyState, 'and a class sees it');
      CheckEquals('FL', Settings.My.State, 'the station is untouched');
   finally
      ClearContestSentState;
      Settings.My.ClearContestOverrides;
      Settings.FromJSON(snapshot);
      snapshot.Free;
   end;
end;

procedure TStationFactOverrideTests.Test_ContestResetClearsTheOverrides;
var
   snapshot: TJSONObject;
begin
   BeginTest('a contest''s configuration starting afresh clears its overrides');
   snapshot := Settings.ToJSON;
   try
      CheckTrue(Settings.TryOverrideForContest('MY ZONE', '3'), 'one contest states zone 3');
      ClearContestCFGCommands;
      CheckFalse(Settings.My.HasContestOverride(sfZone),
                 'the reset before a .cfg or the New Contest choices forgets it');
   finally
      Settings.My.ClearContestOverrides;
      Settings.FromJSON(snapshot);
      snapshot.Free;
   end;
end;

procedure TStationFactOverrideTests.RunAllTests;
begin
   Test_EveryFactIsAPublishedStationProperty;
   Test_NoOverrideResolvesToTheStation;
   Test_AnOverrideWinsAndLeavesTheStationAlone;
   Test_MyQthIsMyState;
   Test_AClearedOverrideFallsBackToTheStation;
   Test_PreferencesEditDuringTheContest;
   Test_RefusedValuesAndNamesThatAreNotFacts;
   Test_CaptureWritesTheOverrideAsTheContests;
   Test_ReopenMakesTheRowTheOverrideAgain;
   Test_ALogWrittenBefore712;
   Test_StationContextCarriesTheResolvedCQZone;
   Test_TheStateSentFallsBackToTheResolvedState;
   Test_ContestResetClearsTheOverrides;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
