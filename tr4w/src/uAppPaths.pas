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

  AND ON WINDOWS THE WRITABLE ONES CAN MOVE (issue 165, 2026-11-20). When the
  program folder refuses a new file -- an install under C:\Program Files run
  by a standard user -- the settings, log, contest and station-state
  accessors answer %APPDATA%\TR4W\ instead, and DataDir stays the program
  folder. The decision is made once, on first use, and is described with the
  routines that make it (ChooseWritableRoot and below). A WRITTEN file asks
  WrittenFilePath / BesideContestLogFilePath, never TR4W_PATH_NAME, which is
  the read-only tier; build\Count-LiveWrites.ps1 ratchets the raw writes.
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
  and twenty years of operators know it -- EXCEPT when that folder refuses new
  files (C:\Program Files, issue 165), when they go under %APPDATA%\TR4W with
  every other writable file. See "A READ-ONLY INSTALL FOLDER" below. *)
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

(* THE WRITABLE SETTINGS DIRECTORY AS THIS RUN SEES IT -- the base of the two
  above and of BackupDir, and where File > Open Log leaves a new contest's
  hand-off file for the instance it starts (issue 228): --settings moves it,
  and the child is given the same --settings. *)
function WritableSettingsDir: string;

(* THE SAME ANSWER FROM ITS INPUTS: aOverride's folder when --settings named a
  file (created), aDefault when it did not. --settings WINS OVER THE
  PER-USER REDIRECT (issue 165) because this is asked first: the corpus and
  the unit tests name their own settings and must keep writing there. *)
function WritableSettingsDirFor(const aOverride, aDefault: string): string;

(* WHERE TR4W'S OWN BACKUPS OF A CONTEST LOG GO -- 'backup' under the
  writable settings directory, with a trailing separator, created on first
  use (issue #98, step 1, 2026-10-24).

  NOT THE CONTEST DIRECTORY, ON PURPOSE. NY4I: "the contest folder holds only
  contest SQLite files." The Open dialog lists every .db in ContestDir, so a
  backup written there was listed as a contest of its own -- and sorted by
  Last QSO, a cleared log (0 QSOs) showed BELOW its own backup, which is how
  an operator came to open the backup believing the clear had failed. The
  dialog's scan is not recursive, and this is a subdirectory of the settings
  area: target\settings\backup\ on Windows, beside the binary's settings, and
  under the settings home on macOS and Linux -- never ContestDir itself.

  --settings MOVES IT, exactly as it moves DownloadedDataDir: the same base,
  so a test or the corpus that points the program at its own settings never
  writes a backup into the developer's real one.

  CREATION IS ATTEMPTED, NOT PROMISED. A folder that cannot be made (a file
  in the way, no permission) is returned anyway, and the caller's write
  fails: a backup that cannot be written is a reportable event, not a
  path this unit could quietly substitute. *)
function BackupDir: string;

(* THE WRITABLE COPY IF THERE IS ONE, THE SHIPPED COPY OTHERWISE.

  The two-tier lookup in ONE place, so "downloaded beats shipped" is stated
  once instead of being spelled out at each caller.  Case-tolerant at both
  tiers, through ExistingDataFile: the file an operator downloads from
  country-files.com is named cty.dat and the program asks for CTY.DAT.

  The country file does NOT come through here -- it has a third tier, a copy
  beside the contest, and FCONTEST.SetUpFileNames owns that order. *)
function PreferredDataFilePath(const aName: string): string;

(* A SHIPPED DOMESTIC FILE -- dom<separator>aName under the data directory,
  matched case-tolerantly (see ExistingDataFile). aName is a file NAME,
  extension included: 'arrlsect.dom'.

  ONE COMPOSITION, THREE CALLERS (2026-10-01). LogCfg loads the contest's
  domestic file, logdom follows an INCLUDE FILE line, and FCONTEST reads a
  QSO party's county file to decide whether the station is in state. Each
  spelled the path itself, and the third had dropped the separator --
  'DOM' + name -- so no station was ever in state for any QSO party
  (inventory defect #1). D7 wrote '%sDOM\%s.DOM'; this is that, for every
  platform.

  NOT the per-contest override. A <log stem>.DOM beside the contest replaces
  the domestic file a contest LOADS, and LogCfg looks for that first; it is
  not a shipped file and this does not look for it.

  ShippedDomDirOverride, when not empty, is the directory looked in instead
  (with or without a trailing separator). The program never writes it: a
  unit test points it at the tree's target/dom, because the test binary's
  working directory has no dom folder (2026-11-18, the multi-province
  parties' district-to-province lookup). LOGSTUFF's DomesticQTHRefusalDomDir
  is the older seam of the same kind, for the refusal path only. *)
function ShippedDomFilePath(const aName: string): string;

var
   ShippedDomDirOverride: string = '';

(* WHAT A COMPLETE INSTALL HAS THAT THIS COPY DOES NOT, one name per line:
  'dom' + PathDelim for the domestic-file folder, 'CTY.DAT', 'TRMASTER.DTA'.
  '' when all three are there.  CTY.DAT and TRMASTER.DTA count as present when
  a downloaded copy exists (PreferredDataFilePath).  Nothing is created or
  changed; the caller decides what the answer means. *)
function MissingInstallParts: string;

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

(* A SHIPPED FILE AS THE PROGRAM'S OWN FOLDER HOLDS IT, whatever the working
  directory is.  On Windows DataFilePath follows the WORKING directory, and a
  binary started from elsewhere (build-out\, a shortcut with another "Start in")
  finds nothing there; this is the folder the executable is in.

    Windows   beside the binary.
    macOS     Contents/Resources (the same place DataFilePath answers).
    Linux     beside the binary.

  It does NOT check that the file exists.  A caller wanting a fallback asks
  DataFilePath first and this second, and skips this one when it is the same
  path. *)
function BesideProgramFilePath(const aName: string): string;

(* THE FOLDER HOLDING help_<code>.po, the Preferences tooltips (issue 245).

  DataFilePath('help') first -- the installed layout, and the one that wins when
  both exist. Failing that, the program's own folder, because a developer run
  from tr4w\target with the binary in build-out\ has the working directory in
  one place and Build-App.ps1's staged help\ in the other. When neither exists
  the first answer is returned, so the log names where it looked. *)
function HelpDir: string;

(* ------------------------------------------------------------------------
  A READ-ONLY INSTALL FOLDER ON WINDOWS (issue 165 option 3, 2026-11-20).

  THE DEFECT. Every writable accessor above answers the program folder on
  Windows -- settings\, tr4w.log, the contest .db and its -wal/-shm, the
  backups, the downloads. Installed under C:\Program Files\TR4W and run with
  a standard user's token, the 64-bit program is refused every one of those
  writes (a 64-bit process gets no VirtualStore redirect). NY4I hit it on
  2026-11-20: "could not open its log file" on the first run, then a raw RTL
  "Unable to create file ...\settings\tr4w.json.new" after the setup wizard.

  THE RULE. Once per run, on first use, TR4W asks whether the program folder
  (the working directory, AppDir) accepts a new file: it creates and deletes a
  uniquely named one. If it does -- C:\tr4w, C:\radio\tr4w, the developer's
  tr4w\target, the corpus and the unit tests -- NOTHING CHANGES: every
  accessor answers exactly what it answered before. If it does not, every
  WRITABLE location moves under %APPDATA%\TR4W\, mirroring the install
  layout (settings\, tr4w.log, the contest logs at its top), and the shipped
  READ-ONLY data is still read from the program folder: DataDir and
  DataFilePath are not touched, so the downloaded -> contest -> shipped
  lookup keeps working.

  ROAMING %APPDATA%, the folder NY4I named and the Windows counterpart of
  ~/Library/Application Support on macOS. Not GetAppConfigDir: on Windows the
  RTL answers LOCALAPPDATA and names the folder after the executable, which
  would be tr4w_fpc for a developer build.

  WINDOWS ONLY. macOS and Linux already put every writable file in the
  operator's home and resolve exactly as before; there the probe never runs
  and every new query answers "not redirected". *)

type
   (* "Does this folder accept a new file?" -- injected so a test can say no
     without a read-only folder, which a unit test cannot make on Windows. *)
   TDirectoryProbe = function(const aDir: string): boolean;

(* The real probe: create, close and delete a uniquely named file in aDir.
  True only when all of that worked. Leaves nothing behind either way. *)
function DirectoryIsWritable(const aDir: string): boolean;

(* THE DECISION, as a function of its inputs -- what the cached Windows answer
  is computed from, and what the tests call.

    aProbe(aInstallDir) True   -> aInstallDir, not redirected. Nothing is
                                  created anywhere.
    otherwise                  -> aPerUserBase\TR4W\, created if missing;
                                  aCreated says THIS call made it, which is
                                  the run that tells the operator.
    no aPerUserBase, or the    -> aInstallDir, not redirected, and aProblem
    folder cannot be made         says why. Today's behaviour is the fallback,
                                  and the failures that follow are reported
                                  where they happen.

  The answer always ends in a separator. *)
function ChooseWritableRoot(const aInstallDir, aPerUserBase: string;
                            aProbe: TDirectoryProbe;
                            out aRedirected, aCreated: boolean;
                            out aProblem: string): string;

(* THE FIRST RUN UNDER %APPDATA% CARRIES THE INSTALL'S SETTINGS ACROSS.
  The installer's 32-bit migration copies an old install's settings\ into
  $INSTDIR\settings, and a redirected program would otherwise ignore them and
  start on defaults. Copies tr4w.json, tr4w.ini and tr4w.pos from
  aInstallDir\settings\ to aRoot\settings\, each ONLY when the destination
  does not have one. Never deletes or changes the install's copy. Returns
  the names it copied, comma-separated, '' for none. *)
function SeedPerUserSettings(const aInstallDir, aRoot: string): string;

(* True when this run's writable files live under %APPDATA%\TR4W. False off
  Windows and whenever the program folder is writable. *)
function WritableFilesRedirected: boolean;

(* Where this run writes: the per-user root when redirected, the program
  folder otherwise (with a trailing separator). Off Windows, '' -- there is
  no single root there; ask the per-kind accessors. *)
function WritableFilesRoot: string;

(* FOR tr4wconvert'S "settings\ beside the binary" RULE: may that folder be
  used? On Windows, only when the binary's folder accepts new files -- the
  installer creates $INSTDIR\settings, so under C:\Program Files the folder
  EXISTS and the program, redirected, never reads it. Off Windows always
  True: the portable rule there is unchanged. *)
function PortableFolderUsable(const aBinaryDir: string): boolean;

(* Why the redirect could not be made, '' when nothing went wrong. *)
function WritableRootProblem: string;

(* THE OPERATOR IS TOLD ONCE -- ONCE PER PER-USER ROOT, NOT ONCE PER RUN.

  NOT "the run that created the root": tr4wconvert, run first as the
  installer tells an upgrading operator to, resolves the same root and would
  create it, and the program would then never say where the files went. So
  the root carries a short text file, WRITABLE_ROOT_NOTE, written when the
  program has told the operator; it also explains the folder to anyone who
  finds it by browsing. Due = redirected and that file absent.

  TakeWritableRootNotice answers True at most once per run and records the
  note when it does. aInstallDir is the folder that refused, aRoot where TR4W
  writes now, aCopied what SeedPerUserSettings carried ('' for none). *)
const
   WRITABLE_ROOT_NOTE = 'WHY TR4W FILES ARE HERE.txt';

function WritableRootNoticeDue(aRedirected: boolean; const aRoot: string): boolean;
procedure RecordWritableRootNotice(const aRoot, aInstallDir: string);
function TakeWritableRootNotice(out aInstallDir, aRoot, aCopied: string): boolean;

(* THE FOLDER THE OLD STATION-STATE FILES ARE WRITTEN BESIDE -- tr4w.pos
  (under its settings\), bandmap.bin, the dvk\ recordings, dxcluster\.

  These were composed from TR4W_PATH_NAME, which is DataDir, the READ-ONLY
  tier. On Windows that is the program folder, so this answers the writable
  root: unchanged when the folder is writable, %APPDATA%\TR4W\ when it is
  not. OFF WINDOWS IT IS DataDir, EXACTLY AS BEFORE -- moving them there is
  a separate decision (they are still written inside a .app bundle or an
  AppImage mount, which is an open defect, not this change). *)
function StationStateDir: string;

(* ------------------------------------------------------------------------
  ONE ANSWER PER KIND OF FILE TR4W WRITES (NY4I, 2026-11-20: "all writes
  should be centralized as much as possible, or at least the path name
  generation"). Each kind maps onto an accessor above, so the answer on
  every platform is the one that accessor already gave:

    wfSettings        SettingsDir          tr4w.json, tr4w.ini, ssl\
    wfDiagnosticLog   LogDir               tr4w.log, tr4w-early.log,
                                           hamlib_trace.log
    wfCrashLog        LogDir               a crash report goes to tr4w.log
    wfContestLog      ContestDir           the contest .db and its .cfg
    wfBackup          BackupDir            a contest log's backups
    wfDownload        DownloadedDataDir    CTY.DAT, TRMASTER.DTA, call history
    wfStationState    StationStateDir      tr4w.pos's folder, bandmap.bin,
                                           dvk\, dxcluster\

  EXPORTS AND REPORTS (ADIF, Cabrillo, the summary sheet, the 3830 score)
  are NOT a kind: they go BESIDE THE CONTEST LOG, wherever that is, and
  BesideContestLogFilePath composes that. A log under %APPDATA% takes its
  exports with it. *)
type
   TWrittenFileKind = (wfSettings, wfDiagnosticLog, wfCrashLog, wfContestLog,
                       wfBackup, wfDownload, wfStationState);

function WrittenFileDir(aKind: TWrittenFileKind): string;
function WrittenFilePath(aKind: TWrittenFileKind; const aName: string): string;

(* aName in the contest log's own folder. aLogPath is the log's full path;
  when it names no folder the answer is aName alone, which is what a caller
  composing ExtractFilePath(aLogPath) + aName produced. *)
function BesideContestLogFilePath(const aLogPath, aName: string): string;

implementation

uses SysUtils, StrUtils, Classes;

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

(* ------------------------------------------------------------------------
  THE WRITABLE-ROOT DECISION. Plain RTL, compiled everywhere so the tests
  run on every platform; only the Windows arm below ever ASKS it.
  ------------------------------------------------------------------------ *)

var
   GProbeCounter: integer = 0;

function DirectoryIsWritable(const aDir: string): boolean;
var
   probe: string;
   h: THandle;
begin
   Result := False;
   if (aDir = '') or (not DirectoryExists(aDir)) then
      begin
      Exit;
      end;

   (* A name nothing else uses: the process id and a counter, so two copies
     of TR4W starting together, or two probes in one run, cannot collide. *)
   Inc(GProbeCounter);
   probe := IncludeTrailingPathDelimiter(aDir) + '.tr4w-write-probe-'
            + IntToStr(GetProcessID) + '-' + IntToStr(GProbeCounter) + '.tmp';

   h := FileCreate(probe);
   if h = feInvalidHandle then
      begin
      Exit;
      end;
   FileClose(h);
   Result := True;
   DeleteFile(probe);
end;

function ChooseWritableRoot(const aInstallDir, aPerUserBase: string;
                            aProbe: TDirectoryProbe;
                            out aRedirected, aCreated: boolean;
                            out aProblem: string): string;
var
   root: string;
begin
   aRedirected := False;
   aCreated    := False;
   aProblem    := '';
   Result      := IncludeTrailingPathDelimiter(aInstallDir);

   if aProbe(aInstallDir) then
      begin
      Exit;
      end;

   if aPerUserBase = '' then
      begin
      aProblem := 'the program folder ' + Result + ' does not accept new files '
                  + 'and APPDATA is not set, so there is nowhere else to write';
      Exit;
      end;

   root := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(aPerUserBase) + 'TR4W');
   if not DirectoryExists(root) then
      begin
      if not ForceDirectories(root) then
         begin
         aProblem := 'the program folder ' + Result + ' does not accept new '
                     + 'files and ' + root + ' could not be created';
         Exit;
         end;
      aCreated := True;
      end;

   aRedirected := True;
   Result      := root;
end;

(* A byte copy that refuses to overwrite. A seed that failed is reported by
  leaving the name out of the answer; the program then starts as a fresh
  install would, which is not a reason to stop it. *)
function CopyIfAbsent(const aSource, aTarget: string): boolean;
var
   src, dst: TFileStream;
begin
   Result := False;
   if (not FileExists(aSource)) or FileExists(aTarget) then
      begin
      Exit;
      end;
   try
      src := TFileStream.Create(AnsiString(aSource), fmOpenRead or fmShareDenyWrite);
      try
         dst := TFileStream.Create(AnsiString(aTarget), fmCreate);
         try
            dst.CopyFrom(src, 0);
         finally
            dst.Free;
         end;
      finally
         src.Free;
      end;
      Result := True;
   except
      on E: EStreamError do
         begin
         Result := False;
         end;
   end;
end;

function SeedPerUserSettings(const aInstallDir, aRoot: string): string;
const
   SEEDED: array[0..2] of string = ('tr4w.json', 'tr4w.ini', 'tr4w.pos');
var
   fromDir, toDir: string;
   i: integer;
begin
   Result  := '';
   fromDir := IncludeTrailingPathDelimiter(aInstallDir) + 'settings' + PathDelim;
   if not DirectoryExists(fromDir) then
      begin
      Exit;
      end;
   toDir := EnsureDir(IncludeTrailingPathDelimiter(aRoot) + 'settings');

   for i := Low(SEEDED) to High(SEEDED) do
      begin
      if CopyIfAbsent(fromDir + SEEDED[i], toDir + SEEDED[i]) then
         begin
         if Result <> '' then
            begin
            Result := Result + ', ';
            end;
         Result := Result + SEEDED[i];
         end;
      end;
end;

var
   (* The cached Windows answer. Resolved on first use, never re-asked: a
     run that changed its mind half way would write half its files in each
     place. *)
   GRootResolved:   boolean = False;
   GRootRedirected: boolean = False;
   GRootCreated:    boolean = False;
   GRootNoticeTaken: boolean = False;
   GRoot:           string  = '';
   GRootInstallDir: string  = '';
   GRootProblem:    string  = '';
   GRootCopied:     string  = '';

{$IFDEF WINDOWS}

{ The working directory -- the same rule TR4W_PATH_NAME has always used. }
function AppDir: string;
begin
   Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

procedure ResolveWritableRoot;
begin
   if GRootResolved then
      begin
      Exit;
      end;
   GRootResolved   := True;
   GRootInstallDir := AppDir;
   GRoot := ChooseWritableRoot(GRootInstallDir, GetEnvironmentVariable('APPDATA'),
                               @DirectoryIsWritable, GRootRedirected,
                               GRootCreated, GRootProblem);
   if GRootRedirected and GRootCreated then
      begin
      GRootCopied := SeedPerUserSettings(GRootInstallDir, GRoot);
      end;
end;

(* THE PROGRAM FOLDER, LIVE, WHEN IT IS WRITABLE -- not a cached copy of it.
  AppDir is the working directory and has always been asked afresh on each
  call; answering a cached string instead would be a change nobody asked for. *)
function WindowsWritableRoot: string;
begin
   ResolveWritableRoot;
   if GRootRedirected then
      begin
      Result := GRoot;
      end
   else
      begin
      Result := AppDir;
      end;
end;

function DataFilePath(const aName: string): string;
begin
   Result := AppDir + aName;
end;

function SettingsFilePath(const aName: string): string;
begin
   Result := EnsureDir(WindowsWritableRoot + 'settings') + aName;
end;

function LogFilePath(const aName: string): string;
begin
   Result := WindowsWritableRoot + aName;
end;

(* DataDir STAYS THE PROGRAM FOLDER: it is the read-only tier. *)
function DataDir: string;     begin Result := AppDir; end;
function SettingsDir: string; begin Result := EnsureDir(WindowsWritableRoot + 'settings'); end;
function LogDir: string;      begin Result := WindowsWritableRoot; end;
function StationStateDir: string; begin Result := WindowsWritableRoot; end;

(* THE BINARY'S OWN DIRECTORY, NOT AppDir. AppDir is the working directory
  here, which is right for data and wrong for libraries: the loader resolves a
  DLL beside the executable no matter where TR4W was started from. *)
function PrivateLibraryDir: string;
begin
   Result := ExtractFilePath(ParamStr(0));
end;
(* Beside the binary, exactly as it has always been -- unless the program
  folder refuses writes, when the contests go to the per-user root with the
  rest of the writable files. See the interface note. *)
function ContestDir: string;  begin Result := WindowsWritableRoot; end;
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

(* DataDir, exactly what TR4W_PATH_NAME composed before -- see the interface
  note. Unchanged on purpose. *)
function StationStateDir: string; begin Result := DataDir; end;

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

(* DataDir, exactly what TR4W_PATH_NAME composed before -- see the interface
  note. Unchanged on purpose. *)
function StationStateDir: string;
begin
   Result := DataDir;
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

(* THE WRITABLE SETTINGS DIRECTORY AS THIS RUN SEES IT: SettingsDir, unless
  --settings named a file elsewhere, in which case that file's directory.
  One answer for every writable file that belongs with the settings -- a
  download and a backup -- so the two cannot disagree about where --settings
  moved them. *)
function WritableSettingsDirFor(const aOverride, aDefault: string): string;
begin
   if aOverride = '' then
      begin
      Result := aDefault;
      Exit;
      end;

   (* ExpandFileName FIRST.  --settings may name a file with no directory at
     all, and ExtractFilePath of that is the empty string -- which would put a
     downloaded country file wherever the program happened to be started from
     rather than beside the settings it belongs to. *)
   Result := EnsureDir(ExtractFilePath(ExpandFileName(aOverride)));
end;

function WritableSettingsDir: string;
var
   settingsFile: string;
begin
   settingsFile := SettingsFileOverride;
   if settingsFile = '' then
      begin
      (* Only asked when there is no override, exactly as before: SettingsDir
        creates its folder. *)
      Result := SettingsDir;
      Exit;
      end;
   Result := WritableSettingsDirFor(settingsFile, '');
end;

function DownloadedDataDir: string;
begin
   Result := WritableSettingsDir;
end;

function BackupDir: string;
begin
   Result := EnsureDir(WritableSettingsDir + 'backup');
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

function ShippedDomFilePath(const aName: string): string;
begin
   if ShippedDomDirOverride <> '' then
      begin
      Result := ExistingDataFile(IncludeTrailingPathDelimiter(ShippedDomDirOverride) + aName);
      end
   else
      begin
      Result := ExistingDataFile(DataFilePath('dom' + PathDelim + aName));
      end;
end;

function MissingInstallParts: string;
   procedure Add(const aName: string);
   begin
      if Result <> '' then
         begin
         Result := Result + LineEnding;
         end;
      Result := Result + aName;
   end;
begin
   Result := '';
   if not DirectoryExists(DataFilePath('dom')) then
      begin
      Add('dom' + PathDelim);
      end;
   if not FileExists(PreferredDataFilePath('CTY.DAT')) then
      begin
      Add('CTY.DAT');
      end;
   if not FileExists(PreferredDataFilePath('TRMASTER.DTA')) then
      begin
      Add('TRMASTER.DTA');
      end;
end;

function BesideProgramFilePath(const aName: string): string;
begin
{$IFDEF DARWIN}
   Result := BundleResources + aName;
{$ELSE}
   Result := ExtractFilePath(ParamStr(0)) + aName;
{$ENDIF}
end;

function HelpDir: string;
var
   beside: string;
begin
   Result := DataFilePath('help');
   if DirectoryExists(Result) then
      begin
      Exit;
      end;
   beside := BesideProgramFilePath('help');
   if DirectoryExists(beside) then
      begin
      Result := beside;
      end;
end;

(* ------------------------------------------------------------------------
  THE REDIRECT, AS THE REST OF THE PROGRAM ASKS ABOUT IT. Off Windows the
  decision is never made, so every answer is "not redirected".
  ------------------------------------------------------------------------ *)

function WritableFilesRedirected: boolean;
begin
{$IFDEF WINDOWS}
   ResolveWritableRoot;
   Result := GRootRedirected;
{$ELSE}
   Result := False;
{$ENDIF}
end;

function WritableFilesRoot: string;
begin
{$IFDEF WINDOWS}
   Result := WindowsWritableRoot;
{$ELSE}
   Result := '';
{$ENDIF}
end;

function PortableFolderUsable(const aBinaryDir: string): boolean;
begin
{$IFDEF WINDOWS}
   Result := DirectoryIsWritable(aBinaryDir);
{$ELSE}
   Result := True;
{$ENDIF}
end;

function WritableRootProblem: string;
begin
{$IFDEF WINDOWS}
   ResolveWritableRoot;
{$ENDIF}
   Result := GRootProblem;
end;

function WritableRootNoticeDue(aRedirected: boolean; const aRoot: string): boolean;
begin
   Result := aRedirected and (aRoot <> '')
             and (not FileExists(IncludeTrailingPathDelimiter(aRoot) + WRITABLE_ROOT_NOTE));
end;

procedure RecordWritableRootNotice(const aRoot, aInstallDir: string);
var
   note: TStringList;
begin
   note := TStringList.Create;
   try
      note.Add('TR4W keeps its settings, its diagnostic log (tr4w.log) and');
      note.Add('new contest logs in this folder because the folder it is');
      note.Add('installed in does not accept new files:');
      note.Add('');
      note.Add(AnsiString('    ' + aInstallDir));
      note.Add('');
      note.Add('TR4W still reads its shipped files (CTY.DAT, TRMASTER.DTA, dom\,');
      note.Add('help\) from that folder. Installing TR4W in a folder you can');
      note.Add('write to, such as C:\tr4w, keeps everything in one place.');
      try
         note.SaveToFile(AnsiString(IncludeTrailingPathDelimiter(aRoot) + WRITABLE_ROOT_NOTE));
      except
         on E: EStreamError do
            begin
            (* Not fatal: the operator is told again next run, which is the
              honest outcome of a note that could not be kept. *)
            end;
      end;
   finally
      note.Free;
   end;
end;

function TakeWritableRootNotice(out aInstallDir, aRoot, aCopied: string): boolean;
begin
{$IFDEF WINDOWS}
   ResolveWritableRoot;
{$ENDIF}
   aInstallDir := GRootInstallDir;
   aRoot       := GRoot;
   aCopied     := GRootCopied;
   Result := (not GRootNoticeTaken) and WritableRootNoticeDue(GRootRedirected, GRoot);
   if Result then
      begin
      GRootNoticeTaken := True;
      RecordWritableRootNotice(GRoot, GRootInstallDir);
      end;
end;

function WrittenFileDir(aKind: TWrittenFileKind): string;
begin
   case aKind of
      wfSettings:
         begin
         Result := SettingsDir;
         end;
      wfDiagnosticLog, wfCrashLog:
         begin
         Result := LogDir;
         end;
      wfContestLog:
         begin
         Result := ContestDir;
         end;
      wfBackup:
         begin
         Result := BackupDir;
         end;
      wfDownload:
         begin
         Result := DownloadedDataDir;
         end;
   else
      begin
      Result := StationStateDir;
      end;
   end;
   Result := IncludeTrailingPathDelimiter(Result);
end;

function WrittenFilePath(aKind: TWrittenFileKind; const aName: string): string;
begin
   Result := WrittenFileDir(aKind) + aName;
end;

function BesideContestLogFilePath(const aLogPath, aName: string): string;
begin
   Result := ExtractFilePath(aLogPath) + aName;
end;

end.
