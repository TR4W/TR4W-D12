unit uTestPlainHttpUrl;
{$I ..\..\src\tr4w.inc}
(*
  WHICH URLS COUNT AS PLAIN HTTP -- uHTTPDownload.IsPlainHttpUrl.

  Preferences shows a note under the HamScore service URL while it is true,
  and the HamScore uploader logs a warning at start-up. Both ask this one
  function, so pinning it pins what the operator is told in both places.

  The rule: the text, TRIMMED, starts with http:// in any case. https://, any
  other scheme, a scheme that only begins with "http", and a bare "http" are
  not plain-http URLs.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uHTTPDownload;

type
   TPlainHttpUrlTests = class(TTestCase)
   protected
      procedure Test_HttpIsPlain;
      procedure Test_TheSchemeIsCaseInsensitive;
      procedure Test_SurroundingSpaceIsIgnored;
      procedure Test_HttpsIsNotPlain;
      procedure Test_EmptyIsNotPlain;
      procedure Test_AnotherSchemeIsNotPlain;
      procedure Test_ASchemeThatOnlyStartsWithHttpIsNotPlain;
      procedure Test_TheBareWordIsNotPlain;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TPlainHttpUrlTests.Test_HttpIsPlain;
begin
   BeginTest('http:// is plain http');
   CheckTrue(IsPlainHttpUrl('http://scoredistributor.net/'),
             'the default HamScore URL is plain http');
   CheckTrue(IsPlainHttpUrl('http://'), 'the scheme alone is enough');
end;

procedure TPlainHttpUrlTests.Test_TheSchemeIsCaseInsensitive;
begin
   BeginTest('the scheme is matched in any case');
   CheckTrue(IsPlainHttpUrl('HTTP://SCOREDISTRIBUTOR.NET/'), 'upper case');
   CheckTrue(IsPlainHttpUrl('Http://scoredistributor.net/'), 'mixed case');
end;

procedure TPlainHttpUrlTests.Test_SurroundingSpaceIsIgnored;
begin
   BeginTest('leading and trailing space does not hide plain http');
   CheckTrue(IsPlainHttpUrl('  http://scoredistributor.net/'), 'leading spaces');
   CheckTrue(IsPlainHttpUrl(#9'http://scoredistributor.net/ '), 'a tab and a trailing space');
end;

procedure TPlainHttpUrlTests.Test_HttpsIsNotPlain;
begin
   BeginTest('https:// is not plain http');
   CheckFalse(IsPlainHttpUrl('https://hamscore.com/postxml/'), 'https');
   CheckFalse(IsPlainHttpUrl('HTTPS://hamscore.com/postxml/'), 'https in upper case');
   CheckFalse(IsPlainHttpUrl(' https://hamscore.com/postxml/'), 'https after a space');
end;

procedure TPlainHttpUrlTests.Test_EmptyIsNotPlain;
begin
   BeginTest('an empty or blank URL is not plain http');
   CheckFalse(IsPlainHttpUrl(''), 'empty');
   CheckFalse(IsPlainHttpUrl('   '), 'spaces only');
end;

procedure TPlainHttpUrlTests.Test_AnotherSchemeIsNotPlain;
begin
   BeginTest('another scheme is not plain http');
   CheckFalse(IsPlainHttpUrl('ftp://example.com/'), 'ftp');
   CheckFalse(IsPlainHttpUrl('scoredistributor.net/'), 'no scheme at all');
end;

procedure TPlainHttpUrlTests.Test_ASchemeThatOnlyStartsWithHttpIsNotPlain;
begin
   BeginTest('a scheme that merely starts with "http" is not plain http');
   CheckFalse(IsPlainHttpUrl('httpx://example.com/'), 'httpx');
   CheckFalse(IsPlainHttpUrl('http:/example.com/'), 'one slash');
end;

procedure TPlainHttpUrlTests.Test_TheBareWordIsNotPlain;
begin
   BeginTest('the word "http" alone is not plain http');
   CheckFalse(IsPlainHttpUrl('http'), 'http');
   CheckFalse(IsPlainHttpUrl('http:'), 'http and a colon');
end;

procedure TPlainHttpUrlTests.RunAllTests;
begin
   Test_HttpIsPlain;
   Test_TheSchemeIsCaseInsensitive;
   Test_SurroundingSpaceIsIgnored;
   Test_HttpsIsNotPlain;
   Test_EmptyIsNotPlain;
   Test_AnotherSchemeIsNotPlain;
   Test_ASchemeThatOnlyStartsWithHttpIsNotPlain;
   Test_TheBareWordIsNotPlain;
end;

end.
