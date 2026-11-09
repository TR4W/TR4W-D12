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
   SysUtils, uTR4WTestFramework, uHTTPDownload, uJSON, uKeychain, uSettingsModel;

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
      procedure Test_ANeverSetUrlGetsTheHttpsDefault;
      procedure Test_ASavedOldHttpUrlIsMigratedOnce;
      procedure Test_AFlagTrueFileIsNeverTouched;
      procedure Test_OnlyTheExactOldDefaultIsMigrated;
      procedure Test_AFreshFileGetsTheDefaultAndTheFlag;
      procedure Test_ASavedCustomUrlIsKept;
      procedure Test_AFreshFileGetsTheScorePostingDefaultAndTheFlag;
      procedure Test_ASavedOldScorePostingUrlIsMigratedOnce;
      procedure Test_AScoreFlagTrueFileIsNeverTouched;
      procedure Test_OnlyTheExactOldScoreDefaultIsMigrated;
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

(* THE HAMSCORE DEFAULT (issue 250). Loading goes through the one path the
  program uses at start-up, TR4WSettings.FromJSON, which leaves alone a
  property the file does not carry and then runs the ONE-TIME migration of a
  saved http://scoredistributor.net/ (THamscoreSettings.MigrateOldDefaultUrl,
  guarded by the saved UrlDefaultMigrated flag). *)
procedure LoadJson(const s: TR4WSettings; const aJson: string);
var
   obj: TJSONObject;
begin
   obj := TJSONObject(TJSONObject.ParseJSONValue(aJson));
   if obj = nil then
      begin
      raise Exception.Create('the fixture must parse');
      end;
   try
      s.FromJSON(obj);
   finally
      obj.Free;
   end;
end;

function HamscoreUrlAfterLoading(const aJson: string): string;
var
   s: TR4WSettings;
begin
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, aJson);
      Result := s.Hamscore.Url;
   finally
      s.Free;
   end;
end;

procedure TPlainHttpUrlTests.Test_ANeverSetUrlGetsTheHttpsDefault;
begin
   BeginTest('a settings file with no HamScore URL gets the https default');
   CheckEquals('https://hamscore.com/postxml/', HAMSCORE_DEFAULT_URL, 'the constant');
   CheckEquals(HAMSCORE_DEFAULT_URL, HamscoreUrlAfterLoading('{}'), 'empty file');
   CheckEquals(HAMSCORE_DEFAULT_URL,
               HamscoreUrlAfterLoading('{"Hamscore":{"SendContactInfo":true}}'),
               'a Hamscore section without a Url');
   CheckFalse(IsPlainHttpUrl(HAMSCORE_DEFAULT_URL), 'the default is not plain http');
end;

procedure TPlainHttpUrlTests.Test_ASavedOldHttpUrlIsMigratedOnce;
var
   s: TR4WSettings;
begin
   BeginTest('a saved http://scoredistributor.net/ becomes https once, and the flag is set');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, '{"Hamscore":{"Url":"http://scoredistributor.net/"}}');
      CheckEquals(HAMSCORE_DEFAULT_URL, s.Hamscore.Url, 'migrated');
      CheckTrue(s.Hamscore.UrlDefaultMigrated, 'flag set');
      CheckEquals('http://scoredistributor.net/', s.Hamscore.UrlMigratedFrom,
                  'the old value is reported for the log');

      (* "ONCE" IS REAL: the operator now chooses the old URL on purpose,
        the settings are saved (flag true) and loaded again. *)
      s.Hamscore.Url := 'http://scoredistributor.net/';
      LoadJson(s, '{"Hamscore":{"Url":"http://scoredistributor.net/",'
                  + '"UrlDefaultMigrated":true}}');
      CheckEquals('http://scoredistributor.net/', s.Hamscore.Url,
                  'a later deliberate choice is not rewritten');
      CheckEquals('', s.Hamscore.UrlMigratedFrom, 'and nothing is reported');
   finally
      s.Free;
   end;
   CheckEquals(HAMSCORE_DEFAULT_URL,
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":" HTTP://ScoreDistributor.net/ "}}'),
               'trimmed, any case');
end;

procedure TPlainHttpUrlTests.Test_AFlagTrueFileIsNeverTouched;
begin
   BeginTest('a file carrying UrlDefaultMigrated=true keeps the old http URL');
   CheckEquals('http://scoredistributor.net/',
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":"http://scoredistributor.net/",'
                                       + '"UrlDefaultMigrated":true}}'));
end;

procedure TPlainHttpUrlTests.Test_OnlyTheExactOldDefaultIsMigrated;
begin
   BeginTest('the same host with another path or scheme is not migrated');
   CheckEquals('http://scoredistributor.net/other/',
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":"http://scoredistributor.net/other/"}}'),
               'another path');
   CheckEquals('https://scoredistributor.net/',
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":"https://scoredistributor.net/"}}'),
               'another scheme');
end;

procedure TPlainHttpUrlTests.Test_AFreshFileGetsTheDefaultAndTheFlag;
var
   s: TR4WSettings;
begin
   BeginTest('a file with no HamScore section ends on the https default with the flag set');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, '{}');
      CheckEquals(HAMSCORE_DEFAULT_URL, s.Hamscore.Url, 'default');
      CheckTrue(s.Hamscore.UrlDefaultMigrated, 'flag');
      CheckEquals('', s.Hamscore.UrlMigratedFrom, 'nothing was migrated');
   finally
      s.Free;
   end;
end;

procedure TPlainHttpUrlTests.Test_ASavedCustomUrlIsKept;
begin
   BeginTest('a saved custom URL is not replaced');
   CheckEquals('https://club.example.org/rtc/',
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":"https://club.example.org/rtc/"}}'));
   CheckEquals('http://club.example.org/rtc/',
               HamscoreUrlAfterLoading('{"Hamscore":{"Url":"http://club.example.org/rtc/"}}'),
               'a custom http URL too');
end;

(* THE SCORE POSTING DEFAULT (issue 253), the same mechanism as HamScore's. *)
function ScorePostingUrlAfterLoading(const aJson: string): string;
var
   s: TR4WSettings;
begin
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, aJson);
      Result := s.Score.PostingUrl;
   finally
      s.Free;
   end;
end;

procedure TPlainHttpUrlTests.Test_AFreshFileGetsTheScorePostingDefaultAndTheFlag;
var
   s: TR4WSettings;
begin
   BeginTest('a file with no Score section ends on the new posting default with the flag set');
   CheckEquals('https://contestonlinescore.com/post/', SCORE_POSTING_DEFAULT_URL, 'the constant');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, '{}');
      CheckEquals(SCORE_POSTING_DEFAULT_URL, s.Score.PostingUrl, 'default');
      CheckTrue(s.Score.PostingUrlDefaultMigrated, 'flag');
      CheckEquals('', s.Score.PostingUrlMigratedFrom, 'nothing was migrated');
      CheckEquals('https://contestonlinescore.com/scoreboard/', s.Score.ReadingUrl,
                  'the reading URL is untouched');
   finally
      s.Free;
   end;
end;

procedure TPlainHttpUrlTests.Test_ASavedOldScorePostingUrlIsMigratedOnce;
var
   s: TR4WSettings;
begin
   BeginTest('a saved https://post.contestonlinescore.com/post/ is moved once, and the flag is set');
   CheckEquals('https://post.contestonlinescore.com/post/', SCORE_POSTING_OLD_DEFAULT_URL, 'the old constant');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      LoadJson(s, '{"Score":{"PostingUrl":"https://post.contestonlinescore.com/post/"}}');
      CheckEquals(SCORE_POSTING_DEFAULT_URL, s.Score.PostingUrl, 'migrated');
      CheckTrue(s.Score.PostingUrlDefaultMigrated, 'flag set');
      CheckEquals(SCORE_POSTING_OLD_DEFAULT_URL, s.Score.PostingUrlMigratedFrom,
                  'the old value is reported for the log');

      (* ONCE: a later deliberate choice of the old URL is kept. *)
      s.Score.PostingUrl := SCORE_POSTING_OLD_DEFAULT_URL;
      LoadJson(s, '{"Score":{"PostingUrl":"https://post.contestonlinescore.com/post/",'
                  + '"PostingUrlDefaultMigrated":true}}');
      CheckEquals(SCORE_POSTING_OLD_DEFAULT_URL, s.Score.PostingUrl,
                  'a later deliberate choice is not rewritten');
      CheckEquals('', s.Score.PostingUrlMigratedFrom, 'and nothing is reported');
   finally
      s.Free;
   end;
   CheckEquals(SCORE_POSTING_DEFAULT_URL,
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":" HTTPS://Post.ContestOnlineScore.com/post/ "}}'),
               'trimmed, any case');
end;

procedure TPlainHttpUrlTests.Test_AScoreFlagTrueFileIsNeverTouched;
begin
   BeginTest('a file carrying PostingUrlDefaultMigrated=true keeps the old posting URL');
   CheckEquals(SCORE_POSTING_OLD_DEFAULT_URL,
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":"https://post.contestonlinescore.com/post/",'
                                           + '"PostingUrlDefaultMigrated":true}}'));
end;

procedure TPlainHttpUrlTests.Test_OnlyTheExactOldScoreDefaultIsMigrated;
begin
   BeginTest('only the exact old posting default is migrated; the slashless URL and others are kept');
   CheckEquals('https://contestonlinescore.com/post',
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":"https://contestonlinescore.com/post"}}'),
               'the apex host without the slash');
   CheckEquals('https://post.contestonlinescore.com/post',
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":"https://post.contestonlinescore.com/post"}}'),
               'the old host, no slash');
   CheckEquals('http://post.contestonlinescore.com/',
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":"http://post.contestonlinescore.com/"}}'),
               'the D7 plain http default');
   CheckEquals('https://club.example.org/rtc/',
               ScorePostingUrlAfterLoading('{"Score":{"PostingUrl":"https://club.example.org/rtc/"}}'),
               'a custom URL');
end;

procedure TPlainHttpUrlTests.RunAllTests;
begin
   Test_AFreshFileGetsTheScorePostingDefaultAndTheFlag;
   Test_ASavedOldScorePostingUrlIsMigratedOnce;
   Test_AScoreFlagTrueFileIsNeverTouched;
   Test_OnlyTheExactOldScoreDefaultIsMigrated;
   Test_ANeverSetUrlGetsTheHttpsDefault;
   Test_ASavedOldHttpUrlIsMigratedOnce;
   Test_AFlagTrueFileIsNeverTouched;
   Test_OnlyTheExactOldDefaultIsMigrated;
   Test_AFreshFileGetsTheDefaultAndTheFlag;
   Test_ASavedCustomUrlIsKept;
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
