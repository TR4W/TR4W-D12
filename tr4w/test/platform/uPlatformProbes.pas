(*
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
 *)

(* WHAT THE PLATFORM ACTUALLY ANSWERS -- THE HEADLESS HALF.

  NO LCL, NO WIDGET SET, NOTHING FROM src/. That is the point of the split, and
  it is the same split uCrashLog and uCrashLogLCL already make for the same
  reason: a program with a widget set and a program without one are different
  programs, and no conditional can tell them apart -- only the unit graph can.

  These probes must run where there is no display, no X server and no session,
  which is every CI machine and every ssh into the Mac. The metric and colour
  probes that DO need a widget set live in their own program.

  EVERY PROBE HERE EARNED ITS PLACE BY BEING A DEFECT FIRST. That is the rule
  for adding one: not "this might differ" -- the space of things that might
  differ is unbounded and a suite built from speculation is a suite nobody
  maintains -- but "this DID differ, it cost us a bench session, and this is
  the question that would have caught it in seconds".

  The provenance is written beside each one. *)
unit uPlatformProbes;

{$MODE DELPHI}
{$H+}

interface

uses
   SysUtils, Classes, dynlibs, uProbeReport;

procedure RunHeadlessProbes(const aReport: TProbeReport);

implementation

(* A THREAD THAT DOES NOTHING AND ENDS, so CloseThread has a real handle to be
  asked about. Its body is irrelevant; its TERMINATION is the precondition. *)
function IdleThread(aParam: Pointer): PtrInt;
begin
   Result := 0;
end;

(* ------------------------------------------------------------------------
  THREADING
  ------------------------------------------------------------------------ *)

procedure ProbeThreading(const aReport: TProbeReport);
var
   h:   TThreadID;
   rc:  dword;
begin
   (* SizeOf(TThreadID) -- 4 ON WIN32, 8 ON EVERY 64-BIT UNIX, AND IT BROKE A
     BUILD. uCrashLog held the main thread id in a plain integer, which is
     fine on Windows and is a TRUNCATED POINTER on Darwin, where TThreadID is
     a pthread_t. The fix was PtrUInt, which that unit already used elsewhere.

     Asked as a NOTE rather than an Expect: the right answer genuinely differs
     and no TR4W code should depend on the number. What TR4W must depend on is
     using a type wide enough to hold it, and that is a compile-time property
     this cannot test. The value is in the DIFF -- 4 against 8 in one table is
     what makes the trap visible. *)
   aReport.Note('rtl.threadid.size', SizeOf(TThreadID),
                'a pointer on Unix, a DWORD on Win32 -- hold it in PtrUInt, ' +
                'never integer');

   aReport.Note('rtl.thandle.size', SizeOf(THandle),
                'System.THandle. LCLType REDECLARES this name; a unit that ' +
                'uses both gets whichever came last in its uses clause');

   aReport.Note('rtl.pointer.size', SizeOf(Pointer),
                'the 64-bit move is measured against this');

   (* CloseThread's RETURN CONVENTION, AND IT PUT A MODAL DIALOG ON SCREEN.

     FPC's Unix thread manager is

         function CCloseThread (threadHandle : TThreadID) : dword;
           begin
             result:=0;
           end;

     (cthreads.pp:451) -- a no-op that ALWAYS returns zero, because a handle is
     not a thing pthreads has to close. On Windows it reaches CloseHandle,
     where zero means FAILURE.

     logk1ea tested it the Windows way. On Linux the check therefore fired
     after EVERY CW message, and the error reporter formatted errno -- which
     was 0, which SysErrorMessage renders as "Success". NY4I, Linux Mint
     2026-09-09, screenshotted a modal box reading "CW: Success" that had to be
     dismissed between contacts.

     A SUCCESS REPORTED AS AN ERROR, IN AN ERROR REPORTER, USING AN ERROR CODE
     THAT SAYS SUCCESS. Nothing about the source reads wrong. This is the
     probe that would have said so in one line. *)
   h := BeginThread(@IdleThread);
   if h = TThreadID(0) then
      begin
      aReport.Skip('rtl.closethread.returns',
                   'could not start a thread to ask about');
      end
   else
      begin
      WaitForThreadTerminate(h, 5000);
      rc := CloseThread(h);

{$IFDEF WINDOWS}
      (* CloseHandle's convention: non-zero is success. *)
      aReport.Expect('rtl.closethread.zero_means_failure', rc = 0, False);
{$ELSE}
      (* Always zero, and it means nothing. Any caller testing it is wrong. *)
      aReport.Expect('rtl.closethread.zero_means_failure', rc = 0, True);
{$ENDIF}
      end;
end;

(* ------------------------------------------------------------------------
  ERROR REPORTING
  ------------------------------------------------------------------------ *)

procedure ProbeErrors(const aReport: TProbeReport);
begin
   (* WHAT ERRNO ZERO RENDERS AS. On Linux it is the single word "Success",
     which is how a benign value reached an operator inside a dialog whose
     title said the CW send had a problem.

     RECORDED, NOT ASSERTED, because the string is the platform's and there is
     nothing wrong with it. The lesson is about the CALLER: never format an
     error code without first establishing that there was an error. *)
   aReport.Note('rtl.syserrormessage.0', SysErrorMessage(0),
                'a BENIGN value with an error-shaped rendering -- never ' +
                'format an error code before confirming there was an error');
end;

(* ------------------------------------------------------------------------
  PATHS AND THE FILE SYSTEM
  ------------------------------------------------------------------------ *)

procedure ProbePaths(const aReport: TProbeReport);
var
   dir:      string;
   lower:    string;
   upper:    string;
   f:        TextFile;
begin
   aReport.Note('paths.pathdelim', PathDelim,
                'build a path with this, never a literal separator');

   (* SPELLED OUT, because the raw value contains the very characters that
     would break the line it is printed on. *)
   aReport.Note('rtl.lineending',
                StringReplace(StringReplace(LineEnding, #13, 'CR',
                                            [rfReplaceAll]),
                              #10, 'LF', [rfReplaceAll]),
                'source files in this tree are CRLF whatever this says -- ' +
                'see Lint-LineEndings');

   aReport.Note('rtl.defaultsystemcodepage', DefaultSystemCodePage,
                'what an AnsiString is decoded as at the file layer');

   (* ExtractFilePath AGAINST A WINDOWS-STYLE PATH.

     THIS IS THE SHAPE THAT MADE EVERY US CALLSIGN DX. fcontest split the
     chosen contest file by scanning BACKWARDS for a backslash. On Unix there
     is none, so the loop never stopped, chewed through the whole path
     truncating at every dot, and

         /home/toms/Desktop/TR4W/tr4w-5.0.2-x86_64-linux/ARRL-FD ... .db

     became

         /home/toms/Desktop/TR4W/tr4w-5

     The log database then opened as the wrong file, so the contest never
     loaded, so the domestic country list was never built, so every K station
     scored as DX. A path separator produced a scoring failure five steps away
     and the only visible symptom was an exchange prompt.

     ASSERTED WITH NO CONDITIONAL, AND THE FIRST VERSION OF THIS PROBE HAD ONE.

     THE PROBE WAS WRONG AND THE PLATFORM WAS RIGHT, WHICH IS THE POINT OF
     RUNNING IT. It expected '' on Unix, reasoning that a backslash is an
     ordinary filename character there. Linux answered 'C:\logs\' and failed
     the run on the very first execution, 2026-09-09.

     FPC DECLARES THE SEPARATOR SET THE SAME WAY EVERYWHERE:

         AllowDirectorySeparators : set of char = ['\\','/'];

     -- rtl/unix/sysunixh.inc:35, character for character what
     rtl/win/syswinh.inc:23 says. So ExtractFilePath splits on a backslash on
     Linux and macOS too, and this is a CROSS-PLATFORM INVARIANT rather than a
     per-platform answer. Pinned as one, because pinning it is stronger: TR4W
     now depends on it, and it would break silently if a future RTL narrowed
     the set on Unix.

     IT MAKES THE fcontest FIX BETTER THAN IT WAS DESCRIBED AS BEING. A contest
     path written on Windows and opened on Linux splits correctly, which the
     backward-scanning loop it replaced could never have managed in reverse.

     THE ASYMMETRY IS REAL AND IS NOT TESTED HERE. The RTL's PARSING accepts a
     backslash on Unix; the FILE SYSTEM does not treat it as a separator, so a
     Unix file may legitimately have one in its name and this function will
     mis-split it. TR4W produced exactly such a file before it was fixed --
     'DXCluster\dxcluster ....txt', a single file sitting beside the directory
     it was meant to go in, because a WRITE path was built with a literal
     separator. Reading is forgiving; writing is not. *)
   aReport.Expect('paths.extractfilepath.backslash',
                  ExtractFilePath('C:\logs\ARRL-FD.db'), 'C:\logs\');

   (* And forward slash, which every platform here accepts. *)
   aReport.Expect('paths.extractfilepath.forwardslash',
                  ExtractFilePath('/logs/ARRL-FD.db'), '/logs/');

   (* IS THE FILE SYSTEM CASE SENSITIVE.

     TR4W ships data files whose names it spells inconsistently -- CTY.DAT and
     cty.dat, TRMASTER.DTA, the dom/ tree -- because on Windows the question
     never came up. uAppPaths.ExistingDataFile exists to resolve that, and
     whether it is NEEDED is exactly this answer.

     Measured rather than assumed: a Mac volume is usually case INSENSITIVE,
     which is not what a Unix answer would lead you to expect, and an
     installer tested only there would ship a name Linux cannot open. *)
   dir   := GetTempDir(False);
   lower := dir + 'tr4w_probe_case.tmp';
   upper := dir + 'TR4W_PROBE_CASE.TMP';

   try
      AssignFile(f, lower);
      Rewrite(f);
      WriteLn(f, 'probe');
      CloseFile(f);

      aReport.Note('fs.case_sensitive', BoolToStr(not FileExists(upper), True),
                   'False here means ExistingDataFile is doing nothing ' +
                   'locally and its absence would not be noticed until Linux');

      DeleteFile(lower);
   except
      on E: Exception do
         begin
         aReport.Skip('fs.case_sensitive',
                      'could not write a probe file: ' + E.Message);
         end;
   end;
end;

(* ------------------------------------------------------------------------
  SHARED LIBRARIES -- DOES THE NAME TR4W ASKS FOR EXIST HERE
  ------------------------------------------------------------------------ *)

(* A LIBRARY NAME IS A PLATFORM ASSUMPTION WEARING A FILE NAME.

  CLAUDE.md already calls this out and the port has now paid for it twice:

    'sqlite3.dll'  -- names a file that cannot exist on macOS or Linux.
    'libsqlite3.so' -- FPC's own unversioned default, shipped ONLY by the
                    -dev package, so the load fails on a machine that has
                    SQLite perfectly well installed. NY4I hit exactly this on
                    Mint, having installed the `sqlite3` package -- which is
                    the command-line tool and contains no shared library at
                    all.
    'libhamlib-4.dll' -- one constant, and the Linux and macOS spellings are
                    NOT guessable from it: a versioned soname and a versioned
                    dylib, neither of which SharedSuffix produces.

  SO ASK THE MACHINE. Each candidate is loaded and released; the first that
  loads is the name that belongs in the constant. Writing an UNVERIFIED name
  is the same mistake pointing the other way, which is why CLAUDE.md says to
  verify each on the platform before changing anything.

  Reported as a Note: this is a survey, and its output is the input to a
  decision rather than a pass or a fail. It becomes an Expect per platform the
  day the constants are unified into one naming unit. *)
procedure ProbeLibraryName(const aReport: TProbeReport;
                           const aKey: string;
                           const aCandidates: array of string);
var
   i:      integer;
   h:      TLibHandle;
   tried:  string;
begin
   tried := '';

   for i := Low(aCandidates) to High(aCandidates) do
      begin
      if tried <> '' then
         begin
         tried := tried + ', ';
         end;
      tried := tried + aCandidates[i];

      h := LoadLibrary(aCandidates[i]);
      if h <> NilHandle then
         begin
         UnloadLibrary(h);
         aReport.Note(aKey, aCandidates[i],
                      'loaded. Tried in order: ' + tried);
         Exit;
         end;
      end;

   aReport.Note(aKey, '(none loaded)',
                'NONE of these resolved: ' + tried);
end;

procedure ProbeLibraries(const aReport: TProbeReport);
begin
{$IFDEF WINDOWS}
   ProbeLibraryName(aReport, 'libs.sqlite3',
                    ['sqlite3.dll']);
   ProbeLibraryName(aReport, 'libs.hamlib',
                    ['libhamlib-4.dll']);
   ProbeLibraryName(aReport, 'libs.ssl',
                    ['libssl-3.dll', 'libssl-1_1.dll', 'ssleay32.dll']);
{$ENDIF}

{$IFDEF LINUX}
   (* libsqlite3.so is the -dev symlink and is listed FIRST on purpose: if it
     ever loads on an operator's machine the versioned name below is not
     buying anything, and if it does not, this row proves why the default
     could not work. *)
   ProbeLibraryName(aReport, 'libs.sqlite3',
                    ['libsqlite3.so', 'libsqlite3.so.0']);
   ProbeLibraryName(aReport, 'libs.hamlib',
                    ['libhamlib.so', 'libhamlib.so.4']);
   ProbeLibraryName(aReport, 'libs.ssl',
                    ['libssl.so', 'libssl.so.3', 'libssl.so.1.1']);
{$ENDIF}

{$IFDEF DARWIN}
   ProbeLibraryName(aReport, 'libs.sqlite3',
                    ['libsqlite3.dylib', 'libsqlite3.0.dylib',
                     '/usr/lib/libsqlite3.dylib']);
   ProbeLibraryName(aReport, 'libs.hamlib',
                    ['libhamlib.dylib', 'libhamlib.4.dylib',
                     '/opt/homebrew/lib/libhamlib.dylib']);
   ProbeLibraryName(aReport, 'libs.ssl',
                    ['libssl.dylib', 'libssl.3.dylib', 'libssl.1.1.dylib',
                     '/opt/homebrew/opt/openssl@3/lib/libssl.dylib']);
{$ENDIF}
end;

procedure RunHeadlessProbes(const aReport: TProbeReport);
begin
   ProbeThreading(aReport);
   ProbeErrors(aReport);
   ProbePaths(aReport);
   ProbeLibraries(aReport);
end;

end.
