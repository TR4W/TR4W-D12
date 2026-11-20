(* THE PROJECT'S WEBSITE IS ONE CONSTANT, AND EVERY ADDRESS BUILT FROM IT IS
  WHAT IT WAS (2026-11-20).

  Version.TR4W_WEBSITE is the one spelling of the site. The About box, Help >
  Home Page, the download page, the version check, the TRMASTER.DTA download
  and the credit line of the 3830 report and the summary sheet each spelled it
  themselves until then. These pins hold every derived address byte for byte
  to the literal it replaced, so a change to the constant is a change these
  name, and build\referenced-urls.txt's probe rows (issue 248) still describe
  the addresses the program actually uses. *)
unit uTestTR4WWebsite;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTR4WWebsiteTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheSiteIsOneConstant;
      procedure Test_EveryAddressIsBuiltFromIt;
      procedure Test_TheReportsCreditTheProgramAndTheSite;
   end;

implementation

uses
   Version,
   VC,
   uCheckLatestVersion,
   uTRMasterUpdate,
   PostUnit;

procedure TTR4WWebsiteTests.Test_TheSiteIsOneConstant;
begin
   BeginTest('Test_TheSiteIsOneConstant');
   CheckEquals('https://tr4w.net', TR4W_WEBSITE,
               'the site, with no trailing slash -- a caller adds the path');
end;

procedure TTR4WWebsiteTests.Test_EveryAddressIsBuiltFromIt;
begin
   BeginTest('Test_EveryAddressIsBuiltFromIt');
   CheckEquals('https://tr4w.net/version.json', VERSION_URL,
               'the version check asks the address it always asked');
   CheckEquals('https://tr4w.net/TRMASTER.DTA', TRMASTER_DOWNLOAD_URL,
               'the TRMASTER.DTA download fetches the address it always fetched');
   CheckEquals('https://tr4w.net/download/?' + TR4W_CURRENTVERSION_NUMBER,
               TR4W_DOWNLOAD_LINK,
               'the download page, the version after the ''?''');
end;

procedure TTR4WWebsiteTests.Test_TheReportsCreditTheProgramAndTheSite;
begin
   BeginTest('Test_TheReportsCreditTheProgramAndTheSite');
   (* The 3830 report's header printed Format('SOFTWARE: %s https://tr4w.net',
     [TR4W_CURRENTVERSION]) and the summary sheet's footer TR4W_CURRENTVERSION +
     ' https://tr4w.net'; both now print 'SOFTWARE: ' + SoftwareCredit. *)
   CheckEquals('TR4W v.' + TR4W_CURRENTVERSION_NUMBER + ' https://tr4w.net',
               SoftwareCredit,
               'the credit line both reports print after SOFTWARE:');
end;

procedure TTR4WWebsiteTests.RunAllTests;
begin
   Test_TheSiteIsOneConstant;
   Test_EveryAddressIsBuiltFromIt;
   Test_TheReportsCreditTheProgramAndTheSite;
end;

end.
