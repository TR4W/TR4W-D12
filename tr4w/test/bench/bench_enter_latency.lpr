program bench_enter_latency;

(* HOW LONG DOES ENTER WAIT FOR THE LOG? (issue 350,
  docs/QSO_LOG_INTEGRITY_REVIEW.md finding 4)

  Two numbers, kept apart because they answer different questions:

    Enter-to-COMMIT  SaveQSO + Commit -- the QSO is durable. This is the
                     acknowledgement boundary and stays synchronous.
    Enter-to-READY   what the operator waits for before the next call:
                     the commit PLUS, when the periodic backup is due, the
                     backup call made on the same thread.

  THREE PHASES over ONE large log (default 20,000 QSOs) in a scratch folder
  under the system temp directory -- never tr4w\target, never a real log:

    A  commit only               SaveQSO + Commit, nothing else.
    B  inline backup             as before issue 350: every --every'th QSO
                                 runs the whole periodic backup (VACUUM INTO,
                                 verification on its own connection, publish
                                 by rename) on this thread, after its commit.
    C  backup worker             as after issue 350: every --every'th QSO
                                 hands the job to uLogBackupWorker (unless
                                 one is already in flight, which is what
                                 logstuff does), so READY is the commit plus
                                 a hand-over -- and the commits of C run
                                 WHILE the worker snapshots, which is the
                                 number that says whether the move costs the
                                 writer anything.

  Each series prints n, p50, p95, p99 and max in milliseconds. Phase B's
  backup uses uLogBackup.TLogFileBackup -- the worker's own class -- where
  the program's inline path used TLogStoreBackup; both snapshot through a
  separate read-only VACUUM INTO connection and verify the same way, so the
  cost is the same work (the store's path opens one connection fewer).

  NOT MEASURED HERE: the grid repaint, the status line, the multiplier
  windows, an open search window, the external-logger dispatcher -- the
  parts of READY that are not the log. Run with the program for those.

  Usage:  bench_enter_latency [qsos] [iterations] [every]
          defaults 20000 200 20
  sqlite3.dll must be beside the exe (copy tr4w\redist\x86_64-win64\sqlite3.dll;
  Build-Bench.ps1 does not stage DLLs). *)

(* The tree's own mode and string model (Delphi mode, UnicodeStrings), so a
  string passed to the log units as an out parameter is their string. *)
{$I ..\..\src\tr4w.inc}

uses
   (* Interfaces FIRST: uLogRepository reaches the LCL (LCLType, TF), and the
      LCL linked without its widgetset half fails at LINK time. Nothing here
      opens a window. *)
   Interfaces,
   SysUtils,
   Classes,
   SyncObjs,
   Math,
{$IFDEF WINDOWS}
   Windows,   (* QueryPerformanceCounter -- see StartClock *)
{$ENDIF}
   Log4D,
   MainUnit,  (* logger -- units below log through it *)
   VC,
   uLogDatabase,
   uLogRepository,
   uLogBackup,
   uLogBackupWorker;

type
   TSeries = class(TObject)
   public
      Name: string;
      Values: array of double;
      Count: integer;
      constructor Create(const aName: string);
      procedure Add(aMs: double);
      procedure Print;
   end;

   (* Catches the worker's results on the worker thread, with the clock. *)
   TWorkerCatcher = class(TObject)
   public
      Lock: SyncObjs.TCriticalSection;
      Runs: integer;
      Failures: integer;
      LastReport: string;
      constructor Create;
      destructor Destroy; override;
      procedure Received(aResult: TLogBackupResult);
   end;

var
   gFreq: Int64 = 0;

(* THE CLOCK. QueryPerformanceCounter on Windows, as bench_callsign does and
  for the same reason: the RTL has no sub-millisecond clock, and a commit is
  well under a millisecond on a fast disk. Off Windows GetTickCount64 (1 ms)
  is the stand-in, and the low percentiles are then only "under 1 ms". *)
procedure StartClock(out aAt: Int64);
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(aAt);
{$ELSE}
   aAt := Int64(GetTickCount64);
{$ENDIF}
end;

function StopClock(const aAt: Int64): double;   (* milliseconds *)
var
   stamp: Int64;
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(stamp);
   Result := (stamp - aAt) * 1000.0 / gFreq;
{$ELSE}
   stamp := Int64(GetTickCount64);
   Result := stamp - aAt;
{$ENDIF}
end;

constructor TSeries.Create(const aName: string);
begin
   inherited Create;
   Name := aName;
   SetLength(Values, 64);
   Count := 0;
end;

procedure TSeries.Add(aMs: double);
begin
   if Count = Length(Values) then
      begin
      SetLength(Values, Count * 2);
      end;
   Values[Count] := aMs;
   inc(Count);
end;

function Percentile(const aSorted: array of double; aCount: integer; aP: double): double;
var
   i: integer;
begin
   i := Ceil(aP * aCount) - 1;
   if i < 0 then
      begin
      i := 0;
      end;
   if i > aCount - 1 then
      begin
      i := aCount - 1;
      end;
   Result := aSorted[i];
end;

procedure TSeries.Print;
var
   sorted: array of double;
   i, j: integer;
   t: double;
begin
   if Count = 0 then
      begin
      WriteLn(Format('  %-34s n=0', [Name]));
      Exit;
      end;
   SetLength(sorted, Count);
   for i := 0 to Count - 1 do
      begin
      sorted[i] := Values[i];
      end;
   (* Insertion sort: a few hundred values. *)
   for i := 1 to Count - 1 do
      begin
      t := sorted[i];
      j := i - 1;
      while (j >= 0) and (sorted[j] > t) do
         begin
         sorted[j + 1] := sorted[j];
         dec(j);
         end;
      sorted[j + 1] := t;
      end;
   WriteLn(Format('  %-34s n=%-5d p50=%9.3f  p95=%9.3f  p99=%9.3f  max=%9.3f ms',
                  [Name, Count,
                   Percentile(sorted, Count, 0.50),
                   Percentile(sorted, Count, 0.95),
                   Percentile(sorted, Count, 0.99),
                   sorted[Count - 1]]));
end;

constructor TWorkerCatcher.Create;
begin
   inherited Create;
   Lock := SyncObjs.TCriticalSection.Create;
end;

destructor TWorkerCatcher.Destroy;
begin
   Lock.Free;
   inherited Destroy;
end;

procedure TWorkerCatcher.Received(aResult: TLogBackupResult);
begin
   Lock.Acquire;
   try
      inc(Runs);
      if not aResult.Succeeded then
         begin
         inc(Failures);
         end;
      LastReport := aResult.Report;
   finally
      Lock.Release;
   end;
   aResult.Free;
end;

procedure SaveOne(aRepo: TLogRepository; aSerial: integer);
var
   rec: ContestExchange;
begin
   rec := Default(ContestExchange);
   rec.Callsign := ShortString('K' + IntToStr(aSerial mod 10) + 'B' + IntToStr(aSerial));
   rec.ceRecordKind := rkQSO;
   rec.NumberSent := aSerial;
   aRepo.SaveQSO(rec);
end;

procedure Scrub(const aPath: string);
const
   SUFFIXES: array[0..5] of string = ('', '.new', '.bak', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(aPath + SUFFIXES[i]) then
         begin
         SysUtils.DeleteFile(aPath + SUFFIXES[i]);
         end;
      end;
end;

var
   qsos, iterations, every: integer;
   dir, backupDir, logFile, dest, report: string;
   db: TLogDatabase;
   repo: TLogRepository;
   worker: TLogBackupWorker;
   catcher: TWorkerCatcher;
   backup: TLogFileBackup;
   commitA, commitB, backupB, readyB, commitC, handC, readyC, commitDuring: TSeries;
   serial, i: integer;
   at: Int64;
   commitMs, backupMs: double;
   busyBefore: boolean;

begin
{$IFDEF WINDOWS}
   QueryPerformanceFrequency(gFreq);
{$ENDIF}
   (* Units this links log through MainUnit's global; only tr4w.lpr's startup
     assigns it. *)
   logger := TLogLogger.GetLogger('EnterLatencyBench');

   qsos := StrToIntDef(ParamStr(1), 20000);
   iterations := StrToIntDef(ParamStr(2), 200);
   every := StrToIntDef(ParamStr(3), 20);
   if (qsos < 0) or (iterations < 1) or (every < 1) then
      begin
      WriteLn('usage: bench_enter_latency [qsos] [iterations] [every]');
      Halt(2);
      end;

   dir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_bench_enter_' + IntToStr(GetProcessID);
   backupDir := IncludeTrailingPathDelimiter(dir) + 'backup';
   logFile := IncludeTrailingPathDelimiter(dir) + 'bench.db';
   dest := IncludeTrailingPathDelimiter(backupDir) + 'bench periodic.db';
   ForceDirectories(backupDir);
   Scrub(logFile);
   Scrub(dest);

   commitA := TSeries.Create('A commit only');
   commitB := TSeries.Create('B commit');
   backupB := TSeries.Create('B inline backup call');
   readyB := TSeries.Create('B ready (commit + backup)');
   commitC := TSeries.Create('C commit');
   handC := TSeries.Create('C worker hand-over call');
   readyC := TSeries.Create('C ready (commit + hand-over)');
   commitDuring := TSeries.Create('C commit while worker busy');
   catcher := TWorkerCatcher.Create;
   db := TLogDatabase.Create;
   repo := nil;
   try
      try
         db.CreateNew(logFile);
      except
         on E: Exception do
            begin
            WriteLn('could not create the log: ', E.Message);
            WriteLn('(is sqlite3.dll beside this exe? copy it from tr4w\redist\x86_64-win64)');
            Halt(1);
            end;
      end;
      repo := TLogRepository.Create(db);

      WriteLn(Format('SQLite %s, journal %s, synchronous %d', [db.SQLiteVersion, db.JournalMode, db.Synchronous]));
      WriteLn(Format('filling %d QSOs into %s ...', [qsos, logFile]));
      serial := 0;
      for i := 1 to qsos do
         begin
         inc(serial);
         SaveOne(repo, serial);
         if i mod 1000 = 0 then
            begin
            repo.Commit;
            end;
         end;
      repo.Commit;

      (* A: commit only. *)
      for i := 1 to iterations do
         begin
         inc(serial);
         StartClock(at);
         SaveOne(repo, serial);
         repo.Commit;
         commitA.Add(StopClock(at));
         end;

      (* B: the inline backup, as before issue 350. *)
      for i := 1 to iterations do
         begin
         inc(serial);
         StartClock(at);
         SaveOne(repo, serial);
         repo.Commit;
         commitMs := StopClock(at);
         commitB.Add(commitMs);
         backupMs := 0;
         if i mod every = 0 then
            begin
            StartClock(at);
            backup := TLogFileBackup.Create(logFile);
            try
               if not backup.Run(dest, report) then
                  begin
                  WriteLn('  inline backup FAILED: ', report);
                  end;
            finally
               backup.Free;
            end;
            backupMs := StopClock(at);
            backupB.Add(backupMs);
            end;
         readyB.Add(commitMs + backupMs);
         end;

      (* C: the worker, as after issue 350. *)
      worker := TLogBackupWorker.Create(catcher.Received, nil);
      try
         for i := 1 to iterations do
            begin
            inc(serial);
            busyBefore := worker.Busy;
            StartClock(at);
            SaveOne(repo, serial);
            repo.Commit;
            commitMs := StopClock(at);
            commitC.Add(commitMs);
            if busyBefore then
               begin
               commitDuring.Add(commitMs);
               end;
            backupMs := 0;
            if (i mod every = 0) and (not worker.Busy) then
               begin
               StartClock(at);
               worker.Request(TLogBackupJob.Create(logFile, backupDir, dest, i));
               backupMs := StopClock(at);
               handC.Add(backupMs);
               end;
            readyC.Add(commitMs + backupMs);
            end;
         if not worker.WaitIdle(600000) then
            begin
            WriteLn('  the worker did not finish within 10 minutes');
            end;
      finally
         worker.Free;
      end;

      WriteLn;
      WriteLn(Format('%d QSOs in the log, %d iterations per phase, backup due every %d', [qsos, iterations, every]));
      commitA.Print;
      commitB.Print;
      backupB.Print;
      readyB.Print;
      commitC.Print;
      commitDuring.Print;
      handC.Print;
      readyC.Print;
      WriteLn(Format('  worker runs completed: %d, failed: %d; last: %s',
                     [catcher.Runs, catcher.Failures, catcher.LastReport]));
   finally
      repo.Free;
      db.Free;
      catcher.Free;
      commitA.Free;
      commitB.Free;
      backupB.Free;
      readyB.Free;
      commitC.Free;
      handC.Free;
      readyC.Free;
      commitDuring.Free;
      Scrub(logFile);
      Scrub(dest);
      RemoveDir(backupDir);
      RemoveDir(dir);
   end;
end.
