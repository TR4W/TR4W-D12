{
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
}
unit uCrashLog;
{$I tr4w.inc}

{
  WHAT KILLED THE PROGRAM, WRITTEN DOWN.

  TR4W had no unhandled-exception handler of any kind. When it died, tr4w.log
  simply stopped, and the last lines were the ordinary unit finalizations -- which
  run on the way out of a crash exactly as they do on a clean exit. So the log of
  a crash was indistinguishable from the log of someone closing the program, and
  a crash report could say only that it closed. That is what happened on
  2026-08-15: a crash on Ctrl-P with nothing in the log to say where.

  TWO HOOKS, because one is not enough and they cover different ground.

  ExceptProc is the RTL's last resort: it runs for an exception nobody caught,
  just before the program dies. It catches faults raised anywhere, including
  inside TR4W's own Win32 window procedures.

  Application.OnException is the LCL's. It matters here because the LCL CATCHES
  exceptions raised inside its own control and event-handler code and shows its
  own dialog -- so a fault in the Preferences form never reaches ExceptProc at
  all. Without this second hook, exactly the parts of the program being rewritten
  right now would be the parts that crashed without a trace.

  ON THE BACKTRACE. BackTraceStrFunc turns a raw address into the RTL's own
  symbolic form. With line info compiled in (-gl) that is file and line; without
  it, still a module and an offset, which narrows a crash far better than a bare
  pointer. Frames are written one per line so a pasted log stays legible.

  IT DOES NOT SWALLOW ANYTHING. Both hooks log and then hand on to whatever was
  installed before. Continuing after an unhandled exception would mean running
  with a half-updated log or a half-drawn window, which turns a crash the
  operator can report into a corruption they cannot.

  ONLY THE FIRST HOOK IS IN THIS UNIT.  The second one is in
  ui\lcl\uCrashLogLCL, and the split is not tidiness -- it is a build break that
  stood for six days.

  This unit used to reference Forms for those two statements, and TF references
  this unit so a fault on a worker thread would not be silent.  That gave

      tr4wserver.dpr -> tr4wserverUnit -> TF -> uCrashLog -> Forms

  and tr4wserver is a CONSOLE program whose unit search path deliberately
  excludes the LCL.  It stopped linking on 2026-08-23 and nothing noticed for
  three days, because that search path is the only thing guarding the boundary
  and it only fires on a full build.

  The IFDEF FPC that used to guard the LCL half -- spelled without its braces
  here, because a compiler directive written inside a brace comment CLOSES the
  comment -- was on the WRONG AXIS.  It
  asked which COMPILER, when the question is whether this PROGRAM has a widget
  set.  Both programs are FPC; only tr4w.exe has Forms.  A conditional cannot
  answer that question at all -- only the unit graph can, which is why the
  answer is a second unit and not a define.

  The server gains crash logging by the same move, which it has never had.
}

interface

uses
   SysUtils;    // TObject, Exception -- in the INTERFACE because
                // WriteCrashReport is exported; see below

{ Call once at startup, after the logger exists.  Idempotent.

  INSTALLS THE RTL HOOK ONLY.  The LCL half lives in ui\lcl\uCrashLogLCL, and
  a program with an LCL calls THAT, which calls this.  See the unit header. }
procedure InstallCrashLog;

{ The common writer, exported so the LCL hook produces an identical record.

  aSource names which hook caught it -- 'RTL' or 'LCL' -- and is the only
  difference between the two paths.  Everything that reports a crash goes
  through here so the hooks cannot drift into different-looking output. }
procedure WriteCrashReport(const aSource: string; aObj: TObject;
                           aAddr: CodePointer;
                           aFrameCount: Longint; aFrames: PCodePointer);

{ Say in the log whether this run can produce usable backtraces.  Called by
  InstallCrashLog. }
procedure ReportSymbolState;

{ Report an exception that WAS caught, with the same detail an unhandled one
  gets.

  Needed because the two hooks only see what nobody handles. Once the message
  loop began recovering from faults instead of dying, the program stayed up --
  and the backtrace vanished with it, leaving a bare "recovered from
  EAccessViolation" and no idea where. Surviving a fault must not cost the
  ability to find it.

  Call from inside the except block: ExceptAddr and ExceptFrames describe the
  exception being handled and are only valid there. }
procedure LogCaughtException(const aSource: string; aObj: TObject);

{ A LINE FOR THE PATHS THAT RUN BEFORE THE LOGGER EXISTS.

  Three things happen before TLogRollingFileAppender is created -- /FIELDCHECK,
  the single-instance mutex, and the "already running" warning -- and until now
  none of them could say anything at all.  So when NY4I found a TR4W process
  with pslist that had no window, no taskbar button and NO LOG LINES
  (2026-08-23), the absence of evidence was the only evidence: it had to have
  stopped somewhere in those three, and nothing could narrow it further.

  Appends to tr4w-early.log beside the program.  Deliberately NOT the main log:
  the mutex check exists precisely because a second instance must not open the
  shared log file. }
procedure EarlyTrace(const aMessage: string);

{ True on the thread that called InstallCrashLog -- i.e. the main thread. }
function OnMainThread: boolean;

{ SAY THAT SOMETHING RAN ON THE WRONG THREAD, ONCE PER CALLER.

  Round 2 of the wh[] conversion turns the main window's entry-field accessors
  from Win32 handle calls into ordinary LCL property access.  That is only safe
  if nothing reaches them off the main thread -- and "I traced the callers" is
  exactly the claim that was wrong three times on 2026-08-23, each time costing
  a crash with an empty log.

  So the program says so instead.  This LOGS, it does not raise: an exception on
  a worker thread is the failure mode being removed, not a way to report it.

  DEDUPED BY CALLER, because these sit on paths that run at poll rates -- a
  violation would otherwise produce a log flood rather than a diagnosis.  Each
  distinct call site is reported once, with its address resolved symbolically,
  which is the thing actually needed: WHICH caller, not how many times. }
procedure ReportOffMainThread(const aSite: string; const aCaller: CodePointer);

implementation

uses
   // SysUtils is in the INTERFACE uses -- WriteCrashReport's signature needs
   // TObject there. Naming it twice is a duplicate-identifier error, not a
   // no-op.
   Windows,    // GetCurrentThreadId
   Version,    // TR4W_CURRENTVERSION_NUMBER -- a raw address is useless
               // unless the exact binary that produced it can be identified
   Log4D;      // our own logger -- see CrashLogger

   { NO Forms, AND THAT IS THE POINT OF THE UNIT.  Everything here must link
     into a console program.  If something in this file comes to want the LCL,
     it belongs in uCrashLogLCL instead -- see the unit header. }

{ NOT MainUnit's `logger` GLOBAL, AND THAT IS DELIBERATE.

  This unit used it, which made the crash reporter depend on the unit that
  owns the main window and every UI global beneath it.  That is backwards on
  its own terms -- the reporter must work when MainUnit is exactly what has
  gone wrong -- and on 2026-08-23 it also became a build error: guarding the
  worker threads meant TF calling LogCaughtException, and TF -> uCrashLog ->
  MainUnit -> TF is a cycle FPC answers with an internal error, not a
  diagnostic.

  A CHILD OF THE SAME LOGGER, so nothing about the output moves.  Log4D
  propagates to the root appender and children inherit the parent's level, and
  the global is TLogLogger.GetLogger('TR4WDebugLog') (tr4w.lpr:657) -- so
  'TR4WDebugLog.CrashLog' lands in the same tr4w.log at the same level, and
  merely says which subsystem wrote the line.  Obtained lazily because a crash
  can happen before startup has configured anything. }
var
   GCrashLogger: TLogLogger = nil;

function CrashLogger: TLogLogger;
begin
   if GCrashLogger = nil then
      begin
      GCrashLogger := TLogLogger.GetLogger('TR4WDebugLog.CrashLog');
      end;
   Result := GCrashLogger;
end;

var
   GPreviousExceptProc: TExceptProc = nil;
   GInstalled: boolean = False;
   GMainThreadId: DWORD = 0;

{ The common writer.  Everything that reports a crash goes through here so the
  two hooks cannot drift into producing different-looking records. }
{ ' (main)' when this is the main thread, '' otherwise.  Named rather than
  inlined because the test reads badly inside a format call. }
function IfMainThread: string;
begin
   // OUR OWN RECORD OF IT, captured in InstallCrashLog. The RTL's
   // MainThreadID does not resolve in this configuration, and recording it
   // ourselves removes the question -- InstallCrashLog runs on the main
   // thread at startup by construction.
   if GetCurrentThreadId = GMainThreadId then
      begin
      Result := ' (main)';
      end
   else
      begin
      Result := '';
      end;
end;

const
   { WHAT THIS BOUNDS, AND WHY IT IS A CLOCK AND NOT AN ADDRESS RANGE.

     Resolving an address that HAS line info costs about a millisecond. One that
     does not costs about 790, because FPC's DWARF reader scans the debug
     section to exhaustion before giving up and TR4W's .dbg is 59.6 MB. A real
     crash on 2026-08-27 carried ten such frames and spent EIGHT SECONDS writing
     its own backtrace -- measured off the timestamps in the log, which show the
     resolved frames 1 ms apart and the unresolved ones 790 ms apart.

     An address range cannot separate the two. The Lazarus LCL ships compiled
     without line info and is STATICALLY LINKED into the same image
     (0x00400000-0x00AC0000 for this build), so its code sits interleaved above
     TR4W's by link order alone. Every expensive frame in that crash was inside
     the image; only the three ntdll frames were outside it. Hardcoding "TR4W's
     code ends at 0x0058" would encode a link-order accident that the next unit
     added anywhere would invalidate, silently, in the one code path nobody
     exercises until it matters.

     So the budget is on time. Resolve until it is spent, then print raw
     addresses -- which are still usable against the .dbg afterwards. A bounded
     report that arrives beats a perfect one that stalls a dying program. }
   FRAME_RESOLVE_BUDGET_MS = 1500;

procedure WriteCrashReport(const aSource: string; aObj: TObject;
                           aAddr: CodePointer;
                           aFrameCount: Longint; aFrames: PCodePointer);
var
   i: integer;
   cls, msg: string;
   startTick: QWord;
   budgetSpent: boolean;

   { One frame, resolved if the budget allows and raw if it does not. Says so
     once, on the frame that crossed the line, so a reader can tell "no symbols
     for this unit" from "we stopped asking". }
   function Frame(p: CodePointer): string;
   begin
      if budgetSpent then
         begin
         Result := SysUtils.Format('$%.8x', [PtrUInt(p)]);
         Exit;
         end;

      if (GetTickCount64 - startTick) <= FRAME_RESOLVE_BUDGET_MS then
         begin
         Result := BackTraceStrFunc(p);
         Exit;
         end;

      budgetSpent := True;
      Result := SysUtils.Format('$%.8x  -- line-info lookups stopped here after '
                                + '%d ms; the frames below are raw addresses, '
                                + 'resolvable against the .dbg for this build',
                                [PtrUInt(p), Int64(GetTickCount64 - startTick)]);
   end;

begin
   // NEVER let the reporter raise.  It runs while the program is already dying,
   // and a fault in here would replace a diagnosable crash with a silent one --
   // precisely the failure this unit exists to remove.
   try
      startTick   := GetTickCount64;
      budgetSpent := False;

      cls := 'unknown';
      msg := '';
      if aObj <> nil then
         begin
         cls := aObj.ClassName;
         if aObj is Exception then
            begin
            msg := Exception(aObj).Message;
            end;
         end;

      // WHICH THREAD, and which build. TR4W runs a reading thread per radio,
      // a WinKey thread, network threads and CW playback, so "an access
      // violation" means something different depending on where it happened.
      CrashLogger.Fatal('[CRASH] %s: unhandled %s in thread %d%s (TR4W %s) -- %s',
                   [aSource, cls, GetCurrentThreadId, IfMainThread,
                    TR4W_CURRENTVERSION_NUMBER, msg]);
      if aAddr <> nil then
         begin
         CrashLogger.Fatal('[CRASH]   at %s', [Frame(aAddr)]);
         end;
      for i := 0 to aFrameCount - 1 do
         begin
         CrashLogger.Fatal('[CRASH]   %s', [Frame(aFrames[i])]);
         end;
   except
      // Deliberately empty: there is nothing left to report it to.
   end;
end;

procedure CatchUnhandledException(Obj: TObject; Addr: CodePointer;
                                  FrameCount: Longint; Frames: PCodePointer);
begin
   WriteCrashReport('RTL', Obj, Addr, FrameCount, Frames);

   // Hand on, so the RTL still reports and terminates as it always did.
   if Assigned(GPreviousExceptProc) then
      begin
      GPreviousExceptProc(Obj, Addr, FrameCount, Frames);
      end;
end;

procedure EarlyTrace(const aMessage: string);
var
   f: TextFile;
   fn: string;
begin
   // EVERYTHING SWALLOWED.  This is diagnostic scaffolding on a path that has no
   // error reporting of its own; a breadcrumb that can itself fail the startup
   // would be worse than no breadcrumb.
   try
      fn := ExtractFilePath(ParamStr(0)) + 'tr4w-early.log';
      AssignFile(f, fn);
      if FileExists(fn) then
         begin
         Append(f);
         end
      else
         begin
         Rewrite(f);
         end;
      try
         WriteLn(f, Format('%s  pid %d  %s',
                           [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
                            GetCurrentProcessId, aMessage]));
      finally
         CloseFile(f);
      end;
   except
      // nothing -- see above
   end;
end;

procedure LogCaughtException(const aSource: string; aObj: TObject);
begin
   WriteCrashReport(aSource, aObj, ExceptAddr, ExceptFrameCount, ExceptFrames);
end;

function OnMainThread: boolean;
begin
   // GMainThreadId, not the RTL's MainThreadID -- see IfMainThread above for
   // why this unit records it itself.
   Result := GetCurrentThreadId = GMainThreadId;
end;

var
   GOffThreadLock: TRTLCriticalSection;
   { ONE ENTRY PER (CALL SITE, THREAD), NOT PER CALL SITE.

     Keyed on the caller alone, this answered "which call sites write off the
     main thread" -- which is what it was added for -- and could not answer
     "which threads reach this one", because the first thread to arrive claimed
     the site and every other was deduped away in silence.

     That mattered on 2026-08-29: a five-minute DX-cluster soak with many spots
     arriving reported nothing new, but the cluster reader almost certainly
     writes through WriteMainWindowText, whose entry the RADIO POLLING thread
     had already claimed seconds after startup. "No new report" could not be
     read as "the cluster path is clean".

     CAPPED, because the pair is not bounded the way the caller alone is:
     TReadingThread is destroyed and recreated on every reconnect (see the note
     in uStateBridge), so a flapping link mints a fresh thread id each time. The
     cap keeps a bad night from filling the log; the last line says it stopped
     rather than going quiet, because a silent cap is the failure mode this
     whole exercise is about. }
   GOffThreadSeen: array of record
      Caller: PtrUInt;
      Thread: TThreadID;
   end;
   GOffThreadCapped: boolean = False;

const
   OFF_THREAD_REPORT_CAP = 64;

procedure ReportOffMainThread(const aSite: string; const aCaller: CodePointer);
var
   i: integer;
   key: PtrUInt;
   fresh: boolean;
   capped: boolean;
begin
   // Before InstallCrashLog there is no main thread on record, so every thread
   // would look wrong.  Say nothing rather than say something false.
   if GMainThreadId = 0 then
      begin
      Exit;
      end;

   key := PtrUInt(aCaller);
   fresh := True;
   capped := False;

   EnterCriticalSection(GOffThreadLock);
   try
      for i := 0 to High(GOffThreadSeen) do
         begin
         if (GOffThreadSeen[i].Caller = key) and
            (GOffThreadSeen[i].Thread = GetCurrentThreadId) then
            begin
            fresh := False;
            Break;
            end;
         end;

      if fresh and (Length(GOffThreadSeen) >= OFF_THREAD_REPORT_CAP) then
         begin
         fresh := False;
         capped := not GOffThreadCapped;   // say it once, then stop
         GOffThreadCapped := True;
         end
      else if fresh then
         begin
         SetLength(GOffThreadSeen, Length(GOffThreadSeen) + 1);
         GOffThreadSeen[High(GOffThreadSeen)].Caller := key;
         GOffThreadSeen[High(GOffThreadSeen)].Thread := GetCurrentThreadId;
         end;
   finally
      LeaveCriticalSection(GOffThreadLock);
   end;

   if capped then
      begin
      CrashLogger.Warn('[Thread] %d distinct (call site, thread) pairs reported '
                       + '-- no more will be logged this session.  A flapping '
                       + 'link recreates its reading thread, so this is usually '
                       + 'reconnects rather than new call sites.',
                       [OFF_THREAD_REPORT_CAP]);
      end;

   if not fresh then
      begin
      Exit;
      end;

   // WARN, not Debug: this is a latent crash, and nobody runs at debug level
   // when it happens.
   CrashLogger.Warn('[Thread] %s called from thread %d, NOT the main thread -- '
                    + 'caller %s', [aSite, GetCurrentThreadId,
                                    BackTraceStrFunc(aCaller)]);
end;


{ WHETHER THE .dbg BESIDE US IS THE RIGHT ONE.

  The scenario this exists for (NY4I): an operator hits a fault nobody can
  reproduce, is sent the matching tr4w.dbg, drops it beside tr4w.exe and sends a
  new log. If they still have an OLD one from a previous version, we need to know
  before reading a single address.

  MEASURED, NOT ASSUMED. A deliberate build-mismatch test showed FPC validates
  the link: a .dbg from a different build is REJECTED, not used, so it cannot
  produce plausible-but-wrong file and line -- which was the real fear. It
  degrades to bare addresses exactly as a missing file does.

  So the probe is: raise and catch an exception on a known line, resolve its
  address, and see whether a line comes back. If one does, the symbols are
  present AND belong to this binary. If not, the file is either absent or
  rejected -- and those two want different advice, so the message says which. }
function ProbeSymbolLine(out aResolved: string): integer;
var
   n, p: integer;
begin
   Result := 0;
   aResolved := '';
   try
      try
         raise Exception.Create('symbol probe');
      except
         aResolved := BackTraceStrFunc(ExceptAddr);
      end;
   except
      // The probe must never be the thing that breaks startup.
      Exit;
   end;

   p := Pos('line ', aResolved);
   if p = 0 then
      begin
      Exit;
      end;
   n := p + 5;
   while (n <= Length(aResolved)) and (aResolved[n] >= '0')
         and (aResolved[n] <= '9') do
      begin
      Result := Result * 10 + Ord(aResolved[n]) - Ord('0');
      Inc(n);
      end;
end;

procedure ReportSymbolState;
var
   resolved, dbg: string;
   line: integer;
begin
   // The build itself, so an archived .dbg can be matched to this log.
   CrashLogger.Info('[CRASH] TR4W %s built %s %s',
               [TR4W_CURRENTVERSION_NUMBER, {$I %DATE%}, {$I %TIME%}]);

   line := ProbeSymbolLine(resolved);
   dbg  := ChangeFileExt(ParamStr(0), '.dbg');

   if line > 0 then
      begin
      CrashLogger.Info('[CRASH] symbols OK -- backtraces will name file and line '
                  + '(probe resolved to %s)', [Trim(resolved)]);
      end
   else if FileExists(dbg) then
      begin
      // The dangerous-looking case, and the reason for the whole check.
      CrashLogger.Warn('[CRASH] %s EXISTS BUT WAS REJECTED -- it does not belong to '
                  + 'this build. Backtraces will show raw addresses only. '
                  + 'Replace it with the .dbg archived for TR4W %s.',
                  [dbg, TR4W_CURRENTVERSION_NUMBER]);
      end
   else
      begin
      CrashLogger.Info('[CRASH] no %s -- backtraces will show raw addresses. That is '
                  + 'normal; the addresses can still be resolved from the .dbg '
                  + 'archived for TR4W %s.',
                  [ExtractFileName(dbg), TR4W_CURRENTVERSION_NUMBER]);
      end;
end;

procedure InstallCrashLog;
begin
   if GInstalled then
      begin
      Exit;
      end;
   GInstalled := True;
   GMainThreadId := GetCurrentThreadId;

   GPreviousExceptProc := ExceptProc;
   ExceptProc := @CatchUnhandledException;

   // 'RTL' not 'RTL + LCL': a program that has an LCL says so itself, from
   // uCrashLogLCL, on the line after this one. The old message claimed both
   // hooks unconditionally, which in a console program would have been a
   // written record of a handler that was never installed.
   CrashLogger.Info('[CRASH] unhandled-exception logging installed (RTL)');
   ReportSymbolState;
end;

initialization
   InitCriticalSection(GOffThreadLock);

finalization
   DoneCriticalSection(GOffThreadLock);

end.
