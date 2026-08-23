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
  uRadio12 in 'src\uRadio12.pas',
  uFunctionKeys in 'src\uFunctionKeys.pas',
  uinet in 'src\uinet.pas',
  uDXClusterClient in 'src\uDXClusterClient.pas',
  uDXSpotParse in 'src\uDXSpotParse.pas',
  uTelnet in 'src\uTelnet.pas',
  uBandmap in 'src\uBandmap.pas',
  uBandMapView in 'src\uBandMapView.pas',
  uBandMapForm in 'src\ui\lcl\uBandMapForm.pas',
  uAppInputHooks in 'src\ui\lcl\uAppInputHooks.pas',
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
  uWindowLayoutStore in 'src\uWindowLayoutStore.pas',
  uTR4WConfigFile in 'src\uTR4WConfigFile.pas',
  uRadioConfigLegacyMap in 'src\uRadioConfigLegacyMap.pas',
  uRadioConfigApply in 'src\uRadioConfigApply.pas',
  // The FMX twins were DELETED 2026-08-17, at the start of the Win32-to-LCL
  // migration.  They were never in an FPC build -- FMX has no FPC compiler --
  // so under the decided toolchain they were code nothing compiled, and had
  // already drifted from the LCL forms that replaced them.  Deleting them here
  // rather than per-form means no conversion has to ask whether it owes a twin.
  // The LCL set is in the {$IFDEF FPC} block below.
  uAccelerators in 'src\uAccelerators.pas',
  uMainWindowProc in 'src\uMainWindowProc.pas',
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
  uPlatformProcess in 'src\utils\uPlatformProcess.pas',
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
  uAltDForm in 'src\ui\lcl\uAltDForm.pas',
  uLogCompareForm in 'src\ui\lcl\uLogCompareForm.pas',
  uCT1BOHForm in 'src\ui\lcl\uCT1BOHForm.pas',
  uBeaconsForm in 'src\ui\lcl\uBeaconsForm.pas',
  uEditQSOForm in 'src\ui\lcl\uEditQSOForm.pas',
  uPanelUpdate in 'src\uPanelUpdate.pas',
  uLPTForm in 'src\ui\lcl\uLPTForm.pas',
  uAboutForm in 'src\ui\lcl\uAboutForm.pas',
  uFunctionKeysForm in 'src\ui\lcl\uFunctionKeysForm.pas',
  uBandPlanForm in 'src\ui\lcl\uBandPlanForm.pas',
  uLegacyIniPrompt in 'src\ui\lcl\uLegacyIniPrompt.pas',
  uIniRetireForm in 'src\ui\lcl\uIniRetireForm.pas',
  uWinManagerForm in 'src\ui\lcl\uWinManagerForm.pas',
  uMessagesListForm in 'src\ui\lcl\uMessagesListForm.pas',
  uEditMessageForm in 'src\ui\lcl\uEditMessageForm.pas',
  uSendKeyboardForm in 'src\ui\lcl\uSendKeyboardForm.pas',
  uAutoCQForm in 'src\ui\lcl\uAutoCQForm.pas',
  uSendSpotForm in 'src\ui\lcl\uSendSpotForm.pas',
  uInputQueryForm in 'src\ui\lcl\uInputQueryForm.pas',
  uProgramMessageForm in 'src\ui\lcl\uProgramMessageForm.pas',
  uKeyerEditForm in 'src\ui\lcl\uKeyerEditForm.pas',
  uRadioEditForm in 'src\ui\lcl\uRadioEditForm.pas',
  uMainForm in 'src\ui\lcl\uMainForm.pas',
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
  uPOTAParks in 'src\uPOTAParks.pas',
  uPendingCounties in 'src\uPendingCounties.pas',
  uCTYUpdate in 'src\uCTYUpdate.pas',
  uTRMasterUpdate in 'src\uTRMasterUpdate.pas',
  uAppStrings in 'src\uAppStrings.pas',
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
                                                                       // This way we can log before we read the DEBUG LOG LEVEL the legacy method in uCFG. // ny4i
begin
   // Enable thread-safe memory management. TR4W creates threads via Win32
   // CreateThread (not TThread), which does NOT set this flag automatically.
   // Without it, concurrent GetMem calls from different threads can corrupt
   // the heap, causing random AVs at startup when radio polling threads and
   // the main thread initialize simultaneously.
   IsMultiThread := True;

   // Application.Initialize creates the widgetset.  Application.Run at the
   // bottom of this file drives it -- Phase 3c, 2026-08-23.  The hand-rolled
   // GetMessage loop that owned the program until then is gone; what lived
   // inside it is in uAppInputHooks.
{$IFDEF FPC}
   InitLCLApplication;
{$ENDIF}

{$IFDEF FPC}
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
{$ENDIF}

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
    ShowNewContest;
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

  RunLCLApplication;
end.
