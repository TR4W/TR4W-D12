(* THE CONTEST'S RULE IS STORED ON THE QSO -- LOG SCHEMA 10 (NY4I,
  2026-11-19: an X-QSO decided by the contest's band/mode/host rule is
  STORED in the record when the QSO is logged, and Cabrillo, ADIF, search
  and Edit QSO simply READ it -- "Otherwise we have business rules being
  derived at cabrillo generation").

  qso.is_off_contest is a derived and stored value, like qso_points: set by
  uContestRegistry.StampOffContest where a QSO is logged, rescored, imported
  or saved from Edit QSO, and read everywhere else. It is NOT is_xqso -- that
  is the operator's statement and stays his. WHAT IS PINNED HERE:

    the migration   a schema-9 log gains the column in ONE commit, every row
                    0, and is marked for the store's one-shot stamp when it
                    holds a QSO; an empty log is not marked; a second open
                    changes nothing
    the stamp       the one-shot stamp judges EVERY QSO row afresh (a stale 1
                    is cleared), never touches is_xqso, deletes the mark and
                    runs once
    a write         an update carries the stored value back as it read it:
                    only a setting point changes it

  The readers (the exports, the totals) and the setting points' order are
  pinned in uTestAutomaticXQSO; the store's append in uTestLogStore; the
  record's byte (offset 330, carved from sReserved) in uTestLogBinaryFile. *)
unit uTestLogOffContest;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogOffContestTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
   protected
      procedure Test_ASchema9LogGainsTheColumnInOneCommit;
      procedure Test_AnEmptySchema9LogIsNotMarked;
      procedure Test_TheOneShotStampJudgesEveryRowOnce;
      procedure Test_AnUpdateCarriesTheStoredRuleBack;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uLogDatabase, uLogSchema, uLogRepository,
   uContestRegistry,       (* ContestHandleOf, StampOffContest *)
   uTestLatestContest,     (* MakeTestContestLog, DowngradeTestLog, ScrubTestLog, TestLogHasColumn *)
   uTestLogDatabase,       (* CommitFramesInWal *)
   uTestLogReceivedYear;   (* QueryText *)

const
   OFF_SQL = 'SELECT group_concat(is_off_contest, '','') ' +
             'FROM (SELECT is_off_contest FROM qso ORDER BY id)';
   XQSO_SQL = 'SELECT group_concat(IFNULL(is_xqso, 0), '','') ' +
              'FROM (SELECT is_xqso FROM qso ORDER BY id)';
   MARK_SQL = 'SELECT value FROM session_state WHERE key = ''' +
              LOG_OFF_CONTEST_BACKFILL_KEY + '''';

(* A CQ WW SSB QSO on aBand in aMode -- its own exchange id and network key,
  so no two rows are grouped as one contact. *)
function CQWWRow(aSeed: integer; aBand: BandType; aMode: ModeType;
                 aExt: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := ContestHandleOf(CQWWSSB);
   Result.id := ShortString('offcontest' + IntToStr(aSeed));
   Result.ceQSOID1 := 5000 + aSeed;
   Result.ceQSOID2 := 6000 + aSeed;
   Result.Callsign := CallString('DL' + IntToStr(aSeed) + 'ABC');
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExt;
   Result.Frequency := 14200000 + aSeed;
   Result.RSTSent := 59;
   Result.RSTReceived := 59;
   Result.Zone := 14;
   Result.QTH.CountryID := 'DL';
   Result.QTH.Continent := Europe;
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 10;
   Result.tSysTime.qtDay := 25;
   Result.tSysTime.qtHour := 12;
   Result.tSysTime.qtMinute := aSeed;
end;

function TLogOffContestTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_offcontest_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   ScrubTestLog(Result);
end;

(* A SCHEMA-9 LOG OPENED BY THIS BUILD: the column, every row 0, the mark and
  the version stamp land in ONE commit -- and the operator's flag is left as
  it was. A second open is a no-op. *)
procedure TLogOffContestTests.Test_ASchema9LogGainsTheColumnInOneCommit;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   flagged: ContestExchange;
begin
   BeginTest('a schema-9 log gains is_off_contest and the stamp mark in one commit');
   fn := TempLogName('nine.db');
   MakeTestContestLog(fn, ContestHandleOf(CQWWSSB), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SaveQSO(CQWWRow(1, Band20, CW, eCW));
         flagged := CQWWRow(2, Band20, Phone, eUSB);
         flagged.ceXQSO := True;
         repo.SaveQSO(flagged);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 9, Low(LOG_V3_QSO_COLUMNS));
   (* NOT OPENED TO INSPECT: a read-only connection to a WAL-mode log leaves
     its -wal behind, and the commit count below must see only the open. *)
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'),
                  'the column, the mark and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V10_QSO_OFF_CONTEST_COLUMN.Name)),
                'the column is there');
      CheckEquals('0,0', QueryText(db, OFF_SQL), 'every row reads 0 until the store stamps it');
      CheckEquals('0,1', QueryText(db, XQSO_SQL), 'the operator''s flag is as it was');
      CheckEquals('1', QueryText(db, MARK_SQL), 'and the log is marked for the stamp');
   finally
      db.Free;
   end;

   (* A SECOND OPEN: current, nothing to add, the mark untouched. *)
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'still current');
      CheckEquals('1', QueryText(db, MARK_SQL), 'the mark waits for the store');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* AN EMPTY LOG HAS NOTHING TO STAMP: the column, and no mark. *)
procedure TLogOffContestTests.Test_AnEmptySchema9LogIsNotMarked;
var
   fn: string;
   db: TLogDatabase;
begin
   BeginTest('an empty schema-9 log gains the column and no mark');
   fn := TempLogName('nine-empty.db');
   MakeTestContestLog(fn, ContestHandleOf(CQWWSSB), '');
   DowngradeTestLog(fn, 9, Low(LOG_V3_QSO_COLUMNS));
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V10_QSO_OFF_CONTEST_COLUMN.Name)),
                'the column');
      CheckEquals('', QueryText(db, MARK_SQL), 'no mark where no QSO is');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* THE ONE-SHOT STAMP, through the program's own stamp: every QSO row judged
  afresh by its contest's rule -- a CW and a 17 m QSO in CQ WW SSB refused, a
  20 m phone QSO credited, a STALE 1 on a credited row cleared -- the
  operator's flag never written, the mark deleted, and never again. *)
procedure TLogOffContestTests.Test_TheOneShotStampJudgesEveryRowOnce;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   stale, flagged: ContestExchange;
begin
   BeginTest('the one-shot stamp judges every QSO row by its contest, once');
   fn := TempLogName('stamp.db');
   MakeTestContestLog(fn, ContestHandleOf(CQWWSSB), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SaveQSO(CQWWRow(1, Band20, Phone, eUSB));      (* credited: 0 *)
         repo.SaveQSO(CQWWRow(2, Band20, CW, eCW));          (* off-mode: 1 *)
         repo.SaveQSO(CQWWRow(3, Band17, Phone, eUSB));      (* off-band: 1 *)
         stale := CQWWRow(4, Band40, Phone, eLSB);           (* credited, stale 1: 0 *)
         stale.ceOffContest := True;
         repo.SaveQSO(stale);
         flagged := CQWWRow(5, Band20, Phone, eUSB);         (* the operator's X-QSO *)
         flagged.ceXQSO := True;
         repo.SaveQSO(flagged);
         repo.Commit;
         CheckEquals('0,0,0,1,0', QueryText(db, OFF_SQL), 'precondition: as written');

         (* NO MARK, NO STAMP. *)
         CheckEquals(-1, repo.BackfillOffContest(@StampOffContest), 'no mark: nothing done');
         repo.Commit;
         CheckEquals('0,0,0,1,0', QueryText(db, OFF_SQL), 'nothing moved');

         repo.SaveSessionValue(LOG_OFF_CONTEST_BACKFILL_KEY, '1');
         repo.Commit;
         CheckEquals(2, repo.BackfillOffContest(@StampOffContest), 'two rows the rule refuses');
         repo.Commit;
         CheckEquals('0,1,1,0,0', QueryText(db, OFF_SQL),
                     'exactly the off-mode and off-band rows; the stale 1 cleared');
         CheckEquals('0,0,0,0,1', QueryText(db, XQSO_SQL),
                     'and the operator''s flag untouched');
         CheckEquals('', QueryText(db, MARK_SQL), 'the mark is gone');
         CheckEquals(-1, repo.BackfillOffContest(@StampOffContest), 'never again');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* A WRITE THAT IS NOT A SETTING POINT CARRIES THE STORED RULE BACK: a QSO
  read, changed elsewhere (a delete flag, a QTC mark) and written keeps the
  value it was read with. *)
procedure TLogOffContestTests.Test_AnUpdateCarriesTheStoredRuleBack;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   rec, back: ContestExchange;
   rowId: Int64;
begin
   BeginTest('an update writes back the stored rule it read');
   fn := TempLogName('update.db');
   MakeTestContestLog(fn, ContestHandleOf(CQWWSSB), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         rec := CQWWRow(1, Band20, CW, eCW);
         StampOffContest(rec);
         CheckTrue(rec.ceOffContest, 'precondition: a CW QSO in CQ WW SSB is stamped off');
         rowId := repo.SaveQSO(rec);
         repo.Commit;

         CheckTrue(repo.LoadQSO(rowId, back), 'it reads back');
         CheckTrue(back.ceOffContest, 'with its stamp');
         CheckFalse(back.ceXQSO, 'and no operator flag');
         back.ceWasSendInQTC := True;
         CheckTrue(repo.UpdateQSO(rowId, back), 'a QTC mark is written');
         repo.Commit;
         CheckTrue(repo.LoadQSO(rowId, back), 'and reads back');
         CheckTrue(back.ceOffContest, 'still stamped: only a setting point changes it');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogOffContestTests.RunAllTests;
begin
   Test_ASchema9LogGainsTheColumnInOneCommit;
   Test_AnEmptySchema9LogIsNotMarked;
   Test_TheOneShotStampJudgesEveryRowOnce;
   Test_AnUpdateCarriesTheStoredRuleBack;
   if FDir <> '' then
      begin
      RemoveDir(FDir);
      end;
end;

end.
