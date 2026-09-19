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
unit LogCfg;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,

  TF,
  VC,
  utils_text,
  IdUDPClient,
  IdGlobal,
  LogStuff,
  (* Windows was here for lstrcatA, Sleep and INVALID_HANDLE_VALUE.
    utils_text.StrLCopy and SysUtils answer the first two; the third is
    written as THandle(-1), which is the value it always was and is what
    FileOpen and FileCreate return. Note these particular uses are LPT
    port BASE ADDRESSES rather than handles -- they borrowed the name for
    its 'not open' sentinel, and spelling it out makes that visible
    (2026-09-08). *)
  PostUnit,
  LogSCP,
  LogCW,
  LogWind,
  LogDupe,
  ZoneCont,
  LogGrid,
  LogDom,
  FCONTEST,
  LOGDVP,
  //Country9,
  LogEdit,
  //LOGDDX,
  LOGWAE,
  LogPack,
  LogK1EA, {DOS,}
//  Help,
  CfgCmd,
  {SlowTree,}Tree, {Crt,}
//  LOGMENU,
  LogNet,
  LogRadio,
  CFGDEF,
  SysUtils,
  Log4D
  ,
  uTR4WStrings;

type
  (* WHICH FILE A CONFIG PASS READS.

    cfgINI IS GONE -- 2026-09-19. NY4I: "calling ReadInConfigFile(cfgINI) that
    does nothing is pointless and should be removed." The legacy tr4w.ini is
    the CONVERTER'S input (tr4w\tools\tr4wconvert --ini <path>), not a startup
    source, and taking the member out is what makes that unrepresentable
    rather than merely unwired: there is no longer a value to pass in. *)
  TCFGType = (cfgCFG, cfgINPUT, cfgCommMes);

function LoadInSeparateConfigFile(FileName: ShortString;
  var FirstCommand: boolean;
  Call: CallString): boolean;

procedure LookForCommands(var ContestConfigFileTitle: Str20);
(* Is the assembled configuration usable?  False, with the reason shown, when
  something required is missing.

  IN THE INTERFACE since 2026-09-02: it used to be called only from inside
  ReadInConfigFile, halfway through assembling the configuration. uProgramMain
  asks it once every source has contributed -- including the log's own contest
  settings, which arrive after every file. *)
function ConfigurationOkay: boolean;

procedure ReadInConfigFile(ConfigFileName: TCFGType);
procedure TryRunPaddleAndFootSwitchThread;
procedure tSetupExchangeNumbers;
procedure EnmuCFGFile(FileString: PShortString);
procedure SetUpGlobalsAndInitialize;

var
  LineNumberInConfigFile                : integer;
  CurrentConfigFile                     : TCFGType;

implementation

uses
   uPortAddress,   // TPortKind -- see the radio port kind accessors
   uSettingsModel, // Settings.My -- the station's own facts
  uAppPaths,     // ResolveDataFileInPlace -- shipped data, whatever case
  uCFG,
  MainUnit,
  uRadioPolling,
   uUDPBroadcaster,
   uUDPBroadcastConfig,
   uTR4WConfigFile,
   uRotatorControl,   // OpenRotatorPorts -- the library opens its own ports
   uContestFileKind;  // a .db chosen as the contest must not be line-parsed

var
  logger: TLogLogger;

(* ~~RestoreCFGPasswordCase~~ -- DELETED 2026-09-19 WITH THE INI READ.

  It was the second pass over tr4w.ini: the first pass upper-cases a whole
  line before splitting it, so a password or any TCaseSensitiveText value
  arrived shouting, and this re-read the same file with UpperCase=False and
  put the operator's own capitalisation back onto the settings object.

  It ran for cfgINI AND NOTHING ELSE -- passwords were never in a contest
  .cfg -- so removing ReadInConfigFile(cfgINI) from startup left it with no
  caller at all. It is also the one thing the ini read still did that reached
  Settings directly, bypassing CheckCommand's aApplyJSONOwned guard; see the
  note at the removed call in uProgramMain for the measurement.

  THE CASE PROBLEM IT WORKED AROUND DOES NOT EXIST IN THE CONVERTER.
  tr4wconvert reads the ini through TIniFile, key by key, which never touches
  the value's case -- so the shape that needed a second pass is gone rather
  than unhandled. *)

procedure PushLogFiles(var LastPushedLogName: Str20);

{ This procedure will take the current active log file and create a
  backup file with the filename PLOG###.BAK.  ## is intially 01, and
  then increments each time.  The active log file is removed. }

//var
//  FileNumber                            : integer;
//  TempString                            : Str20;

begin
  {
    FileNumber := 0;

    repeat
      Str(FileNumber, TempString);
      while length(TempString) < 3 do
        TempString := '0' + TempString;

      TempString := 'PLOG' + TempString + '.BAK';

      if not FileExists(TempString) then
      begin
        RenameFile(LogFileName, TempString);

        LastPushedLogName := TempString;
        Exit;
      end;

      inc(FileNumber);

    until FileNumber > 1000;

    showmessage('Unable to create backup file!!');
    halt;
   }
end;

function ConfigurationOkay: boolean;
begin
{$IF MAKE_DEFAULT_VALUES = TRUE}
  Result := True;
  Exit;
{$IFEND}

  ConfigurationOkay := False;

  if Settings.My.Call = '' then
     begin
     showwarning(TC_NOCALLSIGNSPECIFIED);
     Exit;
     end;
{
  if Settings.Log.BackupFrequency > 0 then
    if FloppyFileSaveName = '' then
    begin
      showwarning(TC_NOFLOPPYFILESAVENAMESPECIFIED);
      Exit;
    end;
}
  ConfigurationOkay := True;
end;

procedure TryRunPaddleAndFootSwitchThread;
begin

(* THE CONTROL-PORT BRANCH IS GONE (2026-09-08), and it never ran.

  It tested `Radio1.tCATPortHandle <> THandle(-1)`. That handle was
  assigned in two places, both to THandle(-1), and nothing ever
  opened it -- so the paddle and foot switch could never come off the radio's
  control port, whatever `USE CONTROL PORT` was set to. The field is deleted;
  see logradio. *)

  (* AND THE LPT BRANCH IS GONE TOO (2026-09-13), which leaves this routine
    with nothing to do.

    Both arms opened a parallel port -- one for the foot switch, one for the
    paddle -- and started the polling thread that read their contacts off the
    LPT status lines.  With the parallel port removed there is no port to
    open and no contacts to read; a YCCC box reports its own paddle over
    OTRSP, on its own thread.

    THE ROUTINE IS KEPT AND EMPTY rather than deleted, because its CALLER is
    the startup sequence and the question "does anything still start the
    paddle thread" should have a visible answer here rather than being
    inferred from an absence. *)

end;

procedure CheckAndInitializeSerialPorts;
begin

  // THE ROTATOR LIBRARY OPENS ITS OWN PORTS. This opened ONE port -- the one
  // named by the legacy ActiveRotatorPort key -- at a baud rate chosen by asking
  // what type of rotator it was. A library rotator on any other port therefore
  // never turned, silently, and a second rotator could not work at all.
  // uRotatorControl now opens the port each LIVE rotator names, and the driver
  // states its own baud rate.
  //
  // ConfigureRotators has already run by this point (tr4w.lpr:974; this routine
  // is reached from :1091) and seeds itself from ActiveRotatorType/Port when the
  // library is empty, so a station that has never opened the Rotators page is
  // unaffected.
  OpenRotatorPorts;
 

  // A hand-edited config can point BOTH radios at the same serial port; the
  // second open would just fail and that radio would look dead ("bad cable").
  // Make the outcome deterministic and SAY it: RADIO ONE keeps the port,
  // RADIO TWO's CAT is disabled for this session, and the operator is told
  // which port collided.  (The radio dialog also warns at Apply time --
  // uCAT.WarnIfPortConflict -- so this only fires for configs edited by hand.)
  (* COMPARED BY DEVICE NAME, NOT BY ORDINAL, and that is not tidiness.

    An ordinal comparison is wrong in BOTH directions once a port can be named
    by a device node.  Two radios on /dev/ttyUSB0 and /dev/ttyUSB1 both have
    the ordinal NoPort, so it would declare a conflict that does not exist and
    silently disable the second radio.  And two radios genuinely on the same
    node would compare equal only by accident.

    EffectiveDeviceName is the same rule the open path uses, so what is
    compared here is exactly what would be opened. *)
  if (Radio1.CATPortKind = pkSerial) and
     (Radio2.CATPortKind = pkSerial) and
     (* UnicodeSameText, not SameText: SysUtils is compiled with String =
       AnsiString and this unit is UnicodeString, so the plain one narrows both
       arguments and the build counts that.  A device name is ASCII either
       way -- written down rather than left to the compiler. *)
     UnicodeSameText(EffectiveDeviceName(Radio1.tCATPortName, Radio1.tCATPortType),
                     EffectiveDeviceName(Radio2.tCATPortName, Radio2.tCATPortType)) then
     begin
     showwarning(SysUtils.Format(TC_PORT_CONFLICT_STARTUP,
        [EffectiveDeviceName(Radio1.tCATPortName, Radio1.tCATPortType)]));

     (* BOTH FIELDS, or the radio is not disabled.  Clearing the ordinal alone
       leaves the NAME set, and CATPortKind reads the name first -- so radio
       two would still be serial, still open the port, and the warning would
       have told the operator it had been turned off. *)
     Radio2.tCATPortType := NoPort;
     Radio2.tCATPortName := '';
     end;

  Radio1.CheckAndInitializePorts_ForThisRadio;
  Radio2.CheckAndInitializePorts_ForThisRadio;

end;

// Loads the UDP settings and hands them to the broadcaster as one coherent
// set.  Separate from SendUDPPayload only because the two answer different
// questions: this one is "what did the operator configure", that one is "how do
// the bytes leave".
procedure ConfigureUDPBroadcastFromLibrary;
var
   cfg: TUDPBroadcastConfig;
   settingsDir: string;
begin
   // The json path from uTR4WConfigFile, which owns that file; the ini path is
   // still derived here because no unit owns tr4w.ini in the same way.
   settingsDir := ExtractFilePath(CharBufferText(TR4W_INI_FILENAME));
   cfg := LoadUDPForStartup(TR4WConfigFileName, settingsDir + 'tr4w.ini');
   try
      UDPBroadcaster.Configure(cfg);   // takes a copy
   finally
      cfg.Free;
   end;
end;

// The transport the broadcaster calls.  It lives here because `udp` does, and
// it is the ONLY place that knows both the socket and the broadcaster.
procedure SendUDPPayload(const aAddress: string; const aPort: integer;
                         const aPayload: AnsiString);
begin
   if udp = nil then
      begin
      Exit;
      end;
   udp.BroadcastEnabled := True;
   udp.Send(aAddress, aPort, aPayload);
end;

procedure SetUpGlobalsAndInitialize;
var
  (* A LOCAL buffer, not the shared wsprintfBuffer global.

    This one genuinely needs a CHARACTER BUFFER rather than a string:
    ResolveDataFileInPlace takes an open array of AnsiChar by reference and
    rewrites it, and StrLCopy below reads it. That is the open-array shape CLAUDE.md
    asks for -- it carries its own bounds -- so what was wrong here was the
    buffer being GLOBAL and shared with forty other call sites, not the
    buffer existing. *)
  domPath                               : array[0..MAX_PATH - 1] of AnsiChar;
begin

  { GetTickCount64 -- StartCPU is QWord, see MainUnit. }
  StartCPU := GetTickCount64;
  udp := TIdUDPClient.Create(nil); // ny4i Issue #99
  // The broadcaster owns WHETHER and WHERE; this unit owns the socket, so it
  // hands over the transport once the socket exists.  Keeping Indy out of
  // uUDPBroadcaster is what lets its enable and port rules be unit-tested
  // against a recording stub instead of a network trace.
  UDPBroadcaster.SetTransport(SendUDPPayload);
  ConfigureUDPBroadcastFromLibrary;
  if Settings.Qtc.Enable then New(QTCDataArray); //LoadQTCDataFile;

//  if TempDomesticQTHDataFileName <> nil then
//    TF.Format(DomQTHDataFileName, '%sDOM\%s.DOM', TR4W_PATH_NAME, TempDomesticQTHDataFileName);

  (* A .DOM BESIDE THE LOG OVERRIDES THE SHIPPED ONE, AND THAT IS A FEATURE.

     The shipped files -- target\dom\*.dom, installed by full.nsi's "Domestic
     multiplier files" section -- are program RESOURCES, in the same category as
     CTY.DAT and TRMASTER.DTA. They are not specific to a contest, an operator or
     a date. TR4W never writes the override; an operator places it deliberately.

     WHY IT EXISTS, from NY4I, 2026-09-02: "we have had to make changes over the
     years to a DOM. Contest operators are hesitant to upgrade especially right
     before a contest. So changing an entry in a single DOM file is less risk
     than installing the latest version with the new DOM file."

     That is the whole justification and it is an operational one, not a
     technical one. A section gets renamed a fortnight before a contest; the fix
     is one line in one file, and the alternative is asking somebody to install a
     new build of their logger days before they use it in anger. Nobody sensible
     does that.

     SO IT SURVIVES THE MOVE TO A SINGLE .db ARTIFACT. Whatever replaces this --
     a domestic table in the log, most likely, so the override travels with the
     contest instead of relying on a filename convention -- has to keep the
     property that MATTERS: correcting one entry must not require upgrading the
     program. A design that only lets the shipped file be replaced by a new
     install has thrown the feature away while appearing to keep it. *)
  if Settings.Contest.DomesticFilename <> '' then
     begin
     if fileexists(TR4W_DOM_FILENAME) then                       // 4.100.2
        begin
        SetCharBuffer(domPath, CharBufferText(TR4W_DOM_FILENAME))
        end
      else
         begin
         SetCharBuffer(domPath,
            SysUtils.Format('%sdom\%s',
                            [CharBufferText(TR4W_PATH_NAME),
                             string(Settings.Contest.DomesticFilename)]));
         (* Windows spelling, resolved for this platform -- see fcontest. *)
         ResolveDataFileInPlace(domPath);
         end;
      (* THE SETTING NOW HOLDS THE RESOLVED PATH, assigned rather than
        zeroed-then-appended-to.

        The zero-and-append was a copy with extra steps: FillChar made the
        length zero, so the StrLen terms around the StrLCopy were all zero
        and what it wrote was domPath at offset zero. It read that way only
        because the array's bound had to be arithmetic. Assignment converts
        the AnsiChar buffer up to its NUL.

        LoadInDomQTHFile IS HANDED domPath'S TEXT. It took a PAnsiChar until
        2026-09-15, and PAnsiChar of a property is the address of a
        TEMPORARY -- the compiler accepts it and the pointer dangles at the
        end of the statement -- which is why it was given the local array
        and not the setting. It takes a string now; CharBufferText reads
        exactly the bytes the setting was just assigned from. *)
      Settings.Contest.DomesticFilename := CharBufferText(domPath);
      if not DomQTHTable.LoadInDomQTHFile(CharBufferText(domPath)) then
         begin
         halt;
         end;
     end;


  //wli  if DVPEnable then
  begin
    //         WriteLn('DVP Initialization in process...');
    DVPInit;
  end;

//  ActiveRadio := RadioOne;
//  InactiveRadio := RadioTwo; {KK1L: 6.73}

//  TotalQSOPoints := 0;

  (* A QSO COUNT WITH NO ENABLE WOULD DO NOTHING, so setting the count
    raises the flag. This is a derivation, not a second owner: the
    setting stays operator-settable and this only turns it on. *)
  if Settings.Operating.AutoTimeIncrement <> 0 then
     begin
     Settings.Operating.IncrementTimeEnable := True;
     end;

  DoingDomesticMults := ActiveDomesticMult <> NoDomesticMults;
  DoingDXMults := ActiveDXMult <> NoDXMults;
  DoingPrefixMults := ActivePrefixMult <> NoPrefixMults;
  DoingZoneMults := ActiveZoneMult <> NoZoneMults;

  //  NumberDifferentMults := 0;

  {KK1L: 6.68 This may need to change to something like...don't know. It works as is.  }
  {IF (DoingDomesticMults)AND                                                          }
  {   ((DomesticQTHDataFileName <> '') OR (ActiveDomesticMult = WYSIWYGDomestic)) THEN }

  if DoingDomesticMults then                              // Gav 4.44.8      Display remaining domestic Mults
     begin
     if RemainingMultDisplay = rmNoRemMultDisplay then
        begin
        RemainingMultDisplay := rmDomestic;
        end;
     inc(NumberDifferentMults);
     end;

  if DoingDXMults then
     begin
     inc(NumberDifferentMults);
     if RemainingMultDisplay = rmNoRemMultDisplay then
        begin
        RemainingMultDisplay := rmDX;
        end;
     end;

  if DoingZoneMults then
     begin
     inc(NumberDifferentMults);
     if RemainingMultDisplay = rmNoRemMultDisplay then
        begin
        RemainingMultDisplay := rmZone;
        end;
     end;

  if DoingPrefixMults then
     begin
     inc(NumberDifferentMults);
     if RemainingMultDisplay = rmNoRemMultDisplay then
        begin
        RemainingMultDisplay := rmPrefix;
        end;
     end;

  LoadSpecialHelloFile;

  //   !!! ����� �� ���� ������ ��� ���� ���
  //��������� ptt �  ����������
  {
    if DDXState <> Off then
    begin
      RadioOneKeyerOutputPort := NoPort;
      RadioTwoKeyerOutputPort := NoPort;
    end;
  }
//  TailEnding := False;

  {Before restart.bin load}
  Move(DefaultFreqMemory, FreqMemory, SizeOf(TFreqMemoryType));

  Sheet.SheetInitAndLoad;
  LoadBandMap;
  DisplayContestTitle;

  if CurrentOperator[0] = #0 then  // ny4i Issue #97
     begin
     (* The operator defaults to the callsign being used. StrPLCopy fills a
       fixed AnsiChar array, so the text is encoded on the way in. *)
     SetCharBuffer(CurrentOperator, Settings.My.Call);
     end;

  CheckAndInitializeSerialPorts;
  InitializeKeyer;
//  ActiveKeyerPort := ActiveRadioPtr.tKeyerPort;
//  tActiveKeyerHandle := ActiveRadioPtr.tKeyerPortHandle;

  TryRunPaddleAndFootSwitchThread;
  MonitorTone := Config.CWTone;

//  ActiveBand := ActiveRadioPtr.BandMemory;
//  ActiveMode := ActiveRadioPtr.ModeMemory;

  DisplayCodeSpeed;
  Str(Radio1.SpeedMemory, SpeedString); {KK1L: 6.73 Initialize SpeedString for ALT-D use.}
  // SetSpeed(CodeSpeed);  // ny4i Issue 153 Not necessary as SetUpToSendOnActiveRadio is called and sets the speed

  if Settings.Cw.AutoSendCharacterCount > 0 then
     begin
     AutoSendEnable := True;
     DisplayAutoSendCharacterCount;
     end;
{
  if ReadInLog then
  begin
    Settings.AutoDupe.EnableCq := False;

    if Config.CWTone = 0 then
    begin
      FlushCWBufferAndClearPTT('LogCfg: config reload');
      CWEnabled := False;
    end;
  end;
}
//  K5KA.AltDString := '';
//  K5KA.State := KAIdle;
//  MarkTime(RITCommandTimeStamp);


end;

function LoadInSeparateConfigFile(FileName: ShortString; var FirstCommand: boolean; Call: CallString): boolean;

var
  ConfigRead                            : Text;
  FileString                            : ShortString;
  LineNumber                            : integer;

begin
 //n4af 4.36.3 ADDED FUNCTION
  LoadInSeparateConfigFile := False;
  LineNumber := 1;

  GetRidOfPrecedingSpaces(FileName);

   if OpenFileForRead_old(ConfigRead, FileName) then         // ADDED 4.36.3
 //if tf.topenFileForRead(h, FileName) then

      begin
      while not Eof(ConfigRead) do
         begin
         ReadLn(ConfigRead, FileString);

         if StringHas(UpperCase(FileString), 'MY CALL') and (Call <> '') then
            begin
            FirstCommand := False;
            Continue;
            end;

         if not ProcessConfigInstruction(FileString, FirstCommand) then
            begin
            //        WriteLn;
            //        WriteLn('INVALID STATEMENT IN ', FileName, '!!  Line ', LineNumber);
            //        WriteLn(FileString);
      FileString[length(FileString) + 1] := #0;
      // Issue #997: asm wsprintf-push -> TF.Format. Args pushed cdecl-reverse;
      // format is %s(FileName) / %u(LineNumber) / %s(FileString).
      showwarning(SysUtils.Format(AnsiString(LclText(TC_INVALIDSTATEMENTIN)), [FileName, LineNumber, FileString]));
      Exit;
            end;

         inc(LineNumber);
         end;

     Close(ConfigRead);
     LoadInSeparateConfigFile := True;
      end   
  
  else
     begin
     FileName[Ord(FileName[0]) + 1] := #0;
     // Issue #997: asm wsprintf-push -> TF.Format.
     showwarning(SysUtils.Format(AnsiString(LclText(TC_UNABLETOFIND)), [FileName]));
     Exit;
     end;
 // n4af }
end;

(* ~~FileHasCommands~~ -- DELETED 2026-09-19 WITH THE INI READ.

  It answered "is this tr4w.ini worth opening" so an inert file was not
  announced at every start. Nothing opens tr4w.ini at startup any more, so
  the question has no asker: the converter reads the file because it was
  asked to, whatever is in it.

  AND NO DETECTOR REPLACES IT. An in-program "you still have an ini" check
  was written and withdrawn the same day -- NY4I: "it frankly kept getting
  in the way and causing confusion". Telling the operator to run the
  conversion once is SETUP's job. *)

(* WHICH FILE A CONFIG PASS READS, AS TEXT.

  This was CFGFilesArray: a typed constant holding the ADDRESSES of the four
  file-name buffers, read back as PAnsiChar -- through StrPas, through an
  implicit conversion into a string parameter, and twice as a raw pointer in
  an argument list. Each buffer is filled by SetCharBuffer, so CharBufferText
  is the read. *)
function CFGFileName(const aType: TCFGType): string;
begin
   Result := '';
   case aType of
      cfgCFG:
         begin
         Result := CharBufferText(TR4W_CFG_FILENAME);
         end;
      cfgINPUT:
         begin
         Result := CharBufferText(TR4W_INPUT_CFG_FILENAME);
         end;
      cfgCommMes:
         begin
         Result := CharBufferText(TR4W_DEFMESSAGES_FILENAME);
         end;
   end;
end;

procedure ReadInConfigFile(ConfigFileName: TCFGType);

{ This procedure will read in the config file which contains the
  initial values for several global variables.  This makes it easier to
  restart the program in case of a power failure. }

(* THE CASE-SENSITIVITY NOTE THAT STOOD HERE WENT WITH THE INI READ,
  2026-09-19.  It described the second pass over tr4w.ini that put an
  operator's own capitalisation back after EnumerateLinesInFile had
  upper-cased the whole line; see the note where RestoreCFGPasswordCase
  used to be.  The upper-casing itself is unchanged and still applies to
  the contest .cfg and the common-messages file, neither of which has
  ever carried a password or a case-sensitive value. *)
begin
  (* THE RESETS USED TO BE HERE, AND THAT IS WHAT MADE EVERY US CALLSIGN DX.

    ClearDomesticCountryList ran at the top of this routine, before ANY of the
    early exits below -- before the "this is a .db, not a text .cfg" exit, and
    before the file is known to exist at all. A contest opened as a DATABASE
    therefore had its domestic country list emptied by a read THAT NEVER
    HAPPENED, and nothing repopulated it.

    The New Contest dialog applies CONTEST before startup gets here
    (uNewContest:592), and that is what calls FoundContest and adds K, VE, KH6
    and KL. This routine then wiped them a fraction of a second later.

    NY4I, Linux Mint 2026-09-09, on a contest created by the dialog:

        [Config] ... is a log database, not a text .cfg
        [Domestic] The domestic country list is EMPTY

    NOT A LINUX BUG. It happens wherever a contest is a .db, which is the
    normal case since phase E2 -- Linux is simply where a fresh contest got
    created and looked at. A .cfg contest still works because the read really
    does follow and repopulates.

    A RESET BELONGS WITH THE THING IT PREPARES FOR. Both moved to immediately
    before the parse, so "clear and rebuild" is one operation rather than two
    separated by four early exits. *)
  LineNumberInConfigFile := 0;
  CurrentConfigFile := ConfigFileName;
  (* A CONTEST FILE THAT IS A DATABASE IS NOT PARSED AS TEXT.

    The operator can now choose a .db in the New Contest dialog -- it is the
    PRIMARY filter there, because a .db is what a contest is. The chosen file
    still arrives in TR4W_CFG_FILENAME, which is correct and is not the bug:
    every other name is derived from that one by STEM, so a .db yields exactly
    the right TR4W_LOG_FILENAME and the right database. The one thing that must
    not happen is feeding those bytes to a line parser.

    SKIPPING THE READ IS THE CORRECT BEHAVIOUR, not damage control. Phase E2
    moved the contest's configuration INTO the log, and uProgramMain calls
    LogStoreApplyContestConfig a few statements after this one -- deliberately
    after, so it overrides. A contest opened as a .db is therefore fully
    configured without this read ever happening. NY4I's own criterion: "when
    done, the .cfg file should not be necessary."

    THE FILE IS ALREADY KNOWN TO BE ONE OF OURS. uProgramMain classified it
    when the name entered the program and stopped for anything else, so the
    only kinds that reach here are a TR4W database and a text config. Asking
    again is cheap and keeps this correct for any future caller that did not
    go through startup.

    cfgCFG ONLY: tr4w.ini and the common-messages file are text by definition
    and are not chosen by the operator. *)
  (* THE tr4w.ini EARLY EXIT THAT STOOD HERE IS GONE -- 2026-09-19.

    It asked FileHasCommands so an inert ini was not opened and not
    announced (NY4I, 2026-09-02: "We also need to stop trying to open
    tr4w.ini").  Startup no longer passes this routine an ini at all --
    cfgINI is not a member of TCFGType any more -- so there is nothing
    left to skip.  The file belongs to tr4wconvert. *)

  if (ConfigFileName = cfgCFG) and
     (ClassifyContestFile(CFGFileName(ConfigFileName)) = cfkTR4WDatabase) then
     begin
     logger.Info('[Config] %s is a log database, not a text .cfg -- the ' +
                 'contest configuration comes from the log itself',
                 [CFGFileName(ConfigFileName)]);
     Exit;
     end;

  (* CLEARED HERE, WHERE THE REBUILD IMMEDIATELY FOLLOWS -- see the note at the
    top of this routine for what happened when these ran before the exits.

    ClearDomesticCountryList: the file about to be parsed is the authority on
    which countries are domestic, so the old set goes first.

    ClearContestCFGCommands: the override tracker is per contest .cfg load, so
    switching contests re-decides which commands that contest claims rather
    than accumulating them across every contest opened this session. *)
  if ConfigFileName = cfgCFG then
     begin
     ClearDomesticCountryList;
     ClearContestCFGCommands;
     end;

  logger.Info('[Config] Loading %s', [CFGFileName(ConfigFileName)]);
  EnumerateLinesInFile(CFGFileName(ConfigFileName), EnmuCFGFile, True);

  // CW-state desync fix: the 'CW ENABLE' config command writes only Config.CWEnable,
  // but the actual transmit gate (SendCrypticCWString) and the Alt-K toggle
  // (SetCWState) key off CWEnabled, while the speed display ORs the two.  With
  // nothing syncing them, "CW ENABLE = FALSE" left CWEnabled at its True
  // default -- so the display showed "WPM" yet no CW was sent until two Alt-K
  // toggles reconciled both.  Mirror the configured value into the runtime gate
  // after every config read so the two can never start out of step.  (Config.CWEnable
  // and CWEnabled represent the same thing and SetCWState always sets both.)
  CWEnabled := Config.CWEnable;

  (* AND THE SAME MIRROR FOR THE OTHER FIVE, 2026-09-14.

    Each of these is two things wearing one name: what the operator CONFIGURED
    and what the session is doing right now. A CW control code changes the
    weight mid-message, the speed keys nudge WPM, Alt-K toggles the gate --
    all of which write the GLOBAL and must not write the setting back, or one
    message's nudge becomes tomorrow's starting speed.

    So the settings are copied into the live globals here, once per config
    read, exactly as CW ENABLE has been since the desync fix above. Their CFGCA
    rows wrote the globals directly, which is why there was nowhere to keep the
    configured value. *)
  Config.CWEnable        := Settings.Cw.Enable;
  CWEnabled              := Settings.Cw.Enable;
  Config.CWTone          := Settings.Cw.Tone;
  Config.FarnsworthEnable := Settings.Cw.FarnsworthEnable;
  Config.FarnsworthSpeed := Settings.Cw.FarnsworthSpeed;
  Config.Weight          := Settings.Cw.Weight;
  CodeSpeed              := Settings.Cw.CodeSpeed;
  StereoPinState         := Settings.Cw.StereoPinHigh;

  (* THE CONFIGURATION IS NOT COMPLETE HERE, SO IT IS NOT CHECKED HERE.

    This halted the program if Settings.My.Call was empty after reading the contest .cfg
    -- halfway through assembling the configuration, with the common messages
    and the log's own settings still to come. That was harmless while the .cfg
    was the last word on a contest. It is not now: the log carries the contest's
    configuration, and a .cfg that no longer holds MY CALL is the intended end
    state, not an error.

    ConfigurationOkay is called from uProgramMain once every source has
    contributed. Same check, same halt, asked when the answer means something. *)
  // (moved) if ConfigFileName = cfgCFG then if not ConfigurationOkay then halt;
end;

procedure LookForCommands(var ContestConfigFileTitle: Str20);

var
  Result, ParameterCount                : integer;
  LastPushedLogName                     : Str20; {KK1L: 6.71}
  TempString                            : Str40;

begin
  PacketFile := False;
   for ParameterCount := 1 to ParamCount do
      begin


      if UpperCase(ParamStr(ParameterCount)) = 'BANDMAP' then
         begin
         FakeBandMap := True;
         end;

      if UpperCase(ParamStr(ParameterCount)) = 'DEBUG' then
         begin
         DebugFlag := True;
         logger.Level := Debug;
         end;

       if UpperCase(ParamStr(ParameterCount)) = 'TRACE' then
          begin
          DebugFlag := True;
          logger.Level := Trace;
          end;

      if UpperCase(ParamStr(ParameterCount)) = 'FOOTSWITCHDEBUG' then
         begin
         FootSwitchDebug := True;
         end;


      if UpperCase(ParamStr(ParameterCount)) = 'NETDEBUG' then
         begin
         NetDebug := True;
         end;

      if UpperCase(ParamStr(ParameterCount)) = 'PACKET' then
         begin
         FakePacket := True;
         end;

      if UpperCase(ParamStr(ParameterCount)) = 'PACKETFILE' then
         begin
         WriteLn('Opening ', ParamStr(ParameterCount + 1), ' as a packet file to process.');
         end;

      if UpperCase(ParamStr(ParameterCount)) = 'PACKETINPUTFILE' then
         begin
         Packet.PacketInputFileName := ParamStr(ParameterCount + 1);

         if StringIsAllNumbers(ParamStr(ParameterCount + 2)) then
            begin
            TempString := ParamStr(ParameterCount + 2);
            Val(TempString, PacketInputFileDelay, Result);
            end;
         end;

      if UpperCase(ParamStr(ParameterCount)) = 'READ' then
         begin
         //      ReadInLog := True;
               ReadInLogFileName := ParamStr(ParameterCount + 1);
                   ////{WLI}            Inc (ParameterCount);
         end;

        {KK1L: 6.71 Added as a multiplier and dupe check}

      if UpperCase(ParamStr(ParameterCount)) = 'RESCORE' then
         begin
         PushLogFiles(LastPushedLogName);
         ReadInLogFileName := LastPushedLogName;
         WriteLn('Ready to rescore ', ReadInLogFileName, '!');
         end;

      // RADIODEBUG / SERIALDEBUG / TALKDEBUG were removed with the COM<n>IN.BIN /
      // COM<n>OUT.BIN writers they enabled.  Those predate Log4D; CAT tracing is
      // now DEBUG LOG LEVEL = TRACE, which logs both directions with timestamps.


      end;
end;

procedure tSetupExchangeNumbers;
var
  tCQExchange, tSPExchange              : ShortString;
  Grid                                  : ShortString;
begin


  tSPExchange := '';
  tCQExchange := '';
  Grid := UTF8Encode(Copy(Settings.My.Grid, 1, 4));
  case Contest of

    MAKROTHEN:
      begin
        tCQExchange := ' ' + Grid + ' ' + Grid;
      end;

    RADIOMEMORY, WISCONSINQSOPARTY: tCQExchange := UTF8Encode(' ' + Settings.My.State);

    LQP, NCCCSPRINT: tCQExchange := UTF8Encode(' # ' + Settings.My.Name + ' ' + Settings.My.State);

//    JTDX, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW, UCG: tCQExchange := ' 5NN #';

    R9W_UW9WK_MEMORIAL, CUPURAL, UKRAINECHAMPIONSHIP, RFASCHAMPIONSHIPCW, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB: tCQExchange := UTF8Encode(' ' + Settings.My.State + '#');

    ALRS_UA1DZ_CUP, OLDNEWYEAR, TENNESSEEQSOPARTY, SALMONRUN, ALLASIANCW, ALLASIANSSB, SEVENQP, ARRL160, ARRLDXCW: tCQExchange := UTF8Encode(' 5NN ' + Settings.My.State);

    OHIOQSOPARTY, CALQSOPARTY, UA4WCHAMPIONSHIP, RAEM, CUPRFCW, CUPRFSSB: tCQExchange := UTF8Encode(' # ' + Settings.My.State);
{
    ARI, SPDX, ARKTIKA_SPRING, PACC, WAG, CUPUA1DZ, RUSSIANDX, RDA, OKDX, UKRAINIAN, OLDNEWYEAR, ARRL10, HADX, YODX, RSGB18, DARCXMAS:
      begin
        if Settings.My.State <> '' then tCQExchange := ' 5NN ' + Settings.My.State else tCQExchange := ' 5NN #';
      end;
}
    JIDXCW, JIDXSSB, CQ160SSB, CQ160CW, LZDX, IARU, OZCR_O, OZCR_Z:
      begin
        if Settings.My.State <> '' then
           begin
           tCQExchange := UTF8Encode(' 5NN ' + Settings.My.State)
           end
        else
           begin
           tCQExchange := UTF8Encode(' 5NN ' + Settings.My.Zone);
           end;
      end;

    CQIR:
      begin
        if Settings.My.State <> '' then
           begin
           tCQExchange := UTF8Encode(' ' + Settings.My.State + ' #')
           end
        else
           begin
           tCQExchange := ' #';
           end;
      end;

    NZFIELDDAY:
      tCQExchange := UTF8Encode(' 5NN # ' + Settings.My.Zone);

//    EUROPEANHFC, CQWWCW, CQWWSSB, GACWWWSACW, GAGARINCUP: tCQExchange := ' 5NN ' + Settings.My.Zone;
    {CZECH_ACTIVITY_VHF,}OZHCRVHF, RADIOVHFFD: tCQExchange := UTF8Encode(' 5NN # ' + Settings.My.Grid);

    NRAUBALTICCW, NRAUBALTICSSB, RU3AXMEMORIAL, {WWPMC,} UBACW, UBASSB: tCQExchange := UTF8Encode(' 5NN # ' + Settings.My.State);

   PCC, IOTA, HELVETIA: if Settings.My.State <> '' then tCQExchange := UTF8Encode(' 5NN # ' + Settings.My.State) else tCQExchange := ' 5NN #';

    EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW:
      begin
        tCQExchange := UTF8Encode(' DE \ # ' + Settings.My.Name);
        tSPExchange := '@' + tCQExchange;
      end;

    CWOPEN:
      begin
        tCQExchange := UTF8Encode(' # ' + Settings.My.Name);
      end;

  end;

{
  case Contest of
    CQWWRTTY:
      begin
        tCQExchange := UTF8Encode(' 599 ' + Settings.My.Zone + ' ' + Settings.My.Zone);
      end;

    CUPRFDIG:
      begin

      end;
  end;
  Settings.Messages.CqExchangeCw := tCQExchange;
  Settings.Messages.SpExchangeCw := tCQExchange;
  Settings.Messages.RepeatSpExchangeCw := tCQExchange;
  Settings.Messages.CqExchangeCwNameKnown := tCQExchange;
  Exit;
}

  if Settings.Messages.CqExchangeCw = '' then
     begin
     Settings.Messages.CqExchangeCw := tCQExchange;
     end;

  if Settings.Messages.SpExchangeCw = '' then
    Settings.Messages.SpExchangeCw := '_@_' + Settings.Messages.CqExchangeCw;

  if Settings.Messages.RepeatSpExchangeCw = '' then
     begin
     Settings.Messages.RepeatSpExchangeCw := tSPExchange;
     end;

  if Settings.Messages.CqExchangeCwNameKnown = '' then
     begin
     Settings.Messages.CqExchangeCwNameKnown := tCQExchange;
     end;
end;

procedure EnmuCFGFile(FileString: PShortString);
var
  ID                                    : ShortString;
  CMD                                   : ShortString;
 begin

  // Lines whose FIRST character (column 1, before any spaces are stripped) is a
  // comment/section marker are ignored:  ;  and  #  are comments,  [  is a
  // section header,  _  is an internal marker.  Kept in sync with the same test
  // in RestoreCFGPasswordCase so both passes treat comments identically.
  if FileString^[1] in [';', '#', '[', '_'] then Exit;

  GetRidOfPrecedingSpaces(FileString^);
  GetRidOfPostcedingSpaces(FileString^);


  ID := PrecedingString(FileString^, '=');
  CMD := PostcedingString(FileString^, '=');

  if ID = '' then Exit;

  GetRidOfPrecedingSpaces(ID);
  GetRidOfPrecedingSpaces(CMD);
  GetRidOfPostcedingSpaces(ID);
  GetRidOfPostcedingSpaces(CMD);

  inc(LineNumberInConfigFile);

  // Issue #997: removed a no-op `if cfgINI then if line > 155 then asm nop end`
  // (a debugger breakpoint anchor; no runtime effect).

  if CurrentConfigFile = cfgCFG then
     begin
     if LineNumberInConfigFile = 1 then
       if ID <> 'MY CALL' then
          begin
          showwarning(TC_THEFIRSTCOMMANDINCONFIGFILEMUSTBE);
          halt;
          end;

     end;

  if CMD = 'SPACE' then
     begin
     CMD[1] := ' ';
     end;
   if cmd = 'FM' then
      begin
      CMD := 'FM';
      end;
  // A MIGRATED SETTING NAMED IN THE CONTEST .cfg IS APPLIED HERE, AND WINS.
  //
  // csJSON makes CheckCommand inert for the config loader -- that is the point,
  // and it is why an ini line for a migrated setting is correctly ignored
  // (NY4I: "settings in the ini file that correspond to entries marked csJSON
  // should be ignored"). But the SAME early exit fires for the contest .cfg,
  // which is not the same thing at all: a station preference should not be read
  // from a stale ini, while a contest deliberately asking for LEADING ZEROS must
  // be obeyed. Six real contest configs set that one, both CQ-WPX among them.
  //
  // So for the CONTEST .cfg only, a csJSON row is applied as a trusted caller
  // and recorded. ApplyStoredCommands then skips it, so the station's stored
  // value cannot overwrite the contest's while that contest is loaded.
  //
  // Station defaults <- contest overrides, with the .cfg needing no storage of
  // its own: it only needs to be SEEN.
  (* EVERY command the CONTEST .cfg sets is recorded as the contest's, not only
    the csJSON ones -- phase E3.

    This note was added for a narrower job: stopping ApplyStoredCommands from
    overwriting a contest's csJSON setting with the station's stored value. So
    it only fired for csJSON rows, and "which commands did this contest set"
    was answered correctly for six of them and silently wrongly for everything
    else.

    That is not sufficient once the LOG has to carry the contest. Measured on
    michigan_qp: the .cfg sets MY STATE=WAYN, which is csOwned, so it was never
    noted, was stored as a STATION setting, and was not applied from the log --
    every QSO exported with a sent QTH of "DX" instead of "WAYN".

    The note is now made for every command in the contest file. It is a record
    of PROVENANCE and nothing else; what is done with the value is unchanged
    below. *)
  (* A STATION-ONLY SETTING IN A CONTEST .cfg IS LOGGED AND DROPPED.
    2026-09-19, NY4I.

    DISPLAY LANGUAGE is the case. It could not take effect from here even if
    it were applied -- StartupUILanguage has already chosen the catalogue
    before any .cfg is read -- but applying it WOULD put the contest's value on
    the property, and the next Preferences save would write that into the
    station's settings\tr4w.json for good.

    BEFORE NoteCommandFromContestCFG, deliberately: the value is not the
    contest's, so recording the provenance would be a lie that
    ApplyStoredCommands then acts on.

    ACCEPTED, NOT REFUSED. Falling through to CheckCommand's failure arm shows
    the MODAL "Invalid statement in config file" below, once per stale line,
    about a .cfg that is otherwise perfectly good. The same reasoning as
    uCFG.RETIRED_COMMANDS, and the same answer: say it in the log.

    THE MEMBERSHIP IS A PROPERTY OF THE SETTING, not a list here -- see
    TSettingsGroup.IsStationOnly. *)
  if (CurrentConfigFile = cfgCFG) and
     Settings.CommandIsStationOnly(string(ID)) then
     begin
     logger.Warn('[Config] %s is a station setting and cannot be set by a ' +
                 'contest .cfg -- the line is ignored.  Set it in Preferences.',
                 [ID]);
     Exit;
     end;

  if CurrentConfigFile = cfgCFG then
     begin
     NoteCommandFromContestCFG(string(ID));
     end;

  if (CurrentConfigFile = cfgCFG) and CommandIsJSONOwned(string(ID)) then
     begin
     if CheckCommand(ID, CMD, True) then
        begin
        logger.Info('[Config] %s = %s from the contest .cfg -- overrides the stored value for this contest',
                    [ID, CMD]);
        end
     else
        begin
        logger.Warn('[Config] %s = %s in the contest .cfg was REFUSED by CFGCA', [ID, CMD]);
        end;
     end
  else if not CheckCommand(ID, CMD) then
     begin
     // Commands removed in a prior version — log quietly, no dialog
     if (ID = 'HAMLIB RIGCTLD PORT') or
        (ID = 'HAMLIB RIGCTLD IP ADDRESS') or
        (ID = 'HAMLIB RIGCTLD RUN AT STARTUP') then
        begin
        logger.Warn('[LogCfg] Obsolete command ignored (removed): %s', [ID]);
        end
     else
        begin
        (* THE THIRD ARGUMENT WAS A POINTER, AND %s CANNOT CONSUME ONE.

          @FileString^[1] is a PAnsiChar into a ShortString -- the Win32
          habit of making a C string of it -- and an array of const carries
          it as vtPointer, so SysUtils.Format raised EConvertError
          ("Invalid argument index") instead of showing the message. The
          refusal path therefore CRASHED THE PROGRAM rather than telling
          the operator which line it could not read.

          Latent since the pointer form was written, because it only fires
          when a config line is actually refused. Found 2026-09-12 by the
          golden corpus: WINTER FIELD DAY's .cfg carries TAIL END CW
          MESSAGE, whose CFGCA row is commented out, so that set alone took
          this path and exited 217.

          AND THE FIRST ARGUMENT IS A POINTER TOO: CFGFilesArray was an
          array[TCFGType] of PAnsiChar, so %s could not consume that one
          either. Two pointers on one line, the same habit twice, and the
          first one kept the crash alive after the third was fixed.

          An array of const takes the strings themselves. *)
        (* BUILT BY CONCATENATION, NOT BY Format. Two of the three arguments
          were POINTERS -- CFGFilesArray was an array of PAnsiChar and
          @FileString^[1] is a PAnsiChar into a ShortString -- which %s
          cannot consume, so this path raised EConvertError and CRASHED the
          program instead of naming the line it could not read. Fixing the
          arguments was not enough; a message with no format string cannot
          fail this way at all, and there is nothing here a format string
          was buying.

          AND FileString IS A PShortString HERE -- the routine's PARAMETER,
          not the ShortString of the same name declared further up this
          unit. My first attempt replaced @FileString^[1] with FileString
          and changed nothing, because that is still a pointer. Two
          variables one name apart, and only the dereference tells them
          apart. *)
        showwarning(AnsiString(CFGFileName(CurrentConfigFile)) + ':' + #13
                    + 'Invalid statement in config file.' + #13 + #13
                    + 'Line ' + AnsiString(IntToStr(LineNumberInConfigFile))
                    + #13 + FileString^);
 //    halt;
        end;
     end;

  (* THE DUPLICATE-KEY DETECTOR THAT STOOD HERE IS GONE -- 2026-09-19.

    It flagged a hand-edited key that appeared twice in tr4w.ini,
    where the line loader takes the last occurrence and the Win32
    profile API takes the first, so a duplicate silently reverted on
    restart.  It was gated on CurrentConfigFile = cfgINI and on
    nothing else -- a contest .cfg may legitimately repeat a key --
    and startup no longer reads an ini, so it could never fire.

    The failure it guarded cannot happen through the converter
    either: tr4wconvert reads the ini through TIniFile, which is the
    first-wins side of the disagreement and the only reader. *)
end;

//begin
  //  RemainingMultDisplayMode := NoRemainingMults;
  //  RunningConfigFile := False;

initialization
  logger := TLogLogger.GetLogger('LogCfg');

end.
