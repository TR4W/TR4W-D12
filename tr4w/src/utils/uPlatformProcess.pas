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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uPlatformProcess;
{$I ..\tr4w.inc}

{
  STARTING ANOTHER PROGRAM -- the one place in TR4W that does it.

  Phase 8 of the Win32-to-LCL migration: `WinExec` and `ShellExecute` are Win32
  and have no GTK or Cocoa equivalent, so every launch in the program came
  through here rather than being translated seventeen times in place.

  TWO ROUTINES, BECAUSE THERE ARE TWO DIFFERENT SITUATIONS, and conflating them
  is how a platform guard ends up in the wrong place:

  RunProgram      -- an executable the OPERATOR chose or that we ship: their MP3
                     player, their DVK recorder, their text editor, tr4wserver.
                     Meaningful on every platform, so it uses TProcess and no
                     guard. Arguments are passed as a LIST, never pasted into a
                     command line: a path with a space in it is the normal case
                     on Windows, and quoting it by hand is how that breaks.

  RunWindowsUtility -- a WINDOWS PROGRAM, named as such: calc.exe, SNDVOL32,
                     cmd.exe, rundll32, explorer, w32tm, MMTTY. These do not
                     exist elsewhere and translating them would be pretending
                     otherwise. This is the ONLY WinExec left in TR4W, and it
                     is the only thing here inside a WINDOWS conditional. On another
                     platform it reports and returns False rather than failing
                     silently -- a menu item that quietly does nothing is worse
                     than one that says it is not available here.

  What SHOULD happen to the RunWindowsUtility callers eventually is that the
  MENU ITEMS stop existing off Windows, which is menu work and belongs with the
  phase that owns menus. Until then the guard is here, in one file, rather than
  scattered through MainUnit as seventeen conditionals.

  BOTH REPORT FAILURE. The Win32 originals returned a value that was almost
  never checked -- WinExec's "less than 32 means it failed" was tested at
  exactly two of the seventeen call sites -- so a mistyped path in the operator's
  MP3 player setting did nothing at all, with no log line to explain it.
}

interface

type
   // How the launched window should appear. Named for the INTENTION rather than
   // in Win32 terms: SW_SHOWNORMAL / SW_SHOWMINIMIZED do not exist off Windows,
   // and a parameter that names them would put Win32 back into every caller.
   TLaunchWindow = (lwNormal, lwMinimised);

// Run an executable with arguments. Cross-platform; no shell, no quoting.
// False if it could not be started, and the reason is logged.
function RunProgram(const aExecutable: string;
                    const aArgs: array of string): boolean;

// Run a Windows-only utility, given as a full command line. Windows only, by
// intent -- see the unit header. False (with a log line) anywhere else.
function RunWindowsUtility(const aCommandLine: string;
                           const aWindow: TLaunchWindow = lwNormal): boolean;

implementation

uses
   SysUtils,
   Process,
   Log4D
{$IFDEF WINDOWS}
   , Windows
{$ENDIF}
   ,
  uAnsiStr;

var
   logger: TLogLogger = nil;

function Log: TLogLogger;
begin
   if logger = nil then
      begin
      logger := TLogLogger.GetLogger('TR4WDebugLog.Process');
      end;
   Result := logger;
end;

function RunProgram(const aExecutable: string;
                    const aArgs: array of string): boolean;
var
   p: TProcess;
   i: integer;
begin
   Result := False;

   if Trim(aExecutable) = '' then
      begin
      Log.Warn('[RunProgram] refused: no executable given');
      Exit;
      end;

   p := TProcess.Create(nil);
   try
      try
         p.Executable := aExecutable;
         for i := Low(aArgs) to High(aArgs) do
            begin
            p.Parameters.Add(aArgs[i]);
            end;

         // NOT poWaitOnExit. Every caller here is "open this thing for the
         // operator" -- waiting would freeze the contest log until they closed
         // their text editor.
         p.Options    := [];
         p.ShowWindow := swoShowNormal;
         p.Execute;
         Result := True;
      except
         // A missing or mistyped executable raises here rather than returning a
         // code. Reported, because the Win32 original's failure was invisible.
         on E: Exception do
            begin
            Log.Error(Format('[RunProgram] %s failed: %s: %s',
                             [aExecutable, E.ClassName, E.Message]));
         end;
      end;
   finally
      p.Free;
   end;
end;

function RunWindowsUtility(const aCommandLine: string;
                           const aWindow: TLaunchWindow = lwNormal): boolean;
{$IFDEF WINDOWS}
var
   show: integer;
   rc: UINT;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   if aWindow = lwMinimised then
      begin
      show := SW_SHOWMINIMIZED;
      end
   else
      begin
      show := SW_SHOWNORMAL;
      end;

   // THE LAST WinExec IN TR4W. PAnsiChar(WinAnsi(...)) is a genuine boundary
   // conversion -- WinExec takes LPCSTR -- and is the kind CLAUDE.md allows.
   rc := Windows.WinExec(PAnsiChar(WinAnsi(aCommandLine)), show);

   // "Less than 32" is WinExec's own error convention, and it was checked at
   // two of the seventeen sites this replaced.
   Result := rc >= 32;
   if not Result then
      begin
      Log.Error(Format('[RunWindowsUtility] "%s" failed, WinExec returned %d',
                       [aCommandLine, rc]));
      end;
{$ELSE}
   // REPORTED, NOT SILENT. These are Windows programs; the honest answer on
   // another platform is to say so.
   Result := False;
   Log.Warn(Format('[RunWindowsUtility] "%s" is a Windows-only utility and was not started',
                   [aCommandLine]));
{$ENDIF}
end;

end.
