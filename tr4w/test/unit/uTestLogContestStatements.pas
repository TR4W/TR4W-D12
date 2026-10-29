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
                  sentinel when the log is reopened;

    retired       a row naming one of the seven contest-rule settings
                  retired at M10 S2 (QSO POINT METHOD, EXCHANGE RECEIVED,
                  INITIAL EXCHANGE, the four multipliers) is set aside in
                  EITHER era, never applied, and deleted by the next capture
                  -- once, so a second capture finds nothing to do.

    credentials   a row naming a TSecretText setting (SERVER PASSWORD,
                  HAMSCORE PASSWORD) is deleted by the capture whatever its
                  source, and set aside in either era on the read -- by
                  NAME, never with its value -- so it is never applied over
                  the vault's password (2026-10-29). The values used are
                  obviously fake.

  RE-POINTED AT M10 S2 (2026-10-14). These tests used the seven as their
  examples, because they were the settings whose sentinels every old log
  carries. With those retired, the same rules are pinned on contest-scoped
  token settings that are still live -- INITIAL EXCHANGE CURSOR POS, QSL
  MODE, SINGLE BAND SCORE and MODE -- whose constructor defaults are the
  sentinels a pre-rule log stores for them.

  THE APPLY IS MODELLED, NOT CALLED. uLogStore.LogStoreApplyContestConfig
  links MainUnit and cannot be linked here; it filters with
  KeepOnlyStatements -- passing uCFG.CommandIsRetired, as ApplyRows does
  here -- and applies each remaining row through CheckCommand, which for a
  settings-owned name IS TrySetByCommand. ApplyRows below does exactly that
  pair, so what is tested is the code the program runs, minus the logging
  around it. *)

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
      procedure Test_RetiredRowsAreSetAsideInEitherEra;
      procedure Test_CaptureDeletesRetiredRowsOnce;
      procedure Test_ACaptureThatFailsPartWayLeavesNothingOfItself;
      procedure Test_Q61_ACategoryChangeIsInTheLogAtOnce;
      procedure Test_Q61_AReopenedLogKeepsItsEntryDeclaration;
      procedure Test_StoredCredentialRowsAreDeletedByTheCapture;
      procedure Test_AStoredCredentialIsNeverApplied;
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
   uCFG,   (* CommandIsRetired -- the one list of withdrawn names, which the
             program passes into the leaf, so the tests pass it too *)
   sqldb,             (* TSQLQuery -- reading the contest row back, Q61 *)
   uContestRegistry,  (* ContestHandleOf -- a contest row to declare on *)
   uLogContestStatements;

const
   (* REAL SPELLINGS, so the tests read like a .cfg an operator could write.
     The vocabularies ARE registered here -- uCFG is linked through
     uTestSettingsModel, and its initialization registers them -- so a value
     outside a setting's vocabulary is refused exactly as in the program. *)
   (* Constructor default 'AT END'; a statement says the other value. *)
   CURSOR_POS   = 'INITIAL EXCHANGE CURSOR POS';
   A_CURSOR_POS = 'AT START';
   (* Constructor default 'NONE'. *)
   QSL_MODE     = 'QSL MODE';
   A_QSL_MODE   = 'STANDARD';
   (* Constructor default '160'. *)
   BAND_SCORE   = 'SINGLE BAND SCORE';
   (* Constructor default 'CW'. *)
   MODE_CMD     = 'MODE';

   (* THE SEVEN RETIRED AT M10 S2, as an old log stores them. *)
   RETIRED_SEVEN: array[0..6] of string = (
      'QSO POINT METHOD',
      'EXCHANGE RECEIVED',
      'INITIAL EXCHANGE',
      'DOMESTIC MULTIPLIER',
      'DX MULTIPLIER',
      'PREFIX MULTIPLIER',
      'ZONE MULTIPLIER');
   (* The constructor sentinels the pre-rule capture wrote for them, in the
     same order. *)
   RETIRED_SENTINELS: array[0..6] of string = (
      'NONE', 'UNKNOWN', 'NONE', 'NONE', 'NONE', 'NONE', 'NONE');

   (* THE TWO CREDENTIALS, and values nobody could mistake for real ones. *)
   SERVER_PASSWORD   = 'SERVER PASSWORD';
   HAMSCORE_PASSWORD = 'HAMSCORE PASSWORD';
   FAKE_STORED_PASSWORD = 'fake-stored-not-a-password';
   FAKE_VAULT_PASSWORD  = 'fake-vault-not-a-password';

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
      KeepOnlyStatements(rows, LogHoldsStatementsOnly(aRepository), nil,
                         CommandIsRetired, nil);
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
   aRepository.SaveConfigValue(AnsiString(CURSOR_POS), 'AT END', 'contest');
   aRepository.SaveConfigValue(AnsiString(QSL_MODE),   'NONE',   'contest');
   aRepository.SaveConfigValue(AnsiString(BAND_SCORE), '160',    'contest');
   aRepository.SaveConfigValue(AnsiString(MODE_CMD),   'CW',     'contest');
end;

(* THE SEVEN RETIRED SETTINGS' ROWS, as every log written before 2026-10-01
  stores them -- the corpus fixtures included. *)
procedure WriteRetiredSentinels(aRepository: TLogRepository);
var
   i: integer;
begin
   for i := Low(RETIRED_SEVEN) to High(RETIRED_SEVEN) do
      begin
      aRepository.SaveConfigValue(AnsiString(RETIRED_SEVEN[i]),
                                  AnsiString(RETIRED_SENTINELS[i]), 'contest');
      end;
end;

procedure TLogContestStatementsTests.Test_ByNameIsAStatement_UnstatedIsNot;
var
   s: TR4WSettings;
   v: string;
begin
   BeginTest('a value set by name is stated; a station-bucket value is not');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.CommandIsStated(CURSOR_POS),
                 'nothing is stated by construction');

      CheckTrue(s.TrySetUnstated(QSL_MODE, A_QSL_MODE), 'the bucket value applies');
      CheckTrue(s.TryGetByCommand(QSL_MODE, v), 'it reads back');
      CheckEquals(A_QSL_MODE, v, 'and it is in force');
      CheckFalse(s.CommandIsStated(QSL_MODE),
                 'but it is not the operator''s statement for this contest');

      CheckTrue(s.TrySetByCommand(CURSOR_POS, A_CURSOR_POS), 'a .cfg line applies');
      CheckTrue(s.CommandIsStated(CURSOR_POS), 'and is a statement');

      (* THE ApplyStoredCommands RULE: it skips a stated setting, so a station
        value never displaces a statement. What it would have asked: *)
      CheckTrue(s.CommandIsContestScoped(CURSOR_POS) and
                s.CommandIsStated(CURSOR_POS),
                'a stated contest setting is what the bucket must not override');

      s.SetCommandStated(CURSOR_POS, False);
      CheckFalse(s.CommandIsStated(CURSOR_POS), 'a statement can be withdrawn');
      CheckTrue(s.TryGetByCommand(CURSOR_POS, v), 'withdrawing it...');
      CheckEquals(A_CURSOR_POS, v, '...does not change the value in force');

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

         StoredValue(repo, CURSOR_POS, found);
         CheckFalse(found, 'no INITIAL EXCHANGE CURSOR POS row -- the contest decides');
         StoredValue(repo, MODE_CMD, found);
         CheckFalse(found, 'no MODE row either');
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
         CheckTrue(s.TrySetByCommand(CURSOR_POS, A_CURSOR_POS), 'the operator states it');
         CheckTrue(CaptureContestStatements(s, repo) >= 1, 'a row is written');
         repo.Commit;

         v := StoredValue(repo, CURSOR_POS, found);
         CheckTrue(found, 'the statement is in the log');
         CheckEquals(A_CURSOR_POS, v, 'with the value stated');
         StoredValue(repo, BAND_SCORE, found);
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
         s.TrySetByCommand(CURSOR_POS, A_CURSOR_POS);
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, CURSOR_POS, found);
         CheckTrue(found, 'stated: the row exists');

         s.SetCommandStated(CURSOR_POS, False);
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, CURSOR_POS, found);
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
         repo.SaveConfigValue(AnsiString(QSL_MODE), AnsiString(A_QSL_MODE), 'contest');
         repo.Commit;

         ApplyRows(s, repo);
         CheckTrue(s.TryGetByCommand(QSL_MODE, v), 'it reads back');
         CheckEquals(A_QSL_MODE, v, 'the non-default value is applied');
         CheckTrue(s.CommandIsStated(QSL_MODE), 'and recorded as a statement');
         CheckFalse(s.CommandIsStated(CURSOR_POS), 'a sentinel is not');

         (* THE NEXT CAPTURE converts the log: the statement is rewritten, the
           sentinels deleted, the log marked. *)
         CaptureContestStatements(s, repo);
         repo.Commit;
         v := StoredValue(repo, QSL_MODE, found);
         CheckTrue(found and (v = A_QSL_MODE), 'the statement survives the capture');
         StoredValue(repo, CURSOR_POS, found);
         CheckFalse(found, 'the INITIAL EXCHANGE CURSOR POS sentinel is deleted');
         StoredValue(repo, MODE_CMD, found);
         CheckFalse(found, 'the MODE sentinel is deleted');
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
   BeginTest('in a marked log a stated default is still a statement');
   fn := TempLogName('stateddefault.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   reopened := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* '160' IS THE CONSTRUCTOR DEFAULT and the operator said it on
           purpose. The pre-rule reading would discard it; the mark is what
           keeps it. (This used Field Day's stated DX MULTIPLIER = NONE until
           that setting retired at M10 S2; the rule is the same.) *)
         CheckTrue(s.TrySetByCommand(BAND_SCORE, '160'), 'the operator states 160');
         CaptureContestStatements(s, repo);
         repo.Commit;
         StoredValue(repo, BAND_SCORE, found);
         CheckTrue(found, 'it is stored');

         ApplyRows(reopened, repo);
         CheckTrue(reopened.CommandIsStated(BAND_SCORE),
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
         (* AN EXISTING LOG, written before the rule: INITIAL EXCHANGE
           CURSOR POS = AT END, the constructor's sentinel. *)
         WritePreFlagSentinels(repo);
         repo.Commit;

         (* THE OPERATOR ADDS THE LINE TO THE CONTEST .cfg. Startup reads the
           .cfg first and the log after it, which is the order this models. *)
         CheckTrue(s.TrySetByCommand(CURSOR_POS, A_CURSOR_POS), 'the .cfg line applies');

         ApplyRows(s, repo);
         CheckTrue(s.TryGetByCommand(CURSOR_POS, v), 'it reads back');
         CheckEquals(A_CURSOR_POS, v,
                     'the stored AT END did NOT overwrite the .cfg statement');
         CheckTrue(s.CommandIsStated(CURSOR_POS), 'and it is still a statement');

         (* AND THE LOG LEARNS IT, so the .cfg is not needed next time. *)
         CaptureContestStatements(s, repo);
         repo.Commit;
         v := StoredValue(repo, CURSOR_POS, found);
         CheckTrue(found, 'the statement is captured');
         CheckEquals(A_CURSOR_POS, v, 'with the .cfg''s value, not the sentinel');
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

  FCONTEST.ApplyContestTraits asks CommandIsStated for each value it writes.
  A name that does not resolve answers False -- "not stated" -- so the
  contest's value would quietly beat the operator's statement, which is the
  exact defect the precedence exists to prevent. So every name set-up uses is
  checked here to be a real, contest-scoped setting that records a statement.

  THE SEVEN TOKEN PATHS uSettingsEffects.ReplayContestStatements asked are
  GONE with their settings (M10 S2, 2026-10-14); set-up no longer asks them.
  One live token is still checked BY PATH, because CommandIsStated resolves a
  name and then asks PathIsStated -- the lookup has to keep working. *)
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
      CheckToken(s, CURSOR_POS, A_CURSOR_POS, 'Contest.InitialExchangeCursorPos');

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

(* M10 S2 -- A RETIRED SETTING'S STORED ROW IS NEVER APPLIED, IN EITHER ERA.

  Every log written before 2026-10-01 stores the seven as sentinels, and a
  statements-only log can hold a real statement made before the ruling. Both
  are set aside by the read -- never reaching the apply, so there is nothing
  to refuse, nothing to warn about and no modal -- and handed back with their
  values so the caller can say what it set aside. A retired row is NOT
  reported as "held the default": a real statement need not have. *)
procedure TLogContestStatementsTests.Test_RetiredRowsAreSetAsideInEitherEra;

   procedure CheckEra(aStatementsOnly: boolean; const aEra: string);
   var
      rows, dropped, retired: TStringList;
      i: integer;
   begin
      rows := TStringList.Create;
      dropped := TStringList.Create;
      retired := TStringList.Create;
      try
         for i := Low(RETIRED_SEVEN) to High(RETIRED_SEVEN) do
            begin
            rows.Add(AnsiString(RETIRED_SEVEN[i] + '=' + RETIRED_SENTINELS[i]));
            end;
         (* A REAL STATEMENT of a retired setting, as a marked log could hold
           one -- not a sentinel. *)
         rows.Values['DX MULTIPLIER'] := 'ARRL DXCC';
         (* And a live contest statement beside them, which must survive. *)
         rows.Add(AnsiString(CURSOR_POS + '=' + A_CURSOR_POS));

         KeepOnlyStatements(rows, aStatementsOnly, dropped,
                            CommandIsRetired, retired);

         CheckEquals(7, retired.Count, aEra + ': all seven are set aside');
         CheckEquals('ARRL DXCC', string(retired.Values['DX MULTIPLIER']),
                     aEra + ': with the value, so a real statement shows');
         CheckEquals(0, dropped.Count,
                     aEra + ': none is reported as a built-in default');
         CheckEquals(1, rows.Count, aEra + ': only the live statement is left');
         CheckEquals(AnsiString(CURSOR_POS), rows.Names[0],
                     aEra + ': and it is the live one');
      finally
         retired.Free;
         dropped.Free;
         rows.Free;
      end;
   end;

begin
   BeginTest('a retired setting''s stored row is set aside, in either era');
   CheckEra(False, 'a log written before the rule');
   CheckEra(True,  'a statements-only log');
end;

(* M10 S2 -- THE CAPTURE DELETES THE RETIRED ROWS, AND THEN HAS NOTHING TO DO.

  The decision, with its evidence, is in uLogContestStatements' header:
  deleted rather than left inert, because nothing can read them again and a
  row left in place would be set aside and reported on every open for ever.
  The second capture is the "no loop" half: it finds nothing, writes nothing
  back, and the log reads clean. A 'station' row of a retired name is a
  record nothing applies and is left alone, like every station row. *)
procedure TLogContestStatementsTests.Test_CaptureDeletesRetiredRowsOnce;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   i: integer;
   found: boolean;
   rows, retired: TStringList;
   before: integer;
begin
   BeginTest('the capture deletes every retired row, once');
   fn := TempLogName('retired.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   rows := TStringList.Create;
   retired := TStringList.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         WriteRetiredSentinels(repo);
         repo.SaveConfigValue('ZONE MULTIPLIER', 'CQ ZONES', 'contest');
         repo.SaveConfigValue('MY CALL', 'NY4I', 'contest');
         repo.Commit;

         CaptureContestStatements(s, repo, CommandIsRetired);
         repo.Commit;
         for i := Low(RETIRED_SEVEN) to High(RETIRED_SEVEN) do
            begin
            StoredValue(repo, RETIRED_SEVEN[i], found);
            CheckFalse(found, RETIRED_SEVEN[i] + ' is deleted by the capture');
            end;
         StoredValue(repo, 'MY CALL', found);
         CheckTrue(found, 'a live row beside them is untouched');
         CheckTrue(LogHoldsStatementsOnly(repo), 'and the log is marked');

         (* THE NEXT OPEN READS CLEAN: nothing is set aside. *)
         repo.LoadContestConfig(rows);
         KeepOnlyStatements(rows, LogHoldsStatementsOnly(repo), nil,
                            CommandIsRetired, retired);
         CheckEquals(0, retired.Count, 'the reopen has nothing to set aside');

         (* AND A SECOND CAPTURE CHANGES NOTHING -- no loop. *)
         before := repo.ConfigCount;
         CaptureContestStatements(s, repo, CommandIsRetired);
         repo.Commit;
         CheckEquals(before, repo.ConfigCount, 'a second capture is a no-op');
      finally
         repo.Free;
      end;
   finally
      retired.Free;
      rows.Free;
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

type
   EInjectedCaptureFailure = class(Exception);

(* A TCommandTest THAT FAILS. CaptureContestStatements calls aIsRetired only
  after its main walk has written and deleted rows, so raising here is a
  failure injected part-way through a capture. *)
function FailMidCapture(const aCommand: string): boolean;
begin
   raise EInjectedCaptureFailure.Create('injected part-way through the capture');
end;

(* A CAPTURE IS ONE TRANSACTION, AND ONE THAT FAILS PART-WAY LEAVES NOTHING.

  "Does not commit -- the caller's capture is one transaction" is this
  unit's contract, and uLogStore's two callers rely on it: CaptureConfiguration
  commits once at the end, and on a failure nothing commits -- Disable, or
  LogStoreClose after the close-time handler reports it, frees the database,
  and the close rolls back. That only holds if every write the capture made
  is still uncommitted when it fails.

  So a capture is made to fail after it has written one row and deleted
  another, the database is freed with no commit, and the reopened log must
  be exactly what was committed before it. *)
procedure TLogContestStatementsTests.Test_ACaptureThatFailsPartWayLeavesNothingOfItself;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
   raised: boolean;
   v: string;
   i: integer;
begin
   BeginTest('a capture that fails part-way leaves nothing of itself');
   fn := TempLogName('failedcapture.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   try
      db := TLogDatabase.Create;
      try
         db.CreateNew(fn);
         repo := TLogRepository.Create(db);
         try
            WriteRetiredSentinels(repo);
            repo.SaveConfigValue(AnsiString(QSL_MODE), AnsiString(A_QSL_MODE),
                                 'contest');
            repo.Commit;

            (* Stated: the capture writes it. QSL MODE is NOT stated in s, so
              the capture deletes its row. Then aIsRetired raises. *)
            CheckTrue(s.TrySetByCommand(CURSOR_POS, A_CURSOR_POS), 'the operator states it');
            raised := False;
            try
               CaptureContestStatements(s, repo, FailMidCapture);
            except
               on EInjectedCaptureFailure do
                  begin
                  raised := True;
                  end;
            end;
            CheckTrue(raised, 'the capture failed part-way');

            StoredValue(repo, CURSOR_POS, found);
            CheckTrue(found, 'before the failure it wrote the stated row');
            StoredValue(repo, QSL_MODE, found);
            CheckFalse(found, 'and deleted the unstated one');
            (* NO COMMIT: the caller does not commit a failed capture. *)
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            StoredValue(repo, CURSOR_POS, found);
            CheckFalse(found, 'the row it wrote did not survive');
            v := StoredValue(repo, QSL_MODE, found);
            CheckTrue(found, 'the row it deleted is back');
            CheckEquals(A_QSL_MODE, v, 'with its committed value');
            for i := Low(RETIRED_SEVEN) to High(RETIRED_SEVEN) do
               begin
               StoredValue(repo, RETIRED_SEVEN[i], found);
               CheckTrue(found, RETIRED_SEVEN[i] + ' is as it was');
               end;
            CheckFalse(LogHoldsStatementsOnly(repo), 'and the log was not marked');
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
   finally
      s.Free;
   end;
   Scrub(fn);
end;

(* Q61: A CATEGORY CHANGE IS IN THE LOG WHEN IT IS MADE, not at the close.

  ASSISTED, BAND, MODE and OPERATOR are one contest-scoped setting each, and
  the log's config table is their one home. The Cabrillo summary window
  applies a change and calls LogStoreRecordContestStatement, which is
  CaptureContestStatement plus a commit -- modelled here as that pair. The
  database is then freed with NO close capture, which is what a crash
  leaves, and a fresh settings object reads the log back the way the
  program does (ApplyRows). *)
procedure TLogContestStatementsTests.Test_Q61_ACategoryChangeIsInTheLogAtOnce;
const
   COMMANDS: array[0..3] of string = (
      'CATEGORY-ASSISTED', 'CATEGORY-BAND', 'CATEGORY-MODE', 'CATEGORY-OPERATOR');
   (* Each differs from the constructor default, so an unmarked log reads it
     as a statement rather than as a sentinel. *)
   VALUES: array[0..3] of string = ('ASSISTED', '40M', 'SSB', 'MULTI-OP');
var
   db: TLogDatabase;
   repo: TLogRepository;
   s, back: TR4WSettings;
   fn: string;
   found: boolean;
   v: string;
   i: integer;
begin
   BeginTest('Q61: a category change is in the log when it is made');
   fn := TempLogName('q61categories.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   back := TR4WSettings.Create;
   try
      db := TLogDatabase.Create;
      try
         db.CreateNew(fn);
         repo := TLogRepository.Create(db);
         try
            for i := Low(COMMANDS) to High(COMMANDS) do
               begin
               CheckTrue(s.TrySetByCommand(COMMANDS[i], VALUES[i]),
                         COMMANDS[i] + ' is applied, as the window applies it');
               CheckTrue(CaptureContestStatement(s, repo, COMMANDS[i]),
                         COMMANDS[i] + ' is written at once');
               repo.Commit;
               end;

            CheckFalse(CaptureContestStatement(s, repo, 'CATEGORY-POWER'),
                       'an unstated category writes no row');
            StoredValue(repo, 'CATEGORY-POWER', found);
            CheckFalse(found, 'and has none');
            CheckFalse(CaptureContestStatement(s, repo, 'CONTEST'),
                       'CONTEST is never a config row');
            CheckTrue(s.TrySetByCommand('MY CALL', 'NY4I'), 'a station setting...');
            CheckFalse(CaptureContestStatement(s, repo, 'MY CALL'),
                       '...is not this rule''s to write');
            repo.Commit;
            CheckFalse(LogHoldsStatementsOnly(repo),
                       'one statement does not mark the log: its other rows ' +
                       'vouch for nothing');
            (* NO CLOSE CAPTURE. *)
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         repo := TLogRepository.Create(db);
         try
            ApplyRows(back, repo);
            for i := Low(COMMANDS) to High(COMMANDS) do
               begin
               v := StoredValue(repo, COMMANDS[i], found);
               CheckTrue(found, COMMANDS[i] + ' survived with no close');
               CheckEquals(VALUES[i], v, COMMANDS[i] + ' holds what was chosen');
               CheckTrue(back.TryGetByCommand(COMMANDS[i], v), COMMANDS[i] + ' reads back');
               CheckEquals(VALUES[i], v, COMMANDS[i] + ' is in force on reopen');
               CheckTrue(back.CommandIsStated(COMMANDS[i]),
                         COMMANDS[i] + ' is the operator''s statement again');
               end;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
   finally
      back.Free;
      s.Free;
   end;
   Scrub(fn);
end;

(* The contest row's declaration, as 'call|assisted|mode|name'. *)
function DeclarationOnFile(aDatabase: TLogDatabase): string;
var
   q: TSQLQuery;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDatabase.Connection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := 'SELECT IFNULL(my_call, '''') || ''|'' || ' +
                    'IFNULL(category_assisted, '''') || ''|'' || ' +
                    'IFNULL(category_mode, '''') || ''|'' || ' +
                    'IFNULL(op_name, '''') FROM contest WHERE id = 1';
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsString;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* Q61's LATENT DEFECT (1): A REOPENED LOG KEEPS ITS ENTRY DECLARATION.

  uLogStore.EnsureOpen called SetEntryDeclaration on EVERY open, so a
  reopened log's declaration became the values in force that day. It now
  calls RecordEntryDeclaration with "this open made the log", which writes
  only then. The log is created and declared, reopened with DIFFERENT
  values the way the next session would offer them, and reopened again. *)
procedure TLogContestStatementsTests.Test_Q61_AReopenedLogKeepsItsEntryDeclaration;
var
   db: TLogDatabase;
   repo: TLogRepository;
   made, today: TLogEntryDeclaration;
   fn: string;
begin
   BeginTest('Q61: a reopened log keeps the entry declaration it was made with');
   fn := TempLogName('q61declaration.db');
   Scrub(fn);

   made := Default(TLogEntryDeclaration);
   made.MyCall := 'NY4I';
   made.CategoryAssisted := 'ASSISTED';
   made.CategoryMode := 'CW';
   made.OpName := 'TOM';

   today := Default(TLogEntryDeclaration);
   today.MyCall := 'W1AW';
   today.CategoryAssisted := 'NON-ASSISTED';
   today.CategoryMode := 'SSB';
   today.OpName := 'HIRAM';

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         CheckFalse(RecordEntryDeclaration(repo, True, made),
                    'a new log with no contest row yet has nowhere to put it');
         repo.SetContest(ContestHandleOf(CQWWCW));
         CheckTrue(RecordEntryDeclaration(repo, True, made),
                   'the open that made the log records its declaration');
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   (* THE NEXT SESSION: the same log, other values in force. *)
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         CheckFalse(RecordEntryDeclaration(repo, False, today),
                    'a reopen records nothing');
         repo.Commit;
         CheckEquals('NY4I|ASSISTED|CW|TOM', DeclarationOnFile(db),
                     'the declaration is still the one the log was made with');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals('NY4I|ASSISTED|CW|TOM', DeclarationOnFile(db),
                  'and so is the file''s');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A CREDENTIAL'S ROW IS DELETED BY THE CAPTURE, WHATEVER ITS SOURCE --
  2026-10-29. The leak this pins: CaptureConfiguration wrote both passwords
  as 'station' rows. A 'station' row is never returned by LoadContestConfig,
  so the count is asked of the WHOLE table (ConfigCount) -- StoredValue would
  report a 'station' row absent whether it was deleted or not. *)
procedure TLogContestStatementsTests.Test_StoredCredentialRowsAreDeletedByTheCapture;
var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   found: boolean;
begin
   BeginTest('a stored credential row is deleted by the capture, whatever its source');
   fn := TempLogName('secrets.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      (* THE PREMISE: both are secrets to the settings object. If either stops
        being one, the rest of this test proves nothing. *)
      CheckTrue(s.CommandIsSecret(SERVER_PASSWORD), 'SERVER PASSWORD is a secret');
      CheckTrue(s.CommandIsSecret(HAMSCORE_PASSWORD), 'HAMSCORE PASSWORD is a secret');
      CheckFalse(s.CommandIsSecret('MY CALL'), 'MY CALL is not');

      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* AS AN OLDER BUILD LEFT THEM: one as the station walk wrote it, one
           as a .cfg-supplied row would be. And a live row beside them. *)
         repo.SaveConfigValue(AnsiString(SERVER_PASSWORD),
                              AnsiString(FAKE_STORED_PASSWORD), 'station');
         repo.SaveConfigValue(AnsiString(HAMSCORE_PASSWORD),
                              AnsiString(FAKE_STORED_PASSWORD), 'contest');
         repo.SaveConfigValue('MY CALL', 'N0TEST', 'contest');
         repo.Commit;
         CheckEquals(3, repo.ConfigCount, 'the log holds the three rows to begin with');

         DeleteStoredSecrets(s, repo);
         repo.Commit;
         CheckEquals(1, repo.ConfigCount, 'both credential rows are gone, in either source');
         StoredValue(repo, 'MY CALL', found);
         CheckTrue(found, 'and the live row beside them is untouched');

         (* AND THE MID-SESSION WRITE REFUSES ONE TOO: it writes nothing for a
           secret, however it is asked. *)
         CheckFalse(CaptureContestStatement(s, repo, SERVER_PASSWORD),
                    'the one-command capture writes no credential row');
         repo.Commit;
         CheckEquals(1, repo.ConfigCount, 'and the table still holds only the live row');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
end;

(* A STORED CREDENTIAL IS NEVER APPLIED, IN EITHER ERA, AND ITS VALUE IS NEVER
  HANDED BACK -- 2026-10-29. An old log's stale password must not overwrite
  the one this station holds in its vault. The read sets the row aside and
  returns the command's NAME only, which is all uLogStore logs. The apply is
  ApplyRows -- the program's filter, then a by-name assignment of what is left
  -- so the vault-side value surviving is the program's answer. *)
procedure TLogContestStatementsTests.Test_AStoredCredentialIsNeverApplied;

   procedure CheckEra(aStatementsOnly: boolean; const aEra: string);
   var
      rows, dropped, retired, secrets: TStringList;
   begin
      rows := TStringList.Create;
      dropped := TStringList.Create;
      retired := TStringList.Create;
      secrets := TStringList.Create;
      try
         rows.Add(AnsiString(SERVER_PASSWORD + '=' + FAKE_STORED_PASSWORD));
         rows.Add(AnsiString(HAMSCORE_PASSWORD + '=' + FAKE_STORED_PASSWORD));
         rows.Add(AnsiString(CURSOR_POS + '=' + A_CURSOR_POS));

         KeepOnlyStatements(rows, aStatementsOnly, dropped,
                            CommandIsRetired, retired, secrets);

         CheckEquals(2, secrets.Count, aEra + ': both credentials are set aside');
         CheckTrue(secrets.IndexOf(AnsiString(SERVER_PASSWORD)) >= 0,
                   aEra + ': SERVER PASSWORD is named');
         CheckTrue(secrets.IndexOf(AnsiString(HAMSCORE_PASSWORD)) >= 0,
                   aEra + ': HAMSCORE PASSWORD is named');
         CheckTrue(Pos(AnsiString(FAKE_STORED_PASSWORD), secrets.Text) = 0,
                   aEra + ': and the value is not handed back');
         CheckEquals(0, retired.Count, aEra + ': neither is reported as retired');
         CheckEquals(0, dropped.Count, aEra + ': nor as a built-in default');
         CheckEquals(1, rows.Count, aEra + ': only the live statement is left');
         if rows.Count = 1 then
            begin
            CheckEquals(AnsiString(CURSOR_POS), rows.Names[0],
                        aEra + ': and it is the live one');
            end;
      finally
         secrets.Free;
         retired.Free;
         dropped.Free;
         rows.Free;
      end;
   end;

var
   db: TLogDatabase;
   repo: TLogRepository;
   s: TR4WSettings;
   fn: string;
   rows: TStringList;
begin
   BeginTest('a stored credential is never applied, and its value is never handed back');
   CheckEra(False, 'a log written before the rule');
   CheckEra(True,  'a statements-only log');

   (* WITH NO LIST TO RECEIVE THE NAMES IT IS STILL REMOVED -- the rule does
     not depend on the caller asking. *)
   rows := TStringList.Create;
   try
      rows.Add(AnsiString(SERVER_PASSWORD + '=' + FAKE_STORED_PASSWORD));
      KeepOnlyStatements(rows, True, nil);
      CheckEquals(0, rows.Count, 'a credential row is removed with no aSecrets list');
   finally
      rows.Free;
   end;

   (* THE APPLY, AGAINST A LOG THAT HOLDS ONE. *)
   fn := TempLogName('secret-apply.db');
   Scrub(fn);
   s := TR4WSettings.Create;
   db := TLogDatabase.Create;
   try
      s.Server.Password := FAKE_VAULT_PASSWORD;
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SaveConfigValue(AnsiString(SERVER_PASSWORD),
                              AnsiString(FAKE_STORED_PASSWORD), 'contest');
         repo.Commit;

         ApplyRows(s, repo);
         CheckEquals(FAKE_VAULT_PASSWORD, string(s.Server.Password),
                     'the station''s password is not overwritten by the log''s');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      s.Free;
   end;
   Scrub(fn);
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
   Test_RetiredRowsAreSetAsideInEitherEra;
   Test_CaptureDeletesRetiredRowsOnce;
   Test_ACaptureThatFailsPartWayLeavesNothingOfItself;
   Test_Q61_ACategoryChangeIsInTheLogAtOnce;
   Test_Q61_AReopenedLogKeepsItsEntryDeclaration;
   Test_StoredCredentialRowsAreDeletedByTheCapture;
   Test_AStoredCredentialIsNeverApplied;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
