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

implementation

uses SysUtils;

{ Create on first use. Windows does not need it -- the directories ship -- but
  macOS and Linux both write into a home directory that starts empty. }
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

{$IFEND}

end.
