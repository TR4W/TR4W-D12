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
unit uAppPaths;
{$I tr4w.inc}

{
  WHERE TR4W'S FILES LIVE -- three accessors, because there are three KINDS of
  file and they land in the same directory on Windows and in three different
  ones everywhere else.

  WHY IT EXISTS. Two rules disagreed. `TR4W_PATH_NAME` is the WORKING directory
  (set from GetCurrentDirectory in uProgramMain) and 39 sites use it; six others
  used `ExtractFilePath(ParamStr(0))`, the BINARY's directory. The shipped layout
  hides the difference because FullBuild puts tr4w.exe in target\ beside the
  data -- but the binary is developed and run from build-out\ with the working
  directory set to target\, and there the two rules point at different places.
  That is what left the Server drop-down on the DX Cluster page empty while the
  DX Cluster window listed servers from the same TRCLUSTER.DAT (NY4I,
  2026-08-30): the window used the working directory and found it, the picker
  used ParamStr(0) and did not.

  THE WINDOWS ARMS ALL RESOLVE FROM THE WORKING DIRECTORY (NY4I, 2026-08-31:
  "you can make the change to the target directory rather than exe path"). That
  is the rule the 39 legacy sites already follow, it is the one that keeps
  working when the binary is run from build-out, and it makes the six
  ParamStr(0) sites agree with the other 39 instead of the reverse.

  NEITHER RULE SURVIVES LEAVING WINDOWS, which is the other reason this is a
  unit and not a constant. On macOS the binary sits in App.app/Contents/MacOS
  while read-only data belongs in Contents/Resources, and the bundle is
  code-signed -- writing beside the binary breaks the signature. On Linux the
  binary is in /usr/bin and its data in /usr/share. In both cases settings and
  logs must go somewhere writable in the user's home, and they are NOT the same
  place as each other: a log is state, not configuration, and someone who syncs
  ~/.config does not want a contest log going with it.

  SO DO NOT COLLAPSE THESE INTO ONE ACCESSOR. On Windows all three return the
  same directory today, which makes the collapse look free and is exactly how
  this comes back.
}

interface

{ Shipped, read-only: CTY.DAT, TRMASTER.DTA, TRCLUSTER.DAT, dom\ }
function DataFilePath(const aName: string): string;

{ Writable, per-operator: tr4w.json, tr4w.ini, window positions }
function SettingsFilePath(const aName: string): string;

{ Writable, possibly large: tr4w.log, contest logs }
function LogFilePath(const aName: string): string;

(* THE SAME THREE PLACES AS DIRECTORIES, with a trailing separator.

  For the callers that hold a PREFIX rather than build one path -- chiefly
  TR4W_PATH_NAME, which forty sites append to with TF.Format('%sCTY.DAT', ...).
  Those cannot use the file accessors without being rewritten one at a time,
  and pointing the prefix at the right directory fixes them all at once.

  DataDir is the one TR4W_PATH_NAME should be: the forty sites are dominated by
  READS of shipped data -- CTY.DAT, TRMASTER.DTA, dom\, r150s.dat, rfobl.dat,
  COMMONMESSAGES.INI. The writes among them are moving to SettingsFilePath and
  LogFilePath individually, because a write is the case where getting it wrong
  puts an operator's contest file inside an application bundle. *)
function DataDir: string;
function SettingsDir: string;
function LogDir: string;

(* WHERE AN OPERATOR'S OWN CONTEST FILES GO -- the .cfg, the SQLite log, the
  .RST and .DOM beside it, and a downloaded CTY.DAT.

  THE FOURTH ROOT, AND ITS ABSENCE WAS A REAL DEFECT.  This unit had a
  read-only DATA root, a writable CONFIG root and a writable STATE root, and
  nowhere for the files the operator CREATES.  Contest files were therefore
  composed from TR4W_PATH_NAME, which is DataDir -- read-only on any Linux or
  macOS install worth the name.

  NY4I hit it on a fresh Debian 13 running the AppImage (2026-09-10).  An
  AppImage mounts itself read-only, so the contest log was being created at
  /tmp/.mount_XXXX/usr/bin/ and QSOs were not saved.  A cty.dat download in the
  same session failed with "Read-only file system", which is the same defect
  wearing different words.  It is NOT AppImage-specific: a tarball installed
  to /usr/share, or a .app bundle, is read-only in exactly the same way.

  ~/tr4w OFF WINDOWS, and VISIBLE ON PURPOSE (NY4I's call, 2026-09-10).  The
  XDG data home, ~/.local/share, is where the specification would put it and is
  hidden -- and a contest log is a document an operator has to find at
  submission time, mail to a robot, and hand to an adjudicator.  A settings
  file is not, which is why config and state stay under XDG.

  WINDOWS IS UNCHANGED and must be: contest files live beside the binary there
  and twenty years of operators know it. *)
function ContestDir: string;
function ContestFilePath(const aName: string): string;

(* --settings <path>, IF ONE WAS GIVEN, AND '' OTHERWISE.

  THE COMMAND LINE IS A PATH QUESTION, so it is answered here rather than
  separately in each unit that cares.  uTR4WConfigFile had this parse; when a
  second caller appeared, a second COPY would have been the thing CLAUDE.md
  warns about -- copies drift, and the drift is invisible.

  CACHED, because TR4WConfigFileName is asked before most of startup has run
  and a variable somebody has to remember to set first would be wrong on the
  call that matters most.  Answering it lazily cannot be ordered wrongly. *)
function SettingsFileOverride: string;

(* WHERE A FILE TR4W DOWNLOADED FOR THE OPERATOR LIVES -- CTY.DAT,
  TRMASTER.DTA, pota_parks.csv.

  NOT DataDir, ON ANY PLATFORM, AND EACH ONE IS WRONG FOR A DIFFERENT REASON:

    Windows   DataDir is the working directory, which on a developer's machine
              IS THE REPOSITORY.  Alt-O wrote over the tracked
              tr4w/target/cty.dat every single time (NY4I, 2026-09-24).
    macOS     DataDir is Contents/Resources -- INSIDE A SIGNED, NOTARIZED
              BUNDLE.  A write there invalidates the signature.
    Linux     an AppImage mounts read-only, at a new path every launch.

  IT IS THE SETTINGS DIRECTORY.  That is writable on all three by definition,
  it is already where the operator's own state lives, and a downloaded country
  file is exactly what it is for: application data the operator did not author.

  AND --settings MOVES IT, WHICH IS WHAT KEEPS THE GOLDEN CORPUS DETERMINISTIC.
  The corpus points the program at its own tracked settings fixture; that
  directory holds no CTY.DAT, so the lookup falls through to the tracked
  shipped copy no matter what the developer has downloaded.  Without that, a
  corpus result would depend on whether somebody had pressed Alt-O -- a
  differently-configured clone failing for a reason that is purely an
  artifact, on the regression oracle itself. *)
function DownloadedDataDir: string;
function DownloadedDataFilePath(const aName: string): string;

(* THE WRITABLE COPY IF THERE IS ONE, THE SHIPPED COPY OTHERWISE.

  The two-tier lookup in ONE place, so "downloaded beats shipped" is stated
  once instead of being spelled out at each caller.  Case-tolerant at both
  tiers, through ExistingDataFile: the file an operator downloads from
  country-files.com is named cty.dat and the program asks for CTY.DAT.

  The country file does NOT come through here -- it has a third tier, a copy
  beside the contest, and FCONTEST.SetUpFileNames owns that order. *)
function PreferredDataFilePath(const aName: string): string;

(* THE SAME FILE, WHATEVER CASE IT IS SPELLED IN.

  Returns aPath when it exists. When it does not, and the platform has a
  case-sensitive filesystem, looks in the same directory for a name that
  differs from the wanted one only in case and returns THAT. Failing both, it
  returns aPath unchanged so the caller reports the name the operator expects
  to see.

  WHY THIS IS AT THE LOOKUP AND NOT IN THE PACKAGING. Two separate things put
  a differently-cased name on disk, and renaming the shipped files only fixes
  one of them:

    1. This repository tracks the country file as `cty.dat` while the program
       opens `CTY.DAT`. On Windows those are one file and it has worked for
       twenty years. On Linux they are two, so TR4W found nothing, fell
       through to its download path, and reported an OpenSSL failure -- an
       error message about the wrong subsystem entirely (NY4I, Linux Mint,
       2026-09-09).

    2. THE ONE THE PACKAGING CANNOT FIX: the country file an operator
       downloads from country-files.com is named `cty.dat`. Updating it by
       hand is the normal way to run a contest station, and on Linux that
       drops a file the program cannot see -- every time, forever, however
       the package was built.

  So the durable answer is that the LOOKUP tolerates case. Renaming three
  files in the repository would have fixed the tarball and left every future
  cty.dat update broken.

  COST: one directory scan, and only after FileExists has already said no. It
  is not on any hot path -- these are startup-time lookups of shipped data.
  On Windows it compiles to the FileExists test alone. *)
function ExistingDataFile(const aPath: string): string;

(* THE SAME THING FOR THE FIXED CHAR ARRAYS THE PROGRAM STORES PATHS IN.

  TR4W_CTY_FILENAME and its siblings are array[0..MAX_PATH-1] of AnsiChar, so
  a caller would otherwise have to write string(PAnsiChar(@TheArray)) to ask
  the question -- a pointer cast, which is the shape we are removing, and one
  that reads past the NUL if the array is not terminated.

  AN OPEN ARRAY INSTEAD: it carries its own bounds, High() is real, and the
  reader stops at the NUL because this code stops it. Nothing is dereferenced
  and nothing is assumed about the caller's declared size. *)
procedure ResolveDataFileInPlace(var aPath: array of AnsiChar);

(* THE FILE NAME OUT OF ANYTHING THAT MIGHT BE A PATH -- BOTH SEPARATORS,
  ON EVERY PLATFORM.

  WHY IT IS NOT ExtractFileName. That reads PathDelim, so on Linux it leaves
  a Windows-spelled path entirely alone: ExtractFileName('dom\s48p14dc.dom')
  is the whole string, and the caller then opens a file with a backslash in
  its name that nothing will ever create.

  WHY IT EXISTS AT ALL. Several settings are documented as NAMES of shipped
  data files -- DOMESTIC FILENAME is 'OKOM.DOM' in every commands_help_*.ini
  -- and a name is the only thing that can survive being written into a
  contest log. An absolute path cannot: an AppImage mounts at a new
  /tmp/.mount_TR4W-<random> every run, an install moves, a memory stick gets
  a different drive letter, and a log opened on another machine sees none of
  them. Measured 2026-09-20, NY4I, Linux Mint: a contest .db held

    DOMESTIC FILENAME = /tmp/.mount_TR4W-5EnhBOm/usr/bin/dom\/tmp/.mount_TR4W-5olHkON/usr/bin/dom/s48p14dc.dom

  -- one run's resolved path, composed into the NEXT run's prefix, because
  the resolved path had been stored back into the setting.

  Returns aValue unchanged when it holds no separator, so a plain name costs
  a scan and nothing else. *)
function DataFileNameOnly(const aValue: string): string;

(* A PROGRAM SHIPPED ALONGSIDE TR4W -- today, tr4wconvert.

  THE FIFTH KIND OF PATH, and it is genuinely none of the other four: it is
  not shipped DATA, it is not writable, and it is not the operator's. It is
  an executable the installer put beside ours, and the platform decides both
  where that is and what an executable is CALLED.

  NOT AppDir.  On Windows AppDir is the working directory, which is right for
  data and wrong here: TR4W can legitimately be started from somewhere else
  and its sibling programs do not move with the shell. This asks the one
  question that is always true -- where is the binary that is running --
  which is also the correct answer inside a .app bundle (Contents/MacOS) and
  under /usr/bin.

  THE EXTENSION IS PART OF THE ANSWER, which is why the caller passes a bare
  name. '.exe' on Windows and nothing anywhere else is exactly the sort of
  OS gate this unit exists to hold (NY4I, 2026-09-16: "Minimizing OS gates in
  the main code makes this more modular"), and asking the LCL for it instead
  would put a widget-set dependency into every caller that only wants a path.

  It does NOT check that the file is there. The caller must, because "the
  program is missing" is something an operator has to be told rather than a
  path this unit could substitute for. *)
function SiblingProgramPath(const aName: string): string;

(* WHERE THIS PROGRAM KEEPS THE SHARED LIBRARIES IT SHIPS ITSELF.

  Not where the SYSTEM keeps libraries -- the dynamic linker already knows
  that.  This is the directory TR4W's own packaging puts a library in when the
  platform does not supply one, and the only caller today is uOpenSSLLoader:
  macOS has shipped no libssl.dylib for years, so TR4W.app carries its own.

  The answer differs by platform in KIND and not just in spelling, which is why
  it is here and not spelled out at the call site:

    Windows   beside the binary.  ssleay32.dll and libeay32.dll sit next to
              tr4w.exe, which is where the installer puts them and where the
              loader looks by default.
    macOS     Contents/Frameworks, the place Apple prescribes for an
              application's private dynamic libraries.
    Linux     beside the binary.  Nothing is shipped there today -- OpenSSL,
              SQLite and HamLib are packages -- so this is the honest answer
              for the AppImage layout rather than a promise.

  It does NOT create the directory and does not check that anything is in it.
  A caller that finds it empty has learned something real. *)
function PrivateLibraryDir: string;

implementation

uses SysUtils, StrUtils;

function DataFileNameOnly(const aValue: string): string;
var
   i: integer;
begin
   Result := aValue;
   (* Backwards from the end: the LAST separator of either spelling wins,
     which is what makes the doubled value above collapse to the name. *)
   for i := Length(Result) downto 1 do
      begin
      if (Result[i] = '/') or (Result[i] = '\') then
         begin
         Result := Copy(Result, i + 1, Length(Result) - i);
         Exit;
         end;
      end;
end;

function SiblingProgramPath(const aName: string): string;
begin
   Result := ExtractFilePath(ParamStr(0)) + aName
{$IFDEF WINDOWS}
             + '.exe'
{$ENDIF}
             ;
end;

{ Create on first use. Windows does not need it -- the directories ship -- but
  macOS and Linux both write into a home directory that starts empty. }
function ExistingDataFile(const aPath: string): string;
{$IFNDEF WINDOWS}
var
   parts: TStringArray;
   built, wanted: string;
   i: integer;
   rec: TSearchRec;
   found: boolean;
{$ENDIF}
begin
   Result := aPath;
   if FileExists(Result) then
      begin
      Exit;
      end;

{$IFNDEF WINDOWS}
   (* A BACKSLASH IS A LEGAL FILENAME CHARACTER HERE, so it has to go before
     anything else can work. This program was written against Win32 and 153
     of its string literals still spell a path with one -- '%sDOM\%s.DOM'
     among them. On Windows both separators open the same file; on Linux
     "DOMrrlsect.dom" is one file with an odd name, in the wrong
     directory, that does not exist. *)
   (* SetDirSeparators, not a hand-written replace. It is the RTL's own
     answer and it takes both separators to whatever PathDelim is here, so
     no backslash literal appears in this unit at all -- which matters,
     because the first version of this line WAS a literal replace and my
     edit script silently ate the backslash, leaving
     StringReplace(Result, '', '/', ...). It compiled, it did nothing, and
     the Windows build could not have caught it: this whole block is
     {$IFNDEF WINDOWS}. A probe run on Linux caught it in one line. *)
   Result := SetDirSeparators(Result);
   if FileExists(Result) then
      begin
      Exit;
      end;

   (* THEN EVERY COMPONENT, NOT JUST THE FILE NAME. The country file is the
     obvious case, but the domestic-multiplier files need the DIRECTORY
     matched too: the program asks for DOM/ARRLSECT.DOM and the package ships
     dom/arrlsect.dom, so a resolver that only looked at the last component
     would search a directory that is not there and find nothing.

     Walks down from the root, replacing each component with the real entry
     that differs from it only in case. Gives up and returns the original the
     moment a component has no match, so the caller reports the name the
     operator expects to see rather than a half-resolved one. *)
   parts := SplitString(Result, '/');
   if Length(parts) < 2 then
      begin
      Exit;
      end;

   built := parts[0];
   if built = '' then
      begin
      built := '/';
      end;

   for i := 1 to High(parts) do
      begin
      wanted := parts[i];
      if wanted = '' then
         begin
         Continue;
         end;

      if FileExists(IncludeTrailingPathDelimiter(built) + wanted) or
         DirectoryExists(IncludeTrailingPathDelimiter(built) + wanted) then
         begin
         built := IncludeTrailingPathDelimiter(built) + wanted;
         Continue;
         end;

      found := False;
      if FindFirst(IncludeTrailingPathDelimiter(built) + '*', faAnyFile, rec) = 0 then
         begin
         try
            repeat
               if UpperCase(rec.Name) = UpperCase(wanted) then
                  begin
                  built := IncludeTrailingPathDelimiter(built) + rec.Name;
                  found := True;
                  Break;
                  end;
            until FindNext(rec) <> 0;
         finally
            FindClose(rec);
         end;
         end;

      if not found then
         begin
         (* No match at this level: nothing below it can resolve either. *)
         Result := aPath;
         Exit;
         end;
      end;

   Result := built;
{$ENDIF}
end;

procedure ResolveDataFileInPlace(var aPath: array of AnsiChar);
var
   i, n: integer;
   current, resolved: string;
begin
   (* Read up to the NUL. High() is the array's own bound, so a caller cannot
     make this walk off the end by passing the wrong size. *)
   current := '';
   for i := Low(aPath) to High(aPath) do
      begin
      if aPath[i] = #0 then
         begin
         Break;
         end;
      current := current + Char(aPath[i]);
      end;

   if current = '' then
      begin
      Exit;
      end;

   resolved := ExistingDataFile(current);
   if resolved = current then
      begin
      Exit;
      end;

   (* Write back, NUL-terminated, and never past the caller's last element.
     A resolved name is the same length as the one we asked for -- only the
     case differs -- so the truncation guard is a belt, not a scenario. *)
   n := Length(resolved);
   if n > High(aPath) then
      begin
      n := High(aPath);
      end;

   for i := 1 to n do
      begin
      aPath[i - 1] := AnsiChar(resolved[i]);
      end;
   aPath[n] := #0;
end;

function EnsureDir(const aDir: string): string;
begin
   Result := IncludeTrailingPathDelimiter(aDir);
   if not DirectoryExists(Result) then
      begin
      ForceDirectories(Result);
      end;
end;

{$IFDEF WINDOWS}

{ The working directory -- the same rule TR4W_PATH_NAME has always used. }
function AppDir: string;
begin
   Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

function DataFilePath(const aName: string): string;
begin
   Result := AppDir + aName;
end;

function SettingsFilePath(const aName: string): string;
begin
   Result := EnsureDir(AppDir + 'settings') + aName;
end;

function LogFilePath(const aName: string): string;
begin
   Result := AppDir + aName;
end;

function DataDir: string;     begin Result := AppDir; end;
function SettingsDir: string; begin Result := EnsureDir(AppDir + 'settings'); end;
function LogDir: string;      begin Result := AppDir; end;

(* THE BINARY'S OWN DIRECTORY, NOT AppDir. AppDir is the working directory
  here, which is right for data and wrong for libraries: the loader resolves a
  DLL beside the executable no matter where TR4W was started from. *)
function PrivateLibraryDir: string;
begin
   Result := ExtractFilePath(ParamStr(0));
end;
// Beside the binary, exactly as it has always been. See the interface note.
function ContestDir: string;  begin Result := AppDir; end;
function ContestFilePath(const aName: string): string;
begin
   Result := ContestDir + aName;
end;

{$ENDIF}

{$IFDEF DARWIN}

{ Contents/MacOS/tr4w -> Contents/Resources/ is up one and across. }
function BundleResources: string;
begin
   Result := IncludeTrailingPathDelimiter(
                ExpandFileName(ExtractFilePath(ParamStr(0)) + '../Resources'));
end;

{ And Contents/Frameworks is its sibling -- where build-unix.sh's packaging
  stage puts libssl and libcrypto. A binary run straight out of build-out has
  no bundle around it, so this names a directory that is not there; the caller
  treats that as "nothing shipped here" and looks elsewhere. }
function PrivateLibraryDir: string;
begin
   Result := IncludeTrailingPathDelimiter(
                ExpandFileName(ExtractFilePath(ParamStr(0)) + '../Frameworks'));
end;

function HomeDir: string;
begin
   Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME'));
end;

function DataFilePath(const aName: string): string;
begin
   Result := BundleResources + aName;
end;

function SettingsFilePath(const aName: string): string;
begin
   Result := EnsureDir(HomeDir + 'Library/Application Support/TR4W') + aName;
end;

function LogFilePath(const aName: string): string;
begin
   Result := EnsureDir(HomeDir + 'Library/Logs/TR4W') + aName;
end;

function DataDir: string;     begin Result := BundleResources; end;
function SettingsDir: string; begin Result := EnsureDir(HomeDir + 'Library/Application Support/TR4W'); end;

(* ~/tr4w, VISIBLE, and the same answer on both platforms.

  A .app bundle is read-only exactly as an AppImage is, so macOS had the same
  defect for the same reason. Putting contest files in the operator's home
  rather than under Library/Application Support is deliberate: what lives there
  is application state, and a contest log is a document that gets found,
  mailed and submitted. *)
function ContestDir: string;
begin
   Result := EnsureDir(HomeDir + 'tr4w');
end;

function ContestFilePath(const aName: string): string;
begin
   Result := ContestDir + aName;
end;

function LogDir: string;      begin Result := EnsureDir(HomeDir + 'Library/Logs/TR4W'); end;

{$ENDIF}

{$IF DEFINED(UNIX) AND NOT DEFINED(DARWIN)}

{ The XDG base-directory spec, with its documented defaults. CONFIG and STATE
  are separate roots on purpose -- see the unit header. }
function XdgDir(const aVar, aFallback: string): string;
var
   base: string;
begin
   base := GetEnvironmentVariable(aVar);
   if base = '' then
      begin
      base := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + aFallback;
      end;
   Result := EnsureDir(IncludeTrailingPathDelimiter(base) + 'tr4w');
end;

function DataFilePath(const aName: string): string;
begin
   { An installed copy first, then beside the binary so a build tree works. }
   Result := '/usr/share/tr4w/' + aName;
   if not (FileExists(Result) or DirectoryExists(Result)) then
      begin
      Result := ExtractFilePath(ParamStr(0)) + aName;
      end;
end;

function SettingsFilePath(const aName: string): string;
begin
   Result := XdgDir('XDG_CONFIG_HOME', '.config') + aName;
end;

function LogFilePath(const aName: string): string;
begin
   Result := XdgDir('XDG_STATE_HOME', '.local/state') + aName;
end;

(* THE SAME THREE, AS DIRECTORIES. I added these to the Windows and Darwin arms
  and forgot this one, which no Windows build could report -- the unit simply
  stopped compiling for Linux and Lint-LinuxCompile caught it. That lint is the
  only thing standing between a per-platform block and a missing arm. *)
function DataDir: string;
begin
   Result := '/usr/share/tr4w/';
   if not DirectoryExists(Result) then
      begin
      (* Not installed to a prefix -- run from a build or an unpacked tarball,
        which is how the tarball we ship is used. Same rule as DataFilePath. *)
      Result := ExtractFilePath(ParamStr(0));
      end;
end;

function SettingsDir: string;
begin
   Result := XdgDir('XDG_CONFIG_HOME', '.config');
end;

function LogDir: string;
begin
   Result := XdgDir('XDG_STATE_HOME', '.local/state');
end;

(* Beside the binary. Nothing is shipped here by the tarball -- OpenSSL,
  SQLite and HamLib are packages on Linux -- and the AppImage carries its
  bundled copies where its own runtime finds them, so no caller looks here
  today. It is answered rather than left out because a missing arm in a
  per-platform block is a unit that stops compiling for one platform only. *)
function PrivateLibraryDir: string;
begin
   Result := ExtractFilePath(ParamStr(0));
end;

(* ~/tr4w -- see the interface note. VISIBLE on purpose: XDG would say
  ~/.local/share and that is hidden, and a contest log has to be found at
  submission time. HOME is used directly rather than through XdgDir because
  this is not an XDG root and pretending it is would invite someone to
  "correct" it later. *)
function ContestDir: string;
begin
   Result := EnsureDir(IncludeTrailingPathDelimiter(
                          GetEnvironmentVariable('HOME')) + 'tr4w');
end;

function ContestFilePath(const aName: string): string;
begin
   Result := ContestDir + aName;
end;

{$IFEND}

(* ------------------------------------------------------------------------
  THE WRITABLE DATA TIER.  See the interface notes; these sit at the end
  because they are answered in terms of SettingsDir and DataDir, which the
  per-platform blocks above define.
  ------------------------------------------------------------------------ *)

var
   GSettingsOverride: string = '';
   GSettingsOverrideResolved: boolean = False;

function SettingsFileOverride: string;
var
   i: integer;
   arg: string;
begin
   if not GSettingsOverrideResolved then
      begin
      GSettingsOverrideResolved := True;
      for i := 1 to ParamCount do
         begin
         arg := ParamStr(i);
         (* UnicodeSameText, NOT SameText.  SysUtils' plain name takes
           AnsiString, so comparing two UTF-16 values through it narrows
           BOTH -- two conversions the build counts, for a comparison of
           ASCII switch text that cannot lose a character. *)
         if UnicodeSameText(Copy(arg, 1, 11), '--settings=') then
            begin
            GSettingsOverride := Copy(arg, 12, Length(arg));
            Break;
            end;
         if UnicodeSameText(arg, '--settings') and (i < ParamCount) then
            begin
            GSettingsOverride := ParamStr(i + 1);
            Break;
            end;
         end;
      end;

   Result := GSettingsOverride;
end;

function DownloadedDataDir: string;
var
   settingsFile: string;
begin
   settingsFile := SettingsFileOverride;
   if settingsFile = '' then
      begin
      Result := SettingsDir;
      Exit;
      end;

   (* ExpandFileName FIRST.  --settings may name a file with no directory at
     all, and ExtractFilePath of that is the empty string -- which would put a
     downloaded country file wherever the program happened to be started from
     rather than beside the settings it belongs to. *)
   Result := EnsureDir(ExtractFilePath(ExpandFileName(settingsFile)));
end;

function DownloadedDataFilePath(const aName: string): string;
begin
   Result := DownloadedDataDir + aName;
end;

function PreferredDataFilePath(const aName: string): string;
begin
   Result := ExistingDataFile(DownloadedDataFilePath(aName));
   if FileExists(Result) then
      begin
      Exit;
      end;

   Result := ExistingDataFile(DataFilePath(aName));
end;

end.
