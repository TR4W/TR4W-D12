unit uTestServerLogHealth;
{$I ..\..\src\tr4w.inc}

(*
   THE SERVER LOG'S HEALTH (issue 314, review H9): what is done with a log that
   ends in part of a record, and the texts the stations and the window get when
   the log cannot be written. The server unit is not linked into this binary;
   the leaf it calls is, and carries every decision.
*)

interface

uses
   SysUtils,
   Classes,
   FileUtil,
   uTR4WTestFramework;

type
   TServerLogHealthTests = class(TTestCase)
   private
      FDir: string;
      function MakeLog(const aName: string; aRecords: integer; aTail: integer;
                       aHeaderOk: boolean): string;
      procedure Test_TheSizeJudge;
      procedure Test_ATornTailWithTheCurrentHeaderIsTrimmedAfterABackup;
      procedure Test_AnotherHeaderIsNeverTouched;
      procedure Test_AWholeLogIsLeftAlone;
      procedure Test_TheNoticesFitAnIntercomLine;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uServerLogHealth;

function ReadAll(const aName: string): AnsiString;
var
   f: TFileStream;
begin
   f := TFileStream.Create(aName, fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(Result[1], f.Size);
         end;
   finally
      f.Free;
   end;
end;

(* A log: the header record, aRecords QSO records, then aTail stray bytes. *)
function TServerLogHealthTests.MakeLog(const aName: string; aRecords: integer;
                                       aTail: integer; aHeaderOk: boolean): string;
var
   f: TFileStream;
   header: TLogHeader;
   rec: ContestExchange;
   i: integer;
   junk: AnsiString;
begin
   Result := FDir + aName;
   f := TFileStream.Create(Result, fmCreate);
   try
      header := Default(TLogHeader);
      if aHeaderOk then
         begin
         header := LogHeader;
         end
      else
         begin
         header.lhVersionString[0] := 'X';
         end;
      f.WriteBuffer(header, SizeOf(TLogHeader));
      for i := 1 to aRecords do
         begin
         rec := Default(ContestExchange);
         rec.ceQSOID1 := i;
         rec.ceQSOID2 := i;
         f.WriteBuffer(rec, SizeOf(ContestExchange));
         end;
      if aTail > 0 then
         begin
         junk := StringOfChar('A', aTail);
         f.WriteBuffer(junk[1], aTail);
         end;
   finally
      f.Free;
   end;
end;

procedure TServerLogHealthTests.Test_TheSizeJudge;
var
   keep: Int64;
   rec: Int64;
begin
   BeginTest('Test_TheSizeJudge');
   rec := SizeOf(ContestExchange);
   CheckEquals(Ord(ttWhole), Ord(JudgeServerLogSize(rec * 5, rec, True, keep)), 'whole');
   CheckEquals(Ord(ttWhole), Ord(JudgeServerLogSize(0, rec, False, keep)), 'empty');
   CheckEquals(Ord(ttTrim), Ord(JudgeServerLogSize(rec * 5 + 100, rec, True, keep)), 'torn tail');
   CheckEquals(Integer(rec * 5), Integer(keep), 'kept whole records');
   CheckEquals(Ord(ttRefuse), Ord(JudgeServerLogSize(rec * 5 + 100, rec, False, keep)),
      'another header: size alone cannot say it is a torn tail');
   CheckEquals(Ord(ttRefuse), Ord(JudgeServerLogSize(100, rec, True, keep)),
      'less than a record holds no header');
end;

procedure TServerLogHealthTests.Test_ATornTailWithTheCurrentHeaderIsTrimmedAfterABackup;
var
   name, backup, error: string;
   size, keep: Int64;
   verdict: TTornTailVerdict;
   before: AnsiString;
begin
   BeginTest('Test_ATornTailWithTheCurrentHeaderIsTrimmedAfterABackup');
   name := MakeLog('torn.trw', 3, 100, True);
   before := ReadAll(name);
   CheckTrue(PlanServerLogRepair(name, size, keep, verdict), 'planned');
   CheckEquals(Ord(ttTrim), Ord(verdict), 'verdict');
   CheckEquals(Integer(SizeOf(ContestExchange) * 4), Integer(keep), 'header + 3 records kept');
   CheckTrue(BackupAndTrimServerLog(name, 'T', keep, backup, error), 'trimmed: ' + error);
   CheckEquals(Integer(keep), Integer(Length(ReadAll(name))), 'file trimmed');
   CheckTrue(ReadAll(name) = Copy(before, 1, keep), 'the whole records are untouched');
   CheckTrue(ReadAll(backup) = before, 'the backup is the whole original, byte for byte');
   CheckTrue(PlanServerLogRepair(name, size, keep, verdict) and (verdict = ttWhole),
      'and it is whole now');
end;

procedure TServerLogHealthTests.Test_AnotherHeaderIsNeverTouched;
var
   name: string;
   size, keep: Int64;
   verdict: TTornTailVerdict;
   before: AnsiString;
begin
   BeginTest('Test_AnotherHeaderIsNeverTouched');
   name := MakeLog('old.trw', 3, 100, False);
   before := ReadAll(name);
   CheckTrue(PlanServerLogRepair(name, size, keep, verdict), 'planned');
   CheckEquals(Ord(ttRefuse), Ord(verdict), 'refused');
   CheckTrue(ReadAll(name) = before, 'file unchanged');
end;

procedure TServerLogHealthTests.Test_AWholeLogIsLeftAlone;
var
   name: string;
   size, keep: Int64;
   verdict: TTornTailVerdict;
begin
   BeginTest('Test_AWholeLogIsLeftAlone');
   name := MakeLog('whole.trw', 2, 0, True);
   CheckTrue(PlanServerLogRepair(name, size, keep, verdict), 'planned');
   CheckEquals(Ord(ttWhole), Ord(verdict), 'nothing to do');
   CheckFalse(PlanServerLogRepair(FDir + 'absent.trw', size, keep, verdict), 'a missing file is not planned');
end;

procedure TServerLogHealthTests.Test_TheNoticesFitAnIntercomLine;
var
   longReason: string;
begin
   BeginTest('Test_TheNoticesFitAnIntercomLine');
   longReason := StringOfChar('x', 400);
   CheckTrue(Length(ServerLogFailureNotice(longReason)) <= SERVER_NOTICE_MAX,
      'a long OS reason is clipped, not the notice');
   CheckTrue(Pos('NOT stored', ServerLogFailureNotice('Disk Full')) > 0, 'says the QSO is not stored');
   CheckTrue(Pos('relayed', ServerLogFailureNotice('Disk Full')) > 0, 'says the QSO is still relayed');
   CheckTrue(Pos('Disk Full', ServerLogFailureNotice('Disk Full')) > 0, 'names the reason');
   CheckTrue(Length(ServerLogRecoveredNotice) <= SERVER_NOTICE_MAX, 'recovery notice fits');
   CheckEquals('', ServerLogProblemText(0, 'x'), 'no failures, no text');
   CheckTrue(Pos('3', ServerLogProblemText(3, 'Disk Full')) > 0, 'the count is shown');
end;

procedure TServerLogHealthTests.RunAllTests;
begin
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-loghealth-' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   try
      Test_TheSizeJudge;
      Test_ATornTailWithTheCurrentHeaderIsTrimmedAfterABackup;
      Test_AnotherHeaderIsNeverTouched;
      Test_AWholeLogIsLeftAlone;
      Test_TheNoticesFitAnIntercomLine;
   finally
      DeleteDirectory(FDir, False);
   end;
end;

end.
