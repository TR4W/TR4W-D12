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

(* THE LANGUAGE CATALOGUES, the same resource the app links -- so the tests of
  the Language setting's vocabulary and captions read what ships, rather than
  a list somebody typed. See uTestUILanguage. *)
{$R ..\..\res\tr4w_languages.res}

uses
(* cthreads MUST BE FIRST, AND ONLY ON UNIX (2026-09-08).

  FOUND BY RUNNING, NOT BY COMPILING. Everything built; the unit-test binary
  then died on its first line of work with

      ESyncObjectException: Failed to create OS basic event with name ""

  which reads like a bug in the empty name and is nothing of the kind. FPC's
  thread manager is PLUGGABLE, and on Unix the real one is installed by the
  side effect of LINKING cthreads. Without it `currenttm` stays the no-threads
  manager, whose NoBasicEventCreate simply `result:=nil` -- and TEvent.Create
  turns a nil handle into that exception, quoting the name it was given.

  So the name was a red herring; the thread manager was missing. TR4W creates
  six TEvents across the radio, keyer, HamScore, TCI, WebSocket and network
  paths, so the APP would have hit exactly the same wall at startup.

  IT HAS TO BE THE FIRST UNIT: cthreads installs the manager in its
  initialization section, and unit initialization runs in uses order. Anything
  above it that starts a thread or creates an event gets the no-threads
  manager. That is why it sits above Interfaces here rather than beside the
  other RTL units.

  Windows needs none of this -- the Win32 RTL has one thread manager, always
  installed -- so the gate is UNIX, not "not Windows": macOS needs it too. *)
{$IFDEF UNIX}
  cthreads,
  (* cwstring -- the UnicodeString manager. See the note in tr4w.lpr: without
    it the first UnicodeString/AnsiString conversion raises
    ENoWideStringSupport at RUN time, and a compile proves nothing either way.
    The tests are the one program here that a Unix CI box actually RUNS, so
    they are also the cheapest place for this to be caught next time. *)
  cwstring,
{$ENDIF}
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
   uStringCompare       in '..\..\src\utils\uStringCompare.pas',
   uAudio               in '..\..\src\utils\uAudio.pas',
   uFileText            in '..\..\src\utils\uFileText.pas',
   uRegex               in '..\..\src\utils\uRegex.pas',
   uTestRegexValidators in 'uTestRegexValidators.pas',
   uWin32Compat         in '..\..\src\utils\uWin32Compat.pas',
   uJSON                in '..\..\src\utils\uJSON.pas',
   uTestStringCompare   in 'uTestStringCompare.pas',
   uTestShortStringConversion in 'uTestShortStringConversion.pas',
   uTestAudio           in 'uTestAudio.pas',
   utils_text           in '..\..\src\utils\utils_text.pas',
   uTestUtilsText       in 'uTestUtilsText.pas',
   uTestLog4DFileAppender in 'uTestLog4DFileAppender.pas',
   uADIF                in '..\..\src\uADIF.pas',
   uTestADIF            in 'uTestADIF.pas',
   uTestADIFFixtures    in 'uTestADIFFixtures.pas',
   uBandLookup          in '..\..\src\uBandLookup.pas',
   uTestBandLookup      in 'uTestBandLookup.pas',
   uCabrilloFormat      in '..\..\src\uCabrilloFormat.pas',
   uTestCabrilloFormat  in 'uTestCabrilloFormat.pas',
   uCabrilloExchange    in '..\..\src\uCabrilloExchange.pas',
   uADIFExchange        in '..\..\src\uADIFExchange.pas',
   uARRLSections        in '..\..\src\uARRLSections.pas',
   uPOTAReference       in '..\..\src\uPOTAReference.pas',
   uGridShape           in '..\..\src\uGridShape.pas',
   uDXCCEntities        in '..\..\src\uDXCCEntities.pas',
   uTestADIFExchange    in 'uTestADIFExchange.pas',
   uTestCabrilloExchange in 'uTestCabrilloExchange.pas',
   uCRC32               in '..\..\src\uCRC32.pas',
   uTestCRC32           in 'uTestCRC32.pas',
   uCRC16               in '..\..\src\uCRC16.pas',
   uSpectrumTypes       in '..\..\src\uSpectrumTypes.pas',
   uK4Spectrum          in '..\..\src\radioFactory\uK4Spectrum.pas',
   uTestBytePattern     in 'uTestBytePattern.pas',
   uTestCRC16           in 'uTestCRC16.pas',
   uTestWinKeyWire      in 'uTestWinKeyWire.pas',
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
   uTestCWByCATTimer    in 'uTestCWByCATTimer.pas',
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
   uSettingsModelBinding in '..\..\src\uSettingsModelBinding.pas',
   uSettingsDeclarations in '..\..\src\uSettingsDeclarations.pas',
   uTestSettingsRegistry in 'uTestSettingsRegistry.pas',
   uRadioConfigLegacyMap in '..\..\src\uRadioConfigLegacyMap.pas',
   uTestRadioConfigLegacyMap in 'uTestRadioConfigLegacyMap.pas',
   uKeyerConfigStore    in '..\..\src\uKeyerConfigStore.pas',
   uTR4WConfigFile      in '..\..\src\uTR4WConfigFile.pas',
   uUILanguage          in '..\..\src\uUILanguage.pas',
   uTestUILanguage      in 'uTestUILanguage.pas',
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
   uN1MMMode            in '..\..\src\uN1MMMode.pas',
   uTestN1MMMode        in 'uTestN1MMMode.pas',
   uTestUDPContactXml   in 'uTestUDPContactXml.pas',
   uTestUDPDatagrams    in 'uTestUDPDatagrams.pas',
   uTestUtilsFile       in 'uTestUtilsFile.pas',
   uTestADIFRegression  in 'uTestADIFRegression.pas',
   uFreqTimeFormat      in '..\..\src\uFreqTimeFormat.pas',
   uTestFreqTimeFormat  in 'uTestFreqTimeFormat.pas',
   uTestFormatTranslation in 'uTestFormatTranslation.pas',
   uStrSearch           in '..\..\src\uStrSearch.pas',
   uTestStrSearch       in 'uTestStrSearch.pas',
   uCallCompress        in '..\..\src\uCallCompress.pas',
   uTestCallCompress    in 'uTestCallCompress.pas',
   uCTYDAT              in '..\..\src\uctydat.pas',
   uTestCTYDAT          in 'uTestCTYDAT.pas',
   uContestReadiness    in '..\..\src\uContestReadiness.pas',
   uTestContestReadiness in 'uTestContestReadiness.pas',
   uMults               in '..\..\src\uMults.pas',
   uTestMults           in 'uTestMults.pas',
   uTestSortedStringList in 'uTestSortedStringList.pas',
   uTestCallsignsList   in 'uTestCallsignsList.pas',
   uTestOffBandCredit   in 'uTestOffBandCredit.pas',
   uTestAutomaticXQSO   in 'uTestAutomaticXQSO.pas',
   uTestMalformedGrid   in 'uTestMalformedGrid.pas',
   uTestRoverDupeKey    in 'uTestRoverDupeKey.pas',
   uTestNYQPRover       in 'uTestNYQPRover.pas',
   uTestOperatorCQMemory in 'uTestOperatorCQMemory.pas',
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
   ComPortEnumerator in '..\..\src\ComPortEnumerator.pas',
   uPortAddress in '..\..\src\uPortAddress.pas',
   uSettingsModel in '..\..\src\uSettingsModel.pas',
   uPrefsSearch in '..\..\src\uPrefsSearch.pas',
   uCWFraming in '..\..\src\radioFactory\uCWFraming.pas',
   uRadioLinkRetry in '..\..\src\uRadioLinkRetry.pas',
   uRadioKYBase in '..\..\src\radioFactory\uRadioKYBase.pas',
   uRadioElecraftBase in '..\..\src\radioFactory\uRadioElecraftBase.pas',
   uRadioKenwoodBase in '..\..\src\radioFactory\uRadioKenwoodBase.pas',
   uTestPrefsSearch in 'uTestPrefsSearch.pas',
   uAccelerators in '..\..\src\uAccelerators.pas',
   uTestAccelerators in 'uTestAccelerators.pas',
   uMenu in '..\..\src\uMenu.pas',
   uTestMenuShortcuts in 'uTestMenuShortcuts.pas',
   uEditingKeys       in '..\..\src\ui\lcl\uEditingKeys.pas',
   uTestEditingKeys   in 'uTestEditingKeys.pas',
   uSHA256 in '..\..\src\utils\uSHA256.pas',
   uTestSHA256 in 'uTestSHA256.pas',
   uTestAllSettings in 'uTestAllSettings.pas',
   uTestCWFraming in 'uTestCWFraming.pas',
   (* THE CONTEST FACTORY. uContestFactory is deliberately NOT here: it reads
      LOGWIND and the settings model, and the point of uTestContestFactory is
      that a contest class needs neither. The classes are listed so their
      initialization sections register them. *)
   uCanonicalExchange in '..\..\src\uCanonicalExchange.pas',
   uContestBase in '..\..\src\contestFactory\uContestBase.pas',
   uContestRegistry in '..\..\src\contestFactory\uContestRegistry.pas',
   uContestSession in '..\..\src\uContestSession.pas',
   uContestStateQSOPartyBase in '..\..\src\contestFactory\uContestStateQSOPartyBase.pas',
   uContestFixedPoints in '..\..\src\contestFactory\uContestFixedPoints.pas',
   uPrefixMultiplierKey in '..\..\src\contestFactory\uPrefixMultiplierKey.pas',
   uDXMultiplierKey     in '..\..\src\contestFactory\uDXMultiplierKey.pas',
   uDomesticKey         in '..\..\src\contestFactory\uDomesticKey.pas',
   uExchangeFields      in '..\..\src\contestFactory\uExchangeFields.pas',
   uContestARRLDXBase in '..\..\src\contestFactory\uContestARRLDXBase.pas',
   uContestARRLDXCW in '..\..\src\contestFactory\uContestARRLDXCW.pas',
   uContestARRLDXPhone in '..\..\src\contestFactory\uContestARRLDXPhone.pas',
   uContestARRLSSBase in '..\..\src\contestFactory\uContestARRLSSBase.pas',
   uContestARRLSSCW in '..\..\src\contestFactory\uContestARRLSSCW.pas',
   uContestARRLSSSSB in '..\..\src\contestFactory\uContestARRLSSSSB.pas',
   uContestCQWPXBase in '..\..\src\contestFactory\uContestCQWPXBase.pas',
   uContestCQWPXCW in '..\..\src\contestFactory\uContestCQWPXCW.pas',
   uContestCQWPXSSB in '..\..\src\contestFactory\uContestCQWPXSSB.pas',
   uContestCQWWBase in '..\..\src\contestFactory\uContestCQWWBase.pas',
   uContestCQWWCW in '..\..\src\contestFactory\uContestCQWWCW.pas',
   uContestCQWWSSB in '..\..\src\contestFactory\uContestCQWWSSB.pas',
   uContestARRLFieldDay in '..\..\src\contestFactory\uContestARRLFieldDay.pas',
   uContestWinterFieldDay in '..\..\src\contestFactory\uContestWinterFieldDay.pas',
   uContestIARU in '..\..\src\contestFactory\uContestIARU.pas',
   uContestGeneralQSO in '..\..\src\contestFactory\uContestGeneralQSO.pas',
   uContestNASprintCW in '..\..\src\contestFactory\uContestNASprintCW.pas',
   uContestNASprintRTTY in '..\..\src\contestFactory\uContestNASprintRTTY.pas',
   uContestFloridaQP in '..\..\src\contestFactory\uContestFloridaQP.pas',
   uContestMichiganQP in '..\..\src\contestFactory\uContestMichiganQP.pas',
   uContestCaliforniaQP in '..\..\src\contestFactory\uContestCaliforniaQP.pas',
   uContestIndianaQP in '..\..\src\contestFactory\uContestIndianaQP.pas',
   uContestColoradoQP in '..\..\src\contestFactory\uContestColoradoQP.pas',
   uContestMinnesotaQP in '..\..\src\contestFactory\uContestMinnesotaQP.pas',
   uContestMissouriQP in '..\..\src\contestFactory\uContestMissouriQP.pas',
   uContestOhioQP in '..\..\src\contestFactory\uContestOhioQP.pas',
   uContestWisconsinQP in '..\..\src\contestFactory\uContestWisconsinQP.pas',
   uContestTennesseeQP in '..\..\src\contestFactory\uContestTennesseeQP.pas',
   uContestTexasQP in '..\..\src\contestFactory\uContestTexasQP.pas',
   uContestArizonaQP in '..\..\src\contestFactory\uContestArizonaQP.pas',
   uContestBritishColumbiaQP in '..\..\src\contestFactory\uContestBritishColumbiaQP.pas',
   uContestNorthCarolinaQP in '..\..\src\contestFactory\uContestNorthCarolinaQP.pas',
   uContestPennsylvaniaQP in '..\..\src\contestFactory\uContestPennsylvaniaQP.pas',
   uContestVirginiaQP in '..\..\src\contestFactory\uContestVirginiaQP.pas',
   uContestNewYorkQP in '..\..\src\contestFactory\uContestNewYorkQP.pas',
   uContestWashingtonSalmonRun in '..\..\src\contestFactory\uContestWashingtonSalmonRun.pas',
   uContestIdahoQP in '..\..\src\contestFactory\uContestIdahoQP.pas',
   uContestDelawareQP in '..\..\src\contestFactory\uContestDelawareQP.pas',
   uContestNebraskaQP in '..\..\src\contestFactory\uContestNebraskaQP.pas',
   uContestIN7QPNE in '..\..\src\contestFactory\uContestIN7QPNE.pas',
   uContestQCWA in '..\..\src\contestFactory\uContestQCWA.pas',
   uContestQCWAGolden in '..\..\src\contestFactory\uContestQCWAGolden.pas',
   uContestCountyHunter in '..\..\src\contestFactory\uContestCountyHunter.pas',
   uContestGridLoc in '..\..\src\contestFactory\uContestGridLoc.pas',
   uContestMarconiMemorial in '..\..\src\contestFactory\uContestMarconiMemorial.pas',
   uContestSASprint in '..\..\src\contestFactory\uContestSASprint.pas',
   uContestXmas in '..\..\src\contestFactory\uContestXmas.pas',
   uContestInternetSprint in '..\..\src\contestFactory\uContestInternetSprint.pas',
   uContestAllJA in '..\..\src\contestFactory\uContestAllJA.pas',
   uContestAPSprint in '..\..\src\contestFactory\uContestAPSprint.pas',
   uContestJALongPrefect in '..\..\src\contestFactory\uContestJALongPrefect.pas',
   uContestKidsDay in '..\..\src\contestFactory\uContestKidsDay.pas',
   uContestMini40 in '..\..\src\contestFactory\uContestMini40.pas',
   uContestMini80 in '..\..\src\contestFactory\uContestMini80.pas',
   uContestMinitest in '..\..\src\contestFactory\uContestMinitest.pas',
   uContestKVP in '..\..\src\contestFactory\uContestKVP.pas',
   uContestMST in '..\..\src\contestFactory\uContestMST.pas',
   uContestYouthChampionshipRF in '..\..\src\contestFactory\uContestYouthChampionshipRF.pas',
   uContestEuropeanHFC in '..\..\src\contestFactory\uContestEuropeanHFC.pas',
   uContestCQIR in '..\..\src\contestFactory\uContestCQIR.pas',
   uContestDARCXmas in '..\..\src\contestFactory\uContestDARCXmas.pas',
   uContestArktikaSpring in '..\..\src\contestFactory\uContestArktikaSpring.pas',
   uContestARRLDigi in '..\..\src\contestFactory\uContestARRLDigi.pas',
   uContestNRAUBalticBase in '..\..\src\contestFactory\uContestNRAUBalticBase.pas',
   uContestNRAUBalticCW in '..\..\src\contestFactory\uContestNRAUBalticCW.pas',
   uContestNRAUBalticSSB in '..\..\src\contestFactory\uContestNRAUBalticSSB.pas',
   uContestSprintSSB in '..\..\src\contestFactory\uContestSprintSSB.pas',
   uContestLocustQP in '..\..\src\contestFactory\uContestLocustQP.pas',
   uContestJockWhiteFieldDay in '..\..\src\contestFactory\uContestJockWhiteFieldDay.pas',
   uContestFOCMarathon in '..\..\src\contestFactory\uContestFOCMarathon.pas',
   uContestUkraineChampionship in '..\..\src\contestFactory\uContestUkraineChampionship.pas',
   uContestUralCup in '..\..\src\contestFactory\uContestUralCup.pas',
   uContestUKEI in '..\..\src\contestFactory\uContestUKEI.pas',
   uContestRSGBIOTA in '..\..\src\contestFactory\uContestRSGBIOTA.pas',
   uContestDARC10M in '..\..\src\contestFactory\uContestDARC10M.pas',
   uContestPACC in '..\..\src\contestFactory\uContestPACC.pas',
   uContestPCC in '..\..\src\contestFactory\uContestPCC.pas',
   uContestWAG in '..\..\src\contestFactory\uContestWAG.pas',
   uContestWWDigi in '..\..\src\contestFactory\uContestWWDigi.pas',
   uContestCQ160CW in '..\..\src\contestFactory\uContestCQ160CW.pas',
   uContestCQ160SSB in '..\..\src\contestFactory\uContestCQ160SSB.pas',
   uContestUBACW in '..\..\src\contestFactory\uContestUBACW.pas',
   uContestUBASSB in '..\..\src\contestFactory\uContestUBASSB.pas',
   uContestARRLRTTYRoundup in '..\..\src\contestFactory\uContestARRLRTTYRoundup.pas',
   uContestCWOps in '..\..\src\contestFactory\uContestCWOps.pas',
   uContestNAQPCW in '..\..\src\contestFactory\uContestNAQPCW.pas',
   uContestNAQPSSB in '..\..\src\contestFactory\uContestNAQPSSB.pas',
   uContestNAQPRTTY in '..\..\src\contestFactory\uContestNAQPRTTY.pas',
   uContestNCCCSprint in '..\..\src\contestFactory\uContestNCCCSprint.pas',
   uContestUkrainianDX in '..\..\src\contestFactory\uContestUkrainianDX.pas',
   uContestOKDX in '..\..\src\contestFactory\uContestOKDX.pas',
   uContestLZDX in '..\..\src\contestFactory\uContestLZDX.pas',
   uContestBataviaFT8 in '..\..\src\contestFactory\uContestBataviaFT8.pas',
   uContestCroatian in '..\..\src\contestFactory\uContestCroatian.pas',
   uContestCanadaDay in '..\..\src\contestFactory\uContestCanadaDay.pas',
   uContestCanadaWinter in '..\..\src\contestFactory\uContestCanadaWinter.pas',
   uContestSACCW in '..\..\src\contestFactory\uContestSACCW.pas',
   uContestSACSSB in '..\..\src\contestFactory\uContestSACSSB.pas',
   uContestLABRE in '..\..\src\contestFactory\uContestLABRE.pas',
   uContestRussianDX in '..\..\src\contestFactory\uContestRussianDX.pas',
   uContestRU3AXMemorial in '..\..\src\contestFactory\uContestRU3AXMemorial.pas',
   uContestCupRFCW in '..\..\src\contestFactory\uContestCupRFCW.pas',
   uContestCupRFSSB in '..\..\src\contestFactory\uContestCupRFSSB.pas',
   uContestCupRFDIG in '..\..\src\contestFactory\uContestCupRFDIG.pas',
   uContestRFChampionshipCW in '..\..\src\contestFactory\uContestRFChampionshipCW.pas',
   uContestRFChampionshipSSB in '..\..\src\contestFactory\uContestRFChampionshipSSB.pas',
   uContestDARCWAEDCCW in '..\..\src\contestFactory\uContestDARCWAEDCCW.pas',
   uContestDARCWAEDCSSB in '..\..\src\contestFactory\uContestDARCWAEDCSSB.pas',
   uContestOZHCRVHF in '..\..\src\contestFactory\uContestOZHCRVHF.pas',
   uContestALRSUA1DZCup in '..\..\src\contestFactory\uContestALRSUA1DZCup.pas',
   uContestSevenQP in '..\..\src\contestFactory\uContestSevenQP.pas',
   uContestAllAsianCW in '..\..\src\contestFactory\uContestAllAsianCW.pas',
   uContestAllAsianSSB in '..\..\src\contestFactory\uContestAllAsianSSB.pas',
   uContestARCI in '..\..\src\contestFactory\uContestARCI.pas',
   uContestARIDX in '..\..\src\contestFactory\uContestARIDX.pas',
   uContestARRL10 in '..\..\src\contestFactory\uContestARRL10.pas',
   uContestARRL160 in '..\..\src\contestFactory\uContestARRL160.pas',
   uContestARRLVHFJan in '..\..\src\contestFactory\uContestARRLVHFJan.pas',
   uContestARRLVHFJun in '..\..\src\contestFactory\uContestARRLVHFJun.pas',
   uContestARRLVHFSep in '..\..\src\contestFactory\uContestARRLVHFSep.pas',
   uContestBaltic in '..\..\src\contestFactory\uContestBaltic.pas',
   uContestBWQP in '..\..\src\contestFactory\uContestBWQP.pas',
   uContestCIS in '..\..\src\contestFactory\uContestCIS.pas',
   uContestCQM in '..\..\src\contestFactory\uContestCQM.pas',
   uContestCQVHF in '..\..\src\contestFactory\uContestCQVHF.pas',
   uContestCQWPXRTTY in '..\..\src\contestFactory\uContestCQWPXRTTY.pas',
   uContestCQWWRTTY in '..\..\src\contestFactory\uContestCQWWRTTY.pas',
   uContestEUSprintSpringCW in '..\..\src\contestFactory\uContestEUSprintSpringCW.pas',
   uContestEUSprintSpringSSB in '..\..\src\contestFactory\uContestEUSprintSpringSSB.pas',
   uContestEUSprintAutumnCW in '..\..\src\contestFactory\uContestEUSprintAutumnCW.pas',
   uContestEUSprintAutumnSSB in '..\..\src\contestFactory\uContestEUSprintAutumnSSB.pas',
   uContestEuropeanVHF in '..\..\src\contestFactory\uContestEuropeanVHF.pas',
   uContestTesla in '..\..\src\contestFactory\uContestTesla.pas',
   uContestFISTS in '..\..\src\contestFactory\uContestFISTS.pas',
   uContestGACWWWSACW in '..\..\src\contestFactory\uContestGACWWWSACW.pas',
   uContestGagarinCup in '..\..\src\contestFactory\uContestGagarinCup.pas',
   uContestHADX in '..\..\src\contestFactory\uContestHADX.pas',
   uContestYUDX in '..\..\src\contestFactory\uContestYUDX.pas',
   uContestURCDXRTTY in '..\..\src\contestFactory\uContestURCDXRTTY.pas',
   uContestGeorgiaQP in '..\..\src\contestFactory\uContestGeorgiaQP.pas',
   uContestHelvetia in '..\..\src\contestFactory\uContestHelvetia.pas',
   uContestJIDXCW in '..\..\src\contestFactory\uContestJIDXCW.pas',
   uContestJIDXSSB in '..\..\src\contestFactory\uContestJIDXSSB.pas',
   uContestJTDX in '..\..\src\contestFactory\uContestJTDX.pas',
   uContestKCJ in '..\..\src\contestFactory\uContestKCJ.pas',
   uContestNewEnglandQP in '..\..\src\contestFactory\uContestNewEnglandQP.pas',
   uContestOceaniaDXCW in '..\..\src\contestFactory\uContestOceaniaDXCW.pas',
   uContestOceaniaDXSSB in '..\..\src\contestFactory\uContestOceaniaDXSSB.pas',
   uContestOldNewYear in '..\..\src\contestFactory\uContestOldNewYear.pas',
   uContestOZCRO in '..\..\src\contestFactory\uContestOZCRO.pas',
   uContestOZCRZ in '..\..\src\contestFactory\uContestOZCRZ.pas',
   uContestRadioVHFFD in '..\..\src\contestFactory\uContestRadioVHFFD.pas',
   uContestRAEM in '..\..\src\contestFactory\uContestRAEM.pas',
   uContestRDA in '..\..\src\contestFactory\uContestRDA.pas',
   uContestRegion1FieldDay in '..\..\src\contestFactory\uContestRegion1FieldDay.pas',
   uContestRegion1FieldDayRCCCW in '..\..\src\contestFactory\uContestRegion1FieldDayRCCCW.pas',
   uContestRegion1FieldDayRCCSSB in '..\..\src\contestFactory\uContestRegion1FieldDayRCCSSB.pas',
   uContestRFASChampionshipCW in '..\..\src\contestFactory\uContestRFASChampionshipCW.pas',
   uContestRSGBRoPoCoCW in '..\..\src\contestFactory\uContestRSGBRoPoCoCW.pas',
   uContestRSGBRoPoCoSSB in '..\..\src\contestFactory\uContestRSGBRoPoCoSSB.pas',
   uContestYBDX in '..\..\src\contestFactory\uContestYBDX.pas',
   uContestSouthAmericanWW in '..\..\src\contestFactory\uContestSouthAmericanWW.pas',
   uContestSPDX in '..\..\src\contestFactory\uContestSPDX.pas',
   uContestStewPerry in '..\..\src\contestFactory\uContestStewPerry.pas',
   uContestTenTen in '..\..\src\contestFactory\uContestTenTen.pas',
   uContestTOEC in '..\..\src\contestFactory\uContestTOEC.pas',
   uContestUCG in '..\..\src\contestFactory\uContestUCG.pas',
   uContestWWL in '..\..\src\contestFactory\uContestWWL.pas',
   uContestWWPMC in '..\..\src\contestFactory\uContestWWPMC.pas',
   uContestYODX in '..\..\src\contestFactory\uContestYODX.pas',
   uContestUNDX in '..\..\src\contestFactory\uContestUNDX.pas',
   uContestKingOfSpainCW in '..\..\src\contestFactory\uContestKingOfSpainCW.pas',
   uContestKingOfSpainSSB in '..\..\src\contestFactory\uContestKingOfSpainSSB.pas',
   uContestWRTC in '..\..\src\contestFactory\uContestWRTC.pas',
   uContestR9WUW9WKMemorial in '..\..\src\contestFactory\uContestR9WUW9WKMemorial.pas',
   uContestRadioMemory in '..\..\src\contestFactory\uContestRadioMemory.pas',
   uContestREFCW in '..\..\src\contestFactory\uContestREFCW.pas',
   uContestREFSSB in '..\..\src\contestFactory\uContestREFSSB.pas',
   uContestBSCI in '..\..\src\contestFactory\uContestBSCI.pas',
   uContestCQMM in '..\..\src\contestFactory\uContestCQMM.pas',
   uContestCWOpen in '..\..\src\contestFactory\uContestCWOpen.pas',
   uContestMakrothen in '..\..\src\contestFactory\uContestMakrothen.pas',
   uContestWWIH in '..\..\src\contestFactory\uContestWWIH.pas',
   uContestRadioYOC in '..\..\src\contestFactory\uContestRadioYOC.pas',
   uContestOKOMSSB in '..\..\src\contestFactory\uContestOKOMSSB.pas',
   uContestMWC in '..\..\src\contestFactory\uContestMWC.pas',
   uContestIRTS in '..\..\src\contestFactory\uContestIRTS.pas',
   uContestEUDX in '..\..\src\contestFactory\uContestEUDX.pas',
   uContestYOTA in '..\..\src\contestFactory\uContestYOTA.pas',
   uContestSST in '..\..\src\contestFactory\uContestSST.pas',
   uContestRTC in '..\..\src\contestFactory\uContestRTC.pas',
   uContestPOTA in '..\..\src\contestFactory\uContestPOTA.pas',
   uContestUA4WChampionship in '..\..\src\contestFactory\uContestUA4WChampionship.pas',
   uContestRSGB18 in '..\..\src\contestFactory\uContestRSGB18.pas',
   uRFChampionshipPoints in '..\..\src\uRFChampionshipPoints.pas',
   uExchangeTokens in '..\..\src\uExchangeTokens.pas',
   uTestContestFactory in 'uTestContestFactory.pas',
   uTestContestExport in 'uTestContestExport.pas',
   uTestContestImport in 'uTestContestImport.pas',
   uTestContestParse in 'uTestContestParse.pas',
   uTestContestTotals in 'uTestContestTotals.pas',
   uTestContestObjects in 'uTestContestObjects.pas',
   uTestLogCapture in 'uTestLogCapture.pas',
   uTestRegisteredContests in 'uTestRegisteredContests.pas',
   uTestContestStatesItsRules in 'uTestContestStatesItsRules.pas',
   (* A CONTEST REGISTERED BY ITS STRING ID, AND ONLY HERE (Q108 S3). The
      fixture has no ContestType member; it must never be in tr4w.lpr --
      Lint-ContestUnitsLinked fails the build if it is. *)
   uContestTestFixture in 'uContestTestFixture.pas',
   uTestContestById in 'uTestContestById.pas',
   uTestContestMultipliers in 'uTestContestMultipliers.pas',
   uTestContestSession in 'uTestContestSession.pas',
   uTestContestDisplay in 'uTestContestDisplay.pas',
   uTestRadioLinkRetry in 'uTestRadioLinkRetry.pas',
   (* THE STATUS/NOTICE SPLIT.  It streams uMainForm.lfm -- a designed form
     verified by rebuilding it in code is not verified at all -- so it reaches
     the LCL, which this binary already links. *)
   uTestStatusAndNotice in 'uTestStatusAndNotice.pas',
   (* THE NEW CONTEST DIALOG'S TITLE NAMES THE BUILD.  Streams
     uNewContestForm.lfm and fires its OnShow; the form arrives here for the
     first time, the LCL it needs is already linked. *)
   uNewContestForm      in '..\..\src\ui\lcl\uNewContestForm.pas',
   uTestNewContestForm  in 'uTestNewContestForm.pas',
   (* THE WSJT-X CQ DECODE'S THREAD HAND-OFF.  Links MainUnit, which already
     brings uWSJTX in; no new dependency. *)
   uTestWSJTXThreading in 'uTestWSJTXThreading.pas',
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
   uTestCPUKeyerRing in 'uTestCPUKeyerRing.pas',
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
   uTestComPortEnumerator in 'uTestComPortEnumerator.pas',
   uTestPortAddress in 'uTestPortAddress.pas',
   uTestSerialDiagnosis in 'uTestSerialDiagnosis.pas',
   uTestSettingsModel in 'uTestSettingsModel.pas',
   uTestSettingsConvert in 'uTestSettingsConvert.pas',
   uSettingsConvert in '..\..\src\uSettingsConvert.pas',
   uTestSettingsPrecedence in 'uTestSettingsPrecedence.pas',
   uTestTLSRefusal in 'uTestTLSRefusal.pas',
   uTestConfigDefaults in 'uTestConfigDefaults.pas',
   uTestTransverterOffset in 'uTestTransverterOffset.pas',
   uTestRadioSupportsCaps in 'uTestRadioSupportsCaps.pas',
   uTestRadioSocketProbe in 'uTestRadioSocketProbe.pas',
   uIcomNetworkTypes    in '..\..\src\uIcomNetworkTypes.pas',
   uIcomNetworkTransport in '..\..\src\uIcomNetworkTransport.pas',
   uTestIcomTeardown    in 'uTestIcomTeardown.pas',
   uTestHamLibIDs       in 'uTestHamLibIDs.pas',
   uTestDXClusterClient in 'uTestDXClusterClient.pas',
   uNetFraming in '..\..\src\uNetFraming.pas',
   uTestNetFraming in 'uTestNetFraming.pas',
   uDXSpotParse         in '..\..\src\uDXSpotParse.pas',
   uSpotAge             in '..\..\src\uSpotAge.pas',
   uTelnetTrace         in '..\..\src\uTelnetTrace.pas',
   uCrashLog            in '..\..\src\uCrashLog.pas',
   Version              in '..\..\src\Version.pas',
   uHPTimer             in '..\..\src\utils\uHPTimer.pas',
   uTestHPTimer         in 'uTestHPTimer.pas',
   uKeychain         in '..\..\src\uKeychain.pas',
   uWindowSnap          in '..\..\src\uWindowSnap.pas',
   uClusterTokens       in '..\..\src\uClusterTokens.pas',
   uTestDXSpotParse     in 'uTestDXSpotParse.pas',
   uTestSpotAge         in 'uTestSpotAge.pas',
   uTestSpotStore       in 'uTestSpotStore.pas',
   uTestTelnetTrace     in 'uTestTelnetTrace.pas',
   uTestCrashContext    in 'uTestCrashContext.pas',
   uTestKeychain     in 'uTestKeychain.pas',
   uTestWindowSnap      in 'uTestWindowSnap.pas',
   uAppPaths            in '..\..\src\uAppPaths.pas',
   uDomFileKeys         in '..\..\src\uDomFileKeys.pas',
   uContestNames        in '..\..\src\uContestNames.pas',
   uTLSTrust            in '..\..\src\utils\uTLSTrust.pas',
   uHTTPDownload        in '..\..\src\utils\uHTTPDownload.pas',
   uLogBinaryFile       in '..\..\src\uLogBinaryFile.pas',
   uTestLogBinaryFile   in 'uTestLogBinaryFile.pas',
   uLogSchema           in '..\..\src\domain\uLogSchema.pas',
uContestFileKind           in '..\..\src\domain\uContestFileKind.pas',
   uLogRepository       in '..\..\src\uLogRepository.pas',
   uTestLogRepository   in 'uTestLogRepository.pas',
   uLogContestStatements in '..\..\src\uLogContestStatements.pas',
   uTestLogContestStatements in 'uTestLogContestStatements.pas',
   uLogNote             in '..\..\src\domain\uLogNote.pas',
   uTestLogNote         in 'uTestLogNote.pas',
   uTestLogNaming       in 'uTestLogNaming.pas',
uTestContestFileKind       in 'uTestContestFileKind.pas',
   uLogImport           in '..\..\src\uLogImport.pas',
   uTestLogImport       in 'uTestLogImport.pas',
   (* uLogStore itself, through its entry points -- a write never assumes the
      .TRW already holds it. *)
   uTestLogStore        in 'uTestLogStore.pas',
   uLogDatabase         in '..\..\src\domain\uLogDatabase.pas',
   uTestLogDatabase     in 'uTestLogDatabase.pas',
   uLogBackup           in '..\..\src\domain\uLogBackup.pas',
   uTestLogBackup       in 'uTestLogBackup.pas',
   uQsoMyFacts          in '..\..\src\domain\uQsoMyFacts.pas',
   uTestLogMyFacts      in 'uTestLogMyFacts.pas',
   uTestScoringMyFacts  in 'uTestScoringMyFacts.pas',
   uNewContestCommands  in '..\..\src\uNewContestCommands.pas',
   uTestNewContestCommands in 'uTestNewContestCommands.pas',
   (* Design 7.12: a station fact is a default a contest may override. *)
   uTestStationFactOverrides in 'uTestStationFactOverrides.pas',
   (* M9b: the New Contest drop-down's list, and a CATEGORY-POWER change. *)
   uContestChoices      in '..\..\src\uContestChoices.pas',
   (* The New Contest dialog's Last Contest button: the log read without
      adopting it, and the caption fitted to the button. *)
   uLogFileFacts        in '..\..\src\domain\uLogFileFacts.pas',
   uLatestContest       in '..\..\src\uLatestContest.pas',
   uTestLatestContest   in 'uTestLatestContest.pas',
   uCategoryPowerChange in '..\..\src\uCategoryPowerChange.pas',
   uTestContestUI       in 'uTestContestUI.pas',
   (* M10 S8: every contest's identity values, frozen as literals when the
      tables were deleted. *)
   uTestContestIdentityPin in 'uTestContestIdentityPin.pas',
   (* M11 S0b: every contest's six session kinds at every matrix station,
      frozen as literals before the kinds move into the classes. *)
   uTestContestKindPin  in 'uTestContestKindPin.pas',
   (* M11 S3: every prefix contest's key, at stations the matrix does not
      run, frozen against the old SetPrefix before the rule moved. *)
   uTestPrefixMultiplierKey in 'uTestPrefixMultiplierKey.pas',
   (* M11 S4: every DX contest's key, country mode and remaining-countries
      filter, at stations the matrix does not run, frozen against the old
      GetDXQTH / country-mode set / FillVisibleBytes before the rule moved. *)
   uTestDXMultiplierKey in 'uTestDXMultiplierKey.pas',
   (* M11 S5: every zone contest's zone count, zone list and zero-based
      numbering, at stations the matrix does not run (a JA entrant), frozen
      against the old session-kind readers before the rule moved. *)
   uTestZoneMultiplier  in 'uTestZoneMultiplier.pas',
   (* P7: the Super Check Partial cell buffer, over the matrix's TRMASTER fixture. *)
   uTestLogSCP          in 'uTestLogSCP.pas',
   (* M11 S6 part 1: every contest's domestic QTH rule that is not the
      domestic file, its hint and its four yes/no answers, at stations the
      matrix does not run, frozen against the old GetDomQTH, DomStringParse
      and session-kind tests before the rules moved. *)
   uTestDomesticMultiplier in 'uTestDomesticMultiplier.pas',
   (* M11 S7: the exchange RULES the engine decided by the session shape
      -- the rover county, several QTHs, a blank exchange, CQ WW RTTY's
      state, the park lookup, the FISTS score -- frozen against the old
      compares before they moved. *)
   uTestExchangeRules   in 'uTestExchangeRules.pas',
   (* M11 S9a: every contest's received-exchange field list, at stations
      the matrix does not run, frozen against the old
      SetUpExchangeInformation before it moved into the classes. *)
   uTestExchangeFields  in 'uTestExchangeFields.pas',
   (* M11 S9b: every contest's ADIF STX_STRING at every roster station,
      frozen against the old FormatADIFExchangeOfKind before it moved into
      the classes. *)
   uTestADIFSentExchange in 'uTestADIFSentExchange.pas',
   (* 2026-10-17: every contest's ADIF exchange tags are exactly the ones its
      own ReceivedExchangeFields declares (TContestBase.EmitADIFReceivedFields). *)
   uTestADIFReceivedFields in 'uTestADIFReceivedFields.pas',
   (* M11 S9c: every contest's two Cabrillo exchange columns at every roster
      station, frozen against the old FormatCabrilloExchangeOfKind before it
      moved into the classes. *)
   uTestCabrilloColumns in 'uTestCabrilloColumns.pas',
   (* M11 S9d: how every contest parses a typed exchange at every roster
      station -- which engine parser it asks for and every rule around it --
      frozen against the old ParseExchangeShape before it moved into the
      classes. *)
   uTestExchangeParse in 'uTestExchangeParse.pas',
   (* M11 S9d: the engine's parsers as a stub the parse tests share -- each
      installs what its parsers "do" and sees which one a contest asked for,
      by name. *)
   uTestExchangeParserStub in 'uTestExchangeParserStub.pas',
   (* M11 S9e part 1: the last three readers of the session's exchange kind
      outside the initial exchange -- the Sweepstakes log columns, the default
      CW exchange messages set-up writes, and whether an exchange word may be
      a grid square -- frozen against the old kind tests before they moved
      into the classes. *)
   uTestExchangeKindReaders in 'uTestExchangeKindReaders.pas',
   (* POTA as a contest class (design Q6, 2026-10-13). *)
   uTestContestPOTA     in 'uTestContestPOTA.pas',
   (* Q62: the CTY entity -> ADIF DXCC table, held to the shipped cty.dat. *)
   uTestDXCCEntities    in 'uTestDXCCEntities.pas',
   (* The Delaware QSO Party, a new contest (design 7.14, 8.2q). *)
   uTestContestDelawareQP in 'uTestContestDelawareQP.pas',
   (* The Nebraska QSO Party, a new contest, and the New England rename
      with its legacy name (design Q105, 2026-10-16). *)
   uTestContestNebraskaQP in 'uTestContestNebraskaQP.pas',
   (* The URC DX RTTY Contest, the first real contest registered by its id
      (Q138, 2026-10-22). *)
   uTestContestURCDXRTTY in 'uTestContestURCDXRTTY.pas',
   (* The Georgia QSO Party, a new contest registered by its id
      (2026-10-23). *)
   uTestContestGeorgiaQP in 'uTestContestGeorgiaQP.pas',
   (* The New England QSO Party's 2026-10-23 sponsor rules: digital points,
      no DX cap, 14 provinces, DC as MD, digital dupes as CW. *)
   uTestContestNewEnglandQP in 'uTestContestNewEnglandQP.pas',
   (* The RTC's 2026 rules: dupes per band AND mode, grids per band
      (2026-10-23). *)
   uTestContestRTC      in 'uTestContestRTC.pas',
   (* The Field Days' "Invalid ARRL Section" names its reason, through the
      one domestic-QTH refusal (2026-10-23). *)
   uTestFieldDaySectionRefusal in 'uTestFieldDaySectionRefusal.pas',
   uTestContestNames    in 'uTestContestNames.pas',
   (* Every QSO party's stated bands (NY4I, 2026-10-16). *)
   uTestQSOPartyBands   in 'uTestQSOPartyBands.pas',
   (* IN7QPNE, the composite of four parties (design 7.14, 8.2r). *)
   uTestContestIN7QPNE in 'uTestContestIN7QPNE.pas',
   (* NY4I's rulings Q45, Q49, Q84, Q71, Q85 and Q104, built 2026-10-17. *)
   uTestContestRulings2026Oct in 'uTestContestRulings2026Oct.pas',
   (* Q47: three read-past-the-end shapes bounded (MWC, Region 1 FD, RCC). *)
   uTestContestReadBounds in 'uTestContestReadBounds.pas',
   (* The Russian DX Contest's 2027 rules and the Popov Youth Cup's SRR 2026
      regulation (Q97, Q131-Q136, built 2026-10-22). *)
   uTestContestRussianRules2026Oct in 'uTestContestRussianRules2026Oct.pas',
   (* A QSO party's host-area rule, typed AND scored (Q107, 2026-10-16). *)
   uTestHostAreaRule    in 'uTestHostAreaRule.pas',
   (* A grid contest's exchange requires the grid, and a bad grid word is
      refused, never dropped (Q115, NY4I 2026-10-18). *)
   uTestGridExchange    in 'uTestGridExchange.pas',
   (* A .dom loaded into a table that already holds one (LOGDOM's emptying
      loop read through nil at the end of every list, D7 included). *)
   uTestDomQTHTableReload in 'uTestDomQTHTableReload.pas',
   (* Shipped .dom files against their sponsor's list: LABRE's 28 codes and
      HQ, EUDX's regions only (UDC cross-walk leads, 2026-10-19). *)
   uTestShippedDomLists in 'uTestShippedDomLists.pas',
   (* ZONECONT's domestic COUNTRY list, once a hand-built linked list:
      order, duplicates, case, width, and the reset (pointer audit P5). *)
   uTestDomesticCountryList in 'uTestDomesticCountryList.pas',
   uTestSettingsFreshInstall in 'uTestSettingsFreshInstall.pas',
   uTestLegacyConversionCheck in 'uTestLegacyConversionCheck.pas',
   uLegacyConversionCheck in '..\..\src\uLegacyConversionCheck.pas',
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
   RegisterSuite(TN1MMModeTests.Create('N1MMMode'));
   RegisterSuite(TUDPContactXmlTests.Create('UDPContactXml'));
   RegisterSuite(TUDPDatagramTests.Create('UDPDatagrams'));
   RegisterSuite(TIcomCIVTests.Create('IcomCIV'));
   RegisterSuite(TRadioBandTests.Create('RadioBand'));
   RegisterSuite(TComboTagTests.Create('ComboTags'));
   RegisterSuite(TFlexRadioUtilsTests.Create('FlexRadioUtils'));
   RegisterSuite(TStringCompareTests.Create('StringCompare'));
   RegisterSuite(TShortStringConversionTests.Create('ShortStringConversion'));
   RegisterSuite(TAudioTests.Create('Audio'));
   RegisterSuite(TRegexValidatorTests.Create('RegexValidators'));
   RegisterSuite(TUtilsTextTests.Create('UtilsText'));
   RegisterSuite(TLog4DFileAppenderTests.Create('Log4DFileAppender'));
   RegisterSuite(TADIFLexerTests.Create('ADIFLexer'));
   RegisterSuite(TADIFHelperTests.Create('ADIFHelpers'));
   RegisterSuite(TADIFMappingTests.Create('ADIFMapping'));
   RegisterSuite(TADIFFixtureTests.Create('ADIFFixtures'));
   RegisterSuite(TBandLookupTests.Create('BandLookup'));
   RegisterSuite(TCabrilloFormatTests.Create('CabrilloFormat'));
   RegisterSuite(TCabrilloExchangeTests.Create('CabrilloExchange'));
   RegisterSuite(TContestExportTests.Create('ContestExport'));
   RegisterSuite(TContestImportTests.Create('ContestImport'));
   RegisterSuite(TContestParseTests.Create('ContestParse'));
   RegisterSuite(TContestTotalsTests.Create('ContestTotals'));
   RegisterSuite(TContestMultipliersTests.Create('ContestMultipliers'));
   RegisterSuite(TContestSessionTests.Create('ContestSession'));
   RegisterSuite(TContestDisplayTests.Create('ContestDisplay'));
   RegisterSuite(TContestStatesItsRulesTests.Create('ContestStatesItsRules'));
   RegisterSuite(TContestByIdTests.Create('ContestById'));
   RegisterSuite(TContestUITests.Create('ContestUI'));
   RegisterSuite(TContestIdentityPinTests.Create('ContestIdentityPin'));
   RegisterSuite(TContestKindPinTests.Create('ContestKindPin'));
   RegisterSuite(TPrefixMultiplierKeyTests.Create('PrefixMultiplierKey'));
   RegisterSuite(TDXMultiplierKeyTests.Create('DXMultiplierKey'));
   RegisterSuite(TZoneMultiplierTests.Create('ZoneMultiplier'));
   RegisterSuite(TDomesticMultiplierTests.Create('DomesticMultiplier'));
   RegisterSuite(TExchangeRuleTests.Create('ExchangeRules'));
   RegisterSuite(TExchangeFieldsTests.Create('ExchangeFields'));
   RegisterSuite(TADIFSentExchangeTests.Create('ADIFSentExchange'));
   RegisterSuite(TADIFReceivedFieldsTests.Create('ADIFReceivedFields'));
   RegisterSuite(TCabrilloColumnsTests.Create('CabrilloColumns'));
   RegisterSuite(TExchangeParseTests.Create('ExchangeParse'));
   RegisterSuite(TExchangeKindReadersTests.Create('ExchangeKindReaders'));
   RegisterSuite(TContestPOTATests.Create('ContestPOTA'));
   RegisterSuite(TDXCCEntitiesTests.Create('DXCCEntities'));
   RegisterSuite(TContestDelawareQPTests.Create('ContestDelawareQP'));
   RegisterSuite(TContestNebraskaQPTests.Create('ContestNebraskaQP'));
   RegisterSuite(TContestURCDXRTTYTests.Create('ContestURCDXRTTY'));
   RegisterSuite(TContestGeorgiaQPTests.Create('ContestGeorgiaQP'));
   RegisterSuite(TContestNewEnglandQPTests.Create('ContestNewEnglandQP'));
   RegisterSuite(TContestRTCTests.Create('ContestRTC'));
   RegisterSuite(TFieldDaySectionRefusalTests.Create('FieldDaySectionRefusal'));
   RegisterSuite(TContestNamesTests.Create('ContestNames'));
   RegisterSuite(TQSOPartyBandsTests.Create('QSOPartyBands'));
   RegisterSuite(TContestIN7QPNETests.Create('ContestIN7QPNE'));
   RegisterSuite(TContestRulings2026OctTests.Create('ContestRulings2026Oct'));
   RegisterSuite(TContestReadBoundsTests.Create('ContestReadBounds'));
   RegisterSuite(TContestRussianRules2026OctTests.Create('ContestRussianRules2026Oct'));
   RegisterSuite(THostAreaRuleTests.Create('HostAreaRule'));
   RegisterSuite(TGridExchangeTests.Create('GridExchange'));
   RegisterSuite(TDomQTHTableReloadTests.Create('DomQTHTableReload'));
   RegisterSuite(TShippedDomListsTests.Create('ShippedDomLists'));
   RegisterSuite(TDomesticCountryListTests.Create('DomesticCountryList'));
   RegisterSuite(TCRC32Tests.Create('CRC32'));
   RegisterSuite(TCRC16Tests.Create('CRC16'));
   RegisterSuite(TWinKeyWireTests.Create('WinKeyWire'));
   RegisterSuite(TLogSCPTests.Create('LogSCP'));
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
   RegisterSuite(TContestReadinessTests.Create('ContestReadiness'));
   RegisterSuite(TMultsTests.Create('Mults'));
   RegisterSuite(TSortedStringListTests.Create('SortedStringList'));
   RegisterSuite(TCallsignsListTests.Create('CallsignsList'));
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
   RegisterSuite(TRadioSocketProbeTests.Create('RadioSocketProbe'));
   RegisterSuite(TTransverterOffsetTests.Create('TransverterOffset'));
   RegisterSuite(TComPortEnumeratorTests.Create('ComPortEnumerator'));
   RegisterSuite(TPortAddressTests.Create('PortAddress'));
   RegisterSuite(TSerialDiagnosisTests.Create('SerialDiagnosis'));
   RegisterSuite(TSettingsModelTests.Create('SettingsModel'));
   RegisterSuite(TSettingsConvertTests.Create('SettingsConvert'));
   RegisterSuite(TSettingsPrecedenceTests.Create('SettingsPrecedence'));
   RegisterSuite(TTLSRefusalTests.Create('TLSRefusal'));
   RegisterSuite(TConfigDefaultsTests.Create('ConfigDefaults'));
   RegisterSuite(THamLibIDTests.Create('HamLibIDs'));
   RegisterSuite(TCWKeyerTests.Create('CWKeyer'));
   RegisterSuite(TCPUKeyerRingTests.Create('CPUKeyerRing'));
   RegisterSuite(TSHA256Tests.Create('SHA256'));
   RegisterSuite(TCWFramingTests.Create('CWFraming'));
   RegisterSuite(TContestFactoryTests.Create('ContestFactory'));
   RegisterSuite(TOffBandCreditTests.Create('OffBandCredit'));
   RegisterSuite(TAutomaticXQSOTests.Create('AutomaticXQSO'));
   RegisterSuite(TMalformedGridTests.Create('MalformedGrid'));
   RegisterSuite(TRoverDupeKeyTests.Create('RoverDupeKey'));
   RegisterSuite(TNYQPRoverTests.Create('NYQPRover'));
   RegisterSuite(TOperatorCQMemoryTests.Create('OperatorCQMemory'));
   RegisterSuite(TRadioLinkRetryTests.Create('RadioLinkRetry'));
   RegisterSuite(TStatusAndNoticeTests.Create('StatusAndNotice'));
   RegisterSuite(TNewContestFormTests.Create('NewContestForm'));
   RegisterSuite(TLatestContestTests.Create('LatestContest'));
   RegisterSuite(TWSJTXThreadingTests.Create('WSJTXThreading'));
   RegisterSuite(TAcceleratorTests.Create('Accelerators'));
   RegisterSuite(TMenuShortcutTests.Create('MenuShortcuts'));
   RegisterSuite(TEditingKeysTests.Create('EditingKeys'));
   RegisterSuite(TPrefsSearchTests.Create('PrefsSearch'));
   RegisterSuite(TRadioStatusTests.Create('RadioStatus'));
   RegisterSuite(TElecraftIFTests.Create('ElecraftIF'));
   RegisterSuite(TAutoInfoTests.Create('AutoInfo'));
   RegisterSuite(TSettingsRegistryTests.Create('SettingsRegistry'));
   RegisterSuite(TAllSettingsTests.Create('AllSettings'));
   RegisterSuite(TRotatorFactoryTests.Create('RotatorFactory'));
   RegisterSuite(TDXClusterClientTests.Create('DXClusterClient'));
   RegisterSuite(TDXSpotParseTests.Create('DXSpotParse'));
   RegisterSuite(TSpotAgeTests.Create('SpotAge'));
   RegisterSuite(TSpotStoreTests.Create('SpotStore'));
   RegisterSuite(TTelnetTraceTests.Create('TelnetTrace'));
   RegisterSuite(TCrashContextTests.Create('CrashContext'));
   RegisterSuite(THPTimerTests.Create('HPTimer'));
   RegisterSuite(TLogNoteTests.Create('LogNote'));
   RegisterSuite(TKeychainTests.Create('Keychain'));
   RegisterSuite(TTestWindowSnap.Create('WindowSnap'));
   RegisterSuite(TLogBinaryFileTests.Create('LogBinaryFile'));
   RegisterSuite(TLogDatabaseTests.Create('LogDatabase'));
   RegisterSuite(TLogBackupTests.Create('LogBackup'));
   RegisterSuite(TNewContestCommandsTests.Create('NewContestCommands'));
   RegisterSuite(TStationFactOverrideTests.Create('StationFactOverrides'));
   RegisterSuite(TSettingsFreshInstallTests.Create('SettingsFreshInstall'));
   RegisterSuite(TLegacyConversionCheckTests.Create('LegacyConversionCheck'));
   RegisterSuite(TUILanguageTests.Create('UILanguage'));
   RegisterSuite(TLogRepositoryTests.Create('LogRepository'));
   RegisterSuite(TLogContestStatementsTests.Create('LogContestStatements'));
   RegisterSuite(TLogNamingTests.Create('LogNaming'));
   RegisterSuite(TContestFileKindTests.Create('ContestFileKind'));
   RegisterSuite(TLogImportTests.Create('LogImport'));
   RegisterSuite(TLogStoreTests.Create('LogStore'));
   RegisterSuite(TLogMyFactsTests.Create('LogMyFacts'));
   RegisterSuite(TScoringMyFactsTests.Create('ScoringMyFacts'));
   RegisterSuite(TClusterTokensTests.Create('ClusterTokens'));
   RegisterSuite(TSplitReassertTests.Create('SplitReassert'));
   RegisterSuite(TCWByCATTimerTests.Create('CWByCATTimer'));
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

   (* A CRASHING TEST USED TO REPORT AN ADDRESS AND NOTHING ELSE.

     FPC's default handler prints SExceptionErrorMessage -- literally
     "Exception at %p: %s" -- and no backtrace, so a suite that faults gives

         Exception at 0000000100E2A3A4: EAccessViolation:
         Access violation.

     and the reader is left with a runtime address from an ASLR'd binary. That
     is barely more useful than nothing, and it is worst exactly where it
     matters most: on a platform you cannot attach a debugger to. macOS refuses
     lldb over ssh without DevToolsSecurity, and that needs a password.

     BOTH BUILDS ALREADY PASS -gl, so the line-info unit is linked and the
     addresses CAN be resolved to file and line -- nothing was asking. This
     asks. DumpExceptionBackTrace walks the frames the exception was raised
     through and prints each as unit, line and address.

     THE EXIT CODE IS STILL 1 AND THE MESSAGE STILL SAYS FAILURE. A crash is a
     failure; this only makes it a legible one. *)
   try
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
   except
      on E: Exception do
         begin
         WriteLn('');
         WriteLn('CRASHED: ', E.ClassName, ': ', E.Message);
         WriteLn('  The suite that was running is the last one named above,');
         WriteLn('  and the test is the one after its last [PASS].');
         WriteLn('');
         WriteLn('Backtrace:');
         DumpExceptionBackTrace(Output);
         WriteLn('');
         WriteLn('FAILURES detected — see above.');
         ExitCode := 1;
         end;
   end;
end.
