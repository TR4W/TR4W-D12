unit uProgramMain;

// THE PROGRAM ITSELF -- everything tr4w.lpr used to hold in its own begin/end.
//
// WHY IT IS HERE AND NOT THERE (NY4I, 2026-08-25).  A .dpr is invisible to a
// search of src\, and this is where the STARTUP ORDER lives: the single-instance
// mutex, the logger, the config and CTY load, the headless modes, the window,
// the threads.  Eight hundred lines of the most order-sensitive code in the
// program sat in the one file nobody greps, and the answer to "where does X
// happen at startup" was "not in any unit."
//
// tr4w.lpr now holds the uses clause, the resources and one call.  The uses
// clause has to stay there -- it is what names every unit for the compiler and
// the IDE, and listing units for search visibility is deliberate (28d8f1da).
// So "which units are compiled" is still a .dpr question; "what does the
// program DO" is not, any more.
//
// THE USES CLAUSE BELOW IS THE .dpr's, IN THE SAME ORDER, MINUS THE PATHS.
// Not tidied, and deliberately so: this program relies on use-order for name
// resolution in places, and it is documented as doing so -- SysUtils declares
// a SysErrorMessage that differs from TF's, and uTelnet carries a note about
// which call sites must be qualified because of it.  Reordering or trimming
// this list is a separate change with its own testing, not a side effect of
// moving code.

{$I tr4w.inc}

interface

// Runs TR4W.  Does not return in normal use: shutdown goes through
// ExitProcess (tr4w_ShutDown, via ExitProgram), which is why nothing may be
// relied upon after the Application.Run at the bottom.
procedure RunTR4W;

implementation

uses
  Messages,
  MMSystem,
  Windows,
  SysUtils,
  LCLTranslator,
  MainUnit,
  BeepUnit,
  CFGCMD,
  CFGDEF,
  FCONTEST,
  LogCfg,
  LogCW,
  LogDom,
  LogDupe,
  LOGDVP,
  LogEdit,
  LogGrid,
  LogK1EA,
  LogNet,
  LogPack,
  LogRadio,
  LogSCP,
  LogStuff,
  LOGWAE,
  LogWind,
  Tree,
  ZoneCont,
  LOGSUBS2,
  LOGSUBS1,
  LOGSend,
  uCT1BOH,
  PostUnit,
  uCabrilloFormat,
  uCabrilloExchange,
  uADIFExchange,
  uInputQuery,
  uNewContest,
  uTextFitAudit,
  uRadioPolling,
  uEditQSO,
  uLogSearch,
  uBeacons,
  uNetFraming,
  uNet,
  uNetClient,
  uTotal,
  uMaster,
  uRemMults,
  uDupesheet,
  uSendSpot,
  uSendKeyboard,
  uRadio12,
  uFunctionKeys,
  uinet,
  uDXClusterClient,
  uDXSpotParse,
  uTelnet,
  uBandmap,
  uBandMapView,
  uBandMapForm,
  uStationsForm,
  uDomainState,
  uWSJTXState,
  uRadioState,
  uKeyerState,
  uStateBridge,
  uFlowGrid,
  uDupeSheetForm,
  uMasterForm,
  uPostScoresForm,
  uHamScoreForm,
  uIntercomForm,
  uMP3RecorderForm,
  uRadioPanelForm,
  uPanadapterRestore,
  uNetworkForm,
  uRemMultsForm,
  uAppInputHooks,
  uFileView,
  uAutoCQ,
  uCAT,
  // The radio-configuration layer.  Nothing calls these yet -- the FMX
  // preferences dialog is the caller -- but they are listed so the compiler
  // checks them against the live CFGCA/CAT surface on every build.
  uRotatorBase,
  uRotatorControl,
  uRotatorRegistry,
  uRotatorYaesu,
  uRotatorOrion,
  uRotatorDCU1,
  uRotatorAlfaSpid,
  uRotatorPSTRotator,
  uSettingsRegistry,
  uSettingsLegacy,
  uSettingsDeclarations,
  uRadioConfigStore,
  uKeyerConfigStore,
  uKeyerConfigApply,
  uUDPBroadcastConfig,
  uUDPBroadcaster,
  uWindowLayoutStore,
  uTR4WConfigFile,
  uRadioConfigLegacyMap,
  uRadioConfigApply,
  // The FMX twins were DELETED 2026-08-17, at the start of the Win32-to-LCL
  // migration.  They were never in an FPC build -- FMX has no FPC compiler --
  // so under the decided toolchain they were code nothing compiled, and had
  // already drifted from the LCL forms that replaced them.  Deleting them here
  // rather than per-form means no conversion has to ask whether it owes a twin.
  // The LCL set is in the {$IFDEF FPC} block below.
  uAccelerators,
  uMainWindowProc,
  uDialogs,
  Version,
  VC,
  uCommctrl,
  uGradient,
  uMessages,
  uWinManager,
  uCbrSum,
  uQTCR,
  uQTCS,
  LPT,
  uGetServerLog,
  TF,
  uFreqTimeFormat,
  uLogEdit,
  uIntercom,
  uLogCompare,
  uMixW,
  uCallsigns,
  uSpots,
  uSpotAge,
  uClusterTokens,
  uGetScores,
  uStations,
  uAltD,
  uWinKey,
  uLPTPortEnumerator,
  uPrefsSearch,
  uConfigValues,
  uCrashLog,
  uCrashLogLCL,
  uCFG,
  uCRC32,
  uMP3Recorder,
  uAltP,
  uEditMessage,
  uCheckLatestVersion,
  uErmak,
  uProcessCommand,
  uMults,
  HtmlHelp,
  uSSL,
  uIO,
  uBMCF,
  uCTYDAT,
  uCallSignRoutines,
  uSynTime,
  uMMTTY,
  uProfiler,
  uMessagesList,
  uRussiaOblasts,
  uMenu,
  utils_net,
  utils_hw,
  uAnsiStr,
  uFileText,
  uPlatformProcess,
  uRegex,
  uWin32Compat,
  uHostedFormWindows,
  // The LCL side of hosting a toolkit in TR4W's own loop.  FPC-only:
  // Delphi cannot compile the LCL, just as FPC cannot compile FMX.
  uLCLCoexist,
  uLCLTranslate,
  uEmbeddedTranslations,
  uLCLFormHelpers,
  uSettingsBinding,
  uUDPDestinationEditForm,
  uAltDForm,
  uLogCompareForm,
  uServerLogForm,
  uCT1BOHForm,
  uBeaconsForm,
  uEditQSOForm,
  uPanelUpdate,
  uMainThreadWork,
  uFlasher,
  uLPTForm,
  uAboutForm,
  uFunctionKeysForm,
  uBandPlanForm,
  uLegacyIniPrompt,
  uIniRetireForm,
  uWinManagerForm,
  uMessagesListForm,
  uEditMessageForm,
  uSendKeyboardForm,
  uAutoCQForm,
  uSendSpotForm,
  uInputQueryForm,
  uProgramMessageForm,
  uKeyerEditForm,
  uRadioEditForm,
  uMainForm,
  uPrefsForm,
  uJSON,
  uHTTPDownload,
  utils_text,
  utils_math,
  utils_file,
  uWinTimer,
  uWSJTX,
  uHamScore,
  uExchangeBuilder,
  uGridLookup,
  Log4D,
  uFactoryRadioBase,
  uSerialPort,
  uRadioFactory,
  uRadioElecraftK4,
  uRadioElecraftSerial,
  uRadioYaesuASCII,
  uRadioYaesuFTDX10,
  uRadioYaesuBinary,
  uRadioYaesuFT1000MP,
  uRadioYaesuFT817Group,
  uRadioYaesuFT817,
  uRadioYaesuFT818,
  uRadioYaesuFT857,
  uRadioYaesuFT897,
  uRadioYaesuFT847,
  uRadioYaesuFT990Group,
  uRadioYaesuFT990,
  uRadioYaesuFT1000,
  uRadioYaesuFT840Group,
  uRadioYaesuFT840,
  uRadioYaesuFT890,
  uRadioYaesuFT900,
  uRadioYaesuFT920,
  uRadioYaesuFT100,
  uRadioYaesuFT747,
  uRadioYaesuFT767,
  uRadioYaesuFT991,
  uRadioYaesuFTDX101,
  uRadioYaesuFT710,
  uRadioYaesuFTX1F,
  uRadioYaesuFT891,
  uRadioYaesuASCIILegacy,
  uRadioYaesuFT450,
  uRadioYaesuFT950,
  uRadioYaesuFT1200,
  uRadioYaesuFT2000,
  uRadioYaesuFTDX3000,
  uRadioYaesuFTDX5000,
  uRadioYaesuFTDX9000,
  uRadioFlexCAT,
  uRadioFlex6000,
  uRadioElecraftK3,
  uRadioElecraftK2,
  uRadioElecraftKX3,
  uRadioKenwoodLAN,
  uWebSocketFraming,
  uWebSocketClient,
  uWebSocketServer,
  uTCIProtocol,
  uTCIServer,
  uRadioTCI,
  uRadioKenwoodTS890,
  uRadioKenwoodTS990,
  uIcomNetworkTypes,
  uIcomNetworkTransport,
  uIcomNetworkDiscovery,
  uRadioIcomBase,
  uRadioIcom9700,
  uRadioIcom7610,
  uRadioIcom7300,
  uRadioIcom705,
  uRadioIcom7300MK2,
  uRadioIcom7600,
  uRadioIcom7760,
  uRadioIcom7850,
  uRadioIcom7851,
  uRadioIcom905,
  GetWinVersionInfo,
  uSuperCheckPartialFileUpload,
  uHamLibDirect,
  uRadioHamLibDirect,
  uExternalLoggerBase,
  uExternalLogger,
  uExternalLoggerFactory,
  // uExternalLoggerManager uses Generics.Collections (Delphi 2009+) - not Delphi 7 IDE compatible
  //uExternalLoggerManager in 'src\uExternalLoggerManager.pas',
  uDXLabPathfinder,
  uYCCCSO2R,
  uCWKeyerBase,
  uCWKeyerCAT,
  uCWKeyerWinKey,
  uCWKeyerYCCC,
  uCWKeyerCPU,
  uRadioFlexAPI,
  uRadioBand,
  uBandLookup,
  ComPortEnumerator,
  uRadioIcom7100,
  uRadioIcom718,
  uRadioIcomLegacy,
  uRadioIcomReadLimited,
  uRadioIcomModern,
  uRadioHamLibOnly,
  uCWFraming,
  uRadioKYBase,
  uRadioElecraftBase,
  uRadioKenwoodBase,
  uRadioIcom78,
  uRadioIcom707,
  uRadioIcom725,
  uRadioIcom726,
  uRadioIcom728,
  uRadioIcom729,
  uRadioIcom735,
  uRadioIcom736,
  uRadioIcom737,
  uRadioIcom738,
  uRadioIcom746,
  uRadioIcom746PRO,
  uRadioIcom756,
  uRadioIcom756PRO,
  uRadioIcom756PROII,
  uRadioIcom756PROIII,
  uRadioIcom761,
  uRadioIcom765,
  uRadioIcom775,
  uRadioIcom781,
  uRadioIcom910,
  uRadioIcom970D,
  uRadioIcom7200,
  uRadioIcom7410,
  uRadioIcom9100,
  uRadioTenTecOmni6,
  uRadioTenTecOrion,
  uRadioIcom7700,
  uRadioIcom7800,
  uRadioRegistry,
  uRadioKenwoodSerial,
  uRadioKenwoodTS570,
  uRadioKenwoodTS140,
  uRadioKenwoodTS440,
  uRadioKenwoodTS450,
  uRadioKenwoodTS480,
  uRadioKenwoodTS590,
  uRadioKenwoodTS690,
  uRadioKenwoodTS850,
  uRadioKenwoodTS870,
  uRadioKenwoodTS940,
  uRadioKenwoodTS950,
  uRadioKenwoodTS2000,
  uIcomCIV,
  uIcomScope,
  // uRadioManager uses Generics.Collections (Delphi 2009+) - not Delphi 7 IDE compatible
  //uRadioManager in 'src\radioFactory\uRadioManager.pas',
  // DELETED 2026-08-28: uRemMults_DOM/DX/Zone, uDXSSpotsFilter,
  // uSpotsFilter and uMultsFrequencies. Commented out of this uses clause
  // since the initial commit, so never compiled, and with no live reference
  // anywhere -- the notes here recorded why: one set depends on a
  // Country9.pas that was never in the repo, one is unfinished, one is
  // orphaned. Six Win32 dialog procedures, 794 lines.
  uMakeHelpFile,
  uLogConfig,
  uPOTAParks,
  uPendingCounties,
  uCTYUpdate,
  uTRMasterUpdate,
  uAppStrings,
  uCabrilloHeader,
  // D12: transitively-compiled units added so project-wide file searches see them
  // (they were pulled in via other units' uses clauses but never listed here).
  uADIF,
  uCabrillo,
  uCallCompress,
  uFlexRadioUtils,
  uGridDistance,
  uK4Discovery,
  uFlexDiscovery,
  uStrSearch,
  NetworkMessageUtils,
  uTR4WStrings;

// ---------------------------------------------------------------------------
// EnsureCountryFile
//
// Loads CTY.DAT and, when that fails, offers to download a current one.
//
// WHY (NY4I, 2026-08-16). TR4W cannot run without a country file, so the old
// code reported the missing file and halted -- a dead end on a first run, and
// the operator's only recourse was to go find the file by hand. We already
// know how to fetch one: that is what Alt-O does. Offer it here instead.
// (The equivalent in TR4QT extracts a bundled copy from Qt resources; TR4W
// downloads, which has the side benefit of arriving current rather than as
// old as the installer.)
//
// SYNCHRONOUS, DELIBERATELY. This runs before CreateMainWindow, so there is
// no window to post WM_CTY_DOWNLOAD_DONE to and no message loop to receive
// it -- DownloadCTYAsync is unusable this early, and so is QuickDisplay,
// which writes into a main-window element. The main thread blocks for the
// duration of the fetch. That is acceptable ONLY because there is no UI yet
// to freeze; do not copy this shape anywhere the window already exists.
//
// TARGET PATH. TR4W_CTY_FILENAME is whatever SetUpFileNames resolved -- the
// contest .cfg directory, else the working directory (FCONTEST.PAS:122-128).
// We write to exactly that name, so the reload below reads the file we just
// fetched, and so does every later Alt-O. Note the working directory is not
// guaranteed writable (an install under Program Files launched from a
// shortcut): that surfaces as a failed download and is reported WITH the
// path, because "download failed" alone does not tell the operator that the
// folder, not the network, is the problem.
//
// Returns True if a country file is loaded and startup may continue.
// ---------------------------------------------------------------------------
function EnsureCountryFile: boolean;
var
  ctyPath                               : string;
  prompt                                : string;
  failReason                            : string;
begin
  Result := ctyLoadInCountryFile(TR4W_CTY_FILENAME, False, True);

  if Result then
     begin
     Exit;
     end;

  ctyPath := string(PAnsiChar(@TR4W_CTY_FILENAME));

  // Headless /EXPORT has no operator to answer a prompt, and a batch export
  // should not make an unannounced network request. Report and fail, exactly
  // as this code did before.
  if tSilentExport then
     begin
     UnableToFindFileMessage(TR4W_CTY_FILENAME);
     logger.Fatal('Unable to load ' + ctyPath);
     Exit;
     end;

  // ctyLoadInCountryFile returns False for BOTH "no such file" and "the file
  // is there but could not be read", so ask the filesystem which it is. A
  // fresh download is the right offer either way, but telling an operator a
  // file is missing when it is actually corrupt sends them after the wrong
  // problem.
  // SysUtils.FileExists explicitly: the unqualified name resolves to a legacy
  // PChar-taking FileExists pulled in from the TRDOS units, which will not
  // take a string.
  if SysUtils.FileExists(ctyPath) then
     begin
     prompt := 'The country file could not be read:' + #13#10#13#10 +
               ctyPath + #13#10#13#10 +
               'TR4W cannot run without it.' + #13#10 +
               'Download a current CTY.DAT now?';
     end
  else
     begin
     prompt := 'The country file was not found:' + #13#10#13#10 +
               ctyPath + #13#10#13#10 +
               'TR4W cannot run without it.' + #13#10 +
               'Download it now?';
     end;

  if MessageBoxW(0, PChar(prompt), 'TR4W',
     MB_YESNO or MB_ICONQUESTION or MB_SYSTEMMODAL or MB_TOPMOST) <> IDYES then
     begin
     logger.Fatal('Unable to load ' + ctyPath +
                  ' -- operator declined the download');
     Exit;
     end;

  logger.Info('CTY.DAT not loaded; downloading to ' + ctyPath);

  if not DownloadCTYFile(ctyPath, failReason) then
     begin
     { SAY WHY. This used to advise checking the network and the folder
       permissions -- and in the one case anybody hit, both were fine and the
       real reason (the OpenSSL pair missing, because tr4w.exe had been copied
       out on its own) was sitting in the log the operator had not been given
       a reason to open. Wrong advice is worse than none. }
     showwarning(SysUtils.Format(SCtyDownloadFailed, [ctyPath, failReason]));
     logger.Fatal('CTY.DAT download failed; cannot continue');
     Exit;
     end;

  // VERIFY, DO NOT ASSUME. A download can report success and still leave a
  // file the parser rejects -- a captive-portal HTML page saved as cty.dat is
  // the obvious way. Say so here, where the cause is still obvious, rather
  // than continuing into a program with no country data.
  Result := ctyLoadInCountryFile(TR4W_CTY_FILENAME, False, True);

  if Result then
     begin
     logger.Info('CTY.DAT downloaded and loaded from ' + ctyPath);
     end
  else
     begin
     showwarning('CTY.DAT was downloaded but could not be read:' +
                 #13#10#13#10 + ctyPath);
     logger.Fatal('Downloaded CTY.DAT failed to load');
     end;
end;

{ The first command-line argument that is not a switch, or '' if there is none.

  TR4W's one positional argument is the contest file, and it used to be read as
  ParamStr(1) because it was the only thing anyone passed. --lang broke that:
  `tr4w.exe --lang es` made "--lang" the contest name, so the New Contest dialog
  never opened and TR4W tried to load a contest called --lang. An operator who
  wanted a Spanish UI had to name a contest to get one (NY4I, 2026-08-27).

  A SWITCH THAT TAKES A VALUE SWALLOWS IT. Otherwise `--lang es` leaves "es"
  standing in the next position, looking exactly like a contest file -- the same
  bug moved along by one. The --lang=es form carries its own value.

  Anything starting with - or / is a switch. TR4W's own /EXPORT uses the slash
  form and takes no value. }
function FirstNonSwitchArgument: string;
var
   i:   integer;
   arg: string;
begin
   Result := '';
   i := 1;
   while i <= ParamCount do
      begin
      arg := ParamStr(i);

      if (arg <> '') and ((arg[1] = '-') or (arg[1] = '/')) then
         begin
         if SameText(arg, '--lang') or SameText(arg, '-l') then
            begin
            Inc(i);        // the switch consumes the value after it
            end;
         Inc(i);
         Continue;
         end;

      Result := arg;
      Exit;
      end;
end;


{ COMMAND-LINE HELP, and the reason it is a message box rather than WriteLn.

  tr4w.exe is linked as a GUI subsystem binary, so it has no console to write
  to -- a WriteLn here goes nowhere and looks like the program did nothing.

  NOT TRANSLATED, deliberately (NY4I): it names switches, which are English
  tokens, and it has to work before a catalogue is chosen -- including in the
  case where the reason for showing it is that no language was given.

  Returns True when it handled the command line and the program should stop. }
function ShowCommandLineUsage: boolean;
var
   i:    integer;
   arg:  string;
   want: boolean;
begin
   Result := False;
   want   := False;

   { No arguments at all is the ordinary case and says nothing. }
   for i := 1 to ParamCount do
      begin
      arg := ParamStr(i);
      if SameText(arg, '-h') or SameText(arg, '-?') or SameText(arg, '--help') then
         begin
         want := True;
         Break;
         end;
      { --lang or -l with nothing after it: the operator meant to pick a
        language and did not say which, so list the ones that are here. }
      if (SameText(arg, '--lang') or SameText(arg, '-l')) and (i = ParamCount) then
         begin
         want := True;
         Break;
         end;
      end;

   if not want then
      begin
      Exit;
      end;

   MessageBoxW(0, PWideChar(
      'TR4W ' + TR4W_CURRENTVERSION_NUMBER + sLineBreak + sLineBreak +
      'Usage:  tr4w.exe [<contest>.cfg] [options]' + sLineBreak + sLineBreak +
      '  <contest>.cfg      open this contest configuration' + sLineBreak +
      '  --lang <code>      run in this language' + sLineBreak +
      '  --lang=<code>      the same' + sLineBreak +
      '  /EXPORT            headless ADIF and Cabrillo export, then exit' + sLineBreak +
      '  -h, -?, --help     this message' + sLineBreak + sLineBreak +
      'Languages in this build:' + sLineBreak +
      '  ' + AvailableLanguages + sLineBreak + sLineBreak +
      'A catalogue in languages\<code>\tr4w.po beside the exe overrides' + sLineBreak +
      'the embedded one.'),
      'TR4W', MB_OK or MB_ICONINFORMATION);
   Result := True;
end;

procedure RunTR4W;
// NoTransMess and TransMess were declared here and never used -- FPC says so
// ("Label not defined"), and it has presumably said so for years into a .dpr
// nobody reads warnings from.  Dropped.  CommandLine is real.
label
  CommandLine;
var
  TempHDC                               : HDC;
  TempColor                             : tr4wColors;
  TempTLogBrush                         : TLogBrush {= (lbStyle: BS_SOLID; lbHatch: 0)};
  c                                     : Cardinal;
  TempString                            : ShortString;
  // The radio library's complaint, if it has one -- see the call site.
  tRadioLibraryError                    : string;
   //  P                                   : Pchar; //n4af
   //   P1                                   : boolean; //n4af
   // S1                                   : String; //n4af
{$IF not tDebugMode}
  s                                     : string;
  loadedLang                            : string;
{$IFEND}
 // logBuffer                             : string;
  tempStickyKey                         : STICKYKEYS;
 // tc                                    : tcolor;
  sDebugLevel                           : string;
  i                                     : tLogLevels;
  //rgb                                   : cardinal;
                                                                       // This way we can log before we read the DEBUG LOG LEVEL the legacy method in uCFG. // ny4i
begin
  { Before anything else: no window, no config, no catalogue read. }
  if ShowCommandLineUsage then
     begin
     Halt(0);
     end;

   // Enable thread-safe memory management. TR4W creates threads via Win32
   // CreateThread (not TThread), which does NOT set this flag automatically.
   // Without it, concurrent GetMem calls from different threads can corrupt
   // the heap, causing random AVs at startup when radio polling threads and
   // the main thread initialize simultaneously.
   IsMultiThread := True;

   { THE RADIO NAME TABLE, BUILT FROM THE FACTORY.

     Every radio unit has self-registered by now -- initialization sections all
     run before this procedure does -- so the registry is complete and the
     tokens tr4w.ini is parsed against can be derived from it. This MUST happen
     before the config is read: uCFG matches 'RADIO ONE MODEL = ...' against
     this list and stores the index as the enum.

     It replaces a hand-maintained array in LOGRADIO that had drifted one
     position out of step with the enum -- see the note where it used to be. }
   PopulateRadioTypeTokens;

   // Application.Initialize creates the widgetset.  Application.Run at the
   // bottom of this file drives it -- Phase 3c, 2026-08-23.  The hand-rolled
   // GetMessage loop that owned the program until then is gone; what lived
   // inside it is in uAppInputHooks.
   InitLCLApplication;

   // HEADLESS FIELD ROUND-TRIP:  tr4w.exe /FIELDCHECK
   //
   // Puts a probe value through every input control of the Edit QSO form and
   // reads it back, then exits with the number of fields that did not survive.
   // Driven by test\ui\Invoke-FieldCheck.ps1.
   //
   // DELIBERATELY HERE, before the mutex and before any config or log is
   // touched: it needs the widgetset and nothing else, so it does not need a
   // contest, cannot disturb settings, and runs happily while TR4W is already
   // open. That also makes it fast enough to gate a build with.
   //
   // It exists because Lint-EditQSOTemplate proves the WIRING and cannot prove
   // that a VALUE survives -- which is what the MaxLength truncation
   // (4f0339d4) was: right wiring, right-looking .lfm, callsign silently cut.
   if SameText(ParamStr(1), '/FIELDCHECK') then
      begin
      Halt(RunEditQSOFieldCheck);
      end;

   // Check for another running instance BEFORE opening any shared files
   // (log file, etc.) to avoid an EFOpenError crash on the second instance.
   // BREADCRUMBS, because nothing here can use the logger -- it does not
   // exist yet, and that is the whole point of doing this first.  A TR4W
   // process with no window and no log lines was found running on 2026-08-23
   // and there was no way to tell where it had stopped.
   // BATCH MODE IS DECIDED HERE, BEFORE THE SINGLE-INSTANCE CHECK, and that
   // ordering is the whole point.  It used to be decided fifty lines below,
   // after the mutex -- so a headless export launched while TR4W was open took
   // the duplicate-instance path and opened a MODAL WARNING with nobody there
   // to dismiss it.  The process then blocked forever: no window the operator
   // would look for, nothing in tr4w.log because the appender is not attached
   // yet, and the executable held locked against a rebuild.
   //
   // That is exactly the invisible TR4W found with pslist on 2026-08-23, and
   // the corpus is what produces it: export-d12-corpus.sh runs
   // `tr4w.exe "<contest>.CFG" /EXPORT` over THIRTEEN logs, so a corpus run
   // started while TR4W is open leaves thirteen of them.
   //
   // The reasoning was already written down one step below -- "a warning raised
   // while READING THE CONFIG could still open a modal and block a headless run
   // with no one there to dismiss it".  Same argument; it just had to apply
   // sooner.
   tSilentExport := SameText(ParamStr(2), '/EXPORT');

   EarlyTrace('startup: checking the single-instance mutex');
   tMutex := CreateMutex(nil, False, tr4w_ClassName);
   if tMutex = 0 then
      begin
      EarlyTrace('startup: CreateMutex FAILED -- exiting');
      Exit;
      end;
   if GetLastError = ERROR_ALREADY_EXISTS then
      begin
      // A HEADLESS RUN NEVER OPENS A DIALOG.  It fails fast and loudly with a
      // distinct exit code instead, so the corpus reports a failure rather than
      // hanging invisibly and locking the executable.
      if tSilentExport then
         begin
         EarlyTrace('startup: another instance holds the mutex -- refusing the '
                    + 'headless export rather than opening a dialog nobody can see');
         Halt(EXITCODE_ALREADY_RUNNING);
         end;

      EarlyTrace('startup: another instance holds the mutex -- warning the operator');
      // THE LCL'S MESSAGE BOX, NOT MessageBoxW.  Application.Initialize has
      // already run, so the LCL owns the pump a modal needs; going around it
      // with a raw MessageBoxW and MB_SYSTEMMODAL was gratuitous Win32.
      ReportAlreadyRunning(TC_RUNWARN);
      EarlyTrace('startup: warning dismissed -- exiting as a duplicate');
      Exit;
      end;
   EarlyTrace('startup: mutex acquired -- this is the only instance');

   TR4W_PATH_NAME[Windows.GetCurrentDirectoryA(SizeOf(TR4W_PATH_NAME), @TR4W_PATH_NAME)] := '\';
   Format(TR4W_INI_FILENAME, '%ssettings\tr4w.ini', TR4W_PATH_NAME);
   // The `try` that opened here had its `finally HamScoreShutdown` at the very
   // bottom, after the message loop.  Both are gone: TR4W exits through
   // ExitProcess in tr4w_ShutDown, so that finally could never have run in
   // normal use -- and HamScoreShutdown is on the shutdown path now, where it
   // does run.
   appender := TLogRollingFileAppender.Create('name','tr4w.log');
   appender.Layout := CreateTR4WLogLayout;
   TLogBasicConfigurator.Configure(appender);
   logger := TLogLogger.GetLogger('TR4WDebugLog');

   // IMMEDIATELY AFTER THE LOGGER EXISTS, and before anything that could
   // fault. Until now an unhandled exception left tr4w.log ending in the
   // ordinary unit finalizations -- indistinguishable from a clean exit --
   // so a crash report could only say that the program had closed.
   // The LCL entry point, which installs the RTL hook too.  This
   // program has a widget set; tr4wserver does not and calls
   // InstallCrashLog directly.  See the uCrashLogLCL header for
   // why that is a second unit and not a define.
   InstallCrashLogLCL;

   { THE SETTINGS REGISTRY, AND THIS IS THE 'once at startup' ITS OWN COMMENT
     PROMISES.  Nothing called it.  DeclareAllSettings was reached only from
     uPrefsForm, so the 226 registrations existed only if the operator had
     opened Preferences in that session.

     That is not cosmetic: tr4w.json groups its commands into sections by
     asking the registry which section a command belongs to (the first
     segment of its dotted key -- see BuildSectionMap in uRadioConfigStore).
     With the registry empty every command is unclassifiable, so all 243 land
     in 'other' and the file has no sections at all.  NY4I hit exactly that,
     including on a tr4w.json created from scratch (2026-08-31).

     Idempotent by design -- it guards on GDeclared -- so the Preferences
     call stays where it is.  Its own header anticipated a second entry
     point; this is the first. }

   DeclareAllSettings;

   // BATCH MODE, decided here rather than at the /EXPORT block far below,
   // because two things before that block need to know.
   //
   // It suppresses modal preview and upload prompts (TF.showwarning,
   // MainUnit), and it was previously set only at the export itself -- which
   // meant a warning raised while READING THE CONFIG could still open a modal
   // and block a headless run with no one there to dismiss it.
   //
   // It also gates the radio-library apply below: an automated export must
   // never write to the operator's live settings (NY4I, 2026-08-06).
   // Reported at the startup banner below, NOT here: the file appender is not
   // attached yet at this point, so a line logged now goes nowhere.
   //
   // ASSIGNED ABOVE, before the single-instance check -- see the note there.
   // FROM settings\tr4w.json, not tr4w.ini.  DEBUG LOG LEVEL is a csJSON row --
   // the store is its system of record -- so reading the ini here handed the
   // earliest log lines a stale value, or the compiled default on a station with
   // no ini at all.
   //
   // Default TRACE (was ERROR) when there is no stored level.  Radio-driver
   // bring-up is diagnosed almost entirely from the TX/RX frame trace, and asking
   // a volunteer tester to hand-edit a config before their first run is a poor
   // trade for log volume.  Only affects a MISSING value: anyone who has set a
   // level keeps it.
   sDebugLevel := StartupLogLevel(TR4WConfigFileName);
   if sDebugLevel = '' then
      begin
      sDebugLevel := 'TRACE';
      end;
   for i := Low(tLogLevelsSA) to High(tLogLevelsSA) do
      begin
      if sDebugLevel = tLogLevelsSA[i] then
         begin
         logLevels := tLogLevels(i);
         break;
         end;
      end;
   UpdateDebugLogLevel;

   logger.info('******************** PROGRAM STARTUP ************************');
   if tSilentExport then
      begin
      logger.Info('[Startup] batch /EXPORT: settings are READ-ONLY for this run ' +
                  '-- the radio library is not applied and no prompt will open');
      end;
   logger.Trace('trace output');
   logger.Info('DecimalSeparator = ' + FormatSettings.DecimalSeparator);



  TR4W_PATH_NAME[Windows.GetCurrentDirectoryA(SizeOf(TR4W_PATH_NAME), @TR4W_PATH_NAME)] := '\';

  { LOAD THE UI LANGUAGE, IF THERE IS ONE.

    TR4W has translated by COMPILING A DIFFERENT BINARY per language -- a TC_
    constant per string, selected by a LANG_xxx define. The replacement is one
    binary whose resourcestrings are REPLACED AT RUN TIME from a .po (NY4I,
    2026-08-13).

    LCLTranslator, NOT DefaultTranslator. The latter is a 24-line unit whose
    entire body is SetDefaultLang('', '', '', false) in its initialization --
    it takes the choice away and hides where it happens. This calls the real
    entry point, in the startup sequence, where it can be read and logged.

    The file name is PINNED to tr4w.po. Defaulted, it is the EXECUTABLE's name,
    and this program ships as tr4w.exe but builds as tr4w_fpc.exe -- the
    developer binary would silently find nothing and look like a translation
    bug. Searched under languages/<lang>/ and locale/<lang>/ beside the exe.

    ForceUpdate is False: no form exists yet, and the LCL's own note says to
    pass False when calling before the interface is up.

    LANGUAGE SELECTION IS NOT FINISHED. SetDefaultLang with an empty Lang
    honours a --lang switch and then the OS locale. TR4W should choose from its
    own setting instead -- an operator running a Spanish Windows does not
    necessarily want a Spanish contest log -- so this is the seam that setting
    plugs into, not the final answer.

    IT IS LOGGED because "it ran" and "it took effect" are different claims and
    only one is visible. An absent .po is not an error, English being the
    compiled-in default, so without this line a missing or misnamed catalogue
    is indistinguishable from a working English build. }
  { FROM THE BINARY, NOT FROM A FILE BESIDE IT.

    This called SetDefaultLang, which only ever searches the disk. It worked and
    it was the wrong shape: NY4I chose an EMBEDDED catalogue (2026-08-26),
    because the language data is already carried inside the exe today via
    an $R on res\tr4w_<lang>.res -- written without braces, since a brace
    comment ends at the first closing brace -- and a loose file is one more
    thing to lose, forget to install, or let go stale against the binary
    beside it.

    LoadEmbeddedTranslation still prefers a file if one is present -- same
    layout SetDefaultLang searched -- so a corrected translation can be dropped
    onto an installation without a rebuild. The embedded copy is the floor.

    It reports what it did in every case, including the absent one: English is
    the compiled-in default, so a missing or misnamed catalogue is otherwise
    indistinguishable from a working English build. }
  loadedLang := LoadEmbeddedTranslation('');
  if loadedLang = '' then
     begin
     logger.Info('UI language: none loaded; using the compiled-in English');
     end;

  { The string tables that cannot be initialised where they are declared. This
    has to follow the translation load and precede the main window: the window
    is built from captions these tables hold. }
  InitializeStringTables;
  uNet.InitializeNetworkColumnTitles;
  uMenu.InitializeMenuText;

 Format(TR4W_INI_FILENAME, '%ssettings\tr4w.ini', TR4W_PATH_NAME);
  LuconSZLoadded := AddFontResourceW(TR4W_LC_FILENAME) <> 0;
  MainFixedFont := tCreateFont(15, FW_BOLD * Ord(BoldFont), @MainFontName[1]);
  MSSansSerifFont := tCreateFont(15, FW_DONTCARE, 'MS Sans Serif');
  CreateDirectoryIfNotExist;

{$IF tDebugMode}
  //uHistory.MakeRevisionHistory;
  TR4W_CFG_FILENAME := 'c:\TR4W\debug.cfg';
{$ELSE}

  { THE CONTEST FILE IS THE FIRST ARGUMENT THAT IS NOT A SWITCH -- see
    FirstNonSwitchArgument. Reading ParamStr(1) directly was right while a
    contest file was the only thing anyone passed, and stopped being right the
    moment --lang existed. }
  s := FirstNonSwitchArgument;
  if s <> '' then
  begin
    // D12: ParamStr returns a wide UnicodeString.  The old
    // CopyMemory(@buf, @s[1], length(s)) copied WIDE bytes into the ANSI
    // FileNameType buffer using a CHARACTER count -> "C",#0,":",#0,... ->
    // the cfg path was truncated to "C", config never loaded, and startup
    // died with "No callsign specified".  Copy the ANSI form instead.
    Windows.lstrcpyA(TR4W_CFG_FILENAME, PAnsiChar(WinAnsi(s)));
    goto CommandLine;
  end;

  begin
    ShowNewContest;
    if TR4W_CFG_FILENAME[0] = '_' then Exit;
  end;
{$IFEND}

  CommandLine:

  { FULLY QUALIFY THE CONTEST .cfg PATH -- EVERY WRITER DEPENDS ON IT.

    TR4W_CFG_FILENAME is ParamStr(1) VERBATIM, so `tr4w.exe uitest.cfg` leaves
    it RELATIVE. Every READER is fine: the config parser opens it with the
    ordinary file API, which resolves a relative name against the CURRENT
    DIRECTORY. Every WRITER is not. WritePrivateProfileString does NOT use the
    current directory -- given a name that is not fully qualified it looks in
    the WINDOWS directory, and creating a file there is denied.

    Measured 2026-08-26, CWD tr4w/target:
       relative name -> returns False, GetLastError=5 (ACCESS_DENIED), no file
       absolute path -> returns True, file written

    So the function-key memories an operator edited in Alt-P went nowhere and
    were gone on restart (NY4I: "they are supposed to still be written to the
    contest CFG file ... hence they are not restored"), and COLUMN WIDTH in
    MainUnit failed exactly the same way. ONE CAUSE, TWO SYMPTOMS -- which is
    why it is fixed HERE, where the path enters the program, and not at either
    call site. Any future .cfg writer inherits the fix.

    It is silent at both ends: the API reports failure through a BOOL that
    both call sites discarded, and a read-back still succeeds because the
    reader resolves the relative name differently. }
  if TR4W_CFG_FILENAME[0] <> #0 then
     begin
     s := ExpandFileName(string(PAnsiChar(@TR4W_CFG_FILENAME[0])));

     // Room for the terminator: FileNameType is MAX_PATH bytes. A path too
     // long to hold is left as it was rather than truncated into a different
     // file -- and said so, because silence is the defect being fixed.
     if Length(s) < SizeOf(FileNameType) then
        begin
        Windows.lstrcpyA(TR4W_CFG_FILENAME, PAnsiChar(WinAnsi(s)));
        end
     else
        begin
        logger.Warn('Contest .cfg path is too long to fully qualify (%d bytes); ' +
                    'settings written back to it will not be saved: %s',
                    [Length(s), s]);
        end;

     // WHICH .cfg AM I ACTUALLY EDITING -- the question this defect turned
     // on, and nothing in the log answered it.
     logger.Info('Contest configuration file: ' + StrPas(@TR4W_CFG_FILENAME[0]));
     end;



  InitializeStrings;

  for TempColor := Low(tr4wColors) to High(tr4wColors) do
  begin
    TempTLogBrush.lbColor := tr4wColorsArray[TempColor];
    tr4wBrushArray[TempColor] := CreateBrushIndirect(TempTLogBrush);
  end;

  tr4w_osverinfo.dwOSVersionInfoSize := SizeOf(OSVERSIONINFO);
  Windows.GetVersionEx(tr4w_osverinfo);

  WindowsOSversion := tr4w_osverinfo.dwPlatformId;

  StickyKeysAtStartup.cbSize := sizeof(STICKYKEYS); // This prevents multiple shift keys from activating sticky keys. It saves settng and restore upon exit. ny4i
  Windows.SystemParametersInfo(SPI_GETSTICKYKEYS, sizeof(STICKYKEYS), @StickyKeysAtStartup, 0);
  tempStickyKey.cbSize := StickyKeysAtStartup.cbSize;
  tempStickyKey.dwFlags := StickyKeysAtStartup.dwFlags and not (SKF_STICKYKEYSON or SKF_HOTKEYACTIVE);
  SystemParametersInfo( SPI_SETSTICKYKEYS, SizeOf(tempStickyKey), @tempStickyKey, 0 );
  Windows.SystemParametersInfo(SPI_GETWORKAREA, 0, @tWorkingAreaRect, 0);
  TempHDC := Windows.GetWindowDC(tr4whandle);

  tEightBitsPerPixel := Windows.GetDeviceCaps(TempHDC, BITSPIXEL) <= 8;
  ReleaseDC(tr4whandle, TempHDC);

  SetUpFileNames;

  RenameCommands;


  LoadTR4WPOSFILE;


  // Offers to download CTY.DAT when it is missing or unreadable, rather than
  // halting on a file the operator has no easy way to obtain. See the
  // function for why the fetch is synchronous here.
  if not EnsureCountryFile then
  begin
    halt;
  end;

  SetConfigurationDefaultValues;

  {Temporary - Feb 2010}


  ReadInConfigFile(cfgINI);

  ReadInConfigFile(cfgCFG);          //n4af 4.31.5
  ReadInConfigFile(cfgCommMes);      //common messages gets precedence - n4af

  // The radio library (settings\tr4w.json) is the FORMAT OF RECORD for radio
  // settings, so it gets the last word -- after every config file above, and
  // before anything reads a [Radio] key.  Without this the ini wins simply by
  // being read here, and a hand-edit of RADIO ONE CONTROL PORT silently
  // overrides the profile the operator chose in Preferences (NY4I found
  // exactly that on 2026-08-06).
  //
  // Radios are NOT touched here: they do not exist yet, and the ordinary
  // CheckAndInitializePorts path below connects them with these values.
  //
  // A failure is reported and then ignored: an unusable library must not stop
  // TR4W starting, and the legacy keys are still a working configuration.
  // Skipped entirely under batch /EXPORT: automated testing must not touch
  // the operator's live settings, and the export halts before the radios are
  // ever used, so the [Radio] keys are irrelevant to its output anyway.
  // COMPUTER ID COMES FROM settings\tr4w.json, INCLUDING UNDER /EXPORT.
  //
  // It is Preferences > Network > "This station", written there through
  // ApplyAndStoreCommand, so the JSON is already where an operator sets it
  // (NY4I, 2026-08-16).  PostUnit compares each QSO's stored cecomputerid
  // against this global to decide the Cabrillo TRANSMITTER DIGIT
  // (PostUnit.PAS:3038), so a headless export that never applied it wrote the
  // wrong digit on every line -- 2632 of them in the Winter Field Day set.
  //
  // ONE named command, not the store.  ApplyStoredCommands stays skipped under
  // /EXPORT: applying everything takes today's settings over the log's own
  // .cfg, which was measured wrong (21/1/4 -> 8/14/4).  This is the station's
  // own identity rather than a property of the log being exported, so the
  // current value is the correct one -- and no corpus .cfg sets it.
  ApplyStoredCommand('COMPUTER ID');

  if (not tSilentExport) and
     (not ApplyActiveProfileToConfigAtStartup(tRadioLibraryError)) then
     begin
     logger.Warn('[Startup] the radio library was not applied: %s', [tRadioLibraryError]);
     end;

  // Issue #1012: the S&P F1 caption is derived from DE ENABLE, whose value is
  // only known after the config files above are read.  Recompute it now so
  // DE ENABLE = FALSE shows "Call" instead of the default "DE+Call".
  UpdateSAndPF1Caption;

  if WSJTXEnabled then
     begin
     wsjtx := TWSJTXServer.Create;
     end;

  // The TCI server.  Created unconditionally and STARTED only if enabled --
  // uWSJTX reads its enable flag in the constructor, which is why toggling
  // that one needs a program restart.  A live object with Start/Stop is what
  // makes the Preferences check box able to take effect without one.
  TCIServer := TTCIServer.Create;
  logger.debug('[tr4w] SpotCollectorEnabled = %s', [BooleanToStr(SpotCollectorEnabled)]);
  if SpotCollectorEnabled then
     StartDXLabPathfinder;
  if elLogType <> lt_NoExternalLogger then
     begin
     externalLogger := TExternalLogger.Create(elLogType);
     externalLogger.loggerPort := externalLoggerPort;
     externalLogger.loggerAddress := externalLoggerAddress;
     end;
  // Issue #783 -- start the HamScore RTC uploader if HAMSCORE ENABLE = TRUE.
  // No-op if disabled or password is empty.
  HamScoreInit;
  UpdateDebugLogLevel;
  //logger.debug('**************** Program Startup ************************');
  logger.info('DecimalSeparator = ' + FormatSettings.DecimalSeparator);
  // INFO, NOT DEBUG. These three identify the software in the log, and a
  // support log is normally gathered at info -- so the first question asked of
  // any crash report, "which version is this?", was answered only for people
  // already running at debug. The ENVIRONMENT versions beside them (HamLib,
  // Windows) were already info, which made the omission easy to miss.
  { COUNTED, because zero is what this defect looked like -- and it looked
    like nothing at all.  An empty registry does not fail; it just makes
    every command in tr4w.json unclassifiable, so they all land in 'other'.

    HERE AND NOT BESIDE DeclareAllSettings, which runs far earlier: the file
    appender is not attached until this point, so a line logged up there goes
    nowhere.  The comment by the batch-mode flag says exactly that, and I
    logged it up there anyway and got silence. }

  logger.Info('[Startup] settings registry: %d declared', [Length(AllSettings)]);
  logger.info('Current program version = %s',[TR4W_CURRENTVERSION]);
  logger.info('Current TR4W Server version = %s',[TR4WSERVER_CURRENTVERSION]);
  logger.info('Current log version = %s',[LOGVERSION]);
  logger.info('HamLib version = %s',[GetHamLibVersion]);
  // INFO, not DEBUG: this is the first thing anyone asks a tester for, and at
  // DEBUG it is absent from exactly the logs that get sent in. HamLib version on
  // the line above is info for the same reason.
  //
  // The raw numbers are printed alongside the friendly name on purpose. They come
  // from the supportedOS block in W11.manifest; without it Windows reports 6.2
  // (Windows 8) to an unmanifested program forever, so "raw: 10.0" is also a
  // check that the manifest is intact.
  logger.info('Windows version = %s %s (raw: %d.%d Build %d)',[GetOSInfo, GetWindowsBuildDetail, tr4w_osverinfo.dwMajorVersion, tr4w_osverinfo.dwMinorVersion, tr4w_osverinfo.dwBuildNumber]);
  if CTY.CtyRFOblMode then       // n4af 4.42.6
     ctyLoadInRFOblList;



  if CTY.ctyR150SMode then
  begin
    ctyLoadInR150SList;
    TempString := 'MY CALL';
    CheckCommand(@TempString, MyCall);
  end;

{$IF SCPDEBUG}
  scpLoadInDateBase('trmaster.dta');
{$IFEND}

  mo.FillVisibleBytes;
  ws := ws + 12;

  tSetupExchangeNumbers;

  if (HFBandEnable = False) and (VHFBandsEnabled = True) then
     begin
     ActiveBand := Band6;
     BandMapDisplayGhz := True;    // n4af 4.42.8
     end;
  if HFBandEnable then
     BandMapDisplayGhz := False;    // n4af 4.42.8

  SetWindowSize;
  CreateFonts;

  // Set OUTSIDE the `with`, deliberately.  Inside it, the bare name HInstance
  // binds to WNDCLASS's OWN hInstance field, not to the module handle -- which
  // is why this used to read SysInit.hInstance.  SysInit is a Delphi-only unit
  // (FPC keeps HInstance in System), and rather than pick a qualifier that has
  // to be right on two compilers, the assignment simply moves to where the
  // unqualified name is already unambiguous.
  tr4w_WinClass.hInstance := HInstance;

  with tr4w_WinClass do
  begin
    // a NAMED resource -- MAKEINTRESOURCE on a string was always a no-op
    HICON := LoadIconW(tr4w_WinClass.hInstance, 'MAINICON');
    lpfnWndProc := @WindowProc;
    HCURSOR := LoadCursor(0, IDC_ARROW);
    hbrBackground := tr4wBrushArray[TWindows[mweWholeScreen].mweBackG {trBtnFace}];
  end;

  //tr4w_main_menu := LoadMenu(hInstance, 'T');
  tr4w_main_menu := CreateTR4WMenu(@T_MENU_ARRAY, T_MENU_ARRAY_SIZE, False);

{$IFDEF AUTOSPOT}
   ShowMessage(TC_AUTOSPOTENABLEDTESTMODEONLY); // Hard on relays - be careful
{$ENDIF}
  // ONE Pascal table, not the 'T' resource -- and not the ELEVEN copies of it
  // that had drifted apart across the language .RES files (see
  // docs\ACCELERATOR_AUDIT.md).  TranslateAccelerator below is unchanged;
  // only where the table comes from has changed, which is what lets the menu
  // caption and the binding be derived from one row.
  tr4w_accelerators := BuildAcceleratorTable;
  // FAIL LOUD. A table that failed to build leaves tr4w_accelerators = 0 and
  // TranslateAccelerator then quietly does nothing -- the program runs and the
  // whole keyboard is dead, with nothing in the log to say why. The count is
  // logged either way so a shrinking table is visible in a bug report.
  if tr4w_accelerators = 0 then
     begin
     logger.Error('[Accelerators] CreateAcceleratorTable FAILED -- no keyboard shortcuts will work');
     end
  else
     begin
     logger.Info('[Accelerators] %d binding(s) installed', [Length(ACCELERATORS)]);
     end;

  RegisterClass(tr4w_WinClass);


  SetUpExchangeInformation(ActiveExchange, ExchangeInformation);
  SetColumnsWidth;
  CreateMainWindow;
  CreateMultsWindows;
  CreateQSONeedWindows;

  SetUpGlobalsAndInitialize;

  // Golden-master automation: launched as  tr4w.exe "<contest>.CFG" /EXPORT
  // the config + log + mults are loaded now, so run the SAME export procs the
  // File->Export menu uses (identical output, incl. the -D12 banner) and exit
  // BEFORE the GUI message loop + radio/network init.  ExportToADIF and
  // CreateCabrilloFile each derive their own filename and, called directly,
  // pop no dialog.  (Contests that show a startup dialog -- e.g. IARU call
  // history -- must be excluded by the driver, since that would block batch.)
  if SameText(ParamStr(2), '/EXPORT') then
     begin
     // tSilentExport was set when the logger was created -- see there for why.
     ExportToADIF;
     CreateCabrilloFile;
     Halt(0);
     end;

  // OFFER TO RETIRE tr4w.ini -- once, and only now.
  //
  // AFTER the /EXPORT Halt above, which is not a detail: the golden-master
  // corpus drives tr4w.exe headless, and a modal dialog there would hang all
  // thirteen runs rather than fail them.
  //
  // After the seeding too -- every station setting has been carried into the
  // JSON store by this point, so the question can honestly say the old file is
  // no longer read.
  OfferToRetireLegacyIni(TR4WConfigFileName);

  if Config.SayHiEnable then
     DisplayNamePercentage;
  SetStereoPin(StereoControlPin, StereoPinState);
  DisplayRadio(ActiveRadio);
  DisplayBandMode(ActiveBand, ActiveMode, False);
  tDisplayCQTotal;
  ClearContestExchange(ReceivedData);
  SetUpToSendOnActiveRadio;

  UpdateTimeAndRateDisplays(True, True);
  SystemTimeChanging;
  DisplayRate(0);
  tDispalyMyComputerID;
  SetMainWindowText(mweCurrentOperator, CurrentOperator);

  ntBeepInit;
  OpenOtherWindows;

  { THE DOMAIN LAYER'S ONE CROSSING INTO THE UI, and it has to be AFTER the
    main window is SHOWN -- not merely after the form or the elements exist.

    Its whole job is to bring the view into line with state that may already be
    set, and for four months it did nothing at all: every element accessor
    guards on ControlUsable, which requires HandleAllocated, and an LCL control
    has no handle until its form is realised.  Installed beside
    CreateTR4WMainForm, the install-time pass wrote into controls that could not
    take a value and returned quietly.

    Invisible until the WSJT-X indicator had to appear at START-UP rather than
    on the first state change -- then it showed as an empty red box painted by
    the colour sweep, with a caption nothing had been able to write (NY4I,
    2026-08-26: "the letters WSJT-X are not in the red box").

    The raw `ShowWindow(wh[mweWSJTX], SW_HIDE)` that used to sit here is gone
    with it: the indicator's visibility belongs to the bridge now, and hiding it
    behind the widget set's back left the panel's Visible True while the window
    was hidden, so the next property change made it reappear -- empty. }
  InstallStateBridge;

  tLoadKeyboardLayout;

  tCallWindowSetFocus;

  LoadInPlugins;

  CheckNTPAtStartup;

  // Load POTA parks database off the UI thread (file may be ~3 MB / 50k entries).
  // TPOTALoadThread parses the CSV and posts WM_POTA_LOAD_DONE when done.
  LoadPOTAParksAsync(tr4whandle);

  // Silent background CTY version check — posts WM_CTY_VERSION_CHECKED when done.
  // Config is already loaded at this point so CTYUpdateCheckOnStartup is valid.
  if CTYUpdateCheckOnStartup then
     CheckCTYVersionAsync(tr4whandle);

  // MY GRID, if it has never been set.
  //
  // WHY AT STARTUP AND NOT ONLY FOR GRID CONTESTS (NY4I, 2026-08-16): MY GRID
  // drives the distance and beam heading to the DX station, so it earns its
  // keep in every contest -- not just the ones that exchange a grid. This
  // restores behaviour that TR4W documented long ago (uHistory.pas:125) and
  // that no longer existed in the code.
  //
  // SetCommand routes it to Preferences with the Station page open and the grid
  // field focused, because MY GRID is a csOwned row and Ctrl-J does not list
  // it -- see SetCommand for the full story.
  //
  // Placed here deliberately: config is loaded (so MyGrid is the operator's
  // real value, not the CFGDEF default) and the main window exists, but the
  // message loop has not started -- which is fine, as the prompt is a modal
  // MessageBox with its own loop and Preferences is opened non-modally.
  //
  // NOT in headless /EXPORT: there is no operator to answer, and a batch export
  // that stops on a modal is a hang. Same rule as the CTY prompt above.
  // ASKED ONCE PER INSTALLATION, not once per start (NY4I, 2026-08-17: "the
  // program keeps showing the MY GRID request upon startup").
  //
  // An operator who does not want a grid should not be asked again every time
  // they open TR4W, and one who does can set it in Preferences > Station --
  // where it is now also findable by search.  The flag is recorded whatever the
  // answer, because being asked and saying no IS an answer.
  if (not tSilentExport) and (Trim(string(MyGrid)) = '') then
     begin
     if GridPromptAlreadyShown then
        begin
        logger.Info('MY GRID is empty; already offered once, not asking again');
        end
     else
        begin
        logger.Info('MY GRID is empty; offering to set it');
        MarkGridPromptShown;   // BEFORE the modal: a crash mid-prompt must not re-arm it
        SetCommand('MY GRID');
        end;
     end;

  // The four synchronization events: CW element, CW paddle, DVP playback and
  // network.  All auto-reset, all starting unsignalled -- which is what the
  // assembly this replaces built, by pushing four zeros for
  // CreateEvent(nil, FALSE, FALSE, nil).
  //
  // Three things about that assembly were worth not keeping.  It opened with
  // `mov ebx,0`, CLOBBERING EBX without saving it -- EBX is callee-saved in the
  // Win32 ABI and the compiler may hold a local in it, and this sits in the
  // middle of the startup path.  It reused the first call's arguments for the
  // next three via `sub esp,16`, walking ESP back over stack bytes that
  // CreateEvent's stdcall epilogue had already popped -- correct only for as
  // long as nothing happens to touch that region in between.  And it checked no
  // result: a failed CreateEvent left a 0 handle, after which every
  // WaitForSingleObject on it fails forever, in silence.
  tCW_Event       := CreateEvent(nil, False, False, nil);
  tCWPaddle_Event := CreateEvent(nil, False, False, nil);
  tDVP_Event      := CreateEvent(nil, False, False, nil);
  tNet_Event      := CreateEvent(nil, False, False, nil);

  if (tCW_Event = 0) or (tCWPaddle_Event = 0) or
     (tDVP_Event = 0) or (tNet_Event = 0) then
     begin
     // Not fatal -- CW still keys, but tCWSleep falls back to plain Sleep() and
     // the element timing coarsens.  Report it rather than degrade silently.
     logger.Error('CreateEvent failed (CW=%d paddle=%d DVP=%d net=%d), last error %d',
        [tCW_Event, tCWPaddle_Event, tDVP_Event, tNet_Event, GetLastError]);
     end;


  if not tHandLogMode then
     begin
     SetTimer(tr4whandle, ONE_SECOND_TIMER_HANDLE, 1000, @OneSecTimerProc);
     // The 250 ms band map refresh timer stood here: a SetTimer on the MAIN
     // window, armed once and never killed, ticking for the life of the
     // program whether or not the band map existed.  The band map form owns
     // a TTimer now -- a window refreshes itself, and the timer lives and
     // dies with the window.
     for c := menu_alt_increment_time_1 to menu_alt_increment_time_0 do EnableMenuItem(tr4w_main_menu, c, MF_GRAYED + MF_BYCOMMAND);
     end
  else
     begin
     showwarning(TC_HANDLOGMODETRUE);
     end;

//  wkLoadSettings;
   if WinKeySettings.wksWinKey2Enable then
      begin
      logger.Info('Calling tCreateThread from WinKeyer');
      tCreateThread(@wkOpen, wkThreadID);
      logger.Info('Created WinKeyer thread with threadid of %d',[wkThreadID] );
      end;

   if YCCCSo2rEnable then
      begin
      logger.Info('Opening YCCC SO2R box');
      if not YCCCOpen then
         logger.Warn('YCCC SO2R box not found or failed to open');
      end;

{$IFDEF MIXWMODE}
  tEnableMenuItem(menu_windows_mmtty, MF_ENABLED);
{$ENDIF}

  CD.MasterFileExists := FileExists(CD.ActiveFilename);

  if not CD.MasterFileExists then
  begin
    QuickDisplay(SysUtils.Format(TC_TRMASTERDTAS, [SysUtils.SysErrorMessage(GetLastError)]));
  end;

{$IF not tDebugMode}
  // THE LAST CONTEST OPENED, recorded in settings\tr4w.json (NY4I, 2026-08-16).
  //
  // It used to go to tr4w.ini, and that single WritePrivateProfileString was
  // the ONLY thing recreating that file: a station whose settings had all
  // reached the JSON still got a two-line tr4w.ini back on every start, which
  // made "the ini is gone" untestable and untrue. Measured before changing it —
  // the recreated file was exactly `[COMMANDS]` and this one key.
  //
  // It stays valid data (it names the contest .cfg to reopen) but it is NOT a
  // setting, so it lives in the store's `general` section beside activeProfile
  // rather than in `commands`, and it is deliberately not registered — nothing
  // in Preferences edits it and it is absent from the search index.
  Windows.CopyMemory(@TR4W_LATESTCFG_FILENAME, @TR4W_CFG_FILENAME, SizeOf(FileNameType));
  SetLatestConfigFile(string(PAnsiChar(@TR4W_LATESTCFG_FILENAME)));
{$IFEND}

{$IF NEWER_DEBUG}
  //QuickDisplay('Warning - This is a Debug version');
{$IFEND}
  // SERIAL PORT DEBUG used to raise a startup dialog here pointing at Portmon.
  // The command is now retired the way the array already supports -- csRem with
  // a nil address -- so it is accepted, not applied, and hidden from the Options
  // dialog, exactly like every other retired command.  No popup: none of the
  // others announce themselves either, and the help entry already reads "No
  // longer used due to Windows restrictions on monitoring the serial port."

  if MyGrid = '' then
    SetCommand('MY GRID');

//  Format(wsprintfBuffer, 'cty.dat: "%s" version', CTY.ctyTable[cty.ctyVersion].Name);
//  SetMainWindowText(mweBeamHeading, wsprintfBuffer);

{$IF tKeyerDebug}
//  CreateModalDialog(150, 90, tr4whandle, @KeyerDebugDlgProc, 0);
//  CreateDialog(hInstance, MAKEINTRESOURCE(72), 0, @KeyerDebugDlgProc);
  CreateDialogIndirectParam(hInstance, PDlgTemplate(@MAINTR4WDLGTEMPLATE)^, tr4whandle, @KeyerDebugDlgProc, 0);
  FrmSetFocus;

{$IFEND}

{$IF MORSERUNNER}
  GetMorseRunnerWindow;
{$IFEND}


   if WSJTXEnabled then
      begin
   // Send colors for Dupes (QSOB4)

   wsjtx.SetDupeBackgroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweBackG]));
   wsjtx.SetDupeForegroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweColor]));

   // Send colors for multipliers
   wsjtx.SetMultBackgroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweBackG]));
   wsjtx.SetMultForegroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweColor]));

   wsjtx.SendColorization := WSJTXSendColorization;
   if WSJTXEnabled then     // This boolean is in uCFG (default to true). This is so we start if the parameter is not set.
      begin
      wsjtx.Start;
      end;
   end;

   // Started AFTER the radios are set up, so the init burst a client gets on
   // connect describes real radios rather than zeroes.  Loopback only: this
   // is an unauthenticated radio-control socket and the clients that use it
   // (WSJT-X, JTDX, a skimmer) run on the operator's own machine.
   if RadioLibraryTCIServerEnabled and (TCIServer <> nil) then
      begin
      // The store says 0 when the operator has not chosen a port, so the
      // default lives in exactly one place -- here, next to the server that
      // owns the constant.  Bind-all is likewise the store's to say; it stays
      // False unless asked, for the loopback reason described above.
      if RadioLibraryTCIPort <= 0 then
         begin
         RadioLibraryTCIPort := TCI_SERVER_DEFAULT_PORT;
         end;

      if not TCIServer.Start(RadioLibraryTCIPort, RadioLibraryTCIBindAll) then
         begin
         QuickDisplay('TCI server could not open port ' + IntToStr(RadioLibraryTCIPort));
         end;
      end;
    {****************************  Main CallBack  ****************************}

  // ============================ THE MESSAGE LOOP IS THE LCL'S ==============
  //
  // Phase 3c, 2026-08-23.  What stood here was a GetMessage / TranslateMessage
  // / DispatchMessage loop wrapped in a fault-recovery repeat, with a `case
  // Msg.Message of` carrying the accelerator table, the numeric-keypad CW
  // memories, QuickQSL, the F-key label refresh and two gotos.
  //
  // It could not go while any input-bearing control was a raw Win32 child,
  // because a raw child raises no LCL events and only a loop that sees every
  // message for the thread could reach it.  The last two -- the function-key
  // buttons and the band map list box -- became LCL controls on 2026-08-22 and
  // 08-23, and the arms went with them.
  //
  // WHERE THE REST WENT, all of it in uAppInputHooks:
  //   TranslateAccelerator      -> AddOnKeyDownBeforeHandler over ACCELERATORS
  //   keypad CW memories        -> the same handler
  //   ShowFMessages on modifier -> AddOnUserInputHandler
  //   the fault-recovery repeat -> AddOnExceptionHandler
  //   QuickQSL (WM_CHAR)        -> TTR4WEntryEvents.EntryKeyPress
  //   MessageIsForHostedWindow  -> nothing: it existed to route messages around
  //                                a loop that no longer exists
  //
  // TR4W STILL EXITS THROUGH ExitProcess (tr4w_ShutDown, via ExitProgram), so
  // Application.Run does not return in normal use and nothing after it can be
  // relied upon -- which is why HamScoreShutdown moved INTO the shutdown path
  // rather than staying in a finally here.
  InstallTR4WInputHooks;

  { THE LAYOUT AUTOSAVE, started HERE and not earlier: the windows have been
    created and placed from the saved layout by now, so its first tick sees no
    change and does not rewrite the file it just read.  See MainUnit. }
  StartLayoutAutosave;

  { AND THE PANADAPTERS THAT WERE OPEN LAST TIME.  After the autosave for the
    same reason -- the layout on disk is what it reads -- but it does its own
    waiting, because a panadapter needs a radio that is CONNECTED and
    streaming, which start-up cannot promise.  See uRadioPanelForm. }
  StartPanadapterRestore;

  (* --textfit: measure every caption against the room it has, then leave.
     Here because the forms must EXIST to be measured, and before the loop
     because the answer does not need one. uTextFitAudit records why this
     cannot be done from outside the process. *)
  if TextFitAuditRequested then
     begin
     InstallTextFitAudit;
     end;

  RunLCLApplication;
end;

end.
