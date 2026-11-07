unit uTestCommandHelp;

(* THE CONFIG-COMMAND HELP TEXT -- uCommandHelp, and the tooltips built on it.

  Two halves. The loader: found, missing, empty, the language fallback, and
  the parts of the .po format the help catalogues use or will use once
  Weblate rewraps a long msgstr into continuation lines. And a pin: every
  setting Preferences can bind resolves to English help in the real
  i18n/help_en.po, or is named in KNOWN_HELP_GAPS -- which must match EXACTLY,
  so a gap that gets help (or a new setting that has none) fails here. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCommandHelpTests = class(TTestCase)
   protected
      procedure TestKeyMatchesIni2po;
      procedure TestFoundSection;
      procedure TestMissingSection;
      procedure TestEmptyDescription;
      procedure TestUntranslatedUsesEnglishMsgid;
      procedure TestContinuationAndEscapes;
      procedure TestObsoleteAndFuzzy;
      procedure TestLanguageFallback;
      procedure TestRegionFallsToLanguage;
      procedure TestNoFilesAtAll;
      procedure TestHintFormat;
      procedure TestEveryRegisteredSettingHasHelp;
      procedure TestRealCatalogueIsUtf8;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Generics.Collections,
   uCommandHelp,
   uSettingsRegistry,
   uSettingsDeclarations;

const
   (* REGISTERED SETTINGS WITH NO ENGLISH HELP in i18n/help_en.po, by config
     command. This is a measurement, not a decision: writing the text is
     NY4I's (docs/HELP_TEXT_GAPS.md is the work-list). Exact in both
     directions -- remove a name the day its help lands. *)
   KNOWN_HELP_GAPS: array[0..27] of string = (
      (* No section in help_en.po. *)
      'ALERT COLOR',
      'BAND MAP WORKED MULT COLOR',
      'CALL WINDOW SHOW ALL SPOTS',
      'COUNTRY INFORMATION FILE',
      'DISPLAY LANGUAGE',
      'NETWORK AUTO CONNECT',
      'NETWORK SHARE SPOTS',
      'OPERATING STANDARD EDIT KEYS',
      'PTT TX INHIBIT BEEP',
      'SHOW ALL SERIAL PORTS',
      'TELNET CONSOLE LINES',
      'TUNE WITH DITS',
      (* A section whose DESCRIPTION= is empty, in the ini and the .po. *)
      'AUTO-CQ DELAY TIME',
      'CW SPEED INCREMENT',
      'DVK PATH',
      'DVK RECORDER',
      'HAND LOG MODE',
      'INCLUDE F-KEY NUMBER',
      'MAIN CALLSIGN',
      'MISSINGCALLSIGNS FILE ENABLE',
      'NET STATUS UPDATE INTERVAL',
      'NO BORDER',
      'NO COLUMN HEADER',
      'QZB RANDOM OFFSET ENABLE',
      'SHOW DOMESTIC MULTIPLIER NAME',
      'SHOW GRIDLINES',
      'STATIONS CALLSIGNS MASK',
      'USE RECORDED SIGNS'
   );

function EnglishHeader: string;
begin
   Result := 'msgid ""' + LineEnding +
             'msgstr ""' + LineEnding +
             '"Project-Id-Version: TR4W\n"' + LineEnding +
             '"Language: en\n"' + LineEnding + LineEnding;
end;

(* AN EMPTY directory, every time. The directory outlives the run, so a file
  one test writes late (TestRegionFallsToLanguage's help_pt_BR.po) was still
  there for its own early check on the NEXT run, and that test passed once per
  machine and failed ever after (measured 2026-11-02). *)
function TempHelpDir(const aName: string): string;
var
   found: TSearchRec;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
             'tr4w_help_test_' + aName + PathDelim;
   ForceDirectories(Result);
   if FindFirst(Result + '*', faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               DeleteFile(Result + found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
end;

(* UTF-8 bytes, as the catalogues are on disk. *)
procedure WriteUtf8File(const aPath, aText: string);
var
   stream: TFileStream;
   bytes: RawByteString;
begin
   bytes  := UTF8Encode(aText);
   stream := TFileStream.Create(aPath, fmCreate);
   try
      if Length(bytes) > 0 then
         begin
         stream.WriteBuffer(bytes[1], Length(bytes));
         end;
   finally
      stream.Free;
   end;
end;

procedure TCommandHelpTests.TestKeyMatchesIni2po;
begin
   BeginTest('TestKeyMatchesIni2po');
   (* Each expected value is what tools/i18n/ini2po.py key_for() writes,
     and each is a msgctxt present in i18n/help_en.po. *)
   CheckEquals('TC_HELP_ALT_D_CQ_ENABLE', CommandHelpKey('ALT-D CQ ENABLE'), 'hyphen');
   CheckEquals('TC_HELP_S_P_EXCHANGE', CommandHelpKey('S&P EXCHANGE'), 'ampersand');
   CheckEquals('TC_HELP_WSJT_X_ENABLED', CommandHelpKey('WSJT-X ENABLED'), 'WSJT-X');
   CheckEquals('TC_HELP_QUICK_QSL_KEY_1', CommandHelpKey('QUICK QSL KEY 1'), 'digit');
   CheckEquals('TC_HELP_AUTO_S_P_ENABLE_SENSITIVITY',
               CommandHelpKey('AUTO S&P ENABLE SENSITIVITY'), 'ampersand inside');
   CheckEquals('TC_HELP_AUTO_CQ_DELAY_TIME', CommandHelpKey('AUTO-CQ DELAY TIME'), 'leading hyphen');
   CheckEquals('TC_HELP_SHORT_0', CommandHelpKey('  short 0 '), 'case and edges');
   CheckEquals('TC_HELP_CATEGORY_ASSISTED', CommandHelpKey('CATEGORY-ASSISTED'), 'category');
end;

procedure TCommandHelpTests.TestFoundSection;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestFoundSection');
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         '#. Config command: CW TONE   (default: 700)' + LineEnding +
         'msgctxt "TC_HELP_CW_TONE"' + LineEnding +
         'msgid "The sidetone pitch."' + LineEnding +
         'msgstr "The sidetone pitch."' + LineEnding);
      CheckEquals(1, cat.Count, 'one entry, the header is not one');
      CheckTrue(cat.TryGetText('TC_HELP_CW_TONE', text), 'found');
      CheckEquals('The sidetone pitch.', text, 'its text');
      CheckTrue(cat.TryGetText('tc_help_cw_tone', text), 'the key is case-insensitive');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestMissingSection;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestMissingSection');
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         'msgctxt "TC_HELP_CW_TONE"' + LineEnding +
         'msgid "The sidetone pitch."' + LineEnding +
         'msgstr ""' + LineEnding);
      CheckFalse(cat.TryGetText('TC_HELP_NO_SUCH_COMMAND', text), 'absent');
      CheckEquals('', text, 'and empty');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestEmptyDescription;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestEmptyDescription');
   (* An ini section with nothing after DESCRIPTION= becomes msgid "" in
     every catalogue. That is "no help", not a blank tooltip. *)
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         'msgctxt "TC_HELP_BLANK_ONE"' + LineEnding +
         'msgid ""' + LineEnding +
         'msgstr ""' + LineEnding);
      CheckFalse(cat.TryGetText('TC_HELP_BLANK_ONE', text), 'empty is absent');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestUntranslatedUsesEnglishMsgid;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestUntranslatedUsesEnglishMsgid');
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         'msgctxt "TC_HELP_CW_TONE"' + LineEnding +
         'msgid "The sidetone pitch."' + LineEnding +
         'msgstr ""' + LineEnding);
      CheckTrue(cat.TryGetText('TC_HELP_CW_TONE', text), 'an untranslated entry still answers');
      CheckEquals('The sidetone pitch.', text, 'with the English msgid');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestContinuationAndEscapes;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestContinuationAndEscapes');
   (* THE SHAPE WEBLATE WRITES: a long msgstr rewrapped into continuation
     lines, with an empty first line. Today only the header looks like this;
     a single-line reader would lose everything after the first Weblate
     commit. CRLF here, to prove the line ending does not matter. *)
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         'msgctxt "TC_HELP_WRAPPED"' + #13#10 +
         'msgid ""' + #13#10 +
         '"First half, "' + #13#10 +
         '"second half."' + #13#10 +
         'msgstr ""' + #13#10 +
         '"Erste H' + #$00E4 + 'lfte, "' + #13#10 +
         '"zweite \"H' + #$00E4 + 'lfte\" \\ ok."' + #13#10);
      CheckTrue(cat.TryGetText('TC_HELP_WRAPPED', text), 'found');
      CheckEquals('Erste H' + #$00E4 + 'lfte, zweite "H' + #$00E4 + 'lfte" \ ok.',
                  text, 'continuations joined, escapes undone, umlaut intact');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestObsoleteAndFuzzy;
var
   cat: TCommandHelpCatalogue;
   text: string;
begin
   BeginTest('TestObsoleteAndFuzzy');
   cat := TCommandHelpCatalogue.Create;
   try
      cat.LoadFromText(EnglishHeader +
         '#, fuzzy' + LineEnding +
         'msgctxt "TC_HELP_DRAFT"' + LineEnding +
         'msgid "English."' + LineEnding +
         'msgstr "Machine draft."' + LineEnding + LineEnding +
         '#~ msgctxt "TC_HELP_GONE"' + LineEnding +
         '#~ msgid "Old."' + LineEnding +
         '#~ msgstr "Alt."' + LineEnding);
      (* NY4I, 2026-09-19/21: unreviewed text ships. *)
      CheckTrue(cat.TryGetText('TC_HELP_DRAFT', text), 'a fuzzy entry is used');
      CheckEquals('Machine draft.', text, 'its draft text');
      CheckFalse(cat.TryGetText('TC_HELP_GONE', text), 'an obsolete entry is not');
      CheckEquals(1, cat.Count, 'and is not counted');
   finally
      cat.Free;
   end;
end;

procedure TCommandHelpTests.TestLanguageFallback;
var
   dir: string;
   help: TCommandHelp;
begin
   BeginTest('TestLanguageFallback');
   dir := TempHelpDir('fallback');
   WriteUtf8File(dir + 'help_en.po', EnglishHeader +
      'msgctxt "TC_HELP_CW_TONE"' + LineEnding +
      'msgid "The sidetone pitch."' + LineEnding +
      'msgstr "The sidetone pitch."' + LineEnding + LineEnding +
      'msgctxt "TC_HELP_ONLY_ENGLISH"' + LineEnding +
      'msgid "Only in English."' + LineEnding +
      'msgstr "Only in English."' + LineEnding);
   WriteUtf8File(dir + 'help_es.po', EnglishHeader +
      'msgctxt "TC_HELP_CW_TONE"' + LineEnding +
      'msgid "The sidetone pitch."' + LineEnding +
      'msgstr "El tono lateral."' + LineEnding);

   help := TCommandHelp.Create(dir, 'es');
   try
      CheckEquals('El tono lateral.', help.Describe('CW TONE'), 'the language first');
      CheckEquals('Only in English.', help.Describe('ONLY ENGLISH'),
                  'a section the language lacks falls back to English');
      CheckEquals('', help.Describe('NOT ANYWHERE'), 'and none is none');
      CheckEquals('', help.Describe(''), 'an empty name asks nothing');
   finally
      help.Free;
   end;

   help := TCommandHelp.Create(dir, 'ja');
   try
      CheckEquals('The sidetone pitch.', help.Describe('CW TONE'),
                  'a language with no catalogue is English');
      CheckEquals('', help.LanguageFile, 'and loads only English');
   finally
      help.Free;
   end;

   help := TCommandHelp.Create(dir, '');
   try
      CheckEquals('The sidetone pitch.', help.Describe('CW TONE'),
                  'an English run ('''') reads English');
   finally
      help.Free;
   end;
end;

procedure TCommandHelpTests.TestRegionFallsToLanguage;
var
   dir: string;
begin
   BeginTest('TestRegionFallsToLanguage');
   dir := TempHelpDir('region');
   WriteUtf8File(dir + 'help_en.po', EnglishHeader);
   WriteUtf8File(dir + 'help_pt.po', EnglishHeader);
   CheckEquals(dir + 'help_pt.po', HelpCatalogueFile(dir, 'pt_br'),
               'pt_br has no catalogue of its own, so Portuguese');
   CheckEquals(dir + 'help_en.po', HelpCatalogueFile(dir, 'zh_cn'),
               'zh_cn has neither, so English');
   (* The file is spelled help_pt_BR.po and the code arrives as pt_br. On
     Linux the lower-case name finds nothing; the path returned must be the
     catalogue's own spelling (Windows' FileExists ignores case, so the
     returned string is what this can check). *)
   WriteUtf8File(dir + 'help_pt_BR.po', EnglishHeader);
   CheckEquals(dir + 'help_pt_BR.po', HelpCatalogueFile(dir, 'pt_br'),
               'pt_br finds help_pt_BR.po by its own spelling');
   CheckEquals(dir + 'help_pt_BR.po', HelpCatalogueFile(dir, 'PT_BR'),
               'whatever case the code arrives in');
end;

procedure TCommandHelpTests.TestNoFilesAtAll;
var
   help: TCommandHelp;
begin
   BeginTest('TestNoFilesAtAll');
   (* A developer run from tr4w/target has no help\ directory. *)
   help := TCommandHelp.Create(TempHelpDir('empty') + 'nothing_here', 'es');
   try
      CheckEquals('', help.Describe('CW TONE'), 'no files, no help, no exception');
      CheckEquals('', help.EnglishFile, 'and says it loaded nothing');
   finally
      help.Free;
   end;
end;

procedure TCommandHelpTests.TestHintFormat;
var
   long: string;
   hint: string;
   lines: TStringList;
   i: integer;
begin
   BeginTest('TestHintFormat');
   CheckEquals('short text', FormatHelpHint('  short   text  '), 'spaces collapse');
   CheckEquals('a / b', FormatHelpHint('a | b'),
               'a pipe would split the LCL hint in two');

   long := '';
   for i := 1 to 200 do
      begin
      long := long + 'word' + IntToStr(i) + ' ';
      end;
   hint := FormatHelpHint(long);
   CheckTrue(Pos(' ...', hint) > 0, 'a long text is cut and says so');
   lines := TStringList.Create;
   try
      lines.Text := hint;
      CheckTrue(lines.Count > 1, 'and is wrapped');
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Length(lines[i]) <= HELP_HINT_WIDTH,
                   Format('line %d is %d columns', [i, Length(lines[i])]));
         end;
   finally
      lines.Free;
   end;
   CheckTrue(Length(StringReplace(hint, LineEnding, ' ', [rfReplaceAll])) <=
             HELP_HINT_MAX_CHARS + 4, 'the cap holds');

   CheckEquals('x' + LineEnding + StringOfChar('y', 80),
               FormatHelpHint('x ' + StringOfChar('y', 80)),
               'a word longer than the width gets its own line, unbroken');
end;

procedure TCommandHelpTests.TestEveryRegisteredSettingHasHelp;
var
   path: string;
   help: TCommandHelp;
   s: TSettingBase;
   missing: TStringList;
   expected: TStringList;
   seen: TDictionary<string, boolean>;
   name: string;
   i: integer;
begin
   BeginTest('TestEveryRegisteredSettingHasHelp');
   (* The catalogue the installer ships as help\help_en.po. *)
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
           '..' + PathDelim + '..' + PathDelim + 'i18n');
   CheckTrue(FileExists(IncludeTrailingPathDelimiter(path) + 'help_en.po'),
             'i18n/help_en.po is found from the test binary: ' + path);

   DeclareAllSettings;
   help     := TCommandHelp.Create(path, 'en');
   missing  := TStringList.Create;
   expected := TStringList.Create;
   seen     := TDictionary<string, boolean>.Create;
   try
      CheckTrue(help.EnglishFile <> '', 'the English catalogue loaded');
      for s in AllSettings do
         begin
         name := UpperCase(Trim(s.LegacyCommand));
         if (name = '') or seen.ContainsKey(name) then
            begin
            Continue;
            end;
         seen.Add(name, True);
         if help.Describe(name) = '' then
            begin
            missing.Add(name);
            end;
         end;
      missing.Sort;
      CheckTrue(seen.Count > 100, Format('the registry was populated (%d commands)',
                                          [seen.Count]));

      for i := Low(KNOWN_HELP_GAPS) to High(KNOWN_HELP_GAPS) do
         begin
         expected.Add(KNOWN_HELP_GAPS[i]);
         end;
      expected.Sort;

      CheckEquals(expected.CommaText, missing.CommaText,
                  'registered settings with no English help -- update ' +
                  'KNOWN_HELP_GAPS (both directions) or write the help');
   finally
      seen.Free;
      expected.Free;
      missing.Free;
      help.Free;
   end;
end;

procedure TCommandHelpTests.TestRealCatalogueIsUtf8;
var
   path: string;
   help: TCommandHelp;
   text: string;
begin
   BeginTest('TestRealCatalogueIsUtf8');
   (* THE REASON THIS READER EXISTS, against the bytes that ship: the
     catalogue on disk is UTF-8, and an accented word must arrive whole --
     no '?' and no mojibake. *)
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
           '..' + PathDelim + '..' + PathDelim + 'i18n');
   help := TCommandHelp.Create(path, 'es');
   try
      CheckTrue(Pos('help_es.po', help.LanguageFile) > 0,
                'the Spanish catalogue loaded: ' + help.LanguageFile);
      text := help.Describe('ALT-D BUFFER ENABLE');
      CheckEquals('Este comando controla si el b' + #$00FA + 'fer alt-D est' +
                  #$00E1 + ' habilitado.',
                  Copy(text, 1, 56), 'the accented Spanish arrives intact');
   finally
      help.Free;
   end;
end;

procedure TCommandHelpTests.RunAllTests;
begin
   TestKeyMatchesIni2po;
   TestFoundSection;
   TestMissingSection;
   TestEmptyDescription;
   TestUntranslatedUsesEnglishMsgid;
   TestContinuationAndEscapes;
   TestObsoleteAndFuzzy;
   TestLanguageFallback;
   TestRegionFallsToLanguage;
   TestNoFilesAtAll;
   TestHintFormat;
   TestEveryRegisteredSettingHasHelp;
   TestRealCatalogueIsUtf8;
end;

end.
