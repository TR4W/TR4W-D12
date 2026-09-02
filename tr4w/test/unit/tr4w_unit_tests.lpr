program tr4w_unit_tests;

{
  TR4W Automated Unit Test Runner
  Delphi 7 — console application, no VCL.

  Usage:
    tr4w_unit_tests.exe
    Exit code 0 = all tests passed.
    Exit code 1 = one or more failures.

  DUnitX migration (Delphi 12 Phase 4):
    Replace the main block with:
      var Runner := TDUnitX.CreateRunner;
      Runner.Run;
    Add [TestFixture]/[Test] attributes to each suite class.
    Remove RegisterSuite calls and RunAllSuites.
}

{$APPTYPE CONSOLE}

uses
{$IFDEF FPC}
   // The LCL is split into an interface half and a widgetset half, and linking
   // the first without the second fails with ~50 undefined WSRegisterXxx
   // symbols at LINK time -- long after every unit has compiled clean, which
   // makes it read like a corrupt build rather than a missing unit.
   //
   // The tests do not test any form.  They reach one TRANSITIVELY: a suite
   // links uCAT, uCAT uses uPrefsForm, and under FPC that is the LCL form.
   // So the whole widgetset comes along for the ride.  That is worth removing
   // -- a unit-test binary should not depend on a UI toolkit -- but the cut
   // belongs at the uCAT seam, not here, and not in the same change that got
   // the suite building again.
   Interfaces,
{$ENDIF}
   SysUtils,
   Log4D,
   MainUnit,
   uTR4WTestFramework   in 'uTR4WTestFramework.pas',
   uIcomCIV             in '..\..\src\uIcomCIV.pas',
   uTestIcomCIV         in 'uTestIcomCIV.pas',
   uRadioBand           in '..\..\src\radioFactory\uRadioBand.pas',
   uTestRadioBand       in 'uTestRadioBand.pas',
   uTestComboTags       in 'uTestComboTags.pas',
   uFlexRadioUtils      in '..\..\src\radioFactory\uFlexRadioUtils.pas',
   uTestFlexRadioUtils  in 'uTestFlexRadioUtils.pas',
   VC                   in '..\..\src\VC.pas',
   uAnsiStr             in '..\..\src\utils\uAnsiStr.pas',
   uFileText            in '..\..\src\utils\uFileText.pas',
   uRegex               in '..\..\src\utils\uRegex.pas',
   uTestRegexValidators in 'uTestRegexValidators.pas',
   uWin32Compat         in '..\..\src\utils\uWin32Compat.pas',
   uHostedFormWindows   in '..\..\src\utils\uHostedFormWindows.pas',
   uJSON                in '..\..\src\utils\uJSON.pas',
   uTestAnsiStr         in 'uTestAnsiStr.pas',
   utils_text           in '..\..\src\utils\utils_text.pas',
   uTestUtilsText       in 'uTestUtilsText.pas',
   uADIF                in '..\..\src\uADIF.pas',
   uTestADIF            in 'uTestADIF.pas',
   uTestADIFFixtures    in 'uTestADIFFixtures.pas',
   uBandLookup          in '..\..\src\uBandLookup.pas',
   uTestBandLookup      in 'uTestBandLookup.pas',
   uCabrilloFormat      in '..\..\src\uCabrilloFormat.pas',
   uTestCabrilloFormat  in 'uTestCabrilloFormat.pas',
   uCabrilloExchange    in '..\..\src\uCabrilloExchange.pas',
   uADIFExchange        in '..\..\src\uADIFExchange.pas',
   uTestADIFExchange    in 'uTestADIFExchange.pas',
   uTestCabrilloExchange in 'uTestCabrilloExchange.pas',
   uCRC32               in '..\..\src\uCRC32.pas',
   uTestCRC32           in 'uTestCRC32.pas',
   uCRC16               in '..\..\src\uCRC16.pas',
   uSpectrumTypes       in '..\..\src\uSpectrumTypes.pas',
   uK4Spectrum          in '..\..\src\radioFactory\uK4Spectrum.pas',
   uK4SpectrumThread    in '..\..\src\radioFactory\uK4SpectrumThread.pas',
   uTestK4Spectrum      in 'uTestK4Spectrum.pas',
   uIcomScope           in '..\..\src\radioFactory\uIcomScope.pas',
   uTestIcomScope       in 'uTestIcomScope.pas',
   uTestIcomScopeSeam   in 'uTestIcomScopeSeam.pas',
   utils_math           in '..\..\src\utils\utils_math.pas',
   uTestUtilsMath       in 'uTestUtilsMath.pas',
   uGridDistance        in '..\..\src\uGridDistance.pas',
   uTestGridDistance    in 'uTestGridDistance.pas',
   utils_file           in '..\..\src\utils\utils_file.pas',
   uWinTimer            in '..\..\src\utils\uWinTimer.pas',
   uTestWinTimer        in 'uTestWinTimer.pas',
   uRadioConfigStore    in '..\..\src\uRadioConfigStore.pas',
   uTestRadioConfigStore in 'uTestRadioConfigStore.pas',
   uRotatorBase in '..\..\src\rotatorFactory\uRotatorBase.pas',
   uRotatorControl in '..\..\src\uRotatorControl.pas',
   uRotatorRegistry in '..\..\src\rotatorFactory\uRotatorRegistry.pas',
   uRotatorYaesu in '..\..\src\rotatorFactory\uRotatorYaesu.pas',
   uRotatorOrion in '..\..\src\rotatorFactory\uRotatorOrion.pas',
   uRotatorDCU1 in '..\..\src\rotatorFactory\uRotatorDCU1.pas',
   uRotatorAlfaSpid in '..\..\src\rotatorFactory\uRotatorAlfaSpid.pas',
   uRotatorPSTRotator in '..\..\src\rotatorFactory\uRotatorPSTRotator.pas',
   uTestRotatorFactory in 'uTestRotatorFactory.pas',
   uSettingsRegistry in '..\..\src\uSettingsRegistry.pas',
   uSettingsLegacy in '..\..\src\uSettingsLegacy.pas',
   uSettingsDeclarations in '..\..\src\uSettingsDeclarations.pas',
   uTestSettingsRegistry in 'uTestSettingsRegistry.pas',
   uRadioConfigLegacyMap in '..\..\src\uRadioConfigLegacyMap.pas',
   uTestRadioConfigLegacyMap in 'uTestRadioConfigLegacyMap.pas',
   uKeyerConfigStore    in '..\..\src\uKeyerConfigStore.pas',
   uTR4WConfigFile      in '..\..\src\uTR4WConfigFile.pas',
   uUDPBroadcastConfig  in '..\..\src\uUDPBroadcastConfig.pas',
   uUDPBroadcaster      in '..\..\src\uUDPBroadcaster.pas',
   uWindowLayoutStore   in '..\..\src\uWindowLayoutStore.pas',
   uTestKeyerConfigStore in 'uTestKeyerConfigStore.pas',
   uTestWebSocketFraming in 'uTestWebSocketFraming.pas',
   uTestWebSocketLoopback in 'uTestWebSocketLoopback.pas',
   uTestTCIProtocol     in 'uTestTCIProtocol.pas',
   uTestTCIServer       in 'uTestTCIServer.pas',
   uTestTR4WConfigFile  in 'uTestTR4WConfigFile.pas',
   uTestWindowLayoutStore in 'uTestWindowLayoutStore.pas',
   uTestComputerID in 'uTestComputerID.pas',
   uTestUDPBroadcaster  in 'uTestUDPBroadcaster.pas',
   uTestUtilsFile       in 'uTestUtilsFile.pas',
   uTestADIFRegression  in 'uTestADIFRegression.pas',
   uFreqTimeFormat      in '..\..\src\uFreqTimeFormat.pas',
   uTestFreqTimeFormat  in 'uTestFreqTimeFormat.pas',
   uTestFormatTranslation in 'uTestFormatTranslation.pas',
   uStrSearch           in '..\..\src\uStrSearch.pas',
   uTestStrSearch       in 'uTestStrSearch.pas',
   uCallCompress        in '..\..\src\uCallCompress.pas',
   uTestCallCompress    in 'uTestCallCompress.pas',
   uCTYDAT              in '..\..\src\uCTYDAT.PAS',
   uTestCTYDAT          in 'uTestCTYDAT.pas',
   uMults               in '..\..\src\uMults.pas',
   uTestMults           in 'uTestMults.pas',
   uCallSignRoutines    in '..\..\src\uCallSignRoutines.pas',
   uTestCallSignRoutines in 'uTestCallSignRoutines.pas',
   uFactoryRadioBase    in '..\..\src\radioFactory\uFactoryRadioBase.pas',
   uRadioYaesuASCII     in '..\..\src\radioFactory\uRadioYaesuASCII.pas',
   uRadioYaesuFTDX10    in '..\..\src\radioFactory\uRadioYaesuFTDX10.pas',
   uRadioYaesuFT991     in '..\..\src\radioFactory\uRadioYaesuFT991.pas',
   uRadioYaesuFTDX101   in '..\..\src\radioFactory\uRadioYaesuFTDX101.pas',
   uRadioYaesuFT710     in '..\..\src\radioFactory\uRadioYaesuFT710.pas',
   uRadioYaesuFTX1F     in '..\..\src\radioFactory\uRadioYaesuFTX1F.pas',
   uRadioYaesuFT891     in '..\..\src\radioFactory\uRadioYaesuFT891.pas',
   uRadioYaesuASCIILegacy  in '..\..\src\radioFactory\uRadioYaesuASCIILegacy.pas',
   uRadioYaesuFT450     in '..\..\src\radioFactory\uRadioYaesuFT450.pas',
   uRadioYaesuFT950     in '..\..\src\radioFactory\uRadioYaesuFT950.pas',
   uRadioYaesuFT1200    in '..\..\src\radioFactory\uRadioYaesuFT1200.pas',
   uRadioYaesuFT2000    in '..\..\src\radioFactory\uRadioYaesuFT2000.pas',
   uRadioYaesuFTDX3000  in '..\..\src\radioFactory\uRadioYaesuFTDX3000.pas',
   uRadioYaesuFTDX5000  in '..\..\src\radioFactory\uRadioYaesuFTDX5000.pas',
   uRadioYaesuFTDX9000  in '..\..\src\radioFactory\uRadioYaesuFTDX9000.pas',
   // Old-binary family, listed EXPLICITLY -- see the note on uRadioIcomLegacy
   // above.  These were reaching this EXE only through uTestYaesuBinary's uses
   // clause, so any change there would have silently dropped their registrations.
   uRadioYaesuBinary    in '..\..\src\radioFactory\uRadioYaesuBinary.pas',
   uRadioYaesuFT1000MP  in '..\..\src\radioFactory\uRadioYaesuFT1000MP.pas',
   uRadioYaesuFT817Group in '..\..\src\radioFactory\uRadioYaesuFT817Group.pas',
   uRadioYaesuFT817      in '..\..\src\radioFactory\uRadioYaesuFT817.pas',
   uRadioYaesuFT818      in '..\..\src\radioFactory\uRadioYaesuFT818.pas',
   uRadioYaesuFT857      in '..\..\src\radioFactory\uRadioYaesuFT857.pas',
   uRadioYaesuFT897      in '..\..\src\radioFactory\uRadioYaesuFT897.pas',
   uRadioYaesuFT847     in '..\..\src\radioFactory\uRadioYaesuFT847.pas',
   uRadioYaesuFT990Group in '..\..\src\radioFactory\uRadioYaesuFT990Group.pas',
   uRadioYaesuFT990     in '..\..\src\radioFactory\uRadioYaesuFT990.pas',
   uRadioYaesuFT1000    in '..\..\src\radioFactory\uRadioYaesuFT1000.pas',
   uRadioYaesuFT840Group in '..\..\src\radioFactory\uRadioYaesuFT840Group.pas',
   uRadioYaesuFT840      in '..\..\src\radioFactory\uRadioYaesuFT840.pas',
   uRadioYaesuFT890      in '..\..\src\radioFactory\uRadioYaesuFT890.pas',
   uRadioYaesuFT900      in '..\..\src\radioFactory\uRadioYaesuFT900.pas',
   uRadioYaesuFT920     in '..\..\src\radioFactory\uRadioYaesuFT920.pas',
   uRadioYaesuFT100     in '..\..\src\radioFactory\uRadioYaesuFT100.pas',
   uRadioYaesuFT747     in '..\..\src\radioFactory\uRadioYaesuFT747.pas',
   uRadioYaesuFT767     in '..\..\src\radioFactory\uRadioYaesuFT767.pas',
   uTestYaesuASCII      in 'uTestYaesuASCII.pas',
   uTestYaesuBinary     in 'uTestYaesuBinary.pas',
   // Listed EXPLICITLY, not reached through another unit's uses clause: radios
   // self-register from their unit's initialization, so a unit that is only
   // linked transitively vanishes the moment that chain changes -- and its
   // radios silently disappear from the registry with no compile error.
   // Exactly that happened: uRadioIcomLegacyModels stopped using
   // uRadioIcomLegacy, and the IC-706 family fell out of this EXE.
   uRadioIcomLegacy in '..\..\src\radioFactory\uRadioIcomLegacy.pas',
   uRadioIcomReadLimited in '..\..\src\radioFactory\uRadioIcomReadLimited.pas',
   uRadioIcomModern in '..\..\src\radioFactory\uRadioIcomModern.pas',
   uRadioHamLibOnly in '..\..\src\radioFactory\uRadioHamLibOnly.pas',
   uLPTPortEnumerator in '..\..\src\uLPTPortEnumerator.pas',
   uPrefsSearch in '..\..\src\uPrefsSearch.pas',
   uCWFraming in '..\..\src\radioFactory\uCWFraming.pas',
   uRadioKYBase in '..\..\src\radioFactory\uRadioKYBase.pas',
   uRadioElecraftBase in '..\..\src\radioFactory\uRadioElecraftBase.pas',
   uRadioKenwoodBase in '..\..\src\radioFactory\uRadioKenwoodBase.pas',
   uTestPrefsSearch in 'uTestPrefsSearch.pas',
   uAccelerators in '..\..\src\uAccelerators.pas',
   uTestAccelerators in 'uTestAccelerators.pas',
   uTestCWFraming in 'uTestCWFraming.pas',
   // Pins the radio-status change detector.  LOGRADIO itself is not listed
   // here -- it arrives through the search path, the same way uTestIcomRegistry
   // reaches RadioParametersArray.
   uTestRadioStatus in 'uTestRadioStatus.pas',
   uElecraftIF in '..\..\src\radioFactory\uElecraftIF.pas',
   uTestElecraftIF in 'uTestElecraftIF.pas',
   uTestAutoInfo in 'uTestAutoInfo.pas',
   // CW keyer factory -- listed EXPLICITLY (same rule as the radio units:
   // adapters self-install from initialization; a transitive-only link path
   // would silently drop them from this EXE).
   uCWKeyerBase in '..\..\src\uCWKeyerBase.pas',
   uCWKeyerCAT in '..\..\src\uCWKeyerCAT.pas',
   uCWKeyerWinKey in '..\..\src\uCWKeyerWinKey.pas',
   uCWKeyerYCCC in '..\..\src\uCWKeyerYCCC.pas',
   uCWKeyerCPU in '..\..\src\uCWKeyerCPU.pas',
   uTestCWKeyer in 'uTestCWKeyer.pas',
   uRadioIcom78 in '..\..\src\radioFactory\uRadioIcom78.pas',
   uRadioIcom707 in '..\..\src\radioFactory\uRadioIcom707.pas',
   uRadioIcom725 in '..\..\src\radioFactory\uRadioIcom725.pas',
   uRadioIcom726 in '..\..\src\radioFactory\uRadioIcom726.pas',
   uRadioIcom728 in '..\..\src\radioFactory\uRadioIcom728.pas',
   uRadioIcom729 in '..\..\src\radioFactory\uRadioIcom729.pas',
   uRadioIcom735 in '..\..\src\radioFactory\uRadioIcom735.pas',
   uRadioIcom736 in '..\..\src\radioFactory\uRadioIcom736.pas',
   uRadioIcom737 in '..\..\src\radioFactory\uRadioIcom737.pas',
   uRadioIcom738 in '..\..\src\radioFactory\uRadioIcom738.pas',
   uRadioIcom746 in '..\..\src\radioFactory\uRadioIcom746.pas',
   uRadioIcom746PRO in '..\..\src\radioFactory\uRadioIcom746PRO.pas',
   uRadioIcom756 in '..\..\src\radioFactory\uRadioIcom756.pas',
   uRadioIcom756PRO in '..\..\src\radioFactory\uRadioIcom756PRO.pas',
   uRadioIcom756PROII in '..\..\src\radioFactory\uRadioIcom756PROII.pas',
   uRadioIcom756PROIII in '..\..\src\radioFactory\uRadioIcom756PROIII.pas',
   uRadioIcom761 in '..\..\src\radioFactory\uRadioIcom761.pas',
   uRadioIcom765 in '..\..\src\radioFactory\uRadioIcom765.pas',
   uRadioIcom775 in '..\..\src\radioFactory\uRadioIcom775.pas',
   uRadioIcom781 in '..\..\src\radioFactory\uRadioIcom781.pas',
   uRadioIcom910 in '..\..\src\radioFactory\uRadioIcom910.pas',
   uRadioIcom970D in '..\..\src\radioFactory\uRadioIcom970D.pas',
   uRadioIcom7200 in '..\..\src\radioFactory\uRadioIcom7200.pas',
   uRadioIcom7110 in '..\..\src\radioFactory\uRadioIcom7110.pas',
   uRadioIcom7410 in '..\..\src\radioFactory\uRadioIcom7410.pas',
   uRadioIcom9100 in '..\..\src\radioFactory\uRadioIcom9100.pas',
   uRadioTenTecOmni6 in '..\..\src\radioFactory\uRadioTenTecOmni6.pas',
   uRadioTenTecOrion in '..\..\src\radioFactory\uRadioTenTecOrion.pas',
   uRadioIcom7700         in '..\..\src\radioFactory\uRadioIcom7700.pas',
   uRadioIcom7800         in '..\..\src\radioFactory\uRadioIcom7800.pas',
   uRadioIcom7850         in '..\..\src\radioFactory\uRadioIcom7850.pas',
   uRadioIcom7851         in '..\..\src\radioFactory\uRadioIcom7851.pas',
   uTestIcomRegistry    in 'uTestIcomRegistry.pas',
   uTestRegistryTaxonomy in 'uTestRegistryTaxonomy.pas',
   // Flex is the only two-constructor registration; list its three units
   // explicitly so their initialization sections self-register in this EXE.
   uRadioFlexAPI        in '..\..\src\radioFactory\uRadioFlexAPI.pas',
   uRadioFlexCAT        in '..\..\src\radioFactory\uRadioFlexCAT.pas',
   uRadioFlex6000       in '..\..\src\radioFactory\uRadioFlex6000.pas',
   uTestFlexRegistry    in 'uTestFlexRegistry.pas',
   uFlexDiscovery       in '..\..\src\radioFactory\uFlexDiscovery.pas',
   uTestFlexDiscovery   in 'uTestFlexDiscovery.pas',
   uTestKenwoodSerial   in 'uTestKenwoodSerial.pas',
   uTestRadioTCI        in 'uTestRadioTCI.pas',
   uTestSerialParams    in 'uTestSerialParams.pas',
   uTestLPTPortEnumerator in 'uTestLPTPortEnumerator.pas',
   uTestConfigDefaults in 'uTestConfigDefaults.pas',
   uTestTransverterOffset in 'uTestTransverterOffset.pas',
   uTestRadioSupportsCaps in 'uTestRadioSupportsCaps.pas',
   uTestHamLibIDs       in 'uTestHamLibIDs.pas',
   uTestDXClusterClient in 'uTestDXClusterClient.pas',
   uNetFraming in '..\..\src\uNetFraming.pas',
   uTestNetFraming in 'uTestNetFraming.pas',
   uDXSpotParse         in '..\..\src\uDXSpotParse.pas',
   uSpotAge             in '..\..\src\uSpotAge.pas',
   uClusterTokens       in '..\..\src\uClusterTokens.pas',
   uTestDXSpotParse     in 'uTestDXSpotParse.pas',
   uTestSpotAge         in 'uTestSpotAge.pas',
   uAppPaths            in '..\..\src\uAppPaths.pas',
   uLogBinaryFile       in '..\..\src\uLogBinaryFile.pas',
   uTestLogBinaryFile   in 'uTestLogBinaryFile.pas',
   uLogSchema           in '..\..\src\domain\uLogSchema.pas',
uContestFileKind           in '..\..\src\domain\uContestFileKind.pas',
uEditableLogView           in '..\..\src\domain\uEditableLogView.pas',
   uLogRepository       in '..\..\src\uLogRepository.pas',
   uTestLogRepository   in 'uTestLogRepository.pas',
   uTestLogNaming       in 'uTestLogNaming.pas',
uTestContestFileKind       in 'uTestContestFileKind.pas',
uTestEditableLogView       in 'uTestEditableLogView.pas',
   uLogImport           in '..\..\src\uLogImport.pas',
   uTestLogImport       in 'uTestLogImport.pas',
   uLogDatabase         in '..\..\src\domain\uLogDatabase.pas',
   uTestLogDatabase     in 'uTestLogDatabase.pas',
   uTestClusterTokens   in 'uTestClusterTokens.pas',
   // Kenwood + Elecraft model units: listed so their initialization sections
   // self-register here, which is what puts them under the base-constructor
   // and registry coverage tests.
   uRadioKenwoodSerial  in '..\..\src\radioFactory\uRadioKenwoodSerial.pas',
   uRadioKenwoodLAN     in '..\..\src\radioFactory\uRadioKenwoodLAN.pas',
   uWebSocketFraming    in '..\..\src\uWebSocketFraming.pas',
   uWebSocketClient     in '..\..\src\uWebSocketClient.pas',
   uWebSocketServer     in '..\..\src\uWebSocketServer.pas',
   uTCIProtocol         in '..\..\src\uTCIProtocol.pas',
   uTCIServer           in '..\..\src\uTCIServer.pas',
   uRadioTCI            in '..\..\src\radioFactory\uRadioTCI.pas',
   uRadioKenwoodTS890   in '..\..\src\radioFactory\uRadioKenwoodTS890.pas',
   uRadioKenwoodTS990   in '..\..\src\radioFactory\uRadioKenwoodTS990.pas',
   uRadioKenwoodTS570   in '..\..\src\radioFactory\uRadioKenwoodTS570.pas',
   uRadioKenwoodTS140    in '..\..\src\radioFactory\uRadioKenwoodTS140.pas',
   uRadioKenwoodTS440    in '..\..\src\radioFactory\uRadioKenwoodTS440.pas',
   uRadioKenwoodTS450    in '..\..\src\radioFactory\uRadioKenwoodTS450.pas',
   uRadioKenwoodTS480    in '..\..\src\radioFactory\uRadioKenwoodTS480.pas',
   uRadioKenwoodTS590    in '..\..\src\radioFactory\uRadioKenwoodTS590.pas',
   uRadioKenwoodTS690    in '..\..\src\radioFactory\uRadioKenwoodTS690.pas',
   uRadioKenwoodTS850    in '..\..\src\radioFactory\uRadioKenwoodTS850.pas',
   uRadioKenwoodTS870    in '..\..\src\radioFactory\uRadioKenwoodTS870.pas',
   uRadioKenwoodTS940    in '..\..\src\radioFactory\uRadioKenwoodTS940.pas',
   uRadioKenwoodTS950    in '..\..\src\radioFactory\uRadioKenwoodTS950.pas',
   uRadioKenwoodTS2000   in '..\..\src\radioFactory\uRadioKenwoodTS2000.pas',
   uRadioElecraftSerial in '..\..\src\radioFactory\uRadioElecraftSerial.pas',
   uRadioElecraftK3     in '..\..\src\radioFactory\uRadioElecraftK3.pas',
   uRadioElecraftK2     in '..\..\src\radioFactory\uRadioElecraftK2.pas',
   uRadioElecraftKX3    in '..\..\src\radioFactory\uRadioElecraftKX3.pas',
   uRadioElecraftK4     in '..\..\src\radioFactory\uRadioElecraftK4.pas',
   uTestSplitReassert   in 'uTestSplitReassert.pas';

begin
   IsMultiThread := True;  // Match main application setting

   // The radio-factory classes log through MainUnit's GLOBAL `logger`,
   // which tr4w.lpr assigns during startup.  A test EXE never runs that
   // startup, so the global stays nil and the first radio call that logs
   // -- UpdateLastValidResponse, on every received frame -- dies with an
   // access violation.  Assign it here the same way the app does.
   //
   // No appender is configured: the loggers then discard output, which is
   // what a test run wants.  This is ONLY about the global being non-nil.
   logger := TLogLogger.GetLogger('TR4WUnitTests');

   WriteLn('=== TR4W Unit Tests ===');
   WriteLn('');

   RegisterSuite(TUDPBroadcasterTests.Create('UDPBroadcaster'));
   RegisterSuite(TIcomCIVTests.Create('IcomCIV'));
   RegisterSuite(TRadioBandTests.Create('RadioBand'));
   RegisterSuite(TComboTagTests.Create('ComboTags'));
   RegisterSuite(TFlexRadioUtilsTests.Create('FlexRadioUtils'));
   RegisterSuite(TAnsiStrTests.Create('AnsiStr'));
   RegisterSuite(TRegexValidatorTests.Create('RegexValidators'));
   RegisterSuite(TUtilsTextTests.Create('UtilsText'));
   RegisterSuite(TADIFLexerTests.Create('ADIFLexer'));
   RegisterSuite(TADIFHelperTests.Create('ADIFHelpers'));
   RegisterSuite(TADIFMappingTests.Create('ADIFMapping'));
   RegisterSuite(TADIFFixtureTests.Create('ADIFFixtures'));
   RegisterSuite(TBandLookupTests.Create('BandLookup'));
   RegisterSuite(TCabrilloFormatTests.Create('CabrilloFormat'));
   RegisterSuite(TCabrilloExchangeTests.Create('CabrilloExchange'));
   RegisterSuite(TCRC32Tests.Create('CRC32'));
   RegisterSuite(TK4SpectrumTests.Create('K4Spectrum'));
   RegisterSuite(TIcomScopeTests.Create('IcomScope'));
   RegisterSuite(TIcomScopeSeamTests.Create('IcomScopeSeam'));
   RegisterSuite(TUtilsMathTests.Create('UtilsMath'));
   RegisterSuite(TGridDistanceTests.Create('GridDistance'));
   RegisterSuite(TUtilsFileTests.Create('UtilsFile'));
   RegisterSuite(TADIFRegressionTests.Create('ADIFRegression'));
   RegisterSuite(TFreqTimeFormatTests.Create('FreqTimeFormat'));
   RegisterSuite(TFormatTranslationTests.Create('FormatTranslation'));
   RegisterSuite(TStrSearchTests.Create('StrSearch'));
   RegisterSuite(TCallCompressTests.Create('CallCompress'));
   RegisterSuite(TCTYDATTests.Create('CTYDAT'));
   RegisterSuite(TMultsTests.Create('Mults'));
   RegisterSuite(TTestNetFraming.Create('NetFraming'));
   RegisterSuite(TTestADIFExchange.Create('ADIFExchange'));
   RegisterSuite(TCallSignRoutinesTests.Create('CallSignRoutines'));
   RegisterSuite(TYaesuASCIITests.Create('YaesuASCII'));
   RegisterSuite(TYaesuBinaryTests.Create('YaesuBinary'));
   RegisterSuite(TIcomRegistryTests.Create('IcomRegistry'));
   RegisterSuite(TRegistryTaxonomyTests.Create('RegistryTaxonomy'));
   RegisterSuite(TFlexRegistryTests.Create('FlexRegistry'));
   RegisterSuite(TFlexDiscoveryTests.Create('FlexDiscovery'));
   RegisterSuite(TKenwoodSerialTests.Create('KenwoodSerial'));
   RegisterSuite(TRadioTCITests.Create('RadioTCI'));
   RegisterSuite(TSerialParamsTests.Create('SerialParams'));
   RegisterSuite(TRadioSupportsCapsTests.Create('RadioSupportsCaps'));
   RegisterSuite(TTransverterOffsetTests.Create('TransverterOffset'));
   RegisterSuite(TLPTPortEnumeratorTests.Create('LPTPortEnumerator'));
   RegisterSuite(TConfigDefaultsTests.Create('ConfigDefaults'));
   RegisterSuite(THamLibIDTests.Create('HamLibIDs'));
   RegisterSuite(TCWKeyerTests.Create('CWKeyer'));
   RegisterSuite(TCWFramingTests.Create('CWFraming'));
   RegisterSuite(TAcceleratorTests.Create('Accelerators'));
   RegisterSuite(TPrefsSearchTests.Create('PrefsSearch'));
   RegisterSuite(TRadioStatusTests.Create('RadioStatus'));
   RegisterSuite(TElecraftIFTests.Create('ElecraftIF'));
   RegisterSuite(TAutoInfoTests.Create('AutoInfo'));
   RegisterSuite(TSettingsRegistryTests.Create('SettingsRegistry'));
   RegisterSuite(TRotatorFactoryTests.Create('RotatorFactory'));
   RegisterSuite(TDXClusterClientTests.Create('DXClusterClient'));
   RegisterSuite(TDXSpotParseTests.Create('DXSpotParse'));
   RegisterSuite(TSpotAgeTests.Create('SpotAge'));
   RegisterSuite(TLogBinaryFileTests.Create('LogBinaryFile'));
   RegisterSuite(TLogDatabaseTests.Create('LogDatabase'));
   RegisterSuite(TLogRepositoryTests.Create('LogRepository'));
   RegisterSuite(TLogNamingTests.Create('LogNaming'));
   RegisterSuite(TContestFileKindTests.Create('ContestFileKind'));
   RegisterSuite(TEditableLogViewTests.Create('EditableLogView'));
   RegisterSuite(TLogImportTests.Create('LogImport'));
   RegisterSuite(TClusterTokensTests.Create('ClusterTokens'));
   RegisterSuite(TSplitReassertTests.Create('SplitReassert'));
   RegisterSuite(TWinTimerTests.Create('WinTimer'));
   RegisterSuite(TRadioConfigStoreTests.Create('RadioConfigStore'));
   RegisterSuite(TRadioConfigLegacyMapTests.Create('RadioConfigLegacyMap'));
   RegisterSuite(TKeyerConfigStoreTests.Create('KeyerConfigStore'));
   RegisterSuite(TWebSocketFramingTests.Create('WebSocketFraming'));
   RegisterSuite(TWebSocketLoopbackTests.Create('WebSocketLoopback'));
   RegisterSuite(TTCIProtocolTests.Create('TCIProtocol'));
   RegisterSuite(TTCIServerTests.Create('TCIServer'));
   RegisterSuite(TTR4WConfigFileTests.Create('TR4WConfigFile'));
   RegisterSuite(TWindowLayoutStoreTests.Create('WindowLayoutStore'));
   RegisterSuite(TComputerIDTests.Create('ComputerID'));

   if RunAllSuites then
      begin
      WriteLn('');
      WriteLn('All tests passed.');
      ExitCode := 0;
      end
   else
      begin
      WriteLn('');
      WriteLn('FAILURES detected — see above.');
      ExitCode := 1;
      end;
end.
