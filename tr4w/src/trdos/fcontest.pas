{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit FCONTEST;
{$I ..\tr4w.inc}

{ PLEASE NOTE!!  This file is included with the TR Logging Program as a
  reference document.  It is intended to show you the default values for
  the different contests supported by the program.

  Changing parameters in this file will have no effect on the operation
  of TR or POST.

  Most variable names are the same as their LOGCFG commands, but in
  some cases, they are slightly different. }

{$IMPORTEDDATA OFF}

interface

uses
  VC,
  TF,
  uAppPaths,      // ExistingDataFile / DownloadedDataFilePath -- where data lives
  utils_text,
  uCallSignRoutines,
  uRussiaOblasts,
  uCTYDAT,
  utils_file,
  PostUnit,
  LogDom,
  Tree,
  LogCW,
  LogWind,
  LogDupe,
  ZoneCont;

const
  { TYPED, so appending it to an AnsiString is not a narrowing conversion.
    A bare '.dom' is a UnicodeString literal in this tree and the ratchet
    counts every one of those. }
  DOM_EXTENSION: AnsiString = '.dom';
//  Help,
//  Country9;

var
  (* IS THE STATION IN THE OPEN QSO PARTY'S HOST STATE? -- M5b, 2026-10-02.

    Written once, by FoundContest's head, from the same FoundMyStateInDomFile
    answer that chooses the in-state or the out-of-state domestic file -- so
    the rule a party applies to a received exchange and the table that
    exchange was looked up in are one decision, not two. False for a contest
    that is not a state party. uContestFactory hands it to the contest as
    TStationContext.InHostState; nothing else reads it. *)
  StationInHostState: boolean = False;

function FoundContest(CMD: ShortString): boolean;
procedure SetUpFileNames;
procedure RecalculateMyCountryContinentAndZone;
procedure RecalculateMyCountryContinentAndZoneNew(Call: CallString);
procedure SetContestTitle;
procedure Add_KVEKH6KL;
procedure Add_KVE;
procedure AddRussianDomesticCountrys;
function FoundMyStateInDomFile: boolean;

procedure SetUpNameAndStateExchange;
procedure SetUpRSTQSONumberExchange;
procedure SetUpRSTMyStateExchange;
procedure SetUpRSTMyZoneExchange;

implementation

uses
   uSettingsModel,     // Settings.Bands -- HF / VHF / WARC enables
   (* ContestIdentity -- the contest object set-up reads -- and
      ReplayContestStatements, the operator's half of ApplyContestTraits. *)
   uContestBase,
   uContestRegistry,
   (* CurrentStation -- the station DescribeSession is handed (M7a). *)
   uContestFactory,
   uSettingsEffects,
   uDomFileKeys,       // FoundMyStateInDomFile's reading rule
   SysUtils,      // ExtractFilePath/ExtractFileName -- see SetUpFileNames
   uConfigValues, LogGrid,
  LogStuff,
  MainUnit,
  LogSCP; {KK1L: 6.71 attempt to get POST to compile. Moved here from INTERFACE section.}

procedure SetUpFileNames;
var
  i: integer;
  chosenPath: string;
  chosenDir:  string;
  chosenName: string;
  chosenStem: string;
  dotPos:     integer;
  candidate:  string;   (* the file a tier proposes -- see the CTY.DAT note *)
  source:     string;   (* which tier won, for the log line *)
begin

  (* PathDelim: this file is WRITTEN as well as read, so the separator has to
    be right when the name is built. Resolving it afterwards only helps a file
    that already exists -- see the note in uTelnet. *)
  SetCharBuffer(TR4W_POS_FILENAME,
                CharBufferText(TR4W_PATH_NAME) + 'settings' + PathDelim + 'tr4w.pos');
  ResolveDataFileInPlace(TR4W_POS_FILENAME);
  SetCharBuffer(TR4W_BANDMAPBIN_FILENAME,
                CharBufferText(TR4W_PATH_NAME) + 'bandmap.bin');

  //  asm push offset TR4W_PATH_NAME  end;
  //  wsprintf(TR4W_IODRIVER_FILENAME, '%sTR4WIO.SYS');
  //  asm add esp,12  end;

  SetCharBuffer(TR4W_COMM_HELP_FILENAME,
                CharBufferText(TR4W_PATH_NAME) + 'commands_help_' + LANG + '.ini');

  (* SPLIT THE CHOSEN CONTEST FILE INTO ITS DIRECTORY AND ITS STEM.

    THIS WAS A BACKWARD WALK LOOKING FOR A BACKSLASH, and it is the single
    defect behind "every US callsign is DX" on Linux (NY4I, 2026-09-09). The
    loop scanned back through the path stopping at '\' for the directory
    boundary and truncating at '.' for the extension. On Unix there is no
    backslash, so it NEVER STOPPED: it chewed backwards through the whole
    path, truncating at every dot it met, and the leftmost one won.

        chosen  /home/toms/Desktop/TR4W/tr4w-5.0.2-x86_64-linux/ARRL-FD ... .db
        became  /home/toms/Desktop/TR4W/tr4w-5

    Everything downstream followed it off a cliff. The log database opened as
    tr4w-5.db instead of the contest the operator picked, so the contest was
    never loaded, so CONTEST = ARRL-FD never reached FoundContest, so
    AddARRLSectionDomesticCountries never ran, so the domestic country list was
    empty -- and DomesticCountryCall answers "not domestic" for an empty list,
    which MEANS DX. A path separator produced a scoring failure five steps
    away, and the only visible symptom was an exchange prompt.

    ExtractFilePath and ExtractFileName are the platform's own answer and
    accept either separator on Windows, so the Windows behaviour is unchanged.

    THE FIRST DOT, NOT THE LAST, IS DELIBERATE. The old loop did not stop after
    stripping an extension, so a name with several dots was cut back to the
    first one. ChangeFileExt would cut back to the last, which is more
    sensible and would ALSO RENAME THE LOG of any existing contest whose file
    name contains more than one dot -- orphaning it. Matching the old rule
    keeps every log on disk findable; changing it is a migration, not a fix. *)
  chosenPath := CharBufferText(TR4W_CFG_FILENAME);
  chosenDir  := ExtractFilePath(chosenPath);
  chosenName := ExtractFileName(chosenPath);

  SetCharBuffer(TR4W_LOG_PATH_NAME, chosenDir);

  dotPos := Pos('.', chosenName);
  if dotPos > 0 then
     begin
     (* Only when there IS an extension, as before: a name without one left
       these three untouched and still does. *)
     chosenStem := chosenDir + Copy(chosenName, 1, dotPos - 1);
     SetCharBuffer(TR4W_LOG_FILENAME, chosenStem + '.TRW');
     SetCharBuffer(TR4W_DOM_FILENAME, chosenStem + '.DOM');
     end;

  SetCharBuffer(TR4W_SYN_FILENAME,
                CharBufferText(TR4W_LOG_PATH_NAME) + 'SERVERLOG.TMP');
  SetCharBuffer(TR4W_REMAININGMULTS_FILENAME,
                CharBufferText(TR4W_LOG_PATH_NAME) + 'REMAININGMULTS.TXT');

  (* THE COUNTRY FILE COMES FROM ONE OF THREE PLACES, IN THIS ORDER: the copy
    TR4W DOWNLOADED, a copy the operator put beside the contest, then the copy
    that SHIPPED.

    THE DOWNLOAD HAS TO COME FIRST.  On Windows the contest directory and the
    shipped directory ARE THE SAME DIRECTORY, so a downloaded file ranked below
    either of them could never be used at all -- the shipped cty.dat sitting in
    target\ would win over the update the operator had just asked for.

    It follows that an operator with BOTH a per-contest CTY.DAT and a
    downloaded one gets the downloaded one.  That is the less surprising of the
    two answers -- pressing Alt-O is an explicit request for the newest file --
    and the log line below says which copy was taken, so it is never a guess.

    ...AND EACH TIER ACCEPTS IT SPELLED cty.dat, WHICH IS HOW IT ARRIVES.  Two
    ways that name reaches the disk in lower case and only the first is ours to
    control: the repository tracks the shipped file as `cty.dat`, and the update
    an operator downloads from country-files.com is `cty.dat` too.  On Windows
    that has never mattered.  On Linux the program found nothing, fell through
    to its download path, and reported an OpenSSL failure -- an error naming the
    wrong subsystem entirely (NY4I, Linux Mint, 2026-09-09).  That tolerance was
    a single ResolveDataFileInPlace after the fact; it is ExistingDataFile per
    candidate now, because a tier has to be able to ANSWER in the case the file
    is actually spelled in or it will be skipped.

    SysUtils.FileExists explicitly: the unqualified name resolves to a legacy
    PAnsiChar-taking FileExists pulled in from the TRDOS units. *)
  candidate := ExistingDataFile(DownloadedDataFilePath('CTY.DAT'));
  source    := 'downloaded';

  if not SysUtils.FileExists(candidate) then
     begin
     candidate := ExistingDataFile(CharBufferText(TR4W_LOG_PATH_NAME) + 'CTY.DAT');
     source    := 'contest directory';
     end;

  if not SysUtils.FileExists(candidate) then
     begin
       // n4af issue  # 219  & 212
     candidate := ExistingDataFile(CharBufferText(TR4W_PATH_NAME) + 'CTY.DAT');
     source    := 'shipped';
     end;

  SetCharBuffer(TR4W_CTY_FILENAME, candidate);

  (* SAY WHICH ONE, ONCE.  Two locations with a precedence between them is a
    thing an operator has to be able to see from the log rather than deduce --
    "my update did nothing" and "my update took" look identical otherwise. *)
  if logger <> nil then
     begin
     logger.Info('[FCONTEST] Country file: %s (%s)', [candidate, source]);
     end;

  (* THE SAME FOUR-TIER RULE FOR THE CALL-HISTORY FILE, and for the same
    reason: a downloaded TRMASTER.DTA is written to the writable data
    directory, so it has to be looked for there first.  MASTER.DTA is the old
    K1EA name and stays last -- it is what an operator may already have, never
    what TR4W creates.

    The call-history file arrives spelled as many ways as the country file, so
    each tier is resolved case-tolerantly, as above. *)
  candidate := ExistingDataFile(DownloadedDataFilePath('TRMASTER.DTA'));
  source    := 'downloaded';

  if not SysUtils.FileExists(candidate) then
     begin
     candidate := ExistingDataFile(CharBufferText(TR4W_LOG_PATH_NAME) + 'TRMASTER.DTA');
     source    := 'contest directory';
     end;

  if not SysUtils.FileExists(candidate) then
     begin
     candidate := ExistingDataFile(CharBufferText(TR4W_PATH_NAME) + 'TRMASTER.DTA');
     source    := 'shipped';
     end;

  if not SysUtils.FileExists(candidate) then
     begin
     candidate := ExistingDataFile(CharBufferText(TR4W_PATH_NAME) + 'MASTER.DTA');
     source    := 'shipped (legacy MASTER.DTA)';
     end;

  SetCharBuffer(CD.ActiveFilename, candidate);

  if logger <> nil then
     begin
     logger.Info('[FCONTEST] Call history file: %s (%s)', [candidate, source]);
     end;

{$IF MAKE_DEFAULT_VALUES = false}

  (* THE MP3 DEFAULT IS GONE with the field it filled.  Nothing read it:
    the recorder that did was deleted along with its lame_enc.dll binding. *)

{$IFEND}

  //   CD.ActiveFilename := TR4W_PATH_NAME + 'TRMASTER.DTA';
  //  CTYDATFilename := TR4W_PATH_NAME + 'CTY.DAT';
  //  BandMapFileName := TR4W_PATH_NAME + 'BANDMAP.BIN';

  { TR4W_LOG_PATH_NAME := TempFoldername;
    if TempFoldername = '' then
    begin
      TempFoldername := TR4W_PATH_NAME;
    end
    else
    begin
      if FileExists(TempFoldername + 'CTY.DAT') then CTYDATFilename := TempFoldername + 'CTY.DAT';
      if FileExists(TempFoldername + 'TRMASTER.DTA') then CD.ActiveFilename := TempFoldername + 'TRMASTER.DTA';
    end;
  }
  //  LogConfigFileName := TempFoldername + FileRoot + '.CFG';
  //  LogRestartFileName := TempFoldername + FileRoot + '.RST';

  SetCharBuffer(TR4W_INTERCOM_FILENAME,
                CharBufferText(TR4W_LOG_PATH_NAME) + 'INTERCOM.TXT');
  SetCharBuffer(TR4W_DEFMESSAGES_FILENAME,
                CharBufferText(TR4W_PATH_NAME) + 'COMMONMESSAGES.INI');

end;

procedure SetUpRSTMyZoneExchange;
var
  OldMyZone: string;
const
  Code599 = '599';
begin
  OldMyZone := '';

  if Settings.My.State <> '' then
    if ActiveExchange = RSTZoneAndPossibleDomesticQTHExchange then
       begin
       OldMyZone := Settings.My.Zone;
       Settings.My.Zone := Settings.My.Zone + ' ' + string(Settings.My.State);
       end;

  Settings.Messages.CqExchangeCw := UTF8Encode(' ' + Code599 + ' ' + Settings.My.Zone);
  SetCQMemoryString(CW, F3, UTF8Encode(' ' + Code599 + ' ' + Settings.My.Zone));
  SetEXMemoryString(CW, F3, Code599);
  SetEXMemoryString(CW, F4, UTF8Encode(Settings.My.Zone));
  SetEXMemoryString(CW, F5, UTF8Encode('@ DE \ ' + Code599 + ' ' + Settings.My.Zone));
  SetEXMemoryString(CW, AltF3, 'RST?');
  SetEXMemoryString(CW, AltF4, 'NR?');
  Settings.Messages.RepeatSpExchangeCw :=
     UTF8Encode(' ' + Code599 + ' ' + Settings.My.Zone + ' ' + Settings.My.Zone);
  Settings.Messages.SpExchangeCw := UTF8Encode(' ' + Code599 + ' ' + Settings.My.Zone);

  if OldMyZone <> '' then
     begin
     Settings.My.Zone := OldMyZone;
     end;
end;

procedure SetUpNameAndStateExchange;
begin
  Settings.Messages.CqExchangeCw := UTF8Encode(' ' + Settings.My.Name + ' ' + Settings.My.State);
  Settings.Messages.RepeatSpExchangeCw := Settings.Messages.CqExchangeCw;
  Settings.Messages.SpExchangeCw := Settings.Messages.CqExchangeCw;
end;

procedure SetUpRSTMyStateExchange;
begin
  Settings.Messages.CqExchangeCw := UTF8Encode(' 5NN ' + Settings.My.State);
  Settings.Messages.RepeatSpExchangeCw := UTF8Encode('5NN ' + Settings.My.State);
  Settings.Messages.SpExchangeCw := UTF8Encode('~ %5NN ' + Settings.My.State);

  SetCQMemoryString(CW, F3, UTF8Encode('5NN ' + Settings.My.State));

  SetEXMemoryString(CW, F3, '5NN');
  SetEXMemoryString(CW, F4, UTF8Encode(Settings.My.State));
  SetEXMemoryString(CW, F5, UTF8Encode('@ DE \ 5NN ' + Settings.My.State));
  SetEXMemoryString(CW, AltF3, 'RST?');
  SetEXMemoryString(CW, AltF4, 'QTH?');
end;

procedure SetUpRSTQSONumberExchange;
begin
  Settings.Messages.CqExchangeCw := ' 5NN #';
  Settings.Messages.RepeatSpExchangeCw := ' 5NN #';
  Settings.Messages.SpExchangeCw := ' 5NN #';
  SetCQMemoryString(CW, F3, '5NN #');

  SetEXMemoryString(CW, F3, '5NN');
  SetEXMemoryString(CW, F4, 'NR #');
  SetEXMemoryString(CW, F5, '@ DE \ 5NN #');
  SetEXMemoryString(CW, AltF3, 'RST?');
  SetEXMemoryString(CW, AltF4, 'NR?');

{$IF LANG = 'RUS'}
  SetEXCaptionMemoryString(CW, F4, '????? ?????');
  SetEXCaptionMemoryString(CW, F5, '??? ???????? + ?????');
{$ELSE}
  SetEXCaptionMemoryString(CW, F4, 'NR');
  SetEXCaptionMemoryString(CW, F5, 'Cl+Ex');
{$IFEND}

  SetEXCaptionMemoryString(CW, F3, 'RST');
end;

(* ADDS EACH COUNTRY OF A LIST, IN ORDER -- the one loop behind the named
  groups below and the applier. The groups themselves are uContestBase's
  constants, which a contest class names too (M7a): one list, two readers. *)
procedure AddDomesticCountryList(const aIDs: array of string);
var
  i: integer;
begin
  for i := Low(aIDs) to High(aIDs) do
     begin
     AddDomesticCountry(CallString(aIDs[i]));
     end;
end;

procedure AddARRLSectionDomesticCountries;
begin
  AddDomesticCountryList(DomesticCountriesARRLSections);
end;

(* THE ENGINE'S KEY CODE FOR A MEMORY A CONTEST NAMES -- see
  uContestBase.TSessionMemoryKey. Tree's constants, assigned exactly as the
  arms passed them. *)
function EngineMemoryKey(aKey: TSessionMemoryKey): AnsiChar;
begin
  case aKey of
    smkF1: Result := F1;
    smkF2: Result := F2;
    smkF3: Result := F3;
    smkF4: Result := F4;
    smkF5: Result := F5;
    smkF6: Result := F6;
    smkF7: Result := F7;
    smkF8: Result := F8;
    smkAltF1: Result := AltF1;
    smkAltF2: Result := AltF2;
    smkAltF3: Result := AltF3;
    smkAltF4: Result := AltF4;
    smkAltF5: Result := AltF5;
    smkAltF6: Result := AltF6;
    smkAltF7: Result := AltF7;
  else
    Result := F1;
  end;
end;

(* THE ONE WRITER OF WHAT A CONTEST'S SET-UP STATES -- M7a, 2026-10-02.

  The contest filled aSession (TContestBase.DescribeSession) and wrote
  nothing; this writes each value it STATED, and nothing it did not -- so a
  contest that names no exchange leaves the head's exchange exactly as
  ApplyContestTraits and the operator's statements left it. A stated value
  overwrites unconditionally, which is what the contest's FoundContest arm
  did, so today's precedence is unchanged: it beats a statement made before
  the CONTEST line and loses to one made after it.

  aDomesticFileName is FoundContest's local, the name the foot of that
  routine writes to DOMESTIC FILENAME; an empty one writes nothing.

  THE ORDER: the engine's choices, the settings, MY STATE, the domestic
  file, the domestic countries (in the contest's order), the shared
  RST-and-serial memories when asked for, the contest's own memories (in
  its order), then the messages. No value here reads another, and no arm
  wrote one value twice except a memory, whose order the list keeps. *)
procedure ApplySessionDefaults(aSession: TSessionDefaults;
                               var aDomesticFileName: string);
var
  i: integer;
  memory: TSessionMemory;
begin
  if aSession.IsStated(svExchange) then
     begin
     ActiveExchange := aSession.Exchange;
     end;
  if aSession.IsStated(svDomesticMult) then
     begin
     ActiveDomesticMult := aSession.DomesticMult;
     end;
  if aSession.IsStated(svDXMult) then
     begin
     ActiveDXMult := aSession.DXMult;
     end;
  if aSession.IsStated(svPrefixMult) then
     begin
     ActivePrefixMult := aSession.PrefixMult;
     end;
  if aSession.IsStated(svBand) then
     begin
     ActiveBand := aSession.Band;
     end;
  if aSession.IsStated(svMode) then
     begin
     ActiveMode := aSession.Mode;
     end;
  if aSession.IsStated(svDomesticMultByBand) then
     begin
     DomesticMultByBand := aSession.DomesticMultByBand;
     end;
  if aSession.IsStated(svAllowDupeQSOs) then
     begin
     tAllowDupeQSOs := aSession.AllowDupeQSOs;
     end;

  if aSession.IsStated(svMultByBand) then
     begin
     Settings.Mult.ByBand := aSession.MultByBand;
     end;
  if aSession.IsStated(svQSOByMode) then
     begin
     Settings.Qso.ByMode := aSession.QSOByMode;
     end;
  if aSession.IsStated(svQSOByBand) then
     begin
     Settings.Qso.ByBand := aSession.QSOByBand;
     end;
  if aSession.IsStated(svWARCEnabled) then
     begin
     Settings.Bands.WarcEnabled := aSession.WARCEnabled;
     end;
  if aSession.IsStated(svHFEnabled) then
     begin
     Settings.Bands.HfEnabled := aSession.HFEnabled;
     end;
  if aSession.IsStated(svLiteralDomesticQTH) then
     begin
     Settings.Contest.LiteralDomesticQth := aSession.LiteralDomesticQTH;
     end;
  if aSession.IsStated(svDigitalModeEnable) then
     begin
     Settings.Contest.DigitalModeEnable := aSession.DigitalModeEnable;
     end;
  if aSession.IsStated(svExchangeMemoryEnable) then
     begin
     Settings.Contest.ExchangeMemoryEnable := aSession.ExchangeMemoryEnable;
     end;
  if aSession.IsStated(svSprintQSYRule) then
     begin
     Settings.Contest.SprintQsyRule := aSession.SprintQSYRule;
     end;
  if aSession.IsStated(svMultipleBands) then
     begin
     Settings.Contest.MultipleBands := aSession.MultipleBands;
     end;
  if aSession.IsStated(svMultipleModes) then
     begin
     Settings.Contest.MultipleModes := aSession.MultipleModes;
     end;
  if aSession.IsStated(svInitialExchangeOverwrite) then
     begin
     Settings.Contest.InitialExchangeOverwrite := aSession.InitialExchangeOverwrite;
     end;
  if aSession.IsStated(svQSONumberByBand) then
     begin
     Settings.Contest.QsoNumberByBand := aSession.QSONumberByBand;
     end;
  if aSession.IsStated(svMinitourDuration) then
     begin
     Settings.Contest.MinitourDuration := aSession.MinitourDuration;
     end;
  if aSession.IsStated(svContactsPerPage) then
     begin
     Settings.Contest.ContactsPerPage := aSession.ContactsPerPage;
     end;
  if aSession.IsStated(svQTCEnable) then
     begin
     Settings.Qtc.Enable := aSession.QTCEnable;
     end;
  if aSession.IsStated(svRfoblMode) then
     begin
     Settings.Contest.RfoblMode := aSession.RfoblMode;
     end;
  if aSession.IsStated(svAutoDupeEnableCQ) then
     begin
     Settings.AutoDupe.EnableCq := aSession.AutoDupeEnableCQ;
     end;
  if aSession.IsStated(svAutoDupeEnableSAndP) then
     begin
     Settings.AutoDupe.EnableSAndP := aSession.AutoDupeEnableSAndP;
     end;
  if aSession.IsStated(svContestName) then
     begin
     Settings.Contest.Name := aSession.ContestName;
     end;
  if aSession.IsStated(svMyState) then
     begin
     Settings.My.State := aSession.MyState;
     end;
  if aSession.IsStated(svDomesticFile) then
     begin
     aDomesticFileName := aSession.DomesticFile;
     end;

  for i := 0 to aSession.DomesticCountryCount - 1 do
     begin
     AddDomesticCountry(CallString(aSession.DomesticCountry(i)));
     end;

  if aSession.IsStated(svRSTQSONumberExchangeMemories) then
     begin
     SetUpRSTQSONumberExchange;
     end;

  for i := 0 to aSession.MemoryCount - 1 do
     begin
     memory := aSession.Memory(i);
     if memory.Bank = smbCQ then
        begin
        SetCQMemoryString(memory.Mode, EngineMemoryKey(memory.Key), UTF8Encode(memory.Text));
        end
     else
        begin
        SetEXMemoryString(memory.Mode, EngineMemoryKey(memory.Key), UTF8Encode(memory.Text));
        end;
     end;

  if aSession.IsStated(svCQExchangeCW) then
     begin
     Settings.Messages.CqExchangeCw := aSession.CQExchangeCW;
     end;
  if aSession.IsStated(svSPExchangeCW) then
     begin
     Settings.Messages.SpExchangeCw := aSession.SPExchangeCW;
     end;
  if aSession.IsStated(svRepeatSPExchangeCW) then
     begin
     Settings.Messages.RepeatSpExchangeCw := aSession.RepeatSPExchangeCW;
     end;
  if aSession.IsStated(svQSLCW) then
     begin
     Settings.Messages.QslCw := aSession.QSLCW;
     end;
  if aSession.IsStated(svQuickQSLCW1) then
     begin
     Settings.Messages.QuickQslCw1 := aSession.QuickQSLCW1;
     end;
  if aSession.IsStated(svQSOBeforeCW) then
     begin
     Settings.Messages.QsoBeforeCw := aSession.QSOBeforeCW;
     end;
  if aSession.IsStated(svCallOkNowCW) then
     begin
     Settings.Messages.CallOkNowCw := aSession.CallOkNowCW;
     end;
end;

(* WHAT A CONTEST'S SET-UP STARTS FROM, AND THE ONE PLACE IT IS WRITTEN -- M2,
  2026-10-01 (docs/CONTEST_OWNERSHIP_DESIGN.md section 4.2).

  THE PRECEDENCE, FOR EVERY VALUE HERE:
    1. what the OPERATOR STATED (TR4WSettings.CommandIsStated -- a .cfg line,
       the New Contest dialog, Preferences, Alt-P, a peer, the log's own
       statements);
    2. otherwise what the CONTEST says -- aContest, which is
       uContestRegistry.ContestIdentity: the registered class, or a plain
       TContestBase reading the row for a contest that has none.
  Never ContestsArray or ContestsBooleanArray directly: the class is the
  single source, and its getters default to the arrays until it states its
  own.

  WHAT CHANGED, AND WHAT DID NOT. Before M2 the head copied the arrays and an
  operator's statement won only because it was APPLIED LATER -- a .cfg line
  after CONTEST re-ran its setter after this. That still happens. What is new
  is that a statement made BEFORE the CONTEST line is no longer overwritten
  here: it used to be, for every one of these values, which is "operator beats
  contest" holding by accident of line order. What a contest states in its
  DescribeSession (M7a; a classless contest's FoundContest arm until it has a
  class) still runs AFTER this and still overwrites what the arm always
  overwrote -- see ApplySessionDefaults.

  THE SEVEN Active* TOKENS ARE REPLAYED, NOT LEFT ALONE. Their statement lives
  in a settings property, but the engine reads a global, and the global can
  disagree with the property: the log's reapply records a statement that
  equals the value in force without assigning anything, so no setter ran.
  uSettingsEffects.ReplayContestStatements runs the very arm a .cfg line runs,
  side effects included (ZONE MULTIPLIER also sets the initial exchange and
  the zone list). The other values ARE their property, so a stated one is
  simply not assigned. *)
procedure ApplyContestTraits(aContest: TContestBase);
begin
  if not Settings.CommandIsStated('QSO BY MODE') then
     begin
     Settings.Qso.ByMode := aContest.QSOByMode;
     end;
  if not Settings.CommandIsStated('QSO BY BAND') then
     begin
     Settings.Qso.ByBand := aContest.QSOByBand;
     end;
  if not Settings.CommandIsStated('MULT BY MODE') then
     begin
     Settings.Mult.ByMode := aContest.MultByMode;
     end;
  if not Settings.CommandIsStated('MULT BY BAND') then
     begin
     Settings.Mult.ByBand := aContest.MultByBand;
     end;
  if not Settings.CommandIsStated('VHF BAND ENABLE') then
     begin
     Settings.Bands.VhfEnabled := aContest.VHFBandsEnabled;
     end;
  if not Settings.CommandIsStated('COUNT DOMESTIC COUNTRIES') then
     begin
     Settings.Contest.CountDomesticCountries := aContest.CountsDomesticCountries;
     end;

  (* CQ OR ITU ZONES, AS THE CONTEST STATES IT. This was a Boolean cast to
    ZoneModeType, which FPC evaluated to 255 for most contests -- no member
    at all, so CTY.DAT answered every zone 0. See TContestBase.GetZoneMode.
    A stated ZONE MULTIPLIER of CQ or ITU zones still overrides it below. *)
  CTY.ctyZoneMode := aContest.ZoneMode;

  ActiveQSOPointMethod := aContest.QSOPointMethod;
  ActiveExchange := aContest.ExchangeKind;
  ActiveInitialExchange := aContest.InitialExchangeKind;
  ActiveDomesticMult := aContest.DomesticMultiplierType;
  ActiveDXMult := aContest.DXMultiplierType;
  ActiveZoneMult := aContest.ZoneMultiplierType;
  ActivePrefixMult := aContest.PrefixMultiplierType;

  ReplayContestStatements;
end;

function FoundContest(CMD: ShortString): boolean;

var

  (* The first two characters of MY STATE -- the New England QSO Party arm. *)
  NewEnglandState: string;

  (* What this contest IS -- owned by uContestRegistry, never freed here. *)
  definition: TContestBase;

  (* What the contest wants its session to start from -- owned here. *)
  session: TSessionDefaults;

  TempDomesticQTHDataFileName: string;
  // i,j                                   : integer;
  // k                                     : str10;
begin
  CTY.ctyCountryMode := ARRLCountryMode;

  NoMultMarineMobile := False;
    {KK1L: 6.68 Added for WRTC 2002 as flag to not count /MM or /AM as mults or countries}

  Settings.Contest.Name := CMD;

  //  Contest := GetContestFromString(CMD);
  if Contest <> DUMMYCONTEST then
     begin
     definition := ContestIdentity(Contest);
     ApplyContestTraits(definition);

     RecalculateMyCountryContinentAndZoneNew(UTF8Encode(Settings.My.Call));

     StationInHostState := False;
     if definition.IsUSQSOParty then
        begin
        StationInHostState := FoundMyStateInDomFile;
        if StationInHostState then
           begin
           TempDomesticQTHDataFileName := definition.InStateDomesticFileName;
           Settings.Contest.Name := ContestTypeSA[Contest] + ' (in state)';
           end
        else
           begin
           (* THE OUT-OF-STATE FILE IS THE CONTEST'S DOMESTIC FILE -- the
             host's counties, the same file FoundMyStateInDomFile reads. It
             was built here as the in-state name plus '_cty', a second
             spelling of the same name; every party's row agrees with it
             since Colorado's was corrected, and
             Test_EveryQSOPartyNamesBothDomesticFiles holds them together. *)
           TempDomesticQTHDataFileName := definition.DomesticFileName;
           Settings.Contest.Name := ContestTypeSA[Contest] + ' (out of state)';
           MultipliersIsCounties := True;
           end;
        Add_KVEKH6KL;
        end
     else
        begin
        TempDomesticQTHDataFileName := definition.DomesticFileName;
        end;

     (* A STATED DOMESTIC FILENAME STANDS -- the same precedence as
       ApplyContestTraits. The foot of this routine writes the setting only
       when this local is not empty, so emptying it leaves the operator's
       file in place; an arm below that names a file still overwrites it, as
       an arm overwrites every value the head writes. *)
     if Settings.CommandIsStated('DOMESTIC FILENAME') then
        begin
        TempDomesticQTHDataFileName := '';
        end;

     (* THE CONTEST DESCRIBES ITS SESSION, AND THIS APPLIES IT -- M7a,
       2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md section 4.2).

       Every contest is asked -- a classless one's identity is a plain
       TContestBase, which states nothing -- and it is asked HERE, where the
       per-contest arms ran, so everything a contest states lands in the
       order it always did: after the head's traits and the operator's
       statements, before the closing exchange set-up below. The arms of
       every contest that has a class are gone into its DescribeSession;
       the `case` below holds only the classless contests' arms, each of
       which goes when its contest gains a class. *)
     session := TSessionDefaults.Create;
     try
        definition.DescribeSession(CurrentStation, session);
        ApplySessionDefaults(session, TempDomesticQTHDataFileName);
     finally
        session.Free;
        end;
     end;

  case Contest of

    { RSGBDX:
      begin
       if (Settings.My.Country[1] = 'G') or (Settings.My.Country[1] = 'M') then
        begin
         ActiveDXMult :=  CQDXCC;
         ActivePrefixMult := CQNonEuropeanCountriesAndWAECallRegions;
        end
         else
          begin
           ActiveDXMult := NoDXMults;
          end;;
      end;
    }
    JIDXSSB, JIDXCW:
      begin
        if Settings.My.Country = 'JA' then
           begin
           ActiveDXMult := ARRLDXCC;
           ActiveInitialExchange := ZoneInitialExchange;
           ActiveExchange := RSTZoneExchange;
           ActiveZoneMult := CQZones;
           end
        else
           begin
           ActiveDomesticMult := DomesticFile;
           ActiveExchange := RSTPrefectureExchange;
           TempDomesticQTHDataFileName := 'JIDX';
           end;

        //        Settings.Contest.Name := 'Japan International DX Test';
        //        CountryTable.ZoneMode := CQZoneMode;
      end;

    SOUTHAMERICANWW: //, SA-SSPRINT: // issue 177
      begin
        if MyContinent = SouthAmerica then
           begin
           ActivePrefixMult := NonSouthAmericanPrefixes
           end
        else
           begin
           ActivePrefixMult := SouthAmericanPrefixes;
           end;
      end;

    STEWPERRY:
      begin
        Settings.Contest.Name := 'STEW-PERRY'; // 4.76.6
        Settings.Messages.CqExchangeCw := UTF8Encode(' ' + Settings.My.Grid);
        Settings.Messages.SpExchangeCw := UTF8Encode(Settings.My.Grid);
        ActiveBand := Band160;
      end;

    ALLASIANCW, ALLASIANSSB:
      begin
        if MyContinent = Asia then
           begin
           ActiveDXMult := ARRLDXCC
           end
        else
           begin
           ActivePrefixMult := Prefix;
           end;
      end;

    YOTA:
      begin
        ActiveBand := Band80;
        //        VHFBandsEnabled := True;
      end;

    ARCI:
      begin
        //        Settings.Contest.Name := 'ARCI QSO PARTY';
        Add_KVEKH6KL;
      end;

    ARI_DX:
      begin
        //        Settings.Contest.Name := 'ARI International DX Contest';
        AddDomesticCountry('I');
        AddDomesticCountry('IS');
        AddDomesticCountry('*IT9'); //WLI
      end;

    ARRL10:
      begin
        ActiveBand := Band10;
        //        ActiveExchange := RSTDomesticOrDXQTHExchange;    4.106.6
        ActiveDXMult := ARRLDXCCWithNoARRLSections;
        //        Settings.Contest.Name := 'ARRL Ten Meter Contest';
         //       Settings.Contest.ExchangeMemoryEnable := False;      // 4.106.4
        Settings.Contest.MultipleBands := False;
        Add_KVEKH6KL;
        AddDomesticCountry('XE');
      end;

    ARRL160:
      begin
        if ARRLSectionCountry(Settings.My.Country) then
           begin
           ActiveExchange := RSTDomesticOrDXQTHExchange; {*}
           ActiveDXMult := ARRLDXCCWithNoARRLSections;
           end
        else
           begin
           ActiveExchange := RSTDomesticQTHExchange; {*}
           end;

        //        Settings.Contest.Name := 'ARRL 160 Contest';
        //        DomesticQTHDataFileName := 'ARRLSECT';
        AddARRLSectionDomesticCountries;
      end;

    {
        ARRLRTTYROUNDUP:
          begin
            CountryTable.CountryMode := CQCountryMode;
            CountryTable.ZoneMode := CQZoneMode;
            ActiveDomesticMult := DomesticFile;
            ActiveDXMult := ARRLDXCC;
    //        ActiveExchange := RSTDomesticQTHOrQSONumberExchange;
    //        ActiveQSOPointMethod := OnePointPerQSO;
            Settings.Contest.Name := 'ARRL RTTY ROUNDUP';
            Settings.Contest.DigitalModeEnable := True;
            //DomesticQTHDataFileName := 'S48P14DC'; //KK1L: 6.72 Used DC file instead per rules
            //Settings.Qso.ByBand := True;
            Add_KVE;
          end;
    }
    RTC: // Issue #902 -- Real-Time Contest (COS)
      begin
        // Rules permit only 40/20/15/10 m on CW and SSB.  TR4W cannot
        // disable individual HF bands (no per-band toggle exists), so
        // 160/80 stay clickable; the scoring branch in CalculateQSOPoints
        // awards 0 points and inhibits mults for any QSO outside the
        // 40/20/15/10 + CW/SSB rules.  WARC bands ARE disabled here.
        Settings.Bands.WarcEnabled := False;

        // CW function-key defaults and SAP exchange strings.
        // Exchange shape: <serial#> <grid> -- e.g. "001 FN20".
        // RST is optional per the rules and is not transmitted by default.
        // The grid is substituted at FCONTEST init time (same idiom as the zone
        // in SetUpRSTMyZoneExchange); the operator must restart the contest
        // setup if it changes.
        Settings.Messages.CqExchangeCw := UTF8Encode(' # ' + Settings.My.Grid);
        Settings.Messages.RepeatSpExchangeCw := UTF8Encode(' # ' + Settings.My.Grid);
        Settings.Messages.SpExchangeCw := UTF8Encode(' # ' + Settings.My.Grid);
        SetCQMemoryString(CW, F3, UTF8Encode('# ' + Settings.My.Grid));
        SetEXMemoryString(CW, F4, UTF8Encode('NR # ' + Settings.My.Grid));
        SetEXMemoryString(CW, F5, UTF8Encode('@ DE \ # ' + Settings.My.Grid));
        SetEXMemoryString(CW, AltF4, 'NR?');
        SetEXCaptionMemoryString(CW, F4, 'NR');
        SetEXCaptionMemoryString(CW, F5, 'Cl+Ex');
      end;

    ARRLVHFJUN, ARRLVHFSEP:
      begin
        ActiveBand := Band6;
        Settings.Contest.Name := 'VHF QSO JUNE';
        Settings.Bands.HfEnabled := False;
        //        VHFBandsEnabled := True;
         //         Settings.My.State := Settings.My.Grid; //Copy(Settings.My.Grid, 1, 4);
      end;

    BALTIC:
      begin
        ActiveBand := Band80;
      end;

    //    BWQP:
    //    ActiveExchange := RSTPowerExchange;

    CIS:
      begin
        AddRussianDomesticCountrys;

        AddDomesticCountry('UR');
        AddDomesticCountry('EU');
        AddDomesticCountry('4J');
        AddDomesticCountry('EK');
        AddDomesticCountry('UN');
        AddDomesticCountry('EX');
        AddDomesticCountry('ER');
        AddDomesticCountry('EY');
        AddDomesticCountry('EZ');
        AddDomesticCountry('UK');
        AddDomesticCountry('4L');

        //??????, ???????, ????????, ???????????, ???????, ?????????, ??????????, ???????, ???????????,
        // ????????????, ?????????? ? ??????

//        Settings.Contest.CountDomesticCountries := True;
//        Settings.Contest.Name := 'CIS DX Contest';
      end;

    CQM:
      begin
        //        Settings.Contest.Name := 'CQ M Contest';
        Settings.Contest.R150SMode := True;
      end;

    CQVHF:
      begin
        ActiveBand := Band2;
        //        Settings.Contest.Name := 'CQ WORLD WIDE VHF Contest';
        Settings.Bands.HfEnabled := False;
        //        VHFBandsEnabled := True;
      end;

    {
        CQWWRTTY:
          begin
            CountryTable.CountryMode := CQCountryMode;
            CountryTable.ZoneMode := CQZoneMode;

            ActiveDomesticMult := DomesticFile;
            ActiveDXMult := CQDXCC;
            ActiveExchange := RSTZoneAndPossibleDomesticQTHExchange;
            ActiveInitialExchange := ZoneInitialExchange;
    //        ActiveQSOPointMethod := CQWWRTTYQSOPointMethod;
            ActiveZoneMult := CQZones;
            Settings.Contest.Name := 'CQ WW RTTY CONTEST';
            Settings.Contest.DigitalModeEnable := True;
            //DomesticQTHDataFileName := 'S48P13';
            //Settings.Mult.ByBand := True;
            //Settings.Qso.ByBand := True;
            Add_KVE;
          end;
    }

    EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB,
      EUSPRINT_SPRING_CW:
      begin
        ActiveBand := Band20;
        //        ActiveInitialExchange := NameInitialExchange;
      end;

    RADIOVHFFD:
      begin
        Settings.Bands.HfEnabled := False;
        ActiveBand := Band2;
        Settings.Contest.DigitalModeEnable := False;
        Settings.Contest.Name := 'RF-VHF-FD';
        Settings.Qso.ByMode := False;
        Settings.Qso.ByBand := True;
        Settings.Contest.QsoNumberByBand := True;
      end;

    EUROPEANVHF:
      begin
        ActiveBand := Band6;
        //        Settings.Contest.Name := 'EUROPEAN VHF CONTEST';
        Settings.Bands.HfEnabled := False;
        //        VHFBandsEnabled := True;
      end;

    HADX:
      begin
        AddDomesticCountry('HA');
      end;

    IRTS: // 4.93.1
      begin
        ActiveBand := Band80;
        Settings.Contest.DigitalModeEnable := FALSE;
        INITIALEXCHANGECURSORPOS := ATSTART;
        if (Settings.My.Country <> 'EI') and (Settings.My.Country <> 'GI') then
           begin
           ActiveDXMult := NoDXMults;
           end;
      end;

    EUDX: // 4.95.6
      begin
        //     AddDomesticCountry

      end;

    YUDX: // 4.57.5
      begin
        AddDomesticCountry('YU');
        if Settings.My.Country = 'YU' then
           begin
           ActiveDomesticMult := NoDomesticMults; // 4.57.7
           ActiveDXMult := ARRLDXCC;
           end
      end;

    HELVETIA:
      begin
        if Settings.My.Country = 'HB' then
           begin
           ActiveDXMult := ARRLDXCC;
           end;
        //  else          // 4.56.3 issue 232
        AddDomesticCountry('HB');
      end;

    OZCR_Z:
      begin
        Settings.Contest.Name := '????-??????? ????????? ?????? - ??????? ?????????';
      end;

    GagarinCup:
      begin
        Settings.Contest.R150SMode := True;
        Settings.Contest.Name := 'Yuri Gagarin International DX Contest';
        Settings.Qso.ByMode := TRUE;
        Settings.Contest.InitialExchangeOverwrite := TRUE;
      end;

    KCJ:
      begin
        ActiveInitialExchange := ZoneInitialExchange; // 4.114.1
        Settings.Contest.InitialExchangeOverwrite := True;
      end;

    {
        MICHQSOPARTY:
          begin
            if FoundMyStateInDomFile then
            begin
              DomesticQTHDataFileName := 'MIQP';
    //          ActiveExchange := QSONumberDomesticQTHExchange; //KK1L: 6.73
            end
            else
            begin
              DomesticQTHDataFileName := 'MICHCTY';
    //          ActiveExchange := QSONumberDomesticQTHExchange; //KK1L: 6.73
            end;
            Add_KVEKH6KL;
          end;
    }
    MWC:
      begin
        ActiveBand := Band80;
        AddDomesticCountry('MWC');

      end;

    SST:
      begin
        Settings.Contest.Name := 'Slow Speed Test';
        ActiveDomesticMult := DomesticFile;
        Add_KVE;
        Settings.Messages.CqExchangeCw := UTF8Encode(' ' + Settings.My.Name + ' ' + Settings.My.State);
        Settings.Messages.SpExchangeCw := UTF8Encode(Settings.My.Name + ' ' + Settings.My.State);
      end;

    NEWENGLANDQSO:
      begin
        (* A NEW ENGLAND STATION: MY STATE BEGINS WITH ONE OF THE SIX STATES.

          A STRING COMPARISON OF THE FIRST TWO CHARACTERS -- 2026-10-01, M2,
          inventory defect #3. This read PWORD(@Settings.My.State[1])^, which
          was D7's way to take two AnsiChars at once. Here string is
          UnicodeString, so the word held ONE character and could never equal
          'ME' or any of the others -- no station was ever in New England --
          and an EMPTY MY STATE gave PWORD the address of nothing: set-up
          crashed for every DX station (the contest matrix's dx variant,
          exit 217). The first-two-characters rule is D7's, kept as it was. *)
        NewEnglandState := Copy(Settings.My.State, 1, 2);
        if (NewEnglandState = 'ME') or
           (NewEnglandState = 'NH') or
           (NewEnglandState = 'VT') or
           (NewEnglandState = 'MA') or
           (NewEnglandState = 'CT') or
           (NewEnglandState = 'RI') then
           begin
           TempDomesticQTHDataFileName := 'NEQSOW1';
           ActiveDXMult := ARRLDXCCWithNoUSACanadaKH6OrKL7;
           ActiveExchange := RSTDomesticOrDXQTHExchange;
           //          Settings.Contest.Name := 'New England QSO Party (within NE)';
           end
        else
           begin
           TempDomesticQTHDataFileName := 'NEQSO';
           //          ActiveDXMult := NoCountDXMults;
           ActiveExchange := RSTDomesticQTHExchange;
           //          Settings.Contest.Name := 'New England QSO Party (outside NE)';
           end;

        DXMultLimit := 20;
        Add_KVEKH6KL;
      end;

    OKOMSSB: // 4.80.1
      begin
        AddDomesticCountry('OK');
        AddDomesticCountry('OM');
        ActiveMode := Phone;
      end;

    POTA:
      begin
        tAllowDupeQSOs := TRUE;
        Settings.AutoDupe.EnableCq := False;
        Settings.AutoDupe.EnableSAndP := False;
        Settings.Contest.Name := 'POTA';
        Settings.Bands.WarcEnabled := True;
        SetCQMemoryString(CW, F1, 'CQ^POTA \ \ ');
        SetCQMemoryString(CW, F2, 'CQ^POTA CQ^POTA \ \ FD');
        //Settings.Messages.CqExchangeCw := ' ' + MyFDClass + ' ' + MySection;
        //Settings.Messages.SpExchangeCw := MyFDClass + ' ' + MySection;
        Settings.Messages.QslCw := '73 \ EE';
        { Build operator name set from TRMASTER.DTA (lazy — no-op if already done) }
        InitOperatorNameSet;
      end;

    RAEM:
      begin
        ActiveBand := Band80;
        Settings.Contest.Name := 'RAEM Ernst Krenkel Memorial Contest';
        InitialExchangeCursorPos := AtStart;
      end;

    RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB:
      begin
        ActiveBand := Band80;
        //        Settings.Contest.Name := 'UK Rotating Postal Code';
        Settings.Contest.MultipleBands := False;
        Settings.Messages.CqExchangeCw := '_~ %5NN ('; // + MyPostalCode;
        Settings.Messages.RepeatSpExchangeCw := '5NN (';
        Settings.Messages.SpExchangeCw := '~ %5NN (';
        SetCQMemoryString(CW, F3, '5NN (');
        SetEXMemoryString(CW, F3, '5NN');
        SetEXMemoryString(CW, F4, '(');
        SetEXMemoryString(CW, F5, '@ DE \ 5NN (');
        SetEXMemoryString(CW, AltF3, 'RST?');
        SetEXMemoryString(CW, AltF4, 'PC?');
      end;

    RDA:
      begin
        AddRussianDomesticCountrys;
        //        Settings.Contest.CountDomesticCountries := True;
        if not RussianID(Settings.My.Country) then
           begin
           ActiveDXMult := NoDXMults;
           end;
        DomesticMultByBand := dmbbAllBand;
      end;

    YBDX: // 4.64.1
      begin
        ActiveMode := Phone;
        ActiveDXMult := ARRLDXCC;
        ActivePrefixMult := IndonesianDistricts;
      end;

    SPDX:
      begin
        //        Settings.Contest.Name := 'SP-DX Contest';
        AddDomesticCountry('SP');
      end;

    TENTEN:
      begin
        //        Settings.Contest.Name := 'Ten Ten QSO Party';
        Add_KVEKH6KL;
      end;

    {
        REFCW:
          begin
            AddDomesticCountry('F');
          end;
    }
    {
        ,QSOPARTY:
          begin
            ActiveDomesticMult := DomesticFile;
            if (PWORD(@Settings.My.State[1])^ = $4957) //WI
            then
              DomesticQTHDataFileName := 'WIQSOWI'
            else
              DomesticQTHDataFileName := 'WIQSO';

            Add_KVEKH6KL;
          end;
    }

    YODX:
      begin
        Settings.Contest.Name := 'YO-DX-HF Contest';
        AddDomesticCountry('YO');
      end;

    UA4WCHAMPIONSHIP:
      begin
        Settings.Contest.MinitourDuration := 15;
      end;

    R9W_UW9WK_MEMORIAL:
      begin
        Settings.Contest.MinitourDuration := 20;
      end;

    OLDNEWYEAR:
      begin
        ActiveBand := Band80;
        Settings.Contest.ExchangeMemoryEnable := True;
      end;

    CQWPXRTTY, WRTC:
      ActiveBand := Band80;

    RFASCHAMPIONSHIPCW {, RFASCHAMPIONSHIPSSB}:
      begin
        //        ActiveMode := CW;
        //        if Contest = RFASCHAMPIONSHIPSSB then ActiveMode := Phone;
      end;

    SEVENQP:
      begin
        //        if (pos('7', Settings.My.Call) > 0) or (pos('/7', Settings.My.Call) > 0) then
        if FoundMyStateInDomFile then
           begin
           //          DomesticQTHDataFileName := '7QP-W7';
           //          Settings.Contest.Name := '7th Area QSO Party Inside W7';
           ActiveExchange := RSTDomesticOrDXQTHExchange;
           ActiveDXMult := ARRLDXCCWithNoUSACanadaKH6OrKL7;
           DXMultLimit := 20;
           //          Add_KVEKH6KL;
           end
        else
           begin
           //          DomesticQTHDataFileName := '7QP';
           //          Settings.Contest.Name := '7th Area QSO Party Outside W7';
           ActiveExchange := RSTDomesticQTHExchange;
           end;
        //        VHFBandsEnabled := True;

      end;

    OZCR_O:
      begin
        Settings.Contest.Name := '????-??????? ????????? ?????? - ????? ?????????';
        Settings.Contest.R150SMode := True;
      end;

    //    UA4N: Settings.Contest.MinitourDuration := 15;

    JTDX: // 4.67.9
      begin
        ActiveInitialExchange := ZoneInitialExchange;
        ActivePrefixMult := MongolianCallSignPrefix;
      end;

    UNDX:
      begin
        AddDomesticCountry('UN');
        //        Settings.Contest.CountDomesticCountries := True;
      end;

    KINGOFSPAINCW, KINGOFSPAINSSB:
      begin
        AddDomesticCountry('EA');
        AddDomesticCountry('EA6');
        AddDomesticCountry('EA8');
        AddDomesticCountry('EA9');
      end;

    CQMM:
      begin
        if MyContinent = SouthAmerica then
           begin
           ActivePrefixMult := SouthAndNorthAmericanPrefixes;
           end;
        DXCCMultByBand := dmbbAllBand;
        ActiveBand := Band80;
      end;

    //    RADIOMEMORY:
    //      CallsignUpdateEnable := False;   -- see the note above

  end;

  if TempDomesticQTHDataFileName <> '' then
     begin
     (* ASSIGNED, NOT APPENDED -- 2026-09-20.

       This was two Windows.lstrcatA calls that walked to the NUL and kept
       writing, and the port kept their APPEND faithfully: the contest's own
       file name was concatenated onto whatever the setting already held.

       THAT MADE FoundContest NON-IDEMPOTENT, and the tree already carries
       two scars from it. uLogStore excludes CONTEST from its skip-a-no-op
       rule and says why -- re-applying it produced `dom\iaruhq.domiaruhq.dom`
       and took the golden corpus from 20 passed to 10 passed / 14 failed --
       and the same shape reached an operator on 2026-09-20 with a mount
       point wrapped around a mount point. Both were treated by arranging
       for the routine not to run twice, which is a guard around a defect
       rather than the defect.

       NOTHING LEGITIMATE WAS APPENDING. The only value that could be here
       is one a contest .cfg set before its CONTEST line, and
       `fooS48P14DC.dom` is not a file anybody meant. A contest .cfg that
       names a domestic file AFTER its CONTEST line still wins, exactly as
       before, because that is a plain assignment through the property. *)
     Settings.Contest.DomesticFilename :=
        TempDomesticQTHDataFileName + string(DOM_EXTENSION);
     end;

  case ActiveExchange of
    NameAndDomesticOrDXQTHExchange: SetUpNameAndStateExchange;

    RSTQSONumberExchange: SetUpRSTQSONumberExchange;

    RSTDomesticQTHExchange,
      RSTAndContinentExchange,
      RSTAndQSONumberOrFrenchDepartmentExchange,
      RSTAndQSONumberOrDomesticQTHExchange,
      RSTDomesticQTHOrQSONumberExchange:

      if Settings.My.State = '' then
         begin
         SetUpRSTQSONumberExchange
         end
      else
         begin
         SetUpRSTMyStateExchange;
         end;

    RSTZoneAndPossibleDomesticQTHExchange, RSTZoneExchange:
      if not (Contest in [JIDXCW, JIDXSSB]) then
         begin
         SetUpRSTMyZoneExchange;
         end;

    RSTZoneOrSocietyExchange:
      if Settings.My.State = '' then
         begin
         SetUpRSTMyZoneExchange
         end
      else
         begin
         SetUpRSTMyStateExchange;
         end;

  end;

  FoundContest := Contest <> DUMMYCONTEST;

  SetContestTitle;

end;

procedure AddRussianDomesticCountrys;
begin
  AddDomesticCountryList(DomesticCountriesRussia);
end;

procedure Add_KVEKH6KL;
begin
  AddDomesticCountryList(DomesticCountriesKVEKH6KL);
end;

procedure Add_KVE;
begin
  AddDomesticCountryList(DomesticCountriesKVE);
end;

procedure RecalculateMyCountryContinentAndZone;
var
  TempQTH: VC.QTHRecord;
begin
  //  CTY.ctyLastCountryCall := '';
  FillChar(CTY.ctyLastLocatedCall, SizeOf(CTY.ctyLastLocatedCall), 0);
  //  CTY.ctyLastLocatedCall := '';
  ctyLocateCall(UTF8Encode(Settings.My.Call), TempQTH);
  (* DERIVED, not stated -- same reason as the routine below. *)
  Settings.My.DeriveCountry(string(TempQTH.CountryID));
  MyContinent := TempQTH.Continent;
  Settings.My.DeriveZone(IntToStr(TempQTH.Zone));
end;

procedure RecalculateMyCountryContinentAndZoneNew(Call: CallString);
var
  TempQTH: VC.QTHRecord;
begin
  FillChar(CTY.ctyLastLocatedCall, SizeOf(CTY.ctyLastLocatedCall), 0);

  (* THE OPERATOR'S OWN ANSWER WINS. Same rule as the zone below it: a
    stated country is looked up, an unstated one is derived from the
    callsign. *)
  if Settings.My.CountryWasSet then
     begin
     ctyLocateCall(ShortString(UTF8Encode(Settings.My.Country)), TempQTH)
     end
  else
     begin
     ctyLocateCall(Call, TempQTH);
     end;

  if not Settings.My.CountryWasSet then
     begin
     (* DERIVED, AND SAID TO BE. Assigning the property would set
       CountryWasSet, so this routine's own answer would read as the
       operator's on the next call -- and the FIRST call can run before the
       callsign has arrived. See TMySettings.DeriveCountry. *)
     Settings.My.DeriveCountry(string(TempQTH.CountryID));

     (* SAY SO, AND SAY FROM WHAT -- 2026-09-20.

       A VALUE THAT APPEARS BY MAGIC IS WORSE THAN ONE THAT IS ABSENT. MY
       COUNTRY decides the exchange for ARRL DX and ARRL 160, and until
       today nothing recorded that it had been derived, from which callsign,
       or that the derivation had come back empty. NY4I spent a bench
       session on exactly that gap.

       WARN WHEN IT COMES BACK EMPTY. That is not a country; it means the
       callsign was absent or CTY.DAT could not place it, and every contest
       that branches on MY COUNTRY is about to take its "not here" arm. *)
     if logger <> nil then
        begin
        if Settings.My.Country = '' then
           begin
           logger.Warn('[FCONTEST] MY COUNTRY could not be derived from ' +
                       'MY CALL = "%s" and is empty. A contest that chooses ' +
                       'its exchange by country will treat this station as ' +
                       'DX. Set MY COUNTRY in Preferences > Station.',
                       [Settings.My.Call]);
           end
        else
           begin
           logger.Info('[FCONTEST] MY COUNTRY = %s, derived from MY CALL = ' +
                       '%s through CTY.DAT. The operator has not stated one; ' +
                       'a value typed in Preferences > Station overrides it.',
                       [Settings.My.Country, Settings.My.Call]);
           end;
        end;

     if MRC = '' then
        begin
        MRC := UTF8Encode(Settings.My.Country);
        end;
     end;

  if not Settings.My.ZoneWasSet then
     begin
     Settings.My.DeriveZone(IntToStr(ctyGetZone(Call)));
     end;

  if not MyContinentIsSet then
     begin
     MyContinent := TempQTH.Continent;
     if MyCo = '' then
        begin
        MyCo := tContinentArray[MyContinent];
        end;
     ContinentString := tContinentArray[MyContinent];
     end;

end;

procedure SetContestTitle;
begin
  (* Plain assignment, which converts and bounds itself. This wrote into the
    ShortString's BODY and then patched its length byte by hand -- the idiom
    that cannot survive the callsign becoming a property, because there is no
    body to point at. *)
  Settings.Contest.Title := UTF8Encode(string(GetYearString) + ' '
                             + string(Settings.Contest.Name) + ' ' + Settings.My.Call);
end;

(* IS THIS STATION IN THE HOST STATE OF THE QSO PARTY BEING SET UP?

  It is when MY STATE is one of the keys of the party's county file -- the
  contest's DomesticFileName, the file every out-of-state station loads. An
  in-state station's "state" is its county.

  THIS HAD NEVER ANSWERED YES IN THIS TREE (inventory defect #1, fixed in
  M2, 2026-10-01). The path was 'DOM' + name + '.DOM' -- D7 wrote
  '%sDOM\%s.DOM' and the separator was lost in the port -- so the file was
  never found and every station was out of state: the out-of-state domestic
  file, exchange and multipliers for every operator of every party, the host
  state's own included. The path now comes from uAppPaths, which the two
  other dom readers use too, and the reading rule -- EnumDOM2's, which was a
  callback writing a unit-level flag -- is uDomFileKeys, where a test reaches
  it.

  The file name is asked of the contest (ContestIdentity), as set-up's head
  asks it, so the in-state test and the out-of-state file are one name. *)
function FoundMyStateInDomFile: boolean;
var
  countyFile: string;
begin
  Result := False;
  if Contest = DUMMYCONTEST then
     begin
     Exit;
     end;

  countyFile := ContestIdentity(Contest).DomesticFileName;
  if countyFile = '' then
     begin
     Exit;
     end;

  Result := DomFileOnDiskDeclaresKey(
               ShippedDomFilePath(countyFile + string(DOM_EXTENSION)),
               Settings.My.State);
end;

end.
