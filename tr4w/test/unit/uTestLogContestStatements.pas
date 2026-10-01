unit uTestLogContestStatements;

(* THE CONTEST LOG STORES ONLY WHAT THE OPERATOR STATED -- section 7.8 of
  docs/CONTEST_OWNERSHIP_DESIGN.md, and uLogContestStatements.

  WHAT THESE PIN, in the order the rule is stated:

    the flag      TrySetByCommand states a contest-scoped setting,
                  TrySetUnstated does not, a station setting is never
                  "stated", and every alias of a setting shares one statement;

    the capture   no row for an unstated contest setting, a row while it is
                  stated, the row deleted when the statement is withdrawn,
                  CONTEST never written, station rows untouched, and the log
                  marked as holding statements only;

    the read      in a log written before the rule, a row holding the
                  constructor default is not a statement and a non-default
                  row is; in a marked log every row is one -- including an
                  operator who stated the default on purpose;

    D2            a contest .cfg statement is NOT overridden by a stored
                  sentinel when the log is reopened.

  THE APPLY IS MODELLED, NOT CALLED. uLogStore.LogStoreApplyContestConfig
  links MainUnit and cannot be linked here; it filters with
  KeepOnlyStatements and applies each remaining row through CheckCommand,
  which for a settings-owned name IS TrySetByCommand. ApplyRows below does
  exactly that pair, so what is tested is the code the program runs, minus
  the logging around it. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogContestStatementsTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
   protected
      procedure Test_ByNameIsAStatement_UnstatedIsNot;
      procedure Test_AStationSettingIsNeverStated;
      procedure Test_AliasesShareOneStatement;
      procedure Test_CaptureWritesNoRowForAnUnstatedSetting;
      procedure Test_CaptureWritesARowWhileStated;
      procedure Test_CaptureDeletesTheRowWhenTheStatementIsWithdrawn;
      procedure Test_CaptureNeverWritesContest;
      procedure Test_CaptureLeavesStationRowsAlone;
      procedure Test_PreFlagDefaultRowIsNotAStatement;
      procedure Test_PreFlagNonDefaultRowIsAppliedAndStated;
      procedure Test_MarkedLogKeepsAStatedDefault;
      procedure Test_D2_CfgStatementBeatsAStoredSentinel;
      procedure Test_ContestSetUpAsksRealContestScopedNames;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes,
   VC,   (* ContestTypeSA and CQWWCW -- a real CONTEST token *)
   uSettingsModel,
   uLogDatabase,
   uLogRepository,
   uLogContestStatements;

const
   (* REAL SPELLINGS, so the tests read like a .cfg an operator could write.
     The vocabularies ARE registered here -- uCFG is linked through
     uTestSettingsModel, and its initialization registers them -- so a value
     outside a setting's vocabulary is refused exactly as in the program. *)
   POINT_METHOD = 'QSO POINT METHOD';
   A_METHOD     = 'ONE POINT PER QSO';
   INITIAL_EX   = 'INITIAL EXCHANGE';
   DX_MULT      = 'DX MULTIPLIER';
   EX_RECEIVED  = 'EXCHANGE RECEIVED';

function TLogContestStatementsTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_stated_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogContestStatementsTests.Scrub(const aFileName: string);
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

(* The stored value of one command, or '' with aFound False. Reads through
  LoadContestConfig because that is the program's own read. *)
function StoredValue(aRepository: TLogRepository; const aCommand: string;
                     out aFound: boolean): string;
var
   rows: TStringList;
   i: integer;
begin
   Result := '';
   rows := TStringList.Create;
   try
      aRepository.LoadContestConfig(rows);
      i := rows.IndexOfName(AnsiString(aCommand));
      aFound := i >= 0;
      if aFound then
         begin
         Result := string(rows.ValueFromIndex[i]);
         end;
   finally
      rows.Free;
   end;
end;

(* THE PROGRAM'S APPLY, MINUS ITS LOGGING: filter, then assign each surviving
  row by name -- which is what CheckCommand does for a settings-owned name. *)
procedure ApplyRows(aSettings: TR4WSettings; aRepository: TLogRepository);
var
   rows: TStringList;
   i: integer;
begin
   rows := TStringList.Create;
   try
      aRepository.LoadContestConfig(rows);
      KeepOnlyStatements(rows, LogHoldsStatementsOnly(aRepository), nil);
      for i := 0 to rows.Count - 1 do
         begin
         aSettings.TrySetByCommand(string(rows.Names[i]),
                                   string(rows.ValueFromIndex[i]));
         end;
   finally
      rows.Free;
   end;
end;

(* A log written BEFORE the rule: every contest-scoped setting's constructor
  value, as the old capture wrote them -- exactly what the corpus logs hold. *)
procedure WritePreFlagSentinels(aRepository: TLogRepository);
begin
   aRepository.SaveConfigValue(AnsiString(POINT_METHOD), 'NONE', 'contest');
   aRepository.SaveConfigValue(AnsiString(INITIAL_EX),   'NONE', 'contest');
   aRepository.SaveConfigValue(AnsiString(DX_MULT),      'NONE', 'contest');
   aRepository.SaveConfigValue(AnsiString(EX_RECEIVED),  'UNKNOWN', 'contest');
end;

procedure TLogContestStatementsTests.Test_ByNameIsAStatement_UnstatedIsNot;
var
   s: TR4WSettings;
   v: string;
begin
   BeginTest('a value set by name is stated; a station-bucket value is not');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.CommandIsStated(POINT_METHOD),
                 'nothing is stated by construction');

      CheckTrue(s.TrySetUnstated(INITIAL_EX, 'ZONE'), 'the bucket value applies');
      CheckTrue(s.TryGetByCommand(INITIAL_EX, v), 'it reads back');
      CheckEquals('ZONE', v, 'and it is in force');
      CheckFalse(s.CommandIsStated(INITIAL_EX),
                 'but it is not the operator''s statement for this contest');

      CheckTrue(s.TrySetByCommand(POINT_METHOD, A_METHOD), 'a .cfg line applies');
      CheckTrue(s.CommandIsStated(POINT_METHOD), 'and is a statement');

      (* THE ApplyStoredCommands RULE: it skips a stated setting, so a station
        value never displaces a statement. What it would have asked: *)
      CheckTrue(s.CommandIsContestScoped(POINT_METHOD) and
                s.CommandIsStated(POINT_METHOD),
                'a stated contest setting is what the bucket must not override');

      s.SetCommandStated(POINT_METHOD, False);
      CheckFalse(s.CommandIsStated(POINT_METHOD), 'a statement can be withdrawn');
      CheckTrue(s.TryGetByCommand(POINT_METHOD, v), 'withdrawing it...');
      CheckEquals(A_METHOD, v, '...does not change the value in force');

      CheckFalse(s.TrySetByCommand('NO SUCH COMMAND', 'X'), 'an unknown name is refused');
      CheckFalse(s.CommandIsStated('NO SUCH COMMAND'), 'and states nothing');
   finally
      s.Free;
   end;
end;

procedure TLogContestStatementsTests.Test_AStationSettingIsNeverStated;
var
   s: TR4WSettings;
begin
   BeginTest('a station setting is never "stated" -- its statement is tr4w.json');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.CommandIsContestScoped('MY CALL'), 'MY CALL is the station''s group');
      CheckTrue(s.TrySetByCommand('MY CALL', 'NY4I'), 'it is set by name');
      CheckFalse(s.CommandIsStated('MY CALL'), 'and the flag does not apply to it');
      s.SetCommandStated('MY CALL', True);
      CheckFalse(s.CommandIsStated('MY CALL'), 'not even when asked to');
   finally
      s.Free;
   end;
end;

procedure TLogContestStatementsTests.Test_AliasesShareOneStatement;
var
   s: TR4WSettings;
begin
   BeginTest('every name for a setting answers with one statement');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('QUICK QSL CW MESSAGE1', 'TU'), 'one spelling sets it');
      CheckTrue(s.CommandIsStated('QUICK QSL MESSAGE 1'), 'a second spelling is stated');
      CheckTrue(s.CommandIsStated('QUICK QSL CW MESSAGE'), 'so is the third');
   finally
      s.Free;
   end;
end;

procedure TLogContestStatementsTests.Test_CaptureWritesNoRowForAnUnstatedSetting;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
begin
   BeginTest('the capture writes no row for an unstated contest setting');
   fn := TempLogName('unstated.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         CheckFalse(LogHoldsStatementsOnly(repo), 'a new file carries no mark yet');
         CheckEquals(0, CaptureContestStatements(s, repo), 'nothing is stated, nothing written');
         repo.Commit;

         StoredValue(repo, POINT_METHOD, found);
         CheckFalse(found, 'no QSO POINT METHOD row -- the contest decides');
         StoredValue(repo, EX_RECEIVED, found);
         CheckFalse(found, 'no EXCHANGE RECEIVED row either');
         CheckEquals(0, repo.ConfigCount, 'no contest-scoped row at all');
         CheckTrue(LogHoldsStatementsOnly(repo), 'and the log is marked');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_CaptureWritesARowWhileStated;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
   v: string;
begin
   BeginTest('the capture writes a row for a stated contest setting');
   fn := TempLogName('stated.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         CheckTrue(s.TrySetByCommand(POINT_METHOD, A_METHOD), 'the operator states it');
         CheckTrue(CaptureContestStatements(s, repo) >= 1, 'a row is written');
         repo.Commit;

         v := StoredValue(repo, POINT_METHOD, found);
         CheckTrue(found, 'the statement is in the log');
         CheckEquals(A_METHOD, v, 'with the value stated');
         StoredValue(repo, DX_MULT, found);
         CheckFalse(found, 'and an unstated sibling is not');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_CaptureDeletesTheRowWhenTheStatementIsWithdrawn;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
begin
   BeginTest('the capture deletes the row when the statement is withdrawn');
   fn := TempLogName('withdrawn.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         s.TrySetByCommand(POINT_METHOD, A_METHOD);
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, POINT_METHOD, found);
         CheckTrue(found, 'stated: the row exists');

         s.SetCommandStated(POINT_METHOD, False);
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, POINT_METHOD, found);
         CheckFalse(found, 'withdrawn: the row is gone, the contest decides');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_CaptureNeverWritesContest;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
begin
   BeginTest('CONTEST is never a config row, stated or not');
   fn := TempLogName('contest.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* THE SPELLING COMES FROM ContestTypeSA, the vocabulary uCFG
           registers for Contest.ContestToken -- and uCFG IS linked here
           (uTestSettingsModel uses it), so TrySetByCommand refuses anything
           else. The first version of this test wrote 'CQ WW', which is no
           contest's token, and failed for exactly that reason.

           THE GUARD IS REACHABLE: a .cfg's CONTEST line and the New Contest
           queue both reach this property through TrySetByCommand, so in the
           program CONTEST is a STATED contest-scoped setting on every
           contest-backed run. Without the guard the capture would write it. *)
         CheckTrue(s.TrySetByCommand('CONTEST', string(ContestTypeSA[CQWWCW])),
                   'CONTEST is set by name, as a .cfg sets it');
         CheckTrue(s.CommandIsStated('CONTEST'), 'and is therefore stated');
         if s.CommandIsStated('CONTEST') then
            begin
            CaptureContestStatements(s, repo);
            repo.Commit;
            StoredValue(repo, 'CONTEST', found);
            CheckFalse(found, 'a stated CONTEST is still not a config row -- ' +
                       'the contest table owns the contest');
            end;
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_CaptureLeavesStationRowsAlone;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
   v: string;
   rows: TStringList;
begin
   BeginTest('station-scoped rows are not this rule''s: kept by capture and read');
   fn := TempLogName('station.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   rows := TStringList.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* MY CALL is the station-scoped row CaptureConfiguration writes as
           'contest', which is what LoadContestConfig returns. *)
         repo.SaveConfigValue('MY CALL', 'NY4I', 'contest');
         CaptureContestStatements(s, repo);
         repo.Commit;
         v := StoredValue(repo, 'MY CALL', found);
         CheckTrue(found, 'the capture did not delete a station row');
         CheckEquals('NY4I', v, 'nor change it');

         (* A station row that HOLDS ITS DEFAULT is still kept by the read --
           the default rule is for contest-scoped rows only. *)
         rows.Add('MY CALL=');
         KeepOnlyStatements(rows, False, nil);
         CheckEquals(1, rows.Count, 'a station row at its default survives the filter');
      finally
         repo.Free;
      end;
   finally
      rows.Free;
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_PreFlagDefaultRowIsNotAStatement;
var
   db: TLogDatabase;
   repo: TLogRepository;
   fn: string;
   rows, dropped: TStringList;
begin
   BeginTest('a pre-rule row holding the constructor default is not a statement');
   fn := TempLogName('preflag.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   rows := TStringList.Create;
   dropped := TStringList.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         WritePreFlagSentinels(repo);
         repo.Commit;
         CheckFalse(LogHoldsStatementsOnly(repo), 'an old log carries no mark');

         repo.LoadContestConfig(rows);
         CheckEquals(4, rows.Count, 'the four sentinels are stored');
         KeepOnlyStatements(rows, LogHoldsStatementsOnly(repo), dropped);
         CheckEquals(0, rows.Count, 'none of them is applied');
         CheckEquals(4, dropped.Count, 'each is reported as dropped');
      finally
         repo.Free;
      end;
   finally
      dropped.Free;
      rows.Free;
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_PreFlagNonDefaultRowIsAppliedAndStated;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   v: string;
   found: boolean;
begin
   BeginTest('a pre-rule NON-default row is a statement: applied, flagged, kept');
   fn := TempLogName('prenondefault.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         WritePreFlagSentinels(repo);
         repo.SaveConfigValue(AnsiString(INITIAL_EX), 'ZONE', 'contest');
         repo.Commit;

         ApplyRows(s, repo);
         CheckTrue(s.TryGetByCommand(INITIAL_EX, v), 'it reads back');
         CheckEquals('ZONE', v, 'the non-default value is applied');
         CheckTrue(s.CommandIsStated(INITIAL_EX), 'and recorded as a statement');
         CheckFalse(s.CommandIsStated(POINT_METHOD), 'a sentinel is not');

         (* THE NEXT CAPTURE converts the log: the statement is rewritten, the
           sentinels deleted, the log marked. *)
         CaptureContestStatements(s, repo);
         repo.Commit;
         v := StoredValue(repo, INITIAL_EX, found);
         CheckTrue(found and (v = 'ZONE'), 'the statement survives the capture');
         StoredValue(repo, POINT_METHOD, found);
         CheckFalse(found, 'the QSO POINT METHOD sentinel is deleted');
         StoredValue(repo, EX_RECEIVED, found);
         CheckFalse(found, 'the EXCHANGE RECEIVED sentinel is deleted');
         CheckTrue(LogHoldsStatementsOnly(repo), 'the log is now marked');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_MarkedLogKeepsAStatedDefault;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s, reopened: TR4WSettings;
   fn: string;
   found: boolean;
begin
   BeginTest('in a marked log a stated default is still a statement (Field Day: no mults)');
   fn := TempLogName('stateddefault.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   reopened := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* 'NONE' IS THE CONSTRUCTOR DEFAULT and the operator said it on
           purpose. The pre-rule reading would discard it; the mark is what
           keeps it. *)
         CheckTrue(s.TrySetByCommand(DX_MULT, 'NONE'), 'the operator states NONE');
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, DX_MULT, found);
         CheckTrue(found, 'it is stored');

         ApplyRows(reopened, repo);
         CheckTrue(reopened.CommandIsStated(DX_MULT),
                   'on reopen it is still the operator''s statement');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      reopened.Free;
      s.Free;
   end;
   Scrub(fn);
end;

procedure TLogContestStatementsTests.Test_D2_CfgStatementBeatsAStoredSentinel;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   v: string;
   found: boolean;
begin
   BeginTest('D2: a .cfg statement is not clobbered by a stored sentinel on reopen');
   fn := TempLogName('d2.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* AN EXISTING LOG, written before the rule: QSO POINT METHOD = NONE,
           the constructor's sentinel. *)
         WritePreFlagSentinels(repo);
         repo.Commit;

         (* THE OPERATOR ADDS THE LINE TO THE CONTEST .cfg. Startup reads the
           .cfg first and the log after it, which is the order this models. *)
         CheckTrue(s.TrySetByCommand(POINT_METHOD, A_METHOD), 'the .cfg line applies');

         ApplyRows(s, repo);
         CheckTrue(s.TryGetByCommand(POINT_METHOD, v), 'it reads back');
         CheckEquals(A_METHOD, v,
                     'the stored NONE did NOT overwrite the .cfg statement');
         CheckTrue(s.CommandIsStated(POINT_METHOD), 'and it is still a statement');

         (* AND THE LOG LEARNS IT, so the .cfg is not needed next time. *)
         CaptureContestStatements(s, repo);
         repo.Commit;
         v := StoredValue(repo, POINT_METHOD, found);
         CheckTrue(found, 'the statement is captured');
         CheckEquals(A_METHOD, v, 'with the .cfg''s value, not the sentinel');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

(* M2 -- CONTEST SET-UP ASKS THESE NAMES, AND A MISSPELLING WOULD BE SILENT.

  FCONTEST.ApplyContestTraits asks CommandIsStated for each value it writes,
  and uSettingsEffects.ReplayContestStatements asks PathIsStated for the seven
  contest tokens by PROPERTY PATH. A name or path that does not resolve
  answers False -- "not stated" -- so the contest's value would quietly beat
  the operator's statement, which is the exact defect the precedence exists to
  prevent. So every name and path set-up uses is checked here to be a real,
  contest-scoped setting that records a statement.

  THE PATHS ARE TYPED A SECOND TIME, from uSettingsEffects' constants, because
  that unit cannot be linked here. The list is case-sensitive, as the
  statement list is. *)
procedure TLogContestStatementsTests.Test_ContestSetUpAsksRealContestScopedNames;

   procedure CheckToken(s: TR4WSettings; const aCommand, aValue, aPath: string);
   begin
      CheckTrue(s.CommandIsContestScoped(aCommand), aCommand + ' is contest-scoped');
      CheckFalse(s.PathIsStated(aPath), aPath + ' is not stated before');
      CheckTrue(s.TrySetByCommand(aCommand, aValue), aCommand + ' sets by name');
      CheckTrue(s.CommandIsStated(aCommand), aCommand + ' is then stated');
      CheckTrue(s.PathIsStated(aPath), aPath + ' is then stated, by path');
   end;

   procedure CheckValue(s: TR4WSettings; const aCommand, aValue: string);
   begin
      CheckTrue(s.CommandIsContestScoped(aCommand), aCommand + ' is contest-scoped');
      CheckTrue(s.TrySetByCommand(aCommand, aValue), aCommand + ' sets by name');
      CheckTrue(s.CommandIsStated(aCommand), aCommand + ' is then stated');
   end;

var
   s: TR4WSettings;
begin
   BeginTest('every name and path contest set-up asks is a real statement');
   s := TR4WSettings.Create;
   try
      CheckToken(s, POINT_METHOD,          A_METHOD,  'Contest.QsoPointMethod');
      CheckToken(s, EX_RECEIVED,           'UNKNOWN', 'Contest.ExchangeReceived');
      CheckToken(s, DX_MULT,               'NONE',    'Contest.DxMultiplier');
      CheckToken(s, 'DOMESTIC MULTIPLIER', 'NONE',    'Contest.DomesticMultiplier');
      CheckToken(s, 'PREFIX MULTIPLIER',   'NONE',    'Contest.PrefixMultiplier');
      CheckToken(s, 'ZONE MULTIPLIER',     'NONE',    'Contest.ZoneMultiplier');
      CheckToken(s, INITIAL_EX,            'ZONE',    'Contest.InitialExchange');

      CheckValue(s, 'QSO BY MODE',              'TRUE');
      CheckValue(s, 'QSO BY BAND',              'TRUE');
      CheckValue(s, 'MULT BY MODE',             'TRUE');
      CheckValue(s, 'MULT BY BAND',             'TRUE');
      CheckValue(s, 'VHF BAND ENABLE',          'TRUE');
      CheckValue(s, 'COUNT DOMESTIC COUNTRIES', 'TRUE');
      CheckValue(s, 'DOMESTIC FILENAME',        'arrlsect.dom');

      CheckFalse(s.PathIsStated('My.Call'), 'a station path is never stated');
   finally
      s.Free;
   end;
end;

procedure TLogContestStatementsTests.RunAllTests;
begin
   Test_ByNameIsAStatement_UnstatedIsNot;
   Test_AStationSettingIsNeverStated;
   Test_AliasesShareOneStatement;
   Test_CaptureWritesNoRowForAnUnstatedSetting;
   Test_CaptureWritesARowWhileStated;
   Test_CaptureDeletesTheRowWhenTheStatementIsWithdrawn;
   Test_CaptureNeverWritesContest;
   Test_CaptureLeavesStationRowsAlone;
   Test_PreFlagDefaultRowIsNotAStatement;
   Test_PreFlagNonDefaultRowIsAppliedAndStated;
   Test_MarkedLogKeepsAStatedDefault;
   Test_D2_CfgStatementBeatsAStoredSentinel;
   Test_ContestSetUpAsksRealContestScopedNames;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
