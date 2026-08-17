program tr4w;
{$IMPORTEDDATA OFF}
{$I src\tr4w.inc}

// VERSIONINFO PE resource (Windows Properties dialog: File version /
// Product name / Language / Copyright fields).  Generated per-build
// by FullBuild.ps1 / Write-VersionInfoResource with the language and
// version values from Version.pas substituted in.  Guarded so the
// Delphi 7 IDE -- which doesn't run FullBuild.ps1 -- compiles cleanly
// without the file present (just produces an EXE with blank version
// fields, same as the historical behaviour).  Command-line builds
// pass -DVERSIONINFO_RES to enable.
{$IFDEF VERSIONINFO_RES}
{$R tr4w_versioninfo.res}
{$ENDIF}

//https://groups.google.com/group/tr4w/feeds?hl=ru
uses
  Messages,
  MMSystem,
  Windows,
  iniFiles,
  SysUtils,
  MainUnit in 'src\MainUnit.pas',
  BeepUnit in 'src\trdos\BeepUnit.pas',
  CFGCMD in 'src\trdos\CfgCmd.pas',
  CFGDEF in 'src\trdos\CFGDEF.PAS',
  FCONTEST in 'src\trdos\FCONTEST.PAS',
  LogCfg in 'src\trdos\LogCfg.pas',
  LogCW in 'src\trdos\LogCW.pas',
  LogDom in 'src\trdos\LOGDOM.PAS',
  LogDupe in 'src\trdos\LOGDUPE.PAS',
  LOGDVP in 'src\trdos\LOGDVP.PAS',
  LogEdit in 'src\trdos\LOGEDIT.PAS',
  LogGrid in 'src\trdos\LOGGRID.PAS',
  LogK1EA in 'src\trdos\LOGK1EA.PAS',
  LogNet in 'src\trdos\LOGNET.PAS',
  LogPack in 'src\trdos\LOGPACK.PAS',
  LogRadio in 'src\trdos\LOGRADIO.PAS',
  LogSCP in 'src\trdos\LOGSCP.PAS',
  LogStuff in 'src\trdos\LOGSTUFF.PAS',
  LOGWAE in 'src\trdos\LOGWAE.PAS',
  LogWind in 'src\trdos\LOGWIND.PAS',
  Tree in 'src\trdos\tree.pas',
  ZoneCont in 'src\trdos\ZONECONT.PAS',
  LOGSUBS2 in 'src\trdos\LOGSUBS2.PAS',
  LOGSUBS1 in 'src\trdos\LOGSUBS1.PAS',
  LOGSend in 'src\trdos\LogSend.pas',
  uCT1BOH in 'src\uCT1BOH.pas',
  PostUnit in 'src\trdos\PostUnit.PAS',
  uCabrilloFormat in 'src\uCabrilloFormat.pas',
  uCabrilloExchange in 'src\uCabrilloExchange.pas',
  uInputQuery in 'src\uInputQuery.pas',
  uNewContest in 'src\uNewContest.pas',
  uRadioPolling in 'src\uRadioPolling.pas',
  uMissingMults in 'src\uMissingMults.pas',
  uEditQSO in 'src\uEditQSO.pas',
  uLogSearch in 'src\uLogSearch.pas',
  uBeacons in 'src\uBeacons.pas',
  uNet in 'src\uNet.pas',
  uTotal in 'src\uTotal.pas',
  uMaster in 'src\uMaster.pas',
  uRemMults in 'src\uRemMults.pas',
  uDupesheet in 'src\uDupesheet.pas',
  uSendSpot in 'src\uSendSpot.pas',
  uSendKeyboard in 'src\uSendKeyboard.pas',
  uOption in 'src\uOption.pas',
  uRadio12 in 'src\uRadio12.pas',
  uFunctionKeys in 'src\uFunctionKeys.pas',
  uinet in 'src\uinet.pas',
  uDXClusterClient in 'src\uDXClusterClient.pas',
  uDXSpotParse in 'src\uDXSpotParse.pas',
  uTelnet in 'src\uTelnet.pas',
  uBandmap in 'src\uBandmap.pas',
  uFileView in 'src\uFileView.pas',
  uAutoCQ in 'src\uAutoCQ.pas',
  uCAT in 'src\uCAT.pas',
  // The radio-configuration layer.  Nothing calls these yet -- the FMX
  // preferences dialog is the caller -- but they are listed so the compiler
  // checks them against the live CFGCA/CAT surface on every build.
  uRotatorBase in 'src\rotatorFactory\uRotatorBase.pas',
  uRotatorControl in 'src\uRotatorControl.pas',
  uRotatorRegistry in 'src\rotatorFactory\uRotatorRegistry.pas',
  uRotatorYaesu in 'src\rotatorFactory\uRotatorYaesu.pas',
  uRotatorOrion in 'src\rotatorFactory\uRotatorOrion.pas',
  uRotatorDCU1 in 'src\rotatorFactory\uRotatorDCU1.pas',
  uRotatorAlfaSpid in 'src\rotatorFactory\uRotatorAlfaSpid.pas',
  uRotatorPSTRotator in 'src\rotatorFactory\uRotatorPSTRotator.pas',
  uSettingsRegistry in 'src\uSettingsRegistry.pas',
  uSettingsLegacy in 'src\uSettingsLegacy.pas',
  uSettingsDeclarations in 'src\uSettingsDeclarations.pas',
  uRadioConfigStore in 'src\uRadioConfigStore.pas',
  uKeyerConfigStore in 'src\uKeyerConfigStore.pas',
  uKeyerConfigApply in 'src\uKeyerConfigApply.pas',
  uUDPBroadcastConfig in 'src\uUDPBroadcastConfig.pas',
  uUDPBroadcaster in 'src\uUDPBroadcaster.pas',
  uTR4WConfigFile in 'src\uTR4WConfigFile.pas',
  uRadioConfigLegacyMap in 'src\uRadioConfigLegacyMap.pas',
  uRadioConfigApply in 'src\uRadioConfigApply.pas',
  // FMX coexistence spike -- see docs\FMX_WIN32_COEXISTENCE.md.  FMX.Forms is
  // needed for Application.Initialize; the spike form is opened on demand by
  // the FMXTEST call-window command and never at startup.
  //
  // EXCLUDED UNDER FPC.  FMX has no FPC equivalent; the LCL is the intended
  // replacement and that port is not done.  Nothing on the headless /EXPORT
  // path -- which is what the golden-master corpus drives -- ever creates a
  // form, so an FPC build without these can still answer the question the
  // corpus asks.  An FPC build is therefore ENGINE-ONLY and cannot be shipped:
  // the four settings dialogs and the two spike commands are simply absent.
  // This guard comes out with the LCL port.  MainUnit already carries the
  // matching guards for the commands that open these forms.
{$IFNDEF FPC}
  FMX.Forms,
  uFMXCoexist in 'src\ui\fmx\uFMXCoexist.pas',
  uFMXSpikeForm in 'src\ui\fmx\uFMXSpikeForm.pas',
  // SPIKE ONLY -- the designed-form probe (FMXDESIGN); remove with the spike.
  uFMXDesignedProbe in 'src\ui\fmx\uFMXDesignedProbe.pas' {FMXDesignedProbe},
  uFMXFormHelpers in 'src\ui\fmx\uFMXFormHelpers.pas',
  uFMXTranslate in 'src\ui\fmx\uFMXTranslate.pas',
  uRadioEditForm in 'src\ui\fmx\uRadioEditForm.pas' {RadioEditForm},
  uKeyerEditForm in 'src\ui\fmx\uKeyerEditForm.pas' {frmKeyerEdit},
  uUDPDestinationEditForm in 'src\ui\fmx\uUDPDestinationEditForm.pas' {frmUDPDestinationEdit},
  // TSettingBindings binds FMX controls to settings, so it belongs with the
  // forms.  RegisterLegacySetting moved to uSettingsLegacy, which has no FMX
  // and stays in the build.
  uSettingsBinding in 'src\uSettingsBinding.pas',
  uPrefsForm in 'src\ui\fmx\uPrefsForm.pas' {PrefsForm},
{$ENDIF}
  uDialogs in 'src\uDialogs.pas',
  Version in 'src\Version.pas',
  VC in 'src\VC.pas',
  uCommctrl in 'src\uCommctrl.pas',
  uGradient in 'src\uGradient.pas',
  uMessages in 'src\uMessages.pas',
  uWinManager in 'src\uWinManager.pas',
  uCbrSum in 'src\uCbrSum.pas',
  uQTCR in 'src\uQTCR.pas',
  uQTCS in 'src\uQTCS.pas',
  LPT in 'src\LPT.pas',
  uGetServerLog in 'src\uGetServerLog.pas',
  TF in 'src\TF.pas',
  uFreqTimeFormat in 'src\uFreqTimeFormat.pas',
  uLogEdit in 'src\uLogEdit.pas',
  uIntercom in 'src\uIntercom.pas',
  uLogCompare in 'src\uLogCompare.pas',
  uMixW in 'src\uMixW.pas',
  uCallsigns in 'src\uCallsigns.pas',
  uSpots in 'src\uSpots.pas',
  uGetScores in 'src\uGetScores.pas',
  uStations in 'src\uStations.pas',
  uAltD in 'src\uAltD.pas',
  uWinKey in 'src\uWinKey.pas',
  uLPTPortEnumerator in 'src\uLPTPortEnumerator.pas',
  uPrefsSearch in 'src\uPrefsSearch.pas',
  uConfigValues in 'src\uConfigValues.pas',
  uCrashLog in 'src\uCrashLog.pas',
  uCFG in 'src\uCFG.pas',
  uCRC32 in 'src\uCRC32.pas',
  uMP3Recorder in 'src\uMP3Recorder.pas',
  uAltP in 'src\uAltP.pas',
  uEditMessage in 'src\uEditMessage.pas',
  uCheckLatestVersion in 'src\uCheckLatestVersion.pas',
  uErmak in 'src\uErmak.pas',
  uProcessCommand in 'src\uProcessCommand.pas',
  uMults in 'src\uMults.pas',
  HtmlHelp in 'src\HtmlHelp.pas',
  uSSL in 'src\uSSL.pas',
  uQuickEdit in 'src\uQuickEdit.pas',
  uIO in 'src\uIO.pas',
  uBMCF in 'src\uBMCF.pas',
  uCTYDAT in 'src\uCTYDAT.PAS',
  uCallSignRoutines in 'src\uCallSignRoutines.pas',
  uSynTime in 'src\uSynTime.pas',
  uMMTTY in 'src\uMMTTY.pas',
  uProfiler in 'src\uProfiler.pas',
  uMessagesList in 'src\uMessagesList.pas',
  uRussiaOblasts in 'src\uRussiaOblasts.pas',
  uMenu in 'src\uMenu.pas',
  utils_net in 'src\utils\utils_net.pas',
  utils_hw in 'src\utils\utils_hw.pas',
  uAnsiStr in 'src\utils\uAnsiStr.pas',
  uFileText in 'src\utils\uFileText.pas',
  uRegex in 'src\utils\uRegex.pas',
  uWin32Compat in 'src\utils\uWin32Compat.pas',
  uHostedFormWindows in 'src\utils\uHostedFormWindows.pas',
{$IFDEF FPC}
  // The LCL side of hosting a toolkit in TR4W's own loop.  FPC-only:
  // Delphi cannot compile the LCL, just as FPC cannot compile FMX.
  uLCLCoexist in 'src\ui\lcl\uLCLCoexist.pas',
  uLCLTranslate in 'src\ui\lcl\uLCLTranslate.pas',
  uLCLFormHelpers in 'src\ui\lcl\uLCLFormHelpers.pas',
  uSettingsBinding in 'src\ui\lcl\uSettingsBinding.pas',
  uUDPDestinationEditForm in 'src\ui\lcl\uUDPDestinationEditForm.pas',
  uKeyerEditForm in 'src\ui\lcl\uKeyerEditForm.pas',
  uRadioEditForm in 'src\ui\lcl\uRadioEditForm.pas',
  uPrefsForm in 'src\ui\lcl\uPrefsForm.pas',
{$ENDIF}
  uJSON in 'src\utils\uJSON.pas',
  uHTTPDownload in 'src\utils\uHTTPDownload.pas',
  utils_text in 'src\utils\utils_text.pas',
  utils_math in 'src\utils\utils_math.pas',
  utils_file in 'src\utils\utils_file.pas',
  uWinTimer in 'src\utils\uWinTimer.pas',
  uWSJTX in 'src\uWSJTX.pas',
  uHamScore in 'src\uHamScore.pas',
  uExchangeBuilder in 'src\uExchangeBuilder.pas',
  uGridLookup in 'src\uGridLookup.pas',
  Log4D in 'src\Log4D.pas',
  uFactoryRadioBase in 'src\radioFactory\uFactoryRadioBase.pas',
  uSerialPort in 'src\uSerialPort.pas',
  uRadioFactory in 'src\radioFactory\uRadioFactory.pas',
  uRadioElecraftK4 in 'src\radioFactory\uRadioElecraftK4.pas',
  uRadioElecraftSerial in 'src\radioFactory\uRadioElecraftSerial.pas',
  uRadioYaesuASCII in 'src\radioFactory\uRadioYaesuASCII.pas',
  uRadioYaesuFTDX10 in 'src\radioFactory\uRadioYaesuFTDX10.pas',
  uRadioYaesuBinary in 'src\radioFactory\uRadioYaesuBinary.pas',
  uRadioYaesuFT1000MP in 'src\radioFactory\uRadioYaesuFT1000MP.pas',
  uRadioYaesuFT817Group in 'src\radioFactory\uRadioYaesuFT817Group.pas',
  uRadioYaesuFT817 in 'src\radioFactory\uRadioYaesuFT817.pas',
  uRadioYaesuFT818 in 'src\radioFactory\uRadioYaesuFT818.pas',
  uRadioYaesuFT857 in 'src\radioFactory\uRadioYaesuFT857.pas',
  uRadioYaesuFT897 in 'src\radioFactory\uRadioYaesuFT897.pas',
  uRadioYaesuFT847 in 'src\radioFactory\uRadioYaesuFT847.pas',
  uRadioYaesuFT990Group in 'src\radioFactory\uRadioYaesuFT990Group.pas',
  uRadioYaesuFT990 in 'src\radioFactory\uRadioYaesuFT990.pas',
  uRadioYaesuFT1000 in 'src\radioFactory\uRadioYaesuFT1000.pas',
  uRadioYaesuFT840Group in 'src\radioFactory\uRadioYaesuFT840Group.pas',
  uRadioYaesuFT840 in 'src\radioFactory\uRadioYaesuFT840.pas',
  uRadioYaesuFT890 in 'src\radioFactory\uRadioYaesuFT890.pas',
  uRadioYaesuFT900 in 'src\radioFactory\uRadioYaesuFT900.pas',
  uRadioYaesuFT920 in 'src\radioFactory\uRadioYaesuFT920.pas',
  uRadioYaesuFT100 in 'src\radioFactory\uRadioYaesuFT100.pas',
  uRadioYaesuFT747 in 'src\radioFactory\uRadioYaesuFT747.pas',
  uRadioYaesuFT767 in 'src\radioFactory\uRadioYaesuFT767.pas',
  uRadioYaesuFT991 in 'src\radioFactory\uRadioYaesuFT991.pas',
  uRadioYaesuFTDX101 in 'src\radioFactory\uRadioYaesuFTDX101.pas',
  uRadioYaesuFT710 in 'src\radioFactory\uRadioYaesuFT710.pas',
  uRadioYaesuFTX1F in 'src\radioFactory\uRadioYaesuFTX1F.pas',
  uRadioYaesuFT891 in 'src\radioFactory\uRadioYaesuFT891.pas',
  uRadioYaesuASCIILegacy in 'src\radioFactory\uRadioYaesuASCIILegacy.pas',
  uRadioYaesuFT450 in 'src\radioFactory\uRadioYaesuFT450.pas',
  uRadioYaesuFT950 in 'src\radioFactory\uRadioYaesuFT950.pas',
  uRadioYaesuFT1200 in 'src\radioFactory\uRadioYaesuFT1200.pas',
  uRadioYaesuFT2000 in 'src\radioFactory\uRadioYaesuFT2000.pas',
  uRadioYaesuFTDX3000 in 'src\radioFactory\uRadioYaesuFTDX3000.pas',
  uRadioYaesuFTDX5000 in 'src\radioFactory\uRadioYaesuFTDX5000.pas',
  uRadioYaesuFTDX9000 in 'src\radioFactory\uRadioYaesuFTDX9000.pas',
  uRadioFlexCAT in 'src\radioFactory\uRadioFlexCAT.pas',
  uRadioFlex6000 in 'src\radioFactory\uRadioFlex6000.pas',
  uRadioElecraftK3 in 'src\radioFactory\uRadioElecraftK3.pas',
  uRadioElecraftK2 in 'src\radioFactory\uRadioElecraftK2.pas',
  uRadioElecraftKX3 in 'src\radioFactory\uRadioElecraftKX3.pas',
  uRadioKenwoodLAN in 'src\radioFactory\uRadioKenwoodLAN.pas',
  uWebSocketFraming in 'src\uWebSocketFraming.pas',
  uWebSocketClient in 'src\uWebSocketClient.pas',
  uWebSocketServer in 'src\uWebSocketServer.pas',
  uTCIProtocol in 'src\uTCIProtocol.pas',
  uTCIServer in 'src\uTCIServer.pas',
  uRadioTCI in 'src\radioFactory\uRadioTCI.pas',
  uRadioKenwoodTS890 in 'src\radioFactory\uRadioKenwoodTS890.pas',
  uRadioKenwoodTS990 in 'src\radioFactory\uRadioKenwoodTS990.pas',
  uIcomNetworkTypes in 'src\uIcomNetworkTypes.pas',
  uIcomNetworkTransport in 'src\uIcomNetworkTransport.pas',
  uIcomNetworkDiscovery in 'src\uIcomNetworkDiscovery.pas',
  uRadioIcomBase in 'src\radioFactory\uRadioIcomBase.pas',
  uRadioIcom9700 in 'src\radioFactory\uRadioIcom9700.pas',
  uRadioIcom7610 in 'src\radioFactory\uRadioIcom7610.pas',
  uRadioIcom7300 in 'src\radioFactory\uRadioIcom7300.pas',
  uRadioIcom705 in 'src\radioFactory\uRadioIcom705.pas',
  uRadioIcom7300MK2 in 'src\radioFactory\uRadioIcom7300MK2.pas',
  uRadioIcom7600 in 'src\radioFactory\uRadioIcom7600.pas',
  uRadioIcom7760 in 'src\radioFactory\uRadioIcom7760.pas',
  uRadioIcom7850 in 'src\radioFactory\uRadioIcom7850.pas',
  uRadioIcom7851 in 'src\radioFactory\uRadioIcom7851.pas',
  uRadioIcom905 in 'src\radioFactory\uRadioIcom905.pas',
  GetWinVersionInfo in 'src\GetWinVersionInfo.pas',
  uSuperCheckPartialFileUpload in 'src\uSuperCheckPartialFileUpload.pas',
  uHamLibDirect in 'src\uHamLibDirect.pas',
  uRadioHamLibDirect in 'src\radioFactory\uRadioHamLibDirect.pas',
  uExternalLoggerBase in 'src\uExternalLoggerBase.pas',
  uExternalLogger in 'src\uExternalLogger.pas',
  uExternalLoggerFactory in 'src\uExternalLoggerFactory.pas',
  // uExternalLoggerManager uses Generics.Collections (Delphi 2009+) - not Delphi 7 IDE compatible
  //uExternalLoggerManager in 'src\uExternalLoggerManager.pas',
  uDXLabPathfinder in 'src\uDXLabPathfinder.pas',
  uYCCCSO2R in 'src\uYCCCSO2R.pas',
  uCWKeyerBase in 'src\uCWKeyerBase.pas',
  uCWKeyerCAT in 'src\uCWKeyerCAT.pas',
  uCWKeyerWinKey in 'src\uCWKeyerWinKey.pas',
  uCWKeyerYCCC in 'src\uCWKeyerYCCC.pas',
  uCWKeyerCPU in 'src\uCWKeyerCPU.pas',
  uRadioFlexAPI in 'src\radioFactory\uRadioFlexAPI.pas',
  uRadioBand in 'src\radioFactory\uRadioBand.pas',
  uBandLookup in 'src\uBandLookup.pas',
  ComPortEnumerator in 'src\ComPortEnumerator.pas',
  uRadioIcom7100 in 'src\radioFactory\uRadioIcom7100.pas',
  uRadioIcom718 in 'src\radioFactory\uRadioIcom718.pas',
  uRadioIcomLegacy in 'src\radioFactory\uRadioIcomLegacy.pas',
  uRadioIcomReadLimited in 'src\radioFactory\uRadioIcomReadLimited.pas',
  uRadioIcomModern in 'src\radioFactory\uRadioIcomModern.pas',
  uRadioHamLibOnly in 'src\radioFactory\uRadioHamLibOnly.pas',
  uCWFraming in 'src\radioFactory\uCWFraming.pas',
  uRadioKYBase in 'src\radioFactory\uRadioKYBase.pas',
  uRadioElecraftBase in 'src\radioFactory\uRadioElecraftBase.pas',
  uRadioKenwoodBase in 'src\radioFactory\uRadioKenwoodBase.pas',
  uRadioIcom78 in 'src\radioFactory\uRadioIcom78.pas',
  uRadioIcom707 in 'src\radioFactory\uRadioIcom707.pas',
  uRadioIcom725 in 'src\radioFactory\uRadioIcom725.pas',
  uRadioIcom726 in 'src\radioFactory\uRadioIcom726.pas',
  uRadioIcom728 in 'src\radioFactory\uRadioIcom728.pas',
  uRadioIcom729 in 'src\radioFactory\uRadioIcom729.pas',
  uRadioIcom735 in 'src\radioFactory\uRadioIcom735.pas',
  uRadioIcom736 in 'src\radioFactory\uRadioIcom736.pas',
  uRadioIcom737 in 'src\radioFactory\uRadioIcom737.pas',
  uRadioIcom738 in 'src\radioFactory\uRadioIcom738.pas',
  uRadioIcom746 in 'src\radioFactory\uRadioIcom746.pas',
  uRadioIcom746PRO in 'src\radioFactory\uRadioIcom746PRO.pas',
  uRadioIcom756 in 'src\radioFactory\uRadioIcom756.pas',
  uRadioIcom756PRO in 'src\radioFactory\uRadioIcom756PRO.pas',
  uRadioIcom756PROII in 'src\radioFactory\uRadioIcom756PROII.pas',
  uRadioIcom756PROIII in 'src\radioFactory\uRadioIcom756PROIII.pas',
  uRadioIcom761 in 'src\radioFactory\uRadioIcom761.pas',
  uRadioIcom765 in 'src\radioFactory\uRadioIcom765.pas',
  uRadioIcom775 in 'src\radioFactory\uRadioIcom775.pas',
  uRadioIcom781 in 'src\radioFactory\uRadioIcom781.pas',
  uRadioIcom910 in 'src\radioFactory\uRadioIcom910.pas',
  uRadioIcom970D in 'src\radioFactory\uRadioIcom970D.pas',
  uRadioIcom7200 in 'src\radioFactory\uRadioIcom7200.pas',
  uRadioIcom7410 in 'src\radioFactory\uRadioIcom7410.pas',
  uRadioIcom9100 in 'src\radioFactory\uRadioIcom9100.pas',
  uRadioTenTecOmni6 in 'src\radioFactory\uRadioTenTecOmni6.pas',
  uRadioTenTecOrion in 'src\radioFactory\uRadioTenTecOrion.pas',
  uRadioIcom7700 in 'src\radioFactory\uRadioIcom7700.pas',
  uRadioIcom7800 in 'src\radioFactory\uRadioIcom7800.pas',
  uRadioRegistry in 'src\radioFactory\uRadioRegistry.pas',
  uRadioKenwoodSerial in 'src\radioFactory\uRadioKenwoodSerial.pas',
  uRadioKenwoodTS570 in 'src\radioFactory\uRadioKenwoodTS570.pas',
  uRadioKenwoodTS140 in 'src\radioFactory\uRadioKenwoodTS140.pas',
  uRadioKenwoodTS440 in 'src\radioFactory\uRadioKenwoodTS440.pas',
  uRadioKenwoodTS450 in 'src\radioFactory\uRadioKenwoodTS450.pas',
  uRadioKenwoodTS480 in 'src\radioFactory\uRadioKenwoodTS480.pas',
  uRadioKenwoodTS590 in 'src\radioFactory\uRadioKenwoodTS590.pas',
  uRadioKenwoodTS690 in 'src\radioFactory\uRadioKenwoodTS690.pas',
  uRadioKenwoodTS850 in 'src\radioFactory\uRadioKenwoodTS850.pas',
  uRadioKenwoodTS870 in 'src\radioFactory\uRadioKenwoodTS870.pas',
  uRadioKenwoodTS940 in 'src\radioFactory\uRadioKenwoodTS940.pas',
  uRadioKenwoodTS950 in 'src\radioFactory\uRadioKenwoodTS950.pas',
  uRadioKenwoodTS2000 in 'src\radioFactory\uRadioKenwoodTS2000.pas',
  uIcomCIV in 'src\uIcomCIV.pas',
  // uRadioManager uses Generics.Collections (Delphi 2009+) - not Delphi 7 IDE compatible
  //uRadioManager in 'src\radioFactory\uRadioManager.pas',
  // uDXSSpotsFilter and uSpotsFilter reference SendViaSocket which is not defined - unfinished code
  //uDXSSpotsFilter in 'src\uDXSSpotsFilter.pas',
  //uSpotsFilter in 'src\uSpotsFilter.pas',
  // uRemMults_DOM/DX/Zone: dead code since initial commit, depends on Country9.pas which was never in the repo
  //uRemMults_DOM in 'src\uRemMults_DOM.pas',
  //uRemMults_DX in 'src\uRemMults_DX.pas',
  //uRemMults_Zone in 'src\uRemMults_Zone.pas',
{$IFNDEF FPC}
  // The OpenGL About box.  OGLVERSION is False (VC.pas), so its only caller
  // -- MainUnit's menu_about arm -- is compiled out and the About menu is a
  // MessageBox; the unit is linked and never entered.  Excluded under FPC
  // rather than ported because Delphi's Winapi.OpenGL and FPC's GL are
  // different bindings and there is nothing behind this to test them with.
  // If OGLVERSION is ever turned on, this needs a real decision.
  uAbout in 'src\uAbout.pas',
{$ENDIF}
  uHardWare in 'src\uHardWare.pas',
  uReminder in 'src\uReminder.pas',
  // uSCP: never referenced anywhere, was never compiled prior to this session - orphaned code
  //uSCP in 'src\uSCP.pas',
  // uMultsFrequencies: never referenced (commented out in MainUnit and uNet) - orphaned code
  //uMultsFrequencies in 'src\uMultsFrequencies.pas',
  uMakeHelpFile in 'src\uMakeHelpFile.pas',
  uLogConfig in 'src\uLogConfig.pas',
  uTrayBalloon in 'src\uTrayBalloon.pas',
  uPOTAParks in 'src\uPOTAParks.pas',
  uPendingCounties in 'src\uPendingCounties.pas',
  uCTYUpdate in 'src\uCTYUpdate.pas',
  uTRMasterUpdate in 'src\uTRMasterUpdate.pas',
  uCabrilloHeader in 'src\uCabrilloHeader.pas',
  // D12: transitively-compiled units added so project-wide file searches see them
  // (they were pulled in via other units' uses clauses but never listed here).
  uADIF in 'src\uADIF.pas',
  uCabrillo in 'src\uCabrillo.pas',
  uCallCompress in 'src\uCallCompress.pas',
  uFlexRadioUtils in 'src\radioFactory\uFlexRadioUtils.pas',
  uGridDistance in 'src\uGridDistance.pas',
  uK4Discovery in 'src\uK4Discovery.pas',
  uFlexDiscovery in 'src\radioFactory\uFlexDiscovery.pas',
  uStrSearch in 'src\uStrSearch.pas',
  NetworkMessageUtils in 'src\utils\NetworkMessageUtils.pas';
  //cty in 'src\cty.pas';  // Excluded: unit name 'cty' conflicts with global variable 'CTY' from uCTYDAT

{ LANG_<xxx>, not the LANG string constant -- see the note in src\tr4w.inc.
  LANG_ENG is derived by that include, which is pulled in at the top of this file. }
{$IFDEF LANG_ENG}{$R res\tr4w_eng.res}{$ENDIF}
{$IFDEF LANG_RUS}{$R res\tr4w_rus.res}{$ENDIF}
{$IFDEF LANG_SER}{$R res\tr4w_ser.res}{$ENDIF}
{$IFDEF LANG_ESP}{$R res\tr4w_esp.res}{$ENDIF}
{$IFDEF LANG_MNG}{$R res\tr4w_mng.res}{$ENDIF}
{$IFDEF LANG_POL}{$R res\tr4w_pol.res}{$ENDIF}
{$IFDEF LANG_CZE}{$R res\tr4w_cze.res}{$ENDIF}
{$IFDEF LANG_ROM}{$R res\tr4w_rom.res}{$ENDIF}
{$IFDEF LANG_CHN}{$R res\tr4w_chn.res}{$ENDIF}
{$IFDEF LANG_GER}{$R res\tr4w_ger.res}{$ENDIF}
{$IFDEF LANG_UKR}{$R res\tr4w_ukr.res}{$ENDIF}

{$R 'Win11.res'}

// Column-double-click padding (Issue #750 follow-up).
//
// Windows' default ListView/Header response to a double-click on a
// column divider is to auto-fit the column to its widest content.
// The auto-fit chooses the header-divider position, which is a few
// pixels narrower than the cell-content area because the ListView's
// cell layout adds an internal left/right margin.  At the just-fits
// threshold the saved value triggers ellipsis on the very content
// that fit visually pre-save.
//
// Fix: intercept HDN_DIVIDERDBLCLICK directly -- run the auto-fit
// ourselves with LVSCW_AUTOSIZE_USEHEADER, add COLUMN_DOUBLECLICK_PAD_PX
// for breathing room, apply that width, and save.  We must do all
// the work inside HDN_DIVIDERDBLCLICK and suppress the default OS
// behaviour: HDN_ENDTRACK only fires for end-of-drag, not for
// double-click auto-fit, so a "set a flag in HDN_DIVIDERDBLCLICK
// and add padding in HDN_ENDTRACK" approach silently drops the
// save on double-click.  Manual drag is handled in HDN_ENDTRACK
// without padding -- the dragged width is the operator's explicit
// choice.
const
  COLUMN_DOUBLECLICK_PAD_PX = 12;

function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

label
  GoToExit, CallDefWindowProc;
var
  HDNotifyPtr: PHDNotify;
  lplvcd: PNMLVCustomDraw;
  hdrColIdx: Integer;
  hdrNewWidth: Integer;
begin

  case Msg of

//    WM_POWERBROADCAST: ShowMessage(PChar('WM_POWERBROADCAST' + IntToStr(wParam)));

    WM_DISPLAYCHANGE:
      begin
        if wParam <= 8 then tEightBitsPerPixel := True else tEightBitsPerPixel := False;
        // Issue #1060: a monitor was added/removed or resolution changed -- pull
        // any now-off-screen TR4W window back onto an active monitor.
        RevalidateOpenWindowsOnScreen;
      end;

    // Issue #912: headless server-log auto-sync.  RunSyncThread (worker)
    // SendMessages here once the download is complete; we close the temp
    // file handle and call ReplaceLogByServerLog on the UI thread so
    // LoadinLog's ListView access is safe.
    WM_USER_HEADLESS_SYNC_REPLACE:
      begin
        if NewServerLogHandle <> INVALID_HANDLE_VALUE then
          begin
          CloseHandle(NewServerLogHandle);
          NewServerLogHandle := INVALID_HANDLE_VALUE;
          end;
        ReplaceLogByServerLog(True);
        logger.Info('Auto-sync: local log replaced with server log.');
        HeadlessSyncMode := False;
      end;

//    WM_MOUSEWHEEL: SetStackPointerOnMouseWheel(SHORT(HiWord(Cardinal(wParam))));
    WM_TRAYBALLON:
      begin

      end;
    WM_TIMECHANGE:
      begin
        GetSystemTime(UTC);
        SystemTimeChanging;
      end;

    //    WM_CONTEXTMENU: if HWND(wParam) = _NewELogWindow then ShowLogPopupMenu(tr4whandle);

{$IF MMTTYMODE}
    WM_SIZE:
      begin
        if MMTTY.MMTTYEngine <> 0 then
        begin
          if wParam = SIZE_MINIMIZED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_SHOWMINNOACTIVE);
          if wParam = SIZE_RESTORED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_RESTORE);
        end;
      end;
{$IFEND}

    WM_WINDOWPOSCHANGING: WINDOWPOSCHANGINGPROC(PWindowPos(lParam));
    WM_NOTIFY:
      begin

        with PNMHdr(lParam)^ do

          if (hWndFrom = wh[mweEditableLog]) then
            case code of

              NM_DBLCLK: EditableLogWindowDblClick;

              // Issue #750: gray out the editable-log row for X-QSO
              // records.  The X-QSO flag is stashed in the row's
              // per-item lParam by tAddContestExchangeToLog ->
              // SetRowXQSOFlag.  We must return CDRF_NOTIFYITEMDRAW
              // at the table-level prepaint to be called back per
              // item; then at item prepaint, replace the text colour
              // with mid-gray ($808080) when the item's lParam is 1.
              // CDRF_NEWFONT tells the listview to apply the new
              // colour.  Exit; bypasses the trailing DefWindowProc
              // call so our Result is what gets returned to the
              // listview's parent-wndproc dispatch.
              NM_CUSTOMDRAW:
                begin
                  lplvcd := PNMLVCustomDraw(lParam);
                  case lplvcd.nmcd.dwDrawStage of
                     CDDS_PREPAINT:
                        begin
                        Result := CDRF_NOTIFYITEMDRAW;
                        Exit;
                        end;
                     CDDS_ITEMPREPAINT:
                        begin
                        if lplvcd.nmcd.lItemlParam = 1 then
                           lplvcd.clrText := $00808080; // mid-gray
                        Result := CDRF_NEWFONT;
                        Exit;
                        end;
                  end;
                end;

              NM_SETFOCUS:
                begin
                  ActiveMainWindow := awEditableLog;
                end;
              NM_KILLFOCUS:
                begin
                end;
            end
          else if (hWndFrom = ListView_GetHeader(wh[mweEditableLog])) then
            begin
            // HDN_DIVIDERDBLCLICK: operator double-clicked the divider
            // to auto-fit.  Do EVERYTHING here (auto-fit, padding,
            // save) instead of deferring to a follow-up HDN_ENDTRACK:
            // per Win32, HDN_ENDTRACK only fires for end-of-drag.  The
            // OS's internal auto-fit during double-click does not
            // generate one, so a flag-based "wait for HDN_ENDTRACK"
            // approach silently drops the save.
            //
            // We run the auto-fit ourselves with LVSCW_AUTOSIZE_USEHEADER,
            // add COLUMN_DOUBLECLICK_PAD_PX for breathing room, apply
            // that to the column, and save.  Returning a non-zero
            // Result suppresses the default header auto-fit; Exit
            // bypasses DefWindowProc which would otherwise overwrite
            // Result with its own return value.
            if (code = HDN_DIVIDERDBLCLICKA) or (code = HDN_DIVIDERDBLCLICKW) then
               begin
               HDNotifyPtr := PHDNotify(lParam);
               hdrColIdx := HDNotifyPtr^.Item;
               ListView_SetColumnWidth(wh[mweEditableLog], hdrColIdx,
                                       LVSCW_AUTOSIZE_USEHEADER);
               hdrNewWidth := ListView_GetColumnWidth(wh[mweEditableLog],
                                                     hdrColIdx)
                              + COLUMN_DOUBLECLICK_PAD_PX;
               ListView_SetColumnWidth(wh[mweEditableLog], hdrColIdx,
                                       hdrNewWidth);
               SaveColumnWidthToConfig(hdrColIdx, hdrNewWidth);
               Result := 1; // suppress default header auto-fit
               Exit;
               end
            else if (code = HDN_ENDTRACK) or (code = HDN_ENDTRACKW) then
               begin
               // Normal end-of-drag: save the dragged width exactly
               // as the operator left it.  No padding here -- the
               // operator explicitly chose this width.
               HDNotifyPtr := PHDNotify(lParam);
               if (HDNotifyPtr^.pItem <> nil) and
                  ((HDNotifyPtr^.pItem^.mask and HDI_WIDTH) <> 0) then
                  SaveColumnWidthToConfig(HDNotifyPtr^.Item,
                                          HDNotifyPtr^.pItem^.cxy)
               else
                  // pItem unavailable — fall back to querying the ListView directly
                  SaveColumnWidthToConfig(HDNotifyPtr^.Item,
                     ListView_GetColumnWidth(wh[mweEditableLog],
                                             HDNotifyPtr^.Item));
               end;
            end;
      end;
    WM_MEASUREITEM: if wParam = MainWindowPCLID then
        PMeasureItemStruct(lParam).itemHeight := ws;
       
    WM_DRAWITEM:
      begin
        if wParam = MainWindowPCLID then
          PossibleCallsProc(PDrawItemStruct(lParam));
      end;


    WM_LBUTTONDOWN: DragWindow(TRHWND);

    WM_SETFOCUS:
      begin
        if ActiveMainWindow = awExchangeWindow then
          tExchangeWindowSetFocus
        else
          tCallWindowSetFocus;
        ShowFMessages(0);
      end;

    WM_POTA_DOWNLOAD_DONE:
      begin
      // Fired by the async download thread (see uPOTAParks).
      // wParam=1: file saved OK; wParam=0: download failed.
      if wParam = 1 then
         begin
         if LoadPOTAParks(POTAParksFilePath) > 0 then
            QuickDisplay(PAnsiChar('POTA parks loaded'))
         else
            QuickDisplay(PAnsiChar('POTA parks file could not be loaded'));
         end
      else
         QuickDisplay(PAnsiChar('POTA parks download failed'));
      end;

    WM_TRMASTER_DOWNLOAD_DONE:
      begin
      // Fired by the async download thread (see uTRMasterUpdate).
      // wParam=1: file saved OK; wParam=0: download failed.
      //
      // WHY THIS DOES NOT RELOAD SCP, unlike the CTY handler above.
      // ctyLoadInCountryFile is a clean, idempotent reload entry point.
      // TRMASTER has no equivalent: LOGSCP loads it LAZILY into a heap index
      // array behind three flags (TRMasterFileOpen, IndexArrayAllocated,
      // MasterFileExists) plus a cached OperatorNameSet built once, and the
      // only close routine, SCPDisableAndDeAllocateFileBuffer, also sets
      // SCPDisabledByApplication -- it disables SCP rather than reloading it.
      //
      // A partial reload that left OperatorNameSet stale, or SCP disabled,
      // would be wrong data during a contest and would look like nothing at
      // all. Telling the operator to restart is honest and costs one restart;
      // guessing at TRDOS load state is not worth a wrong callsign hint.
      // A proper CD.ReloadTRMaster belongs with the SQLite log work, not here.
      if wParam = 1 then
         begin
         QuickDisplay(PAnsiChar('TRMASTER.DTA downloaded -- restart TR4W to use it'));
         end
      else
         begin
         QuickDisplay(PAnsiChar('TRMASTER.DTA download failed'));
         end;
      end;

    WM_POTA_LOAD_DONE:
      begin
      // Fired by TPOTALoadThread after parsing the CSV off the UI thread.
      // lParam is the parsed TStringList — ApplyLoadedParks takes ownership.
      ApplyLoadedParks(lParam);
      end;

    WM_TCI_APPLY:
      begin
      // Posted by a TCI connection thread (see uTCIServer). lParam is the apply
      // command; TCIRunQueuedApply runs it here on the main thread and frees it.
      //
      // A posted message rather than TThread.Queue because a queueing thread
      // that exits purges its own callback, and rather than Synchronize because
      // that would block an Indy connection thread against TTCIServer.Stop.
      TCIRunQueuedApply(lParam);
      end;

    WM_CTY_VERSION_CHECKED:
      begin
      if wParam = 1 then
         begin
         // Silent startup notice — no MessageBox, no blocking
         Format(wsprintfBuffer,
            'Newer CTY.DAT available (dated %d). Press Alt-O to download.',
            lParam);
         QuickDisplay(wsprintfBuffer);
         end;
      end;

    WM_CTY_DOWNLOAD_DONE:
      begin
      if wParam = 1 then
         begin
         QuickDisplay(PAnsiChar('CTY.DAT downloaded. Reloading...'));
         // Reload on main thread — CTY tables have no locking, so background
         // reload would race with callsign lookups. Message handler is a safe
         // quiescent point.
         ctyLoadInCountryFile(TR4W_CTY_FILENAME, False, True);
         QuickDisplay(PAnsiChar('CTY.DAT reloaded successfully.'));
         end
      else
         QuickDisplay(PAnsiChar('CTY.DAT download failed.'));
      end;

    WM_CTLCOLORLISTBOX, WM_CTLCOLOREDIT, WM_CTLCOLORSTATIC:
      begin
        Result := DrawWindows(lParam, wParam);
        if Result <> 0 then Exit;
      end;

    WM_CLOSE:
      begin
        GoToExit:
        ExitProgram(True);
        Msg := 0;
      end;

    WM_COMMAND:
      begin
        case wParam of
          66:
            begin
              EditableLogWindowDblClick;
            end;
        end;
{$IF tDebugMode}
        if HiWord(wParam) = BN_CLICKED then
        begin
          if lParam = integer(CPUButtonHandle) then CPUButtonProc;
          FrmSetFocus;
        end;
{$IFEND}

        if (LoWord(wParam) >= 10000) and (LoWord(wParam) <= 10700) then
           ProcessMenu(wParam);
        if (LoWord(wParam) >= 10700) and (LoWord(wParam) <= 10750) then
            RunPlugin(LoWord(wParam));

        if lParam = integer(wh[mweCall]) then
        begin
          if HiWord(wParam) = EN_KILLFOCUS then
          begin
            if tr4w_CustomCaret then DestroyCaret;
            CheckQuestionMark;
          end;
          if HiWord(wParam) = EN_UPDATE {EN_CHANGE} then CallWindowChange;

          if HiWord(wParam) = EN_SETFOCUS then
          begin
            ActiveMainWindow := awCallWindow;
            ChangeCaret(wh[mweCall]);
{$IF MORSERUNNER}
//            Windows.SendMessage(MorseRunner_Callsign, WM_SETFOCUS, 0, 0);
{$IFEND}
          end;
        end;

        if lParam = integer(wh[mweExchange]) then
        begin
          if HiWord(wParam) = EN_KILLFOCUS then
          begin
            if tr4w_CustomCaret then DestroyCaret;
          end;
          if HiWord(wParam) = EN_CHANGE then ExchangeWindowChange;
          if HiWord(wParam) = EN_SETFOCUS then
          begin
            ActiveMainWindow := awExchangeWindow;
            ChangeCaret(wh[mweExchange]);
{$IF MORSERUNNER}
//            Windows.SendMessage(MorseRunner_nUMBER, WM_SETFOCUS, 0, 0);
{$IFEND}
          end;
        end;

      end;

  end; {of case}

{$IF MMTTYMODE}
  if Msg = MMTTY.mmttyMSG then mmttyProcessMessage(wParam, lParam);
{$IFEND}

  CallDefWindowProc:
  Result := longword(DefWindowProc(TRHWND, Msg, wParam, lParam));
end;

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

  if not DownloadCTYFile(ctyPath) then
     begin
     // uCTYUpdate has already logged the underlying exception.
     showwarning('Could not download CTY.DAT to:' + #13#10#13#10 +
                 ctyPath + #13#10#13#10 +
                 'Check the network connection, and that the folder above is ' +
                 'writable, then start TR4W again.' + #13#10 +
                 'tr4w.log records the reason.');
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

label
  NoTransMess, TransMess, CommandLine;
var
  TempHDC                               : HDC;
  TempColor                             : tr4wColors;
  TempTLogBrush                         : TLogBrush {= (lbStyle: BS_SOLID; lbHatch: 0)};
  c                                     : Cardinal;
  TempString                            : ShortString;
  // The radio library's complaint, if it has one -- see the call site.
  tRadioLibraryError                    : string;
  // Surviving a fault in the message loop -- see the loop itself.
  tLoopFailures                         : integer;
  // Int64, NOT QWord: networkmessageutils declares a QWord of its own and
  // the unqualified name resolves to that one here.
  tLastLoopFailure                      : Int64;
   //  P                                   : Pchar; //n4af
   //   P1                                   : boolean; //n4af
   // S1                                   : String; //n4af
{$IF not tDebugMode}
  s                                     : string;
{$IFEND}
 // logBuffer                             : string;
  tempStickyKey                         : STICKYKEYS;
 // tc                                    : tcolor;
  sDebugLevel                           : string;
  i                                     : tLogLevels;
  //rgb                                   : cardinal;
  iniFile                               : TINIFile;                    // Used to simply find the DEBUG setting so we can set it when the logger object is created.
                                                                       // This way we can log before we read the DEBUG LOG LEVEL the legacy method in uCFG. // ny4i
begin
   // Enable thread-safe memory management. TR4W creates threads via Win32
   // CreateThread (not TThread), which does NOT set this flag automatically.
   // Without it, concurrent GetMem calls from different threads can corrupt
   // the heap, causing random AVs at startup when radio polling threads and
   // the main thread initialize simultaneously.
   IsMultiThread := True;

   // FMX platform services, set up but NEVER RUN.  Application.Initialize
   // registers the platform services an FMX form needs to create its window;
   // it does not start a message loop and does not create a main form.  The
   // loop below stays TR4W's own -- Application.Run is never called, and there
   // is deliberately no Application.CreateForm anywhere.
   //
   // Both calls go with the FMX units under FPC -- see the uses clause.  They
   // only REGISTER services for forms that build cannot create.
{$IFNDEF FPC}
   FMX.Forms.Application.Initialize;

   // ...and then tell FMX the application is running, because Application.Run
   // is what normally says so and we never call it.  Without this every FMX
   // form stays Active=False and its edits never show a caret.  See
   // uFMXCoexist.TellFMXTheApplicationIsRunning for the full chain.
   TellFMXTheApplicationIsRunning;
{$ELSE}
   // The LCL equivalent, and it is genuinely smaller: Application.Initialize
   // creates the widgetset, and that is all this needs. There is no
   // ApplicationState to lie about, because the LCL does not gate a form's
   // Active flag on one the way FMX does.
   //
   // Application.Run is NOT called here and must never be -- TR4W owns the
   // message loop below. See uLCLCoexist.
   InitLCLForHostedLoop;
{$ENDIF}

   // Check for another running instance BEFORE opening any shared files
   // (log file, etc.) to avoid an EFOpenError crash on the second instance.
   tMutex := CreateMutex(nil, False, tr4w_ClassName);
   if tMutex = 0 then
      begin
      Exit;
      end;
   if GetLastError = ERROR_ALREADY_EXISTS then
      begin
      MessageBoxW(0, Pchar(TC_RUNWARN), tr4w_ClassName, MB_OK or MB_ICONWARNING or MB_SYSTEMMODAL or MB_TOPMOST);
      Exit;
      end;

   TR4W_PATH_NAME[Windows.GetCurrentDirectoryA(SizeOf(TR4W_PATH_NAME), @TR4W_PATH_NAME)] := '\';
   Format(TR4W_INI_FILENAME, '%ssettings\tr4w.ini', TR4W_PATH_NAME);
   iniFile := TINIFile.create(TR4W_INI_FILENAME);
   try
   appender := TLogRollingFileAppender.Create('name','tr4w.log');
   appender.Layout := CreateTR4WLogLayout;
   TLogBasicConfigurator.Configure(appender);
   logger := TLogLogger.GetLogger('TR4WDebugLog');

   // IMMEDIATELY AFTER THE LOGGER EXISTS, and before anything that could
   // fault. Until now an unhandled exception left tr4w.log ending in the
   // ordinary unit finalizations -- indistinguishable from a clean exit --
   // so a crash report could only say that the program had closed.
   InstallCrashLog;

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
   tSilentExport := SameText(ParamStr(2), '/EXPORT');
   // Default TRACE (was ERROR) when the key is absent from tr4w.ini.  Radio-driver
   // bring-up is diagnosed almost entirely from the TX/RX frame trace, and asking a
   // volunteer tester to hand-edit tr4w.ini before their first run is a poor trade
   // for log volume.  Only affects a MISSING key: anyone who has set a level keeps it.
   sDebugLevel := iniFile.ReadString('COMMANDS','DEBUG LOG LEVEL', 'TRACE');
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

 Format(TR4W_INI_FILENAME, '%ssettings\tr4w.ini', TR4W_PATH_NAME);
  LuconSZLoadded := AddFontResourceW(TR4W_LC_FILENAME) <> 0;
  MainFixedFont := tCreateFont(15, FW_BOLD * Ord(BoldFont), @MainFontName[1]);
  MSSansSerifFont := tCreateFont(15, FW_DONTCARE, 'MS Sans Serif');
  CreateDirectoryIfNotExist;

{$IF tDebugMode}
  //uHistory.MakeRevisionHistory;
  TR4W_CFG_FILENAME := 'c:\TR4W\debug.cfg';
{$ELSE}

  s := ParamStr(1);
  if s <> '' then
  begin
    // D12: ParamStr returns a wide UnicodeString.  The old
    // CopyMemory(@buf, @s[1], length(s)) copied WIDE bytes into the ANSI
    // FileNameType buffer using a CHARACTER count -> "C",#0,":",#0,... ->
    // the cfg path was truncated to "C", config never loaded, and startup
    // died with "No callsign specified".  Copy the ANSI form instead.
    Windows.lstrcpyA(TR4W_CFG_FILENAME, PAnsiChar(AnsiString(s)));
    goto CommandLine;
  end;

  begin
    CreateModalDialog(305, 235, tr4whandle, @NewContestDlgProc, 0);
    if TR4W_CFG_FILENAME[0] = '_' then Exit;
  end;
{$IFEND}

  CommandLine:



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

  // The radio library (settings	r4w.json) is the FORMAT OF RECORD for radio
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
   ShowMessage('AUTOSPOT is enabled - Test Mode Only'); // Hard on relays - be careful
{$ENDIF}
  tr4w_accelerators := LoadAccelerators(hInstance, 'T');
  // Ctrl+T → menu_repeat_pota_parks is defined directly in the .res file.

  RegisterClass(tr4w_WinClass);

  CursorBitmap := LoadImage(hInstance, 'cursor.bmp', IMAGE_BITMAP, ws2 * 3, ws + 2, LR_LOADFROMFILE);

  SetUpExchangeInformation(ActiveExchange, ExchangeInformation);
  SetColumnsWidth;
  CreateMainWindow;
  CreateMultsWindows;
  CreateQSONeedWindows;

  Windows.ShowWindow(wh[mweWSJTX], SW_HIDE);
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
  if (not tSilentExport) and (Trim(string(MyGrid)) = '') then
     begin
     logger.Info('MY GRID is empty; offering to set it');
     SetCommand('MY GRID');
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
     SetTimer(tr4whandle, BANDMAP_REFRESH_TIMER_HANDLE, 250, @BandMapRefreshTimerProc);
     for c := menu_alt_increment_time_1 to menu_alt_increment_time_0 do EnableMenuItem(tr4w_main_menu, c, MF_GRAYED + MF_BYCOMMAND);
     end
  else
     begin
     showwarning('HAND LOG MODE = TRUE');
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
    QuickDisplay(SysUtils.Format('TRMASTER.DTA : %s', [SysUtils.SysErrorMessage(GetLastError)]));
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

  { AN EXCEPTION IN THE MESSAGE LOOP NO LONGER ENDS THE PROGRAM.

    NY4I, after the third Ctrl-P crash: "I am not a fan of the abrupt
    termination." Nor is anything else about it defensible. TR4W is a CONTEST
    LOGGER: a fault while drawing a caption used to take the whole session down,
    mid-contest, with the log open -- when the fault itself had nothing to do
    with logging QSOs. Windows applications survive a bad window procedure; this
    one did not, because nothing here caught anything.

    The loop body is untouched. It is re-entered after a fault, which keeps the
    two gotos (TransMess / NoTransMess) inside a single block and avoids
    restructuring the most heavily-edited code in the program.

    A LIMIT, so a persistent fault cannot become a silent spin: ten failures
    inside a minute and it gives up and re-raises, which is the old behaviour.
    The count resets after a quiet minute, so occasional unrelated faults over a
    long contest do not accumulate into a shutdown. }
  tLoopFailures := 0;
  tLastLoopFailure := 0;
  repeat
  try
  while (GetMessage(Msg, 0, 0, 0)) do
  begin

    // FIRST question, before accelerators and before every case arm below.
    // A message for an FMX window gets a plain Translate + Dispatch and
    // nothing else: this loop routes WM_CHAR into the callsign window and
    // treats F-keys and the numeric keypad as CW memories, all of which would
    // steal keystrokes from a text box in another window.  One test closes
    // every such leak at once.  See uFMXCoexist.
    // No FMX under FPC -- the units are excluded from the project, so there is
    // no FMX window for a message to belong to.  See tr4w.dpr's uses clause.
{$IFNDEF FPC}
    if MessageIsForFMXWindow(Msg) then
       begin
       goto TransMess;
       end;
{$ELSE}
    // Same question, asked of the LCL forms: does this message belong to a
    // hosted window rather than to TR4W's own? The registry behind it
    // (uHostedFormWindows) is shared and toolkit-blind on purpose -- both
    // toolkits register a plain HWND and neither one is named here.
    if MessageIsForHostedWindow(Msg) then
       begin
       goto TransMess;
       end;
{$ENDIF}

    // Issue #23 -- when a clipboard/edit key (Ctrl-C/V/X/A/Z) is pressed with
    // the DX Cluster command field focused, skip the main accelerator table so
    // the keystroke reaches the field (e.g. Ctrl-V pastes) instead of firing
    // Execute Config File / Clear Mult Sheet.
    if (not TelnetWantsClipboardKey(Msg)) and
       (TranslateAccelerator(tr4whandle, tr4w_accelerators, Msg) <> 0) then
    begin
      // (an `asm nop end;` breakpoint placeholder stood here)
      goto NoTransMess;
    end;
    case Msg.Message of

      WM_CHAR:
        begin
          if (Char(Msg.wParam) = QuickQSLKey1) or (Char(Msg.wParam) = QuickQSLKey2) then QuickQSLProcedure(Char(Msg.wParam));
          if (Msg.HWND = wh[mweCall]) or (Msg.HWND = wh[mweExchange]) then
          begin
            if (Msg.HWND = wh[mweCall]) then
               begin
               CallWindowKeyDownProc(Msg.wParam);
               if CallWindowCharConsumed then
                  begin
                  CallWindowCharConsumed := False;
                  goto NoTransMess;
                  end;
               end
            else if Msg.HWND = wh[mweExchange] then       // ny4i Issue 87
               begin
               ExchangeWindowKeyDownProc(Msg.wParam);     // 4.102.7
               end;
              if KeyboardCallsignChar(Msg.wParam, boolean(ActiveMainWindow) {tr4w_ExchangeWindowActive}) = False then
               begin
               goto NoTransMess;
               end;
          end;
        end;

      WM_SYSKEYDOWN, WM_KEYDOWN:
        begin

          if Config.KeypadCWMemories then
            if Msg.wParam in [VK_NUMPAD0..VK_NUMPAD9] then
            begin
              if Msg.wParam <> VK_NUMPAD0 then
                ProcessFuntionKeys(Msg.wParam + 27)
              else
                ProcessFuntionKeys(Msg.wParam + 37);
              goto NoTransMess;
            end;

          if (Msg.HWND = wh[mweEditableLog]) and (Msg.wParam = VK_DOWN) then
            if ListView_GetNextItem(wh[mweEditableLog], LVNI_ALL, LVNI_SELECTED) = tLogIndex - 1 then
              tCallWindowSetFocus;

          if (Msg.HWND = wh[mweCall]) or (Msg.HWND = wh[mweExchange]) then
          begin
            // Ctrl+= : repeat the exact characters last sent on CW (call +
            // exchange windows, CW mode).  '=' alone is QUICK QSL KEY 2, so a
            // bare key collides; a Ctrl combo avoids that and is dispatched
            // here like the other WM_KEYDOWN shortcuts, then fully consumed.
            if (Msg.wParam = 187 {VK_OEM_PLUS '='}) and (ActiveMode = CW) and
               ((GetKeyState(VK_CONTROL) and $8000) <> 0) then
            begin
              RepeatLastCWMessage;
              goto NoTransMess;
            end;
            if Msg.wParam in [VK_F1..vk_f12] then ProcessFuntionKeys(Msg.wParam);
            if Msg.wParam = VK_F4 then goto NoTransMess;
            if Msg.wParam > 40 then goto TransMess;
            if Msg.wParam = VK_RIGHT {39} then if Msg.HWND = wh[mweExchange] then TryPutSpaceinExchangeWindow;
            if Msg.wParam = VK_PRIOR {33} then ProcessMenu(menu_cwspeedup);
            if Msg.wParam = VK_NEXT {34} then ProcessMenu(menu_cwspeeddown);
            if Msg.wParam = VK_SPACE {32} then if Msg.HWND = wh[mweCall] then
              begin
                SpaceBarProc2;
//                if ActiveRadioPtr^.CWByCAT then BackToInactiveRadioAfterQSO;
                goto NoTransMess;
              end;

            if (Msg.wParam = VK_UP)                                      and
               (ActiveMainWindow = awCallWindow {tr4w_CallWindowActive}) and
               (CallWindowString = '')                                   then
                begin
                if tLogIndex <> 0 then
                   begin
                   tAltE;
                   end;
                end;

            if (Msg.wParam = VK_UP {38}) or (Msg.wParam = VK_DOWN {40}) then
            begin
              ProcessTAB(0);
              Msg.wParam := 0;
            end;
            if {18} Msg.wParam = VK_MENU then ShowFMessages(24);
            if {17} Msg.wParam = VK_CONTROL then

              ShowFMessages(12);


  if Msg.wParam = VK_SHIFT  then
            begin
              if ShiftKeyEnable then    // 4.105.6
                {*in S&P the shift key tunes the K3 VFO with the RIT or XIT on, but RIT/XIT do not change
                  ?In RUN mode the shift key should tune the RIT and not the xmit VFO...  but the VFO DISPLAY must change to show the RX frequency
                *}
              begin
                if lobyte(HiWord(Msg.lParam)) = 42 then
                if OpMode = CQOpMode then      // 4.97.3
                {RITBumpDown;} RITBumpDown
                  else        // 4.105.6
                   VFOBumpDown;
                if lobyte(HiWord(Msg.lParam)) = 54 then
                 if OpMode = CQOpMode then       // 4.97.3
                 {RITBumpUp;} RITBumpUp
                  else
                   VFOBumpUP;
                end;
              end;
            end;
          end;

      WM_KEYUP:
        begin
      {    if (Msg.wParam = VK_SPACE) and (Msg.HWND = wh[mweCall]) then           //   4.102.4
          tailend;       }
          if (Msg.wParam = VK_CONTROL) or (Msg.wParam = VK_MENU) then ShowFMessages(0);
          if Msg.wParam < 40 then goto TransMess;

          if Msg.HWND = wh[mweCall] then
          begin

            if Msg.wParam = 222 then
            begin
              if StartSendingNowKey = '''' then
                StartSendingNow(True);
              goto NoTransMess;
            end;

                //                CallWindowKeyDownProc(Msg.wParam);

          end;

          if Msg.HWND = BandMapListBox then
          begin
            if Msg.wParam = VK_DELETE then DeleteSpotFromBandmap;
{ $ I F  O L DCTRLJ}
            if Msg.wParam in [66, 77, 68, 80, 206] then
            begin
              if Msg.wParam = 66 then InvertBoolean(BandMapAllBands);
              DisplayBandMap; //ProcessInput(BAB);
             if Msg.wParam = 77 then InvertBoolean(BandMapAllModes) ;
              DisplayBandMap; //ProcessInput(BAM);
              if Msg.wParam = 68 then InvertBoolean(BandMapDupeDisplay);
              DisplayBandMap; //ProcessInput(BDD);
              if Msg.wParam = 206 then InvertBoolean(BandMapSO2RDisplay);
              DisplayBandMap; //ProcessInput(BDD);
            end;
{ $ I F END}
          end;
        end;

      WM_SYSKEYUP:
        begin
          if (Msg.wParam = VK_MENU) then
          begin
            ShowFMessages(0);
            //if Cardinal(Msg.lParam) and 16777216 = 0 then goto NoTransMess;
          end;
          if Msg.wParam = VK_F10 then goto NoTransMess;
        end;

      WM_MOUSEMOVE:
        begin
//          SendMessage(hwndTT, TTM_RELAYEVENT, 0, integer(@Msg));
        end;

      WM_RBUTTONDBLCLK:
        begin
          GetButtonByRDblClick(Msg.HWND);
        end;

      WM_RBUTTONDOWN:
        begin
          // Issue #1001: right-click a function-key button -> context menu to
          // edit that key's message (CQ vs S&P aware). No-op elsewhere.
          ShowFunctionKeyContextMenu(Msg.HWND);
        end;
{
      WM_RBUTTONDOWN:
        begin
          if Msg.HWND = wh[mweBandMode] then ProcessMenu(75857);
          if Msg.HWND = CodeSpeedWindowHandle then ProcessMenu(76039);
        end;

      WM_LBUTTONDOWN:
        begin
          if Msg.HWND = wh[mweBandMode] then ProcessMenu(75858);
          if Msg.HWND = CodeSpeedWindowHandle then ProcessMenu(76040);
        end;

      WM_MBUTTONDOWN:
        if Msg.HWND = wh[mweBandMode] then ProcessMenu(75859);

      WM_LBUTTONDBLCLK:
        begin
          if (Msg.HWND = wh[mweClock]) or (Msg.HWND = wh[mweDate]) then ProcessMenu(75851);
          if (Msg.HWND = PaddleWindowHandle) or (Msg.HWND = FootSwWindowHandle) then ProcessMenu(menu_lpt);

//          Windows.GetWindowText(Msg.HWND, @wsprintfBuffer, 100);
//          GetTextFace(windows.GetDC (Msg.HWND), 100, @wsprintfBuffer);
//          ShowMessage(wsprintfBuffer);

        end;
}
    end; //of case
    TransMess:
      //      inc(Tw);
    TranslateMessage(Msg);
    DispatchMessage(Msg);
    NoTransMess:
//  except sm end;
  end;
    // GetMessage returned False: WM_QUIT, the ordinary way out.
    Break;
  except
    on E: Exception do
       begin
       if (Int64(GetTickCount64) - tLastLoopFailure) > 60000 then
          begin
          tLoopFailures := 0;
          end;
       tLastLoopFailure := Int64(GetTickCount64);
       Inc(tLoopFailures);

       // THE BACKTRACE FIRST. ExceptProc only fires for exceptions nobody
       // handles, so catching the fault here removed the [CRASH] record that
       // said WHERE -- the first recovered run logged 'recovered from
       // EAccessViolation' and nothing else. Surviving a fault must not cost
       // the ability to find it.
       LogCaughtException('MessageLoop', E);
       logger.Error('[MessageLoop] recovered from %s -- %s (failure %d). '
                    + 'TR4W is still running; the [CRASH] lines above say where.',
                    [E.ClassName, E.Message, tLoopFailures]);

       if tLoopFailures >= 10 then
          begin
          logger.Fatal('[MessageLoop] 10 faults inside a minute -- giving up '
                       + 'rather than spinning.');
          raise;
          end;
       end;
  end;
  until False;
  finally
     // Issue #783 -- stop the HamScore RTC uploader cleanly so the worker
     // thread isn't holding sockets when the process exits.
     HamScoreShutdown;
     if Assigned(iniFile) then
        begin
        iniFile.Free;
        //Pointer(TINIFile(iniFile)) := nil;
        end;
  end; // of Try...finally

end.
