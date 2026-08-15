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

implementation

uses
   SysUtils,
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

{ The common writer.  Everything that reports a crash goes through here so the
  two hooks cannot drift into producing different-looking records. }
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

      logger.Fatal('[CRASH] %s: unhandled %s -- %s', [aSource, cls, msg]);
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

procedure InstallCrashLog;
begin
   if GInstalled then
      begin
      Exit;
      end;
   GInstalled := True;

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
      end;
end;

initialization

finalization
   FreeAndNil(GReporter);

end.
