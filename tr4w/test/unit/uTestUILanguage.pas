unit uTestUILanguage;

(* THE DISPLAY LANGUAGE -- the precedence, the early read, the setting, and
  the list Preferences offers.

  NY4I, 2026-09-19: a Mac has no practical command line, so an operator needs
  a way to choose the language in the UI that overrides the system's. The
  precedence is a --lang switch, then the Language setting, then the OS, then
  the compiled-in English (uUILanguage.ChooseUILanguage).

  THE EARLY READ IS THE PART MOST LIKELY TO REGRESS. The catalogue is loaded
  before LoadSettingsForStartup, so the setting is read straight from the file
  by uTR4WConfigFile.StartupUILanguage -- and a blank or broken file must fall
  through to the OS rather than stop the program.

  THE VOCABULARY COMES FROM THE CATALOGUES THE BINARY CARRIES. This test
  binary links the same tr4w_languages.res the app does, so what it checks is
  what ships. The macOS preferred-language arm of SystemUILanguage cannot run
  here; it was proven natively on mac-ci (2026-09-19). *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TUILanguageTests = class(TTestCase)
   protected
      procedure Test_TheSwitchBeatsTheSetting;
      procedure Test_TheSettingBeatsTheSystem;
      procedure Test_AnEmptySettingFollowsTheSystem;
      procedure Test_NothingAtAllIsEnglish;
      procedure Test_AnUnknownSettingFallsBackAndSaysSo;
      procedure Test_TheSettingIsCaseFolded;
      procedure Test_LanguagePartOfALocale;
      procedure Test_TheEarlyReadFindsTheSetting;
      procedure Test_TheEarlyReadWithNoSettingIsEmpty;
      procedure Test_ABlankOrBrokenFileFallsThrough;
      procedure Test_TheSettingRoundTripsThroughJSON;
      procedure Test_TheCommandAcceptsOnlyWhatShips;
      procedure Test_TheListComesFromTheEmbeddedCatalogues;
      procedure Test_EachLanguageIsShownInItsOwnName;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, DateUtils, uJSON, uSettingsModel, uSettingsRegistry,
   uSettingsDeclarations, uTR4WConfigFile, uUILanguage, uEmbeddedTranslations;

(* A stub catalogue list: German and English only. *)
function OnlyGermanAndEnglish(const aCode: string): boolean;
begin
   Result := (aCode = 'de') or (aCode = 'en');
end;

function TempSettingsFile: string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) +
             Format('tr4w-uilanguage-%d.json', [Random(1000000000)]);
end;

procedure WriteText(const aFileName, aText: string);
var
   f: TextFile;
begin
   AssignFile(f, aFileName);
   Rewrite(f);
   try
      Write(f, aText);
   finally
      CloseFile(f);
   end;
end;

(* The file and the .bad copy ReadRootOrEmpty makes of one that will not
  parse. *)
procedure RemoveSettingsFile(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '.bad') then
      begin
      DeleteFile(aFileName + '.bad');
      end;
end;

(* ---------------------------------------------------------------------
  THE PRECEDENCE.
  --------------------------------------------------------------------- *)

procedure TUILanguageTests.Test_TheSwitchBeatsTheSetting;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('a --lang switch beats the Language setting and the OS');
   CheckEquals('es', ChooseUILanguage('es', 'de', 'fr', @OnlyGermanAndEnglish,
                                      source, refused), 'the switch wins');
   CheckTrue(source = ulsSwitch, 'and says so');
   CheckFalse(refused, 'the setting was not consulted, so not refused');
end;

procedure TUILanguageTests.Test_TheSettingBeatsTheSystem;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('the Language setting beats the operating system');
   CheckEquals('de', ChooseUILanguage('', 'de', 'fr', @OnlyGermanAndEnglish,
                                      source, refused), 'the setting wins');
   CheckTrue(source = ulsSetting, 'and says so');

   (* ENGLISH IS A CHOICE, not an absence: an operator on a German Mac who
     wants English sets 'en', and it must beat the OS. *)
   CheckEquals('en', ChooseUILanguage('', 'en', 'de', @OnlyGermanAndEnglish,
                                      source, refused),
               'English chosen explicitly beats a German OS');
   CheckTrue(source = ulsSetting, 'from the setting');
end;

procedure TUILanguageTests.Test_AnEmptySettingFollowsTheSystem;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('an empty setting is "System default" and follows the OS');
   CheckEquals('fr', ChooseUILanguage('', '', 'fr', @OnlyGermanAndEnglish,
                                      source, refused), 'the OS supplies it');
   CheckTrue(source = ulsSystem, 'from the system');
   CheckFalse(refused, 'empty is not a refusal');

   CheckEquals('fr', ChooseUILanguage('', '   ', 'fr', @OnlyGermanAndEnglish,
                                      source, refused), 'blank is empty too');
   CheckFalse(refused, 'blank is not a refusal either');
end;

procedure TUILanguageTests.Test_NothingAtAllIsEnglish;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('no switch, no setting, no locale: the compiled-in English');
   CheckEquals('', ChooseUILanguage('', '', '', @OnlyGermanAndEnglish,
                                    source, refused),
               ''''' is what the loader reads as the compiled-in English');
   CheckTrue(source = ulsNone, 'from nothing');
end;

procedure TUILanguageTests.Test_AnUnknownSettingFallsBackAndSaysSo;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('a setting this build cannot load falls back to the OS, reported');
   CheckEquals('fr', ChooseUILanguage('', 'xx', 'fr', @OnlyGermanAndEnglish,
                                      source, refused),
               'the OS, not English and not "xx"');
   CheckTrue(source = ulsSystem, 'from the system');
   CheckTrue(refused, 'and the refusal is reported for the log');

   CheckEquals('', ChooseUILanguage('', 'xx', '', @OnlyGermanAndEnglish,
                                    source, refused),
               'no OS either: English');
   CheckTrue(refused, 'still reported');

   CheckEquals('fr', ChooseUILanguage('', 'de', 'fr', nil, source, refused),
               'with no availability test at all, nothing is taken on trust');
   CheckTrue(refused, 'and that is reported, not a crash');
end;

procedure TUILanguageTests.Test_TheSettingIsCaseFolded;
var
   source: TUILanguageSource;
   refused: boolean;
begin
   BeginTest('a hand-edited setting in any case still selects its catalogue');
   CheckEquals('de', ChooseUILanguage('', ' DE ', 'fr', @OnlyGermanAndEnglish,
                                      source, refused), 'DE is de');
   CheckTrue(source = ulsSetting, 'from the setting');
end;

procedure TUILanguageTests.Test_LanguagePartOfALocale;
begin
   BeginTest('the language half of a locale id');
   CheckEquals('de', LanguagePartOf('de_DE'), 'POSIX');
   CheckEquals('de', LanguagePartOf('de-US'), 'a macOS preferred language');
   CheckEquals('zh', LanguagePartOf('zh-Hans-CN'), 'with a script');
   CheckEquals('fr', LanguagePartOf('fr_FR.UTF-8'), 'with a code set');
   CheckEquals('pt', LanguagePartOf('PT'), 'bare, and case-folded');
   CheckEquals('', LanguagePartOf(''), 'nothing');
end;

(* ---------------------------------------------------------------------
  THE EARLY READ, BEFORE THE SETTINGS OBJECT EXISTS.
  --------------------------------------------------------------------- *)

procedure TUILanguageTests.Test_TheEarlyReadFindsTheSetting;
var
   path: string;
begin
   BeginTest('StartupUILanguage reads settings.Display.Language from the file');
   path := TempSettingsFile;
   try
      WriteText(path, '{"settings":{"Display":{"Language":"de"},' +
                      '"Log":{"DebugLevel":"llInfo"}}}');
      CheckEquals('de', StartupUILanguage(path), 'the stored code');
   finally
      RemoveSettingsFile(path);
   end;
end;

procedure TUILanguageTests.Test_TheEarlyReadWithNoSettingIsEmpty;
var
   path: string;
begin
   BeginTest('no Display section, or no settings section: follow the OS');
   path := TempSettingsFile;
   try
      WriteText(path, '{"settings":{"Log":{"DebugLevel":"llInfo"}}}');
      CheckEquals('', StartupUILanguage(path), 'a file from before the setting');

      WriteText(path, '{"general":{}}');
      CheckEquals('', StartupUILanguage(path), 'no settings section at all');

      WriteText(path, '{"settings":{"Display":{"Language":""}}}');
      CheckEquals('', StartupUILanguage(path), '"System default" as stored');
   finally
      RemoveSettingsFile(path);
   end;

   CheckEquals('', StartupUILanguage(path), 'no file at all -- a first run');
end;

procedure TUILanguageTests.Test_ABlankOrBrokenFileFallsThrough;
var
   path: string;
begin
   BeginTest('a blank or unparseable tr4w.json falls through, and does not raise');
   path := TempSettingsFile;
   try
      WriteText(path, '');
      CheckEquals('', StartupUILanguage(path), 'a zero-byte file');

      WriteText(path, '{"settings": {"Display": ');
      CheckEquals('', StartupUILanguage(path), 'a truncated file');

      WriteText(path, '[1, 2, 3]');
      CheckEquals('', StartupUILanguage(path), 'JSON, but not an object');

      WriteText(path, '{"settings":{"Display":"de"}}');
      CheckEquals('', StartupUILanguage(path), 'a group that is not an object');
   finally
      RemoveSettingsFile(path);
   end;
end;

(* ---------------------------------------------------------------------
  THE SETTING ITSELF.
  --------------------------------------------------------------------- *)

procedure TUILanguageTests.Test_TheSettingRoundTripsThroughJSON;
var
   a, b: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('Display.Language round-trips through the settings JSON');
   a := TR4WSettings.Create;
   b := TR4WSettings.Create;
   try
      CheckEquals('', a.Display.Language, 'the default follows the OS');
      a.Display.Language := 'de';
      obj := a.ToJSON;
      try
         CheckEquals('de', obj.FindPath('Display.Language').AsString,
                     'written where StartupUILanguage looks for it');
         b.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckEquals('de', b.Display.Language, 'and read back');
      CheckFalse(a.CommandIsContestScoped('DISPLAY LANGUAGE'),
                 'the station''s, not the contest''s -- it lives in tr4w.json');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TUILanguageTests.Test_TheCommandAcceptsOnlyWhatShips;
var
   s: TR4WSettings;
   v: string;
begin
   BeginTest('DISPLAY LANGUAGE accepts a shipped code or "", and refuses others');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.OwnsCommand('DISPLAY LANGUAGE'), 'the derived name resolves');
      CheckTrue(s.TrySetByCommand('DISPLAY LANGUAGE', 'de'), 'a shipped code');
      CheckTrue(s.TryGetByCommand('DISPLAY LANGUAGE', v), 'reads back');
      CheckEquals('de', v, 'as set');
      CheckFalse(s.TrySetByCommand('DISPLAY LANGUAGE', 'xx'),
                 'a code no catalogue answers to is refused');
      CheckEquals('de', s.Display.Language, 'and the refusal changes nothing');
      CheckTrue(s.TrySetByCommand('DISPLAY LANGUAGE', ''),
                '"" -- System default -- is a legal value');
      CheckEquals('', s.Display.Language, 'and clears it');
   finally
      s.Free;
   end;
end;

(* ---------------------------------------------------------------------
  WHAT PREFERENCES OFFERS.
  --------------------------------------------------------------------- *)

procedure TUILanguageTests.Test_TheListComesFromTheEmbeddedCatalogues;
var
   codes: string;
   offered: TArray<string>;
   i, n: integer;
begin
   BeginTest('the Language list is the catalogues this binary carries');
   codes := ' ' + AvailableLanguages + ' ';
   CheckTrue(Pos(' en ', codes) > 0, 'English is embedded: ' + codes);
   CheckTrue(Pos(' de ', codes) > 0, 'and at least one other language');

   CheckTrue(IsUILanguageAvailable('de'), 'de is loadable');
   CheckTrue(IsUILanguageAvailable('EN'), 'en always is, in any case');
   CheckFalse(IsUILanguageAvailable('xx'), 'xx is not');
   CheckFalse(IsUILanguageAvailable(''), '"" is not a language');

   offered := Settings.AllowedValuesForCommand('DISPLAY LANGUAGE');
   CheckTrue(Length(offered) > 2, 'Preferences offers a list, not a text box');
   CheckEquals('', offered[0], 'System default comes first');

   (* EVERY OFFERED CODE IS LOADABLE, and every embedded one is offered: the
     list is the enumeration, so the two cannot disagree. *)
   n := 0;
   for i := 1 to High(offered) do
      begin
      CheckTrue(IsUILanguageAvailable(offered[i]),
                offered[i] + ' is offered and loadable');
      CheckTrue(Pos(' ' + offered[i] + ' ', codes) > 0,
                offered[i] + ' is an embedded catalogue');
      Inc(n);
      end;
   CheckEquals(Length(Trim(codes)) - Length(StringReplace(Trim(codes), ' ', '',
               [rfReplaceAll])) + 1, n, 'one entry per embedded catalogue');
end;

procedure TUILanguageTests.Test_EachLanguageIsShownInItsOwnName;
var
   s: TSettingBase;
   started: TDateTime;
   offered: TArray<string>;
   i: integer;
   elapsed: int64;
begin
   BeginTest('each language is offered in its own name, with its code');
   DeclareAllSettings;
   s := FindSetting('appearance.language');
   CheckTrue(s <> nil, 'Preferences has the setting');
   if s = nil then
      begin
      Exit;
      end;
   CheckTrue(s.NeedsRestart, 'and says a restart is needed -- which it is');

   CheckEquals('Deutsch (de)', s.CaptionForValue('de'),
               'German, as its catalogue names itself');
   CheckEquals('English (en)', s.CaptionForValue('en'), 'English');
   CheckEquals('System default', s.CaptionForValue(''),
               'the empty value, in words');
   CheckEquals('xx', UILanguageCaption('xx'),
               'a code with no catalogue shows as the code');

   (* COSTED: the first call parses every catalogue once and the rest are
     cached. Preferences shows the whole list, so this is its price. *)
   offered := Settings.AllowedValuesForCommand('DISPLAY LANGUAGE');
   started := Now;
   for i := 0 to High(offered) do
      begin
      CheckTrue(UILanguageCaption(offered[i]) <> '',
                'a caption for "' + offered[i] + '"');
      end;
   elapsed := MilliSecondsBetween(Now, started);
   CheckTrue(elapsed < 1000, Format('all %d captions in %d ms',
                                    [Length(offered), elapsed]));
end;

procedure TUILanguageTests.RunAllTests;
begin
   Randomize;
   Test_TheSwitchBeatsTheSetting;
   Test_TheSettingBeatsTheSystem;
   Test_AnEmptySettingFollowsTheSystem;
   Test_NothingAtAllIsEnglish;
   Test_AnUnknownSettingFallsBackAndSaysSo;
   Test_TheSettingIsCaseFolded;
   Test_LanguagePartOfALocale;
   Test_TheEarlyReadFindsTheSetting;
   Test_TheEarlyReadWithNoSettingIsEmpty;
   Test_ABlankOrBrokenFileFallsThrough;
   Test_TheSettingRoundTripsThroughJSON;
   Test_TheCommandAcceptsOnlyWhatShips;
   Test_TheListComesFromTheEmbeddedCatalogues;
   Test_EachLanguageIsShownInItsOwnName;
end;

end.
