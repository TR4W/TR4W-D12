program fpc_tests;
{$MODE DELPHI}
//  THE FIRST TR4W TESTS TO RUN UNDER FPC.
//
//  A REDUCED driver, not the real tr4w_unit_tests.dpr, and the reduction is the
//  point: the full project still pulls in Indy through uFactoryRadioBase, which
//  is a separate question (spike step 6). This links only suites whose
//  dependencies are already proven to compile under FPC, so that "does a TR4W
//  test PASS on a different compiler" gets an answer now rather than after the
//  Indy question is settled.
//
//  Everything here is the SAME SOURCE the Delphi build uses -- no forked copies,
//  and no conditional defines added to force a pass. If a number differs from
//  Delphi's, that is a finding, which is the entire purpose.
uses
   SysUtils,
   uTR4WTestFramework,
   uTestRotatorFactory,
   uTestSettingsRegistry;
var
   ok: boolean;
begin
   RegisterSuite(TRotatorFactoryTests.Create('RotatorFactory'));
   RegisterSuite(TSettingsRegistryTests.Create('SettingsRegistry'));
   ok := RunAllSuites;
   if not ok then
      begin
      ExitCode := 1;
      end;
end.
