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
  uIO,
  utils_text,
  idUDPClient,
  idGlobal,
  LogStuff,
  Windows,
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
//  LOGHP,
  LogPack,
  LogK1EA, {DOS,}
//  Help,
//  LOGPROM,
  CFGCMD,
  {SlowTree,}Tree, {Crt,}
//  LOGMENU,
  LogNet,
  LogRadio,
  CFGDEF,
  SysUtils,
  Log4D
  ;

type
  TCFGType = (cfgCFG, cfgINI, cfgINPUT, cfgCommMes);

function LoadInSeparateConfigFile(FileName: ShortString;
  var FirstCommand: boolean;
  Call: CallString): boolean;

procedure LookForCommands(var ContestConfigFileTitle: Str20);
procedure ReadInConfigFile(ConfigFileName: TCFGType);
procedure TryRunPaddleAndFootSwitchThread;
procedure tSetupExchangeNumbers;
procedure InitializeOtherLPTPorts;
procedure EnmuCFGFile(FileString: PShortString);
procedure SetUpGlobalsAndInitialize;

const
  CFGFilesArray                         : array[TCFGType] of PAnsiChar = (@TR4W_CFG_FILENAME, @TR4W_INI_FILENAME, @TR4W_INPUT_CFG_FILENAME, @TR4W_DEFMESSAGES_FILENAME);

var
  LineNumberInConfigFile                : integer;
  CurrentConfigFile                     : TCFGType;

implementation

uses
  uAnsiStr,      // StrComp/StrPLCopy over PAnsiChar (SysUtils variants are PWideChar)
  uCFG,
  MainUnit,
  uRadioPolling,
   uUDPBroadcaster,
   uUDPBroadcastConfig,
   uTR4WConfigFile,
   uRotatorControl;   // OpenRotatorPorts -- the library opens its own ports

type
  // One single-valued tr4w.ini key already applied this load pass, plus the raw
  // source-line number of its first occurrence (see gRawLineNumber).
  TSeenINICmd = record
    Name: string;
    Line: integer;
  end;

var
  logger: TLogLogger;

  // Single-valued tr4w.ini keys already applied in the current load pass, used to
  // flag hand-edited duplicates (see EnmuCFGFile).  Managed array -> reset with
  // SetLength(...,0) in ReadInConfigFile; no create/free needed.
  gSeenINICmds: array of TSeenINICmd;

  // Raw source-line counter for the current load pass: incremented once per
  // NON-EMPTY line the enumerator yields (comments and section headers included;
  // EnumerateLinesInFile drops blank lines before the callback).  Equals the
  // physical file line number except where blank lines precede -- close enough to
  // locate a hand-edited duplicate, and it needs no change to the shared enumerator.
  gRawLineNumber: integer;

{ Callback for the ctPassword fixup second pass (see ReadInConfigFile).
  Called by EnumerateLinesInFile with UpperCase=False so CMD retains original
  case. Uppercases only the key (ID) for CFGCA lookup, then stores CMD for any
  entry whose crType is ctPassword. }
procedure RestoreCFGPasswordCase(FileString: PShortString);
var
   ID: ShortString;
   CMD: ShortString;
   I: Integer;
begin
   // Same comment/section markers as EnmuCFGFile (;  #  [  _) -- keep in sync.
   if FileString^[1] in [';', '#', '[', '_'] then Exit;

   GetRidOfPrecedingSpaces(FileString^);
   GetRidOfPostcedingSpaces(FileString^);

   ID  := PrecedingString(FileString^, '=');
   CMD := PostcedingString(FileString^, '=');

   if ID = '' then Exit;

   GetRidOfPrecedingSpaces(ID);
   GetRidOfPrecedingSpaces(CMD);
   GetRidOfPostcedingSpaces(ID);
   GetRidOfPostcedingSpaces(CMD);

   // Uppercase only the key so it matches CFGCA entries (which are uppercase).
   // CMD is intentionally left as-is — preserving the user's original case.
   strU(ID);
   ID[Length(ID) + 1] := #0;  // null-terminate for PChar comparisons

   for I := 1 to CommandsArraySize do
      begin
      if CFGCA[I].crType in [ctCaseSensitive, ctPassword] then
         if uAnsiStr.StrComp(CFGCA[I].crCommand, @ID[1]) = 0 then
            begin
            PShortString(CFGCA[I].crAddress)^ := CMD;
            PShortString(CFGCA[I].crAddress)^[Length(CMD) + 1] := #0;
            if CFGCA[I].crType = ctPassword then
               begin
               logger.Debug('[case fixup] "%s" restored, value=*******', [CFGCA[I].crCommand])
               end
            else
               begin
               logger.Debug('[case fixup] "%s" restored, value=%s', [CFGCA[I].crCommand, CMD]);
               end;
            Break;
            end;
      end;
end;

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

  if MyCall = '' then
     begin
     showwarning(TC_NOCALLSIGNSPECIFIED);
     Exit;
     end;
{
  if FloppyFileSaveFrequency > 0 then
    if FloppyFileSaveName = '' then
    begin
      showwarning(TC_NOFLOPPYFILESAVENAMESPECIFIED);
      Exit;
    end;
}
  ConfigurationOkay := True;
end;

procedure InitializeOtherLPTPorts;
begin

  if ActivePaddlePort <> NoPort then
    if ActivePaddlePort = RelayControlPort then
       begin
       showwarning('RELAY CONTROL PORT = PADDLE PORT');
 //      Exit;
       end;

  tRelayControlPortBaseAddress := INVALID_HANDLE_VALUE;
  if tGetPortType(RelayControlPort) = ParallelInterface then
     begin
     OpenLPT(tRelayControlPortBaseAddress, RelayControlPort);
     end;

  tActiveStereoPortBaseAddress := INVALID_HANDLE_VALUE;
  if tGetPortType(ActiveStereoPort) = ParallelInterface then
     begin
     OpenLPT(tActiveStereoPortBaseAddress, ActiveStereoPort);
     end;

  Radio1.tBandOutputPortBaseAddress := INVALID_HANDLE_VALUE;
  if tGetPortType(Radio1.BandOutputPort) = ParallelInterface then
     begin
     OpenLPT(Radio1.tBandOutputPortBaseAddress, Radio1.BandOutputPort);
     end;

  Radio2.tBandOutputPortBaseAddress := INVALID_HANDLE_VALUE;
  if tGetPortType(Radio2.BandOutputPort) = ParallelInterface then
     begin
     OpenLPT(Radio2.tBandOutputPortBaseAddress, Radio2.BandOutputPort);
     end;
end;

procedure TryRunPaddleAndFootSwitchThread;
begin

  if tUseControlPort then
    if Radio1.tCATPortHandle <> INVALID_HANDLE_VALUE then
       begin
       DoingPaddle := True;
       tDoingFootSwitchEnable := True;
       tRuntPaddleAndFootSwitchThread;
       Exit;
       end;

  if tGetPortType(ActiveFootSwitchPort) = ParallelInterface then
    if OpenLPT(tFootSwitchPortBaseAddress, ActiveFootSwitchPort) then
       begin
       tRuntPaddleAndFootSwitchThread;
       tDoingFootSwitchEnable := True;
       end;

  if tGetPortType(ActivePaddlePort) = ParallelInterface then
    if OpenLPT(tPaddlePortBaseAddress, ActivePaddlePort) then
       begin
       tRuntPaddleAndFootSwitchThread;
       DoingPaddle := True;
       end;

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
  // ConfigureRotators has already run by this point (tr4w.dpr:974; this routine
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
  if (Radio1.tCATPortType in SerialPorts) and
     (Radio1.tCATPortType = Radio2.tCATPortType) then
     begin
     showwarning(SysUtils.Format(TC_PORT_CONFLICT_STARTUP,
        [string(AnsiString(PortTypeSA[Radio1.tCATPortType]))]));
     Radio2.tCATPortType := NoPort;
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
   settingsDir := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))));
   cfg := LoadUDPForStartup(settingsDir + 'tr4w.json', settingsDir + 'tr4w.ini');
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
//var
//FileName : str40;
begin

  StartCPU := GetTickCount;
  udp := TIdUDPClient.Create(nil); // ny4i Issue #99
  // The broadcaster owns WHETHER and WHERE; this unit owns the socket, so it
  // hands over the transport once the socket exists.  Keeping Indy out of
  // uUDPBroadcaster is what lets its enable and port rules be unit-tested
  // against a recording stub instead of a network trace.
  UDPBroadcaster.SetTransport(SendUDPPayload);
  ConfigureUDPBroadcastFromLibrary;
  if QTCsEnabled then New(QTCDataArray); //LoadQTCDataFile;

//  if TempDomesticQTHDataFileName <> nil then
//    TF.Format(DomQTHDataFileName, '%sDOM\%s.DOM', TR4W_PATH_NAME, TempDomesticQTHDataFileName);

  if DomQTHDataFileName[0] <> #0 then
     begin
     if fileexists(TR4W_DOM_FILENAME) then                       // 4.100.2
        begin
        TF.Format(wsprintfBuffer, '%s', TR4W_DOM_FILENAME)
        end
      else
         begin
         TF.Format(wsprintfBuffer, '%sdom\%s', TR4W_PATH_NAME, DomQTHDataFileName);
         end;
      Windows.ZeroMemory(@DomQTHDataFileName, SizeOf(DomQTHDataFileName));
      Windows.lstrcatA(DomQTHDataFileName, wsprintfBuffer);
      if not DomQTHTable.LoadInDomQTHFile(DomQTHDataFileName) then
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

  if AutoTimeIncrementQSOs <> 0 then
     begin
     IncrementTimeEnable := True;
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
  Windows.CopyMemory(@FreqMemory, @DefaultFreqMemory, SizeOf(TFreqMemoryType));

  Sheet.SheetInitAndLoad;
  LoadBandMap;
  DisplayContestTitle;

  if CurrentOperator[0] = #0 then  // ny4i Issue #97
     begin
     uAnsiStr.StrPLCopy(CurrentOperator, MyCall, High(CurrentOperator)); // This copies the string MyCall to char array CurrentOperator (I love mixed types :) ) // ny4i
     end;

  CheckAndInitializeSerialPorts;
  InitializeKeyer;
//  ActiveKeyerPort := ActiveRadioPtr.tKeyerPort;
//  tActiveKeyerHandle := ActiveRadioPtr.tKeyerPortHandle;

  TryRunPaddleAndFootSwitchThread;
  InitializeOtherLPTPorts;
  MonitorTone := Config.CWTone;

//  ActiveBand := ActiveRadioPtr.BandMemory;
//  ActiveMode := ActiveRadioPtr.ModeMemory;

  DisplayCodeSpeed;
  Str(Radio1.SpeedMemory, SpeedString); {KK1L: 6.73 Initialize SpeedString for ALT-D use.}
  // SetSpeed(CodeSpeed);  // ny4i Issue 153 Not necessary as SetUpToSendOnActiveRadio is called and sets the speed

  if AutoSendCharacterCount > 0 then
     begin
     AutoSendEnable := True;
     DisplayAutoSendCharacterCount;
     end;
{
  if ReadInLog then
  begin
    AutoDupeEnableCQ := False;

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
      TF.Format(wsprintfBuffer, TC_INVALIDSTATEMENTIN, @FileName[1], LineNumber, @FileString[1]);
      showwarning(wsprintfBuffer);
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
     TF.Format(wsprintfBuffer, TC_UNABLETOFIND, @FileName[1]);
     showwarning(wsprintfBuffer);
     Exit;
     end;
 // n4af }
end;

procedure ReadInConfigFile(ConfigFileName: TCFGType);

{ This procedure will read in the config file which contains the
  initial values for several global variables.  This makes it easier to
  restart the program in case of a power failure. }

{ --- ARCHITECTURE NOTE: The Case-Sensitivity Problem ---

  EnumerateLinesInFile is called below with UpperCase=True. This causes it to
  call strU() on every raw line from the file BEFORE the line is parsed into a
  command key and value. strU() uppercases the ENTIRE line in place using x86 ASM,
  so a line like:

      RADIO ONE ICOM NETWORK PASSWORD=appleipod

  becomes:

      RADIO ONE ICOM NETWORK PASSWORD=APPLEIPOD

  before EnmuCFGFile ever splits on '='. The value extracted as CMD is therefore
  already uppercase when CheckCommand stores it, regardless of the ctPassword type.

  The UpperCase=True flag exists for good reason: many command values (booleans
  stored as 'T'/'F', port names like 'NONE', alpha chars, band names) must be
  uppercase to pass CheckCommand's validation logic. Changing the flag globally
  would break all of those.

  STOPGAP FIX (until the config parser is refactored):
  After the normal load pass, re-read every ctPassword field from the INI file a
  second time using Windows.GetPrivateProfileString. The Win32 INI API returns
  values exactly as written in the file — it never modifies case. This overwrites
  the uppercase value that the first pass stored, restoring the user's original
  mixed-case password or username.

  This fixup only runs for cfgINI (not .cfg files) because:
  - Passwords/usernames are only stored in tr4w.ini, not in contest .cfg files.
  - GetPrivateProfileString requires a section + key from a proper INI file.

  Long-term fix: the parser should split the raw line into key/value BEFORE
  calling strU, then uppercase only the key, leaving the value untouched.
  All ctPassword fields in CFGCA (crType = ctPassword) would then be handled
  correctly without a second-pass workaround. }

begin
  if ConfigFileName = cfgCFG then
     begin
     ClearDomesticCountryList;
     end;
  LineNumberInConfigFile := 0;
  gRawLineNumber := 0;
  CurrentConfigFile := ConfigFileName;
  // Reset the duplicate-key tracker per load; only tr4w.ini is checked (see EnmuCFGFile).
  if ConfigFileName = cfgINI then
     begin
     SetLength(gSeenINICmds, 0);
     end;

  // Reset the contest-override tracker per contest .cfg load, so switching
  // contests re-decides which commands that contest claims rather than
  // accumulating them across every contest opened this session.
  if ConfigFileName = cfgCFG then
     begin
     ClearContestCFGCommands;
     end;
  logger.Info('[Config] Loading %s', [CFGFilesArray[ConfigFileName]]);
  EnumerateLinesInFile(CFGFilesArray[ConfigFileName], EnmuCFGFile, True);

  // STOPGAP: Re-read ctPassword fields with original case from the INI file.
  // See the architecture note above for why this is necessary.
  // Uses EnumerateLinesInFile (UpperCase=False) + RestoreCFGPasswordCase callback
  // rather than GetPrivateProfileString, which proved unreliable in this context.
  if ConfigFileName = cfgINI then
     begin
     EnumerateLinesInFile(TR4W_INI_FILENAME, RestoreCFGPasswordCase, False);
     end;

  // CW-state desync fix: the 'CW ENABLE' config command writes only Config.CWEnable,
  // but the actual transmit gate (SendCrypticCWString) and the Alt-K toggle
  // (SetCWState) key off CWEnabled, while the speed display ORs the two.  With
  // nothing syncing them, "CW ENABLE = FALSE" left CWEnabled at its True
  // default -- so the display showed "WPM" yet no CW was sent until two Alt-K
  // toggles reconciled both.  Mirror the configured value into the runtime gate
  // after every config read so the two can never start out of step.  (Config.CWEnable
  // and CWEnabled represent the same thing and SetCWState always sets both.)
  CWEnabled := Config.CWEnable;

  if ConfigFileName = cfgCFG then if not ConfigurationOkay then halt;
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
  Grid := Copy(MyGrid, 1, 4);
  case Contest of

    MAKROTHEN:
      begin
        tCQExchange := ' ' + Grid + ' ' + Grid;
      end;

    RADIOMEMORY, WISCONSINQSOPARTY: tCQExchange := ' ' + MyState;

    LQP, NCCCSPRINT: tCQExchange := ' # ' + MyName + ' ' + MyState;

//    JTDX, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW, UCG: tCQExchange := ' 5NN #';

    R9W_UW9WK_MEMORIAL, CUPURAL, UKRAINECHAMPIONSHIP, RFASCHAMPIONSHIPCW, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB: tCQExchange := ' ' + MyState + '#';

    ALRS_UA1DZ_CUP, OLDNEWYEAR, TENNESSEEQSOPARTY, SALMONRUN, ALLASIANCW, ALLASIANSSB, SEVENQP, ARRL160, ARRLDXCW: tCQExchange := ' 5NN ' + MyState;

    OHIOQSOPARTY, CALQSOPARTY, UA4WCHAMPIONSHIP, RAEM, CUPRFCW, CUPRFSSB: tCQExchange := ' # ' + MyState;
{
    ARI, SPDX, ARKTIKA_SPRING, PACC, WAG, CUPUA1DZ, RUSSIANDX, RDA, OKDX, UKRAINIAN, OLDNEWYEAR, ARRL10, HADX, YODX, RSGB18, DARCXMAS:
      begin
        if MyState <> '' then tCQExchange := ' 5NN ' + MyState else tCQExchange := ' 5NN #';
      end;
}
    JIDXCW, JIDXSSB, CQ160SSB, CQ160CW, LZDX, IARU, OZCR_O, OZCR_Z:
      begin
        if MyState <> '' then
           begin
           tCQExchange := ' 5NN ' + MyState
           end
        else
           begin
           tCQExchange := ' 5NN ' + MyZone;
           end;
      end;

    CQIR:
      begin
        if MyState <> '' then
           begin
           tCQExchange := ' ' + MyState + ' #'
           end
        else
           begin
           tCQExchange := ' #';
           end;
      end;

    NZFIELDDAY:
      tCQExchange := ' 5NN # ' + MyZone;

//    EUROPEANHFC, CQWWCW, CQWWSSB, GACWWWSACW, GAGARINCUP: tCQExchange := ' 5NN ' + MyZone;
    {CZECH_ACTIVITY_VHF,}OZHCRVHF, RADIOVHFFD: tCQExchange := ' 5NN # ' + MyGrid;

    NRAUBALTICCW, NRAUBALTICSSB, RU3AXMEMORIAL, {WWPMC,} UBACW, UBASSB: tCQExchange := ' 5NN # ' + MyState;

   PCC, IOTA, HELVETIA: if MyState <> '' then tCQExchange := ' 5NN # ' + MyState else tCQExchange := ' 5NN #';

    EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW:
      begin
        tCQExchange := ' DE \ # ' + MyName;
        tSPExchange := '@' + tCQExchange;
      end;

    CWOPEN:
      begin
        tCQExchange := ' # ' + MyName;
      end;

  end;

{$IF MMTTYMODE}
{
  case Contest of
    CQWWRTTY:
      begin
        tCQExchange := ' 599 ' + MyZone + ' ' + MyZone;
      end;

    CUPRFDIG:
      begin

      end;
  end;
  CQExchange := tCQExchange;
  SearchAndPounceExchange := tCQExchange;
  RepeatSearchAndPounceExchange := tCQExchange;
  CQExchangeNameKnown := tCQExchange;
  Exit;
}
{$IFEND}

  if CQExchange = '' then
     begin
     CQExchange := tCQExchange;
     end;

  if SearchAndPounceExchange = '' then
    SearchAndPounceExchange := {$IF MMTTYMODE} '_@_' + {$IFEND}CQExchange;

  if RepeatSearchAndPounceExchange = '' then
     begin
     RepeatSearchAndPounceExchange := tSPExchange;
     end;

  if CQExchangeNameKnown = '' then
     begin
     CQExchangeNameKnown := tCQExchange;
     end;
end;

procedure EnmuCFGFile(FileString: PShortString);
var
  ID                                    : ShortString;
  CMD                                   : ShortString;
  k                                     : integer;
  firstLine                             : integer;
 begin

  // Count every non-empty source line the enumerator yields (comments and section
  // headers included) so a duplicate can be reported at ~its physical file line.
  inc(gRawLineNumber);

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
  if (CurrentConfigFile = cfgCFG) and CommandIsJSONOwned(string(ID)) then
     begin
     NoteCommandFromContestCFG(string(ID));
     if CheckCommand(@ID, CMD, True) then
        begin
        logger.Info('[Config] %s = %s from the contest .cfg -- overrides the stored value for this contest',
                    [ID, CMD]);
        end
     else
        begin
        logger.Warn('[Config] %s = %s in the contest .cfg was REFUSED by CFGCA', [ID, CMD]);
        end;
     end
  else if not CheckCommand(@ID, CMD) then
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
        TF.Format(wsprintfBuffer, TC_INVALIDSTATEMENTINCONFIGFILE, CFGFilesArray[CurrentConfigFile], LineNumberInConfigFile, @FileString^[1]);
        showwarning(wsprintfBuffer);
 //    halt;
        end;
     end
  else
     begin
     // Flag a hand-edited duplicate single-valued key in tr4w.ini.  The line-based
     // loader applies every occurrence (last wins) while the Win32 profile API used
     // by the config dialog reads/writes the first (first wins) -- so a duplicate
     // silently reverts on restart.  Only tr4w.ini scalars qualify; accumulating
     // commands (freq/band lists, ADD DOMESTIC COUNTRY) legitimately repeat.
     if (CurrentConfigFile = cfgINI) and CommandIsSingleValued(@ID) then
        begin
        firstLine := -1;
        for k := 0 to High(gSeenINICmds) do
           begin
           if gSeenINICmds[k].Name = string(ID) then
              begin
              firstLine := gSeenINICmds[k].Line;
              Break;
              end;
           end;
        if firstLine >= 0 then
           begin
           logger.Warn('[Config] Duplicate key "%s" in tr4w.ini: first at line %d, ' +
              'repeated at line %d -- startup uses the last occurrence, the config ' +
              'dialog uses the first; remove one.',
              [ID, firstLine, gRawLineNumber]);
           end
        else
           begin
           SetLength(gSeenINICmds, Length(gSeenINICmds) + 1);
           gSeenINICmds[High(gSeenINICmds)].Name := string(ID);
           gSeenINICmds[High(gSeenINICmds)].Line := gRawLineNumber;
           end;
        end;
     end;
end;

//begin
  //  RemainingMultDisplayMode := NoRemainingMults;
  //  RunningConfigFile := False;

initialization
  logger := TLogLogger.GetLogger('LogCfg');

end.
