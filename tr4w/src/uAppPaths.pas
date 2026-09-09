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

implementation

uses SysUtils, StrUtils;

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
   Result := StringReplace(Result, '', '/', [rfReplaceAll]);
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

{$ENDIF}

{$IFDEF DARWIN}

{ Contents/MacOS/tr4w -> Contents/Resources/ is up one and across. }
function BundleResources: string;
begin
   Result := IncludeTrailingPathDelimiter(
                ExpandFileName(ExtractFilePath(ParamStr(0)) + '../Resources'));
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

{$IFEND}

end.
