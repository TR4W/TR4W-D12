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
   SysUtils,
   Log4D,
   MainUnit,
   uTR4WTestFramework   in 'uTR4WTestFramework.pas',
   uIcomCIV             in '..\..\src\uIcomCIV.pas',
   uTestIcomCIV         in 'uTestIcomCIV.pas',
   uRadioBand           in '..\..\src\uRadioBand.pas',
   uTestRadioBand       in 'uTestRadioBand.pas',
   uFlexRadioUtils      in '..\..\src\uFlexRadioUtils.pas',
   uTestFlexRadioUtils  in 'uTestFlexRadioUtils.pas',
   VC                   in '..\..\src\VC.pas',
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
   uTestCabrilloExchange in 'uTestCabrilloExchange.pas',
   uCRC32               in '..\..\src\uCRC32.pas',
   uTestCRC32           in 'uTestCRC32.pas',
   utils_math           in '..\..\src\utils\utils_math.pas',
   uTestUtilsMath       in 'uTestUtilsMath.pas',
   uGridDistance        in '..\..\src\uGridDistance.pas',
   uTestGridDistance    in 'uTestGridDistance.pas',
   utils_file           in '..\..\src\utils\utils_file.pas',
   uTestUtilsFile       in 'uTestUtilsFile.pas',
   uTestADIFRegression  in 'uTestADIFRegression.pas',
   uFreqTimeFormat      in '..\..\src\uFreqTimeFormat.pas',
   uTestFreqTimeFormat  in 'uTestFreqTimeFormat.pas',
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
   uFactoryRadioBase    in '..\..\src\uFactoryRadioBase.pas',
   uRadioYaesuASCII     in '..\..\src\uRadioYaesuASCII.pas',
   uRadioYaesuFTDX10    in '..\..\src\uRadioYaesuFTDX10.pas',
   uRadioYaesuFT991     in '..\..\src\uRadioYaesuFT991.pas',
   uRadioYaesuFTDX101   in '..\..\src\uRadioYaesuFTDX101.pas',
   uRadioYaesuFT710     in '..\..\src\uRadioYaesuFT710.pas',
   uRadioYaesuFTX1F     in '..\..\src\uRadioYaesuFTX1F.pas',
   uRadioYaesuFT891     in '..\..\src\uRadioYaesuFT891.pas',
   uRadioYaesuASCIILegacy  in '..\..\src\uRadioYaesuASCIILegacy.pas',
   uRadioYaesuFT450     in '..\..\src\uRadioYaesuFT450.pas',
   uRadioYaesuFT950     in '..\..\src\uRadioYaesuFT950.pas',
   uRadioYaesuFT1200    in '..\..\src\uRadioYaesuFT1200.pas',
   uRadioYaesuFT2000    in '..\..\src\uRadioYaesuFT2000.pas',
   uRadioYaesuFTDX3000  in '..\..\src\uRadioYaesuFTDX3000.pas',
   uRadioYaesuFTDX5000  in '..\..\src\uRadioYaesuFTDX5000.pas',
   uRadioYaesuFTDX9000  in '..\..\src\uRadioYaesuFTDX9000.pas',
   // Old-binary family, listed EXPLICITLY -- see the note on uRadioIcomLegacy
   // above.  These were reaching this EXE only through uTestYaesuBinary's uses
   // clause, so any change there would have silently dropped their registrations.
   uRadioYaesuBinary    in '..\..\src\uRadioYaesuBinary.pas',
   uRadioYaesuFT1000MP  in '..\..\src\uRadioYaesuFT1000MP.pas',
   uRadioYaesuFT817     in '..\..\src\uRadioYaesuFT817.pas',
   uRadioYaesuFT847     in '..\..\src\uRadioYaesuFT847.pas',
   uRadioYaesuFT857     in '..\..\src\uRadioYaesuFT857.pas',
   uRadioYaesuFT990Group in '..\..\src\uRadioYaesuFT990Group.pas',
   uRadioYaesuFT990     in '..\..\src\uRadioYaesuFT990.pas',
   uRadioYaesuFT1000    in '..\..\src\uRadioYaesuFT1000.pas',
   uRadioYaesuFT840     in '..\..\src\uRadioYaesuFT840.pas',
   uRadioYaesuFT920     in '..\..\src\uRadioYaesuFT920.pas',
   uRadioYaesuFT100     in '..\..\src\uRadioYaesuFT100.pas',
   uRadioYaesuFT747     in '..\..\src\uRadioYaesuFT747.pas',
   uRadioYaesuFT767     in '..\..\src\uRadioYaesuFT767.pas',
   uTestYaesuASCII      in 'uTestYaesuASCII.pas',
   uTestYaesuBinary     in 'uTestYaesuBinary.pas',
   // Listed EXPLICITLY, not reached through another unit's uses clause: radios
   // self-register from their unit's initialization, so a unit that is only
   // linked transitively vanishes the moment that chain changes -- and its
   // radios silently disappear from the registry with no compile error.
   // Exactly that happened: uRadioIcomLegacyModels stopped using
   // uRadioIcomLegacy, and the IC-706 family fell out of this EXE.
   uRadioIcomLegacy in '..\..\src\uRadioIcomLegacy.pas',
   uRadioIcomReadLimited in '..\..\src\uRadioIcomReadLimited.pas',
   uRadioIcom78 in '..\..\src\uRadioIcom78.pas',
   uRadioIcom707 in '..\..\src\uRadioIcom707.pas',
   uRadioIcom725 in '..\..\src\uRadioIcom725.pas',
   uRadioIcom726 in '..\..\src\uRadioIcom726.pas',
   uRadioIcom728 in '..\..\src\uRadioIcom728.pas',
   uRadioIcom729 in '..\..\src\uRadioIcom729.pas',
   uRadioIcom735 in '..\..\src\uRadioIcom735.pas',
   uRadioIcom736 in '..\..\src\uRadioIcom736.pas',
   uRadioIcom737 in '..\..\src\uRadioIcom737.pas',
   uRadioIcom738 in '..\..\src\uRadioIcom738.pas',
   uRadioIcom746 in '..\..\src\uRadioIcom746.pas',
   uRadioIcom746PRO in '..\..\src\uRadioIcom746PRO.pas',
   uRadioIcom756 in '..\..\src\uRadioIcom756.pas',
   uRadioIcom756PRO in '..\..\src\uRadioIcom756PRO.pas',
   uRadioIcom756PROII in '..\..\src\uRadioIcom756PROII.pas',
   uRadioIcom756PROIII in '..\..\src\uRadioIcom756PROIII.pas',
   uRadioIcom761 in '..\..\src\uRadioIcom761.pas',
   uRadioIcom765 in '..\..\src\uRadioIcom765.pas',
   uRadioIcom775 in '..\..\src\uRadioIcom775.pas',
   uRadioIcom781 in '..\..\src\uRadioIcom781.pas',
   uRadioIcom910 in '..\..\src\uRadioIcom910.pas',
   uRadioIcom970D in '..\..\src\uRadioIcom970D.pas',
   uRadioIcom7200 in '..\..\src\uRadioIcom7200.pas',
   uRadioIcom7410 in '..\..\src\uRadioIcom7410.pas',
   uRadioIcom9100 in '..\..\src\uRadioIcom9100.pas',
   uRadioTenTecOmni6 in '..\..\src\uRadioTenTecOmni6.pas',
   uRadioIcom7700         in '..\..\src\uRadioIcom7700.pas',
   uRadioIcom7800         in '..\..\src\uRadioIcom7800.pas',
   uRadioIcom7850         in '..\..\src\uRadioIcom7850.pas',
   uRadioIcom7851         in '..\..\src\uRadioIcom7851.pas',
   uTestIcomRegistry    in 'uTestIcomRegistry.pas',
   // Flex is the only two-constructor registration; list its three units
   // explicitly so their initialization sections self-register in this EXE.
   uRadioFlexAPI        in '..\..\src\uRadioFlexAPI.pas',
   uRadioFlexCAT        in '..\..\src\uRadioFlexCAT.pas',
   uRadioFlex6000       in '..\..\src\uRadioFlex6000.pas',
   uTestFlexRegistry    in 'uTestFlexRegistry.pas',
   uFlexDiscovery       in '..\..\src\uFlexDiscovery.pas',
   uTestFlexDiscovery   in 'uTestFlexDiscovery.pas',
   uTestKenwoodSerial   in 'uTestKenwoodSerial.pas',
   uTestSerialParams    in 'uTestSerialParams.pas',
   uTestRadioSupportsCaps in 'uTestRadioSupportsCaps.pas',
   // Kenwood + Elecraft model units: listed so their initialization sections
   // self-register here, which is what puts them under the base-constructor
   // and registry coverage tests.
   uRadioKenwoodSerial  in '..\..\src\uRadioKenwoodSerial.pas',
   uRadioKenwoodLAN     in '..\..\src\uRadioKenwoodLAN.pas',
   uRadioKenwoodTS890   in '..\..\src\uRadioKenwoodTS890.pas',
   uRadioKenwoodTS990   in '..\..\src\uRadioKenwoodTS990.pas',
   uRadioKenwoodTS570   in '..\..\src\uRadioKenwoodTS570.pas',
   uRadioKenwoodTS140    in '..\..\src\uRadioKenwoodTS140.pas',
   uRadioKenwoodTS440    in '..\..\src\uRadioKenwoodTS440.pas',
   uRadioKenwoodTS450    in '..\..\src\uRadioKenwoodTS450.pas',
   uRadioKenwoodTS480    in '..\..\src\uRadioKenwoodTS480.pas',
   uRadioKenwoodTS590    in '..\..\src\uRadioKenwoodTS590.pas',
   uRadioKenwoodTS690    in '..\..\src\uRadioKenwoodTS690.pas',
   uRadioKenwoodTS850    in '..\..\src\uRadioKenwoodTS850.pas',
   uRadioKenwoodTS870    in '..\..\src\uRadioKenwoodTS870.pas',
   uRadioKenwoodTS940    in '..\..\src\uRadioKenwoodTS940.pas',
   uRadioKenwoodTS950    in '..\..\src\uRadioKenwoodTS950.pas',
   uRadioKenwoodTS2000   in '..\..\src\uRadioKenwoodTS2000.pas',
   uRadioElecraftSerial in '..\..\src\uRadioElecraftSerial.pas',
   uRadioElecraftK3     in '..\..\src\uRadioElecraftK3.pas',
   uRadioElecraftK2     in '..\..\src\uRadioElecraftK2.pas',
   uRadioElecraftKX3    in '..\..\src\uRadioElecraftKX3.pas';

begin
   IsMultiThread := True;  // Match main application setting

   // The radio-factory classes log through MainUnit's GLOBAL `logger`,
   // which tr4w.dpr assigns during startup.  A test EXE never runs that
   // startup, so the global stays nil and the first radio call that logs
   // -- UpdateLastValidResponse, on every received frame -- dies with an
   // access violation.  Assign it here the same way the app does.
   //
   // No appender is configured: the loggers then discard output, which is
   // what a test run wants.  This is ONLY about the global being non-nil.
   logger := TLogLogger.GetLogger('TR4WUnitTests');

   WriteLn('=== TR4W Unit Tests ===');
   WriteLn('');

   RegisterSuite(TIcomCIVTests.Create('IcomCIV'));
   RegisterSuite(TRadioBandTests.Create('RadioBand'));
   RegisterSuite(TFlexRadioUtilsTests.Create('FlexRadioUtils'));
   RegisterSuite(TUtilsTextTests.Create('UtilsText'));
   RegisterSuite(TADIFLexerTests.Create('ADIFLexer'));
   RegisterSuite(TADIFHelperTests.Create('ADIFHelpers'));
   RegisterSuite(TADIFMappingTests.Create('ADIFMapping'));
   RegisterSuite(TADIFFixtureTests.Create('ADIFFixtures'));
   RegisterSuite(TBandLookupTests.Create('BandLookup'));
   RegisterSuite(TCabrilloFormatTests.Create('CabrilloFormat'));
   RegisterSuite(TCabrilloExchangeTests.Create('CabrilloExchange'));
   RegisterSuite(TCRC32Tests.Create('CRC32'));
   RegisterSuite(TUtilsMathTests.Create('UtilsMath'));
   RegisterSuite(TGridDistanceTests.Create('GridDistance'));
   RegisterSuite(TUtilsFileTests.Create('UtilsFile'));
   RegisterSuite(TADIFRegressionTests.Create('ADIFRegression'));
   RegisterSuite(TFreqTimeFormatTests.Create('FreqTimeFormat'));
   RegisterSuite(TStrSearchTests.Create('StrSearch'));
   RegisterSuite(TCallCompressTests.Create('CallCompress'));
   RegisterSuite(TCTYDATTests.Create('CTYDAT'));
   RegisterSuite(TMultsTests.Create('Mults'));
   RegisterSuite(TCallSignRoutinesTests.Create('CallSignRoutines'));
   RegisterSuite(TYaesuASCIITests.Create('YaesuASCII'));
   RegisterSuite(TYaesuBinaryTests.Create('YaesuBinary'));
   RegisterSuite(TIcomRegistryTests.Create('IcomRegistry'));
   RegisterSuite(TFlexRegistryTests.Create('FlexRegistry'));
   RegisterSuite(TFlexDiscoveryTests.Create('FlexDiscovery'));
   RegisterSuite(TKenwoodSerialTests.Create('KenwoodSerial'));
   RegisterSuite(TSerialParamsTests.Create('SerialParams'));
   RegisterSuite(TRadioSupportsCapsTests.Create('RadioSupportsCaps'));

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
