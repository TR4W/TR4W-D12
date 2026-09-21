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

  AND THIS UNIT NOW IMPORTS Windows AND shlwapi, behind one IFDEF WINDOWS --
  which is a change of position, stated rather than slipped in. RunWindowsUtility
  below still says it removed "the last `uses Windows` reason from this ROUTINE",
  and that remains true of the routine. The UNIT is a different matter: asking
  which program is registered for .txt has no FPC/LCL class behind it, so the
  platform call is the answer, and the whole point of this unit is that the gate
  lives HERE and nowhere else.

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

(* RUN A CONSOLE PROGRAM IN ITS OWN WINDOW AND WAIT FOR IT.

  The third situation, and it is genuinely different from the two above rather
  than a flag on one of them: the child is INTERACTIVE and it is an ordered
  step in what the caller is doing.

  poNewConsole, because TR4W is a GUI program and has no console of its own to
  lend. Without it the child gets no terminal at all -- and tr4wconvert, the
  one caller, deliberately refuses to ask a question it cannot ask and writes
  NOTHING in that case. A hidden or piped launch would therefore look like it
  worked and change nothing.

  poWaitOnExit, because the caller is about to read the file the child writes.
  This is the one place where freezing TR4W is correct: it happens once, at
  startup, before any window exists, and the alternative is a race against the
  operator's own answer.

  The exit STATUS is returned but is not the evidence a caller should reason
  from -- tr4wconvert exits 0 whether it converted or the operator declined,
  which is right for a shell and useless as a test of what happened. Look at
  the file.

  OFF WINDOWS poNewConsole DOES NOTHING; the child inherits whatever stdio
  this process has, which from a desktop launcher is none. That is stated,
  not worked around: the caller checks the RESULT on disk and reports
  honestly when nothing was converted, which covers this case and "the
  operator said no" with the same sentence. *)
function RunConsoleProgramAndWait(const aExecutable: string;
                                  const aArgs: array of string;
                                  out aExitStatus: integer): boolean;

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

(* SHOW A PATH IN THE DESKTOP'S OWN FILE MANAGER -- Explorer, Finder, or
  whatever the Linux desktop supplies.

  THIS IS WHERE "Open log directory" WENT WRONG ON A MAC. NY4I, testing
  5.0.15: "on the mac version, open log directory does not work". The old
  route built the command line `explorer <path>` and handed it to
  RunWindowsUtility -- which is Windows-only BY INTENT and declines elsewhere
  with a log line. So the menu item did nothing at all, said nothing at all,
  and was indistinguishable from a broken menu. Exactly the silent-fallback
  failure CLAUDE.md treats as a defect in its own right, and the same one that
  "Open in text editor" had on Linux.

  A DIRECTORY IS OPENED WITH LCLIntf.OpenDocument, the LCL's own launcher:
  ShellExecute on Windows, `open` on macOS, xdg-open / kfmclient / gnome-open
  on Unix. There is no reason to write any of those three by hand, and the
  house rule is to reach for the LCL facility first.

  A FILE IS SELECTED IN ITS FOLDER WHERE THE PLATFORM HAS A VERB FOR IT, and
  that has no LCL facility -- `explorer /select,` and `open -R` are the two
  platform calls in this routine. They are HERE rather than at a call site
  because this unit is where TR4W's OS gates live (NY4I, 2026-09-16:
  "Minimizing OS gates in the main code makes this more modular"). Linux has
  no freedesktop verb for "select this file", so there the containing folder
  is opened and the operator finds the file in it.

  False, with the reason logged, when the path does not exist or nothing could
  be started -- so the CALLER CAN SAY SO. That is the whole point of the
  change. *)
function RevealInFileManager(const aPath: string): boolean;

implementation

uses
   Classes,     (* TStrings/TStringList, for the argument list *)
   SysUtils,
{$IFDEF WINDOWS}
   (* THE OS GATE LIVES HERE, WHICH IS THE POINT OF THIS UNIT (NY4I,
     2026-09-16): "Minimizing OS gates in the main code makes this more
     modular."

     shlwapi IS FPC'S OWN, not a binding of ours -- winunits-base ships it for
     i386-win32 and x86_64-win64, declaring AssocQueryStringA, ASSOCF_NONE and
     ASSOCSTR_EXECUTABLE. MainUnit used to hand-declare the same entry point
     with `external 'shlwapi.dll'` and two local constants; all three are gone.
     Windows comes with it for DWORD and S_OK. *)
   Windows,
   shlwapi,
{$ENDIF}
   Process,     (* TProcess, TShowWindowOptions, CommandToList *)
   LCLIntf,     (* OpenDocument -- the LCL's own cross-platform launcher *)
   utils_text,    (* LclText, CharBufferText *)
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
var
   editor: array[0..1023] of AnsiChar;
   len:    DWORD;
begin
   (* WHICH PROGRAM IS REGISTERED FOR .txt -- the Windows answer to the same
     question `open -t` answers on macOS and a list of GUI editors answers on
     Linux. Was in MainUnit behind its own gate and its own shlwapi import;
     both are deleted, and the call is FPC's. *)
   Result := False;
   len := SizeOf(editor);
   editor[0] := #0;

   if AssocQueryStringA(ASSOCF_NONE, ASSOCSTR_EXECUTABLE, '.txt', nil,
                        editor, @len) = S_OK then
      begin
      if editor[0] <> #0 then
         begin
         (* NO QUOTING. RunProgram passes arguments as a LIST, so a path with a
           space in it needs no quotes -- hand-quoting was the bug this was
           written to avoid. *)
         Result := RunProgram(CharBufferText(editor), [aPath]);
         end;
      end;

   if not Result then
      begin
      (* NOTEPAD, AND ONLY HERE. Windows-only by name, which is why it is
        inside this arm rather than at a call site: a caller that had to know
        about Notepad would be a caller that had to know which platform it is
        on. *)
      Log.Warn('[Process] no .txt association could be started for %s -- '
               + 'falling back to Notepad', [aPath]);
      Result := RunWindowsUtility(SysUtils.Format('Notepad %s', [aPath]));
      end;
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

(* THE FOLDER HALF, WRITTEN ONCE. It is the answer when the caller named a
  directory, and it is also the fallback when a FILE could not be selected in
  its folder -- two paths through RevealInFileManager, one body. *)
function OpenFolderOrLog(const aFolder: string): boolean;
begin
   (* LclText AT THE BOUNDARY. The LCL compiles with AnsiString parameters and
     sets DefaultSystemCodePage to 65001, so our UTF-16 becomes UTF-8 here.
     Saying so explicitly is what CLAUDE.md asks for and what keeps the
     narrowing ceiling meaningful -- the same reason CommandToList is called
     this way below. *)
   Result := OpenDocument(LclText(aFolder));
   if not Result then
      begin
      Log.Error(Format('[Process] no file manager could be started for %s',
                       [aFolder]));
      end;
end;

function RevealInFileManager(const aPath: string): boolean;
var
   folder: string;
begin
   Result := False;

   if Trim(aPath) = '' then
      begin
      Log.Warn('[Process] RevealInFileManager refused: empty path');
      Exit;
      end;

   (* ASK THE FILE SYSTEM, NOT THE SPELLING. This used to decide between
     "open the folder" and "select the file" by looking for a '.' in the
     string -- so a contest directory named CQWW.2026\ was treated as a file,
     and an extensionless file as a folder. *)
   if DirectoryExists(aPath) then
      begin
      Result := OpenFolderOrLog(aPath);
      Exit;
      end;

   if not FileExists(aPath) then
      begin
      Log.Error(Format('[Process] %s does not exist -- nothing to show',
                       [aPath]));
      Exit;
      end;

{$IFDEF WINDOWS}
   (* THE PLATFORM CALL, KEEPING THE SPELLING THAT SHIPPED. `explorer
     /select,` is the Windows verb for "show this file in its folder,
     selected"; there is no LCL facility for it, which is why this one is not
     OpenDocument. Unquoted, as before -- quoting the whole token is what
     Explorer refuses, and changing it here would be changing the one platform
     that works today. *)
   Result := RunWindowsUtility(Format('explorer /select, %s', [aPath]));
{$ENDIF}
{$IFDEF DARWIN}
   (* -R is Finder's "reveal": open the enclosing folder with the file
     selected. Part of macOS, like `open` itself. *)
   Result := RunProgram('open', ['-R', aPath]);
{$ENDIF}

   if Result then
      begin
      Exit;
      end;

   (* NO "SELECT THIS FILE" VERB HERE, or the one there is would not start.
     The containing folder is the honest answer: the operator asked to see
     where the file lives, and they can see it. *)
   folder := ExtractFileDir(aPath);
   Result := OpenFolderOrLog(folder);
end;

(* THE ONE PLACE A PROCESS IS ACTUALLY STARTED.

  Both public routines end here. They differ in how the CALLER states the
  command -- a list of arguments, or a single command line -- and in nothing
  else, so the launch itself is written once. It was about to be written twice:
  WinExec took a line and TProcess takes a list, and the obvious conversion
  would have left a second copy of everything below. *)
function Launch(const aExecutable: string;
                aArgs: TStrings;
                aShow: TShowWindowOptions;
                aOptions: TProcessOptions;
                out aExitStatus: integer): boolean;
var
   p: TProcess;
   i: integer;
begin
   Result := False;
   (* -1 MEANS "NOBODY WAITED", and it is the answer on every path but one.
     A launch that did not wait has no exit status to report, and a launch
     that failed never produced one; returning 0 there would read as "the
     program ran and succeeded". *)
   aExitStatus := -1;

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

         (* THE OPTIONS COME FROM THE CALLER, AND THE DEFAULT IS STILL NONE.

           RunProgram and RunWindowsUtility pass [] for the reason that was
           written here: every one of their callers is "open this thing for
           the operator", and waiting would freeze the contest log until they
           closed their text editor.

           RunConsoleProgramAndWait passes the opposite, because it exists for
           the one case where waiting is the whole point -- see its note. *)
         p.Options    := aOptions;
         p.ShowWindow := aShow;
         p.Execute;
         if poWaitOnExit in aOptions then
            begin
            aExitStatus := p.ExitStatus;
            end;
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

(* An open array of arguments as the TStrings Launch wants, written once.

  IT IS ONE ROUTINE ON PURPOSE. The second caller copied this loop and the
  copy was visible in the build: TStringList holds AnsiString here, so each
  copy of `args.Add(aArgs[i])` is its own narrowing warning against the
  build's ceiling. Two copies, two warnings, and the ceiling counts them --
  which is a small, honest signal of exactly what CLAUDE.md says about copies
  drifting. *)
function ArgsToList(const aArgs: array of string): TStringList;
var
   i: integer;
begin
   Result := TStringList.Create;
   for i := Low(aArgs) to High(aArgs) do
      begin
      Result.Add(aArgs[i]);
      end;
end;

function RunProgram(const aExecutable: string;
                    const aArgs: array of string): boolean;
var
   args: TStringList;
   ignoredStatus: integer;
begin
   args := ArgsToList(aArgs);
   try
      Result := Launch(aExecutable, args, swoShowNormal, [], ignoredStatus);
   finally
      args.Free;
   end;
end;

function RunConsoleProgramAndWait(const aExecutable: string;
                                  const aArgs: array of string;
                                  out aExitStatus: integer): boolean;
var
   args: TStringList;
begin
   args := ArgsToList(aArgs);
   try
      (* poNewConsole AND poWaitOnExit, and both are load-bearing -- see the
        interface note. The exit status is only meaningful once Execute has
        returned, which is what poWaitOnExit guarantees. *)
      Result := Launch(aExecutable, args, swoShowNormal,
                       [poNewConsole, poWaitOnExit], aExitStatus);
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
   ignoredStatus: integer;
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
      Result := Launch(exe, parts, show, [], ignoredStatus);
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
