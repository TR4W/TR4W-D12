unit uLogConnectionWatch;
{$I ..\tr4w.inc}

(* THE WATCHDOG OVER EVERY SECOND CONNECTION TO THE CONTEST LOG.

  NY4I, 2026-10-31: the log belongs to TR4W and the database must never get
  in the way of logging. A delivery worker is the junior partner. With more
  than one thread touching the database, the main program keeps a watchdog,
  so that nothing can leave the log locked.

  ------------------------------------------------------------------------
  WHAT IS WATCHED
  ------------------------------------------------------------------------

  A SECONDARY connection: one opened by a thread other than the main one
  (today the WRL delivery worker, uWRLWorker). Each one owns a
  TLogConnectionWatch. Its TLogConnection tells the watch when a transaction
  begins and ends (TLogConnection.StartDBTransaction / Commit / RollBack, so
  no caller can forget), and hands it the SQLite handle while it is open.

  THE MAIN CONNECTION IS NOT WATCHED, ON PURPOSE. sqldb keeps a read
  transaction open after every read and the main connection reads all the
  time, so it would always look "open for minutes". In WAL mode a read
  transaction blocks no writer. What it CAN do -- make the next write fail
  at once with SQLITE_BUSY_SNAPSHOT -- is handled where the main connection
  writes (uLogStore's BeginMainWrite), not here.

  ------------------------------------------------------------------------
  THE ESCALATION, and why it has three steps
  ------------------------------------------------------------------------

  Measured 2026-10-31 (Python's sqlite3, the same C library):

    sqlite3_interrupt during a long statement   ends it in about 0 s
    sqlite3_interrupt during a busy-timeout wait does NOT end the wait
    sqlite3_interrupt on an idle open transaction does nothing at all

  So interrupt is not a way to end a transaction. It is a way to end a
  STATEMENT, after which the owner's own exception handling rolls back. The
  steps are:

    1. open longer than LOG_WATCH_THRESHOLD_MS: logged, and the owner is
       ASKED to roll back (TakeRollbackRequest, polled by the owner between
       statements -- the case of an idle transaction left open by a bug).
    2. still the same transaction LOG_WATCH_GRACE_MS later: sqlite3_interrupt
       -- the case of a statement that will not finish.
    3. still the same transaction another grace later: the owner's OnGiveUp
       runs (the WRL owner stops that worker and starts a new one once the old
       thread has exited; pending deliveries are durable in external_delivery).

  Each step counts as one intervention (LogWatchInterventionCount), which
  Tools > Run Verification Checks reports.

  THE WATCHDOG NEVER CLOSES ANOTHER THREAD'S CONNECTION. sqldb objects are
  not thread-safe; closing a connection from the main thread while its owner
  is inside a statement would be a use-after-free. sqlite3_interrupt is the
  one call SQLite documents as safe from another thread, and it is made under
  this watch's lock, which the owner also takes to Detach before it closes the
  connection -- so the handle is never one that has been freed.

  ------------------------------------------------------------------------
  THE THRESHOLD: 3 s
  ------------------------------------------------------------------------

  A worker transaction is a claim or a settle: one SELECT and one UPDATE,
  milliseconds. The worker's busy wait is 1 s (uWRLWorker) and the main
  connection's is LOG_BUSY_TIMEOUT_MS = 2 s (uLogDatabase). A worker
  transaction still open after 3 s is therefore already longer than the main
  connection would wait for it, which is the definition of "in the way of
  logging". The grace of 2 s gives the owner one more of its own busy waits
  to react before the next step.

  NO LCL, NO LOGGER: a leaf in src/domain. The TTimer that calls
  RunLogWatchdog, and the logging of what it returns, belong to the owner of
  the secondary connection (uWRLExternalLogger). *)

interface

uses
   SyncObjs;

const
   LOG_WATCH_THRESHOLD_MS = 3000;
   LOG_WATCH_GRACE_MS = 2000;

type
   TLogWatchStage = (lwsQuiet, lwsAskedToRollBack, lwsInterrupted, lwsGivenUp);

   TLogConnectionWatch = class;

   TLogWatchEvent = procedure(aWatch: TLogConnectionWatch) of object;

   (* One line per intervention RunLogWatchdog made, for the caller to log. *)
   TLogWatchEvents = array of string;

   TLogConnectionWatch = class
   private
      FLock: TCriticalSection;
      FName: string;
      (* GetTickCount64 when the open transaction began; 0 when none. An Int64
        under FLock rather than an interlocked one: on i386 a 64-bit
        interlocked read is not a plain load, and the lock is taken a few
        times per transaction, which costs nothing measurable. *)
      FBegan: Int64;
      FHandle: Pointer;
      FRollbackRequested: boolean;
      (* THE WATCHDOG'S OWN STATE -- main thread only. FStageFor is the FBegan
        value the stage belongs to, so a new transaction starts again at
        lwsQuiet. *)
      FStage: TLogWatchStage;
      FStageFor: Int64;
      FOnGiveUp: TLogWatchEvent;
   public
      constructor Create(const aName: string);
      destructor Destroy; override;

      (* THE OWNER'S SIDE. Called on the owning thread, by TLogConnection. *)
      procedure TransactionBegan;
      procedure TransactionEnded;
      procedure Attach(aHandle: Pointer);
      procedure Detach;
      (* True once after RequestRollback: the owner then rolls back. *)
      function TakeRollbackRequest: boolean;

      (* ANY THREAD. *)
      function BeganAt: Int64;
      (* How long the open transaction has been open at aNow; 0 when none. *)
      function OpenForMs(aNow: Int64): Int64;

      (* THE WATCHDOG'S SIDE. *)
      procedure RequestRollback;
      (* sqlite3_interrupt on the attached handle. False when none is
        attached (the connection is closed). *)
      function Interrupt: boolean;

      property Name: string read FName;
      property Stage: TLogWatchStage read FStage;
      property OnGiveUp: TLogWatchEvent read FOnGiveUp write FOnGiveUp;
   end;

(* The registry. Main thread: a secondary connection's owner registers its
  watch when it creates it and unregisters it before freeing it. *)
procedure RegisterLogConnectionWatch(aWatch: TLogConnectionWatch);
procedure UnregisterLogConnectionWatch(aWatch: TLogConnectionWatch);

(* ONE WATCHDOG PASS, on the main thread, at aNow (GetTickCount64; a test
  passes its own). Returns a line per intervention made. *)
function RunLogWatchdog(aNow: Int64): TLogWatchEvents;

(* Interventions this session, every watch counted. *)
function LogWatchInterventionCount: Int64;

(* THE SHARED LOCK-STATE QUESTION: every registered connection whose
  transaction has been open at least aThresholdMs at aNow, as
  "name (open N ms)" separated by "; ". '' when none. The verification check
  and the startup dialog ask this; the watchdog acts on the same numbers. *)
function LogWatchLongTransactions(aNow: Int64; aThresholdMs: Int64): string;

implementation

uses
   SysUtils,
   (* sqlite3_interrupt: FPC's OWN binding, the one sqlite3conn itself calls
     through, already loaded by the time a connection is open. Not a new DLL
     binding. TSQLite3Connection has no method for it, so this is the one
     raw call, and it is the one SQLite documents as safe from another
     thread (sqlite.org/c3ref/interrupt.html). *)
   sqlite3dyn;

type
   TLogConnectionWatches = array of TLogConnectionWatch;

var
   GLock: TCriticalSection = nil;
   GWatches: TLogConnectionWatches;
   GInterventions: Int64 = 0;

constructor TLogConnectionWatch.Create(const aName: string);
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FName := aName;
end;

destructor TLogConnectionWatch.Destroy;
begin
   UnregisterLogConnectionWatch(Self);
   FLock.Free;
   inherited Destroy;
end;

procedure TLogConnectionWatch.TransactionBegan;
begin
   FLock.Enter;
   try
      FBegan := GetTickCount64;
      (* A tick of 0 would read as "none"; vanishingly rare, but cheap. *)
      if FBegan = 0 then
         begin
         FBegan := 1;
         end;
   finally
      FLock.Leave;
   end;
end;

procedure TLogConnectionWatch.TransactionEnded;
begin
   FLock.Enter;
   try
      FBegan := 0;
      FRollbackRequested := False;
   finally
      FLock.Leave;
   end;
end;

procedure TLogConnectionWatch.Attach(aHandle: Pointer);
begin
   FLock.Enter;
   try
      FHandle := aHandle;
   finally
      FLock.Leave;
   end;
end;

procedure TLogConnectionWatch.Detach;
begin
   FLock.Enter;
   try
      FHandle := nil;
      FBegan := 0;
      FRollbackRequested := False;
   finally
      FLock.Leave;
   end;
end;

function TLogConnectionWatch.TakeRollbackRequest: boolean;
begin
   FLock.Enter;
   try
      Result := FRollbackRequested;
      FRollbackRequested := False;
   finally
      FLock.Leave;
   end;
end;

function TLogConnectionWatch.BeganAt: Int64;
begin
   FLock.Enter;
   try
      Result := FBegan;
   finally
      FLock.Leave;
   end;
end;

function TLogConnectionWatch.OpenForMs(aNow: Int64): Int64;
var
   began: Int64;
begin
   began := BeganAt;
   Result := 0;
   if (began <> 0) and (aNow > began) then
      begin
      Result := aNow - began;
      end;
end;

procedure TLogConnectionWatch.RequestRollback;
begin
   FLock.Enter;
   try
      if FBegan <> 0 then
         begin
         FRollbackRequested := True;
         end;
   finally
      FLock.Leave;
   end;
end;

function TLogConnectionWatch.Interrupt: boolean;
begin
   FLock.Enter;
   try
      Result := FHandle <> nil;
      if Result then
         begin
         sqlite3_interrupt(FHandle);
         end;
   finally
      FLock.Leave;
   end;
end;

procedure EnsureRegistryLock;
begin
   if GLock = nil then
      begin
      GLock := TCriticalSection.Create;
      end;
end;

procedure RegisterLogConnectionWatch(aWatch: TLogConnectionWatch);
var
   n: integer;
begin
   if aWatch = nil then
      begin
      Exit;
      end;
   EnsureRegistryLock;
   GLock.Enter;
   try
      for n := 0 to High(GWatches) do
         begin
         if GWatches[n] = aWatch then
            begin
            Exit;
            end;
         end;
      n := Length(GWatches);
      SetLength(GWatches, n + 1);
      GWatches[n] := aWatch;
   finally
      GLock.Leave;
   end;
end;

procedure UnregisterLogConnectionWatch(aWatch: TLogConnectionWatch);
var
   i, j: integer;
begin
   if GLock = nil then
      begin
      Exit;
      end;
   GLock.Enter;
   try
      for i := 0 to High(GWatches) do
         begin
         if GWatches[i] = aWatch then
            begin
            for j := i to High(GWatches) - 1 do
               begin
               GWatches[j] := GWatches[j + 1];
               end;
            SetLength(GWatches, Length(GWatches) - 1);
            Break;
            end;
         end;
   finally
      GLock.Leave;
   end;
end;

(* A COPY, so an OnGiveUp that unregisters a watch cannot change the list
  being walked. *)
function CopyOfWatches: TLogConnectionWatches;
var
   i: integer;
begin
   Result := nil;
   if GLock = nil then
      begin
      Exit;
      end;
   GLock.Enter;
   try
      SetLength(Result, Length(GWatches));
      for i := 0 to High(GWatches) do
         begin
         Result[i] := GWatches[i];
         end;
   finally
      GLock.Leave;
   end;
end;

procedure AddEvent(var aEvents: TLogWatchEvents; const aText: string);
var
   n: integer;
begin
   n := Length(aEvents);
   SetLength(aEvents, n + 1);
   aEvents[n] := aText;
end;

function RunLogWatchdog(aNow: Int64): TLogWatchEvents;
var
   watches: TLogConnectionWatches;
   w: TLogConnectionWatch;
   i: integer;
   open, began: Int64;
begin
   Result := nil;
   watches := CopyOfWatches;
   for i := 0 to High(watches) do
      begin
      w := watches[i];
      began := w.BeganAt;
      open := w.OpenForMs(aNow);
      if (began = 0) or (open < LOG_WATCH_THRESHOLD_MS) then
         begin
         w.FStage := lwsQuiet;
         w.FStageFor := 0;
         Continue;
         end;
      if w.FStageFor <> began then
         begin
         (* A different transaction from the one the stage was about. *)
         w.FStage := lwsQuiet;
         w.FStageFor := began;
         end;

      case w.FStage of
         lwsQuiet:
            begin
            w.RequestRollback;
            w.FStage := lwsAskedToRollBack;
            Inc(GInterventions);
            AddEvent(Result, Format('%s: a transaction has been open %d ms; ' +
               'asked it to roll back', [w.Name, open]));
            end;
         lwsAskedToRollBack:
            begin
            if open >= LOG_WATCH_THRESHOLD_MS + LOG_WATCH_GRACE_MS then
               begin
               w.Interrupt;
               w.FStage := lwsInterrupted;
               Inc(GInterventions);
               AddEvent(Result, Format('%s: still open after %d ms; ' +
                  'interrupted its statement', [w.Name, open]));
               end;
            end;
         lwsInterrupted:
            begin
            if open >= LOG_WATCH_THRESHOLD_MS + 2 * LOG_WATCH_GRACE_MS then
               begin
               w.FStage := lwsGivenUp;
               Inc(GInterventions);
               AddEvent(Result, Format('%s: still open after %d ms; ' +
                  'stopping its owner', [w.Name, open]));
               if Assigned(w.FOnGiveUp) then
                  begin
                  w.FOnGiveUp(w);
                  end;
               end;
            end;
         lwsGivenUp:
            begin
            (* Reported once; the owner has been told. *)
            end;
      end;
      end;
end;

function LogWatchInterventionCount: Int64;
begin
   Result := GInterventions;
end;

function LogWatchLongTransactions(aNow: Int64; aThresholdMs: Int64): string;
var
   watches: TLogConnectionWatches;
   i: integer;
   open: Int64;
begin
   Result := '';
   watches := CopyOfWatches;
   for i := 0 to High(watches) do
      begin
      open := watches[i].OpenForMs(aNow);
      if (open > 0) and (open >= aThresholdMs) then
         begin
         if Result <> '' then
            begin
            Result := Result + '; ';
            end;
         Result := Result + Format('%s (open %d ms)', [watches[i].Name, open]);
         end;
      end;
end;

finalization
   FreeAndNil(GLock);

end.
