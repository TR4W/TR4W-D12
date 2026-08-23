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
}

interface

{ Call once at startup, after the logger exists.  Idempotent. }
procedure InstallCrashLog;

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

implementation

uses
   SysUtils,
   Windows,    // GetCurrentThreadId
   Version,    // TR4W_CURRENTVERSION_NUMBER -- a raw address is useless
               // unless the exact binary that produced it can be identified
{$IFDEF FPC}
   Forms,      // Application.OnException -- the LCL's own handler
{$ENDIF}
   MainUnit;   // logger

type
   TCrashReporter = class(TObject)
   public
      procedure HandleLCLException(Sender: TObject; E: Exception);
   end;

var
   GPreviousExceptProc: TExceptProc = nil;
   GReporter: TCrashReporter = nil;
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

procedure WriteCrashReport(const aSource: string; aObj: TObject;
                           aAddr: CodePointer;
                           aFrameCount: Longint; aFrames: PCodePointer);
var
   i: integer;
   cls, msg: string;
begin
   // NEVER let the reporter raise.  It runs while the program is already dying,
   // and a fault in here would replace a diagnosable crash with a silent one --
   // precisely the failure this unit exists to remove.
   try
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

      if logger = nil then
         begin
         Exit;
         end;

      // WHICH THREAD, and which build. TR4W runs a reading thread per radio,
      // a WinKey thread, network threads and CW playback, so "an access
      // violation" means something different depending on where it happened.
      logger.Fatal('[CRASH] %s: unhandled %s in thread %d%s (TR4W %s) -- %s',
                   [aSource, cls, GetCurrentThreadId, IfMainThread,
                    TR4W_CURRENTVERSION_NUMBER, msg]);
      if aAddr <> nil then
         begin
         logger.Fatal('[CRASH]   at %s', [BackTraceStrFunc(aAddr)]);
         end;
      for i := 0 to aFrameCount - 1 do
         begin
         logger.Fatal('[CRASH]   %s', [BackTraceStrFunc(aFrames[i])]);
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

procedure TCrashReporter.HandleLCLException(Sender: TObject; E: Exception);
begin
   // ExceptAddr/ExceptFrames rather than the exception object alone: the LCL
   // hands over only E, and an exception without a location is barely more
   // useful than "it crashed".
   WriteCrashReport('LCL', E, ExceptAddr, ExceptFrameCount, ExceptFrames);

{$IFDEF FPC}
   // Then the LCL's own dialog, unchanged.  Suppressing it would hide from the
   // operator a fault we have only written to a file they have not been asked
   // to look at.
   Application.ShowException(E);
{$ENDIF}
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
   if logger = nil then
      begin
      Exit;
      end;

   // The build itself, so an archived .dbg can be matched to this log.
   logger.Info('[CRASH] TR4W %s built %s %s',
               [TR4W_CURRENTVERSION_NUMBER, {$I %DATE%}, {$I %TIME%}]);

   line := ProbeSymbolLine(resolved);
   dbg  := ChangeFileExt(ParamStr(0), '.dbg');

   if line > 0 then
      begin
      logger.Info('[CRASH] symbols OK -- backtraces will name file and line '
                  + '(probe resolved to %s)', [Trim(resolved)]);
      end
   else if FileExists(dbg) then
      begin
      // The dangerous-looking case, and the reason for the whole check.
      logger.Warn('[CRASH] %s EXISTS BUT WAS REJECTED -- it does not belong to '
                  + 'this build. Backtraces will show raw addresses only. '
                  + 'Replace it with the .dbg archived for TR4W %s.',
                  [dbg, TR4W_CURRENTVERSION_NUMBER]);
      end
   else
      begin
      logger.Info('[CRASH] no %s -- backtraces will show raw addresses. That is '
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

{$IFDEF FPC}
   GReporter := TCrashReporter.Create;
   // NO @ on the method reference: tr4w.inc compiles every unit in
   // {$MODE Delphi}, where a method is assigned directly. The ObjFPC spelling
   // with @, which the FreePascal wiki example uses, does not compile here.
   Application.OnException := GReporter.HandleLCLException;
{$ENDIF}

   if logger <> nil then
      begin
      logger.Info('[CRASH] unhandled-exception logging installed (RTL + LCL)');
      ReportSymbolState;
      end;
end;

initialization

finalization
   FreeAndNil(GReporter);

end.
