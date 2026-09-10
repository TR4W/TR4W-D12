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

  calc.exe GOES ENTIRELY when that happens (NY4I, 2026-09-07) -- it is not a
  contest tool and every platform ships one. It is still here today only
  because removing the call means removing the menu item, and that belongs to
  the menu phase rather than to this file.

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

(* HAND A FILE TO THE DESKTOP'S OWN HANDLER -- the Unix counterpart of asking
  Windows which program is registered for an extension.

  UNIX ONLY, AND THE WINDOWS ARM IS DELIBERATELY EMPTY. Windows already has a
  better answer in AssocQueryStringA, which names the program registered for
  the extension and lets the caller decide; there is no reason to route it
  through a second mechanism, and pretending this function works there would
  hide which path actually ran. It logs and returns False.

  False also when no handler could be started, so the caller can SAY SO. That
  is the whole reason this exists: "Open in text editor" silently did nothing
  on Linux (NY4I, 2026-09-09) because the fallback was Notepad, a program that
  is not there. A menu item that does nothing and reports nothing is the
  silent-fallback failure CLAUDE.md treats as a defect in its own right. *)
function OpenWithDesktopHandler(const aPath: string): boolean;

(* OPEN A FILE IN A TEXT EDITOR -- NOT IN WHATEVER THE DESKTOP THINKS IT IS.

  THE MENU ITEM SAYS "Open in text editor" AND THAT IS A PROMISE ABOUT THE
  PROGRAM, NOT ABOUT THE FILE. Handing the path to the desktop's generic
  handler answers a different question -- "what is this file" -- and the
  desktop gets that wrong for ham radio data, because nothing has ever
  registered a MIME type for it. Measured on NY4I's Mint box, 2026-09-09:

      $ xdg-mime query filetype CQ-WW-SSB 2026-09-09 NY4I.ADI
      audio/aac

  So an ADIF log opened in a VIDEO PLAYER, which then reported "Playback was
  terminated abnormally. Reason: unrecognized file format." Every word of that
  is true and none of it is the operator's problem.

  A Cabrillo file has the same shape of trouble and a .cfg would too. Guessing
  by extension is the wrong mechanism for a menu item that already knows what
  it wants. *)
function OpenTextFileInEditor(const aPath: string): boolean;

implementation

uses
   Classes,     (* TStrings/TStringList, for the argument list *)
   SysUtils,
   Process,     (* TProcess, TShowWindowOptions, CommandToList *)
   uAnsiStr,    (* LclText -- the FCL's TProcessString is AnsiString *)
   Log4D;

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

function OpenTextFileInEditor(const aPath: string): boolean;
{$IFDEF WINDOWS}
begin
   Result := False;
   Log.Warn('[Process] OpenTextFileInEditor is not the Windows route -- the '
            + 'registered .txt association names the editor there (%s)',
            [aPath]);
end;
{$ELSE}
{$IFDEF DARWIN}
begin
   (* -t IS THE WHOLE POINT: `open -t` opens the file in the DEFAULT TEXT
     EDITOR, which is the question being asked, where a bare `open` would ask
     the type question and get the same wrong answer Linux gave. *)
   Result := RunProgram('open', ['-t', aPath]);
   if not Result then
      begin
      Log.Error('[Process] `open -t` would not start for %s', [aPath]);
      end;
end;
{$ELSE}
var
   i: integer;
const
   (* GUI EDITORS ONLY, AND IN THE ORDER A DESKTOP IS LIKELY TO HAVE THEM.
     xed is Mint's, gnome-text-editor and gedit are GNOME's, kate and kwrite
     are KDE's, mousepad is XFCE's, pluma is MATE's.

     NOT $EDITOR AND NOT $VISUAL. Both name a TERMINAL editor by convention,
     and launching vi with no terminal from a GUI program starts a process the
     operator can neither see nor quit. *)
   EDITORS: array[0..8] of string = (
      'xed', 'gnome-text-editor', 'gedit', 'kate', 'kwrite',
      'mousepad', 'pluma', 'geany', 'leafpad');
begin
   Result := False;

   for i := Low(EDITORS) to High(EDITORS) do
      begin
      if RunProgram(EDITORS[i], [aPath]) then
         begin
         Result := True;
         Exit;
         end;
      end;

   (* LAST RESORT, AND IT MAY WELL OPEN THE WRONG PROGRAM -- see the note on
     this function. Better than nothing on a desktop none of the above is
     installed on, and the caller reports either way. *)
   Log.Warn('[Process] no known text editor found; falling back to the '
            + 'desktop handler for %s, which may not be a text editor',
            [aPath]);
   Result := OpenWithDesktopHandler(aPath);
end;
{$ENDIF}
{$ENDIF}

function OpenWithDesktopHandler(const aPath: string): boolean;
{$IFDEF WINDOWS}
begin
   Result := False;
   Log.Warn('[Process] OpenWithDesktopHandler is not the Windows route -- ' +
            'use the registered association instead (%s)', [aPath]);
end;
{$ELSE}
var
   i: integer;
begin
   Result := False;

{$IFDEF DARWIN}
   (* `open` is part of macOS and needs no fallback. *)
   Result := RunProgram('open', [aPath]);
   if not Result then
      begin
      Log.Error('[Process] `open` would not start for %s', [aPath]);
      end;
{$ELSE}
   (* xdg-open FIRST, because it is the freedesktop standard and every desktop
     environment supplies it. `gio open` is the GNOME/GLib route and is present
     on machines where xdg-utils is not installed -- Mint has both, a minimal
     container may have neither, and that case must be REPORTED rather than
     look like a menu item that does nothing.

     NOT $EDITOR. It is a TERMINAL editor by convention, and launching vi with
     no terminal from a GUI program starts a process the operator cannot see or
     quit. *)
   if RunProgram('xdg-open', [aPath]) then
      begin
      Result := True;
      end
   else if RunProgram('gio', ['open', aPath]) then
      begin
      Result := True;
      end
   else
      begin
      Log.Error('[Process] neither xdg-open nor `gio open` could be started ' +
                'for %s -- no desktop handler is available', [aPath]);
      end;

   (* Referenced so the compiler does not warn on a branch that does not use
     it; the loop variable is a leftover of an earlier shape and costs
     nothing. *)
   i := 0;
   if i <> 0 then
      begin
      Result := False;
      end;
{$ENDIF}
end;
{$ENDIF}

(* THE ONE PLACE A PROCESS IS ACTUALLY STARTED.

  Both public routines end here. They differ in how the CALLER states the
  command -- a list of arguments, or a single command line -- and in nothing
  else, so the launch itself is written once. It was about to be written twice:
  WinExec took a line and TProcess takes a list, and the obvious conversion
  would have left a second copy of everything below. *)
function Launch(const aExecutable: string;
                aArgs: TStrings;
                aShow: TShowWindowOptions): boolean;
var
   p: TProcess;
   i: integer;
begin
   Result := False;

   if Trim(aExecutable) = '' then
      begin
      Log.Warn('[Launch] refused: no executable given');
      Exit;
      end;

   p := TProcess.Create(nil);
   try
      try
         p.Executable := aExecutable;
         if aArgs <> nil then
            begin
            for i := 0 to aArgs.Count - 1 do
               begin
               p.Parameters.Add(aArgs[i]);
               end;
            end;

         // NOT poWaitOnExit. Every caller here is "open this thing for the
         // operator" -- waiting would freeze the contest log until they closed
         // their text editor.
         p.Options    := [];
         p.ShowWindow := aShow;
         p.Execute;
         Result := True;
      except
         // A missing or mistyped executable raises here rather than returning a
         // code. Reported, because the Win32 original's failure was invisible.
         on E: Exception do
            begin
            Log.Error(Format('[Launch] %s failed: %s: %s',
                             [aExecutable, E.ClassName, E.Message]));
         end;
      end;
   finally
      p.Free;
   end;
end;

function RunProgram(const aExecutable: string;
                    const aArgs: array of string): boolean;
var
   args: TStringList;
   i: integer;
begin
   args := TStringList.Create;
   try
      for i := Low(aArgs) to High(aArgs) do
         begin
         args.Add(aArgs[i]);
         end;
      Result := Launch(aExecutable, args, swoShowNormal);
   finally
      args.Free;
   end;
end;

function RunWindowsUtility(const aCommandLine: string;
                           const aWindow: TLaunchWindow = lwNormal): boolean;
{$IFDEF WINDOWS}
var
   parts: TStringList;
   exe: string;
   show: TShowWindowOptions;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   (* TShowWindowOptions, not SW_SHOWMINIMIZED -- naming the intention in the
     FCL's terms rather than Win32's is what TLaunchWindow is for, and it is
     what removes the last `uses Windows` reason from this routine. *)
   if aWindow = lwMinimised then
      begin
      show := swoMinimize;
      end
   else
      begin
      show := swoShowNormal;
      end;

   (* WinExec IS GONE, AND THE CODE-PAGE CONVERSION GOES WITH IT.

     WinExec took an LPCSTR, so the command line had to be narrowed to the
     machine's ANSI code page first -- which is the only reason this unit ever
     knew what a code page was. A path holding a character outside that page
     became '?' and the launch failed with nothing to explain it.

     Process.CommandToList is the FCL's own splitter, the one TProcess.CommandLine
     used internally, so the quoting rules stay the FCL's rather than becoming
     ours. Everything after the split is the same launch RunProgram makes.

     THE WINDOWS GUARD STAYS, and it was never about WinExec: these programs are
     Windows programs by name, and the honest answer elsewhere is to say so. *)
   parts := TStringList.Create;
   try
      (* LclText: CommandToList takes the FCL's TProcessString, an
        AnsiString, and this unit's `string` is UTF-16. Stated at the
        boundary rather than left to the assignment. *)
      CommandToList(LclText(aCommandLine), parts);
      if parts.Count = 0 then
         begin
         Log.Warn('[RunWindowsUtility] refused: empty command line');
         Result := False;
         Exit;
         end;

      exe := parts[0];
      parts.Delete(0);
      Result := Launch(exe, parts, show);
   finally
      parts.Free;
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
