(* THE PROJECT'S WEBSITE IS ONE CONSTANT, AND EVERY ADDRESS BUILT FROM IT IS
  WHAT IT WAS (2026-11-20).

  Version.TR4W_WEBSITE is the one spelling of the site. The About box, Help >
  Home Page, the download page, the version check, the TRMASTER.DTA fallback
  and the credit line of the 3830 report and the summary sheet each spelled it
  themselves until then. These pins hold every derived address byte for byte
  to the literal it replaced, so a change to the constant is a change these
  name. The TRMASTER.DTA primary URL uses the separate data site. The
  build\referenced-urls.txt probe rows still describe the addresses in use. *)
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
      procedure Test_TRMasterDownloadUsesPagesAndProtectsTheLocalFile;
   end;

implementation

uses
   Classes,
   SysUtils,
   Version,
   VC,
   uCheckLatestVersion,
   uHttpTransport,
   uTestFakeTransport,
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
   CheckEquals('https://tr4w.github.io/TRMASTER.DTA', TRMASTER_DOWNLOAD_URL,
               'TRMASTER.DTA has a stable address independent of the release');
   CheckEquals('https://tr4w.net/TRMASTER.DTA', TRMASTER_FALLBACK_URL,
               'the previous TRMASTER.DTA address is still a fallback');
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

procedure TTR4WWebsiteTests.Test_TRMasterDownloadUsesPagesAndProtectsTheLocalFile;
var
   fake: TFakeHttpTransport;
   contents: TMemoryStream;
   fixture, target: string;
   validData: RawByteString;
begin
   BeginTest('Test_TRMasterDownloadUsesPagesAndProtectsTheLocalFile');
   fixture := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
      'contest-matrix' + PathDelim + 'MATRIX-TRMASTER.DTA');
   target := UniqueTempFileName('trmaster');
   contents := TMemoryStream.Create;
   fake := TFakeHttpTransport.Create;
   DeclareCertificateChecking;
   SetHttpTransportForTest(fake);
   try
      contents.LoadFromFile(fixture);
      SetString(validData, PAnsiChar(contents.Memory), contents.Size);
      fake.ScriptStatus := 200;
      fake.ScriptBody := validData;
      CheckTrue(DownloadTRMasterFile(target), 'Pages file was installed');
      CheckEquals(1, fake.Calls, 'a valid primary response uses one request');
      CheckEquals(TRMASTER_DOWNLOAD_URL, fake.Last.URL, 'Pages is tried first');

      fake.Calls := 0;
      fake.ScriptBody := '<html>Not the data file</html>';
      fake.HasFollowUp := True;
      fake.FollowUpStatus := 200;
      fake.FollowUpBody := validData;
      CheckTrue(DownloadTRMasterFile(target), 'invalid Pages file triggers the fallback');
      CheckEquals(2, fake.Calls, 'both hosts were tried');
      CheckEquals(TRMASTER_FALLBACK_URL, fake.Last.URL, 'fallback uses the legacy URL');

      fake.Calls := 0;
      fake.FollowUpFailure := hfCannotConnect;
      CheckFalse(DownloadTRMasterFile(target), 'invalid primary and offline fallback fail');
      contents.LoadFromFile(target);
      CheckTrue((contents.Size = Length(validData)) and
         CompareMem(contents.Memory, Pointer(validData), Length(validData)),
         'the previous local file remains byte-identical');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      contents.Free;
      DeleteFile(target);
   end;
end;

procedure TTR4WWebsiteTests.RunAllTests;
begin
   Test_TheSiteIsOneConstant;
   Test_EveryAddressIsBuiltFromIt;
   Test_TheReportsCreditTheProgramAndTheSite;
   Test_TRMasterDownloadUsesPagesAndProtectsTheLocalFile;
end;

end.
