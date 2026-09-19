(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)
unit uUILanguage;
{$I tr4w.inc}

(*
  WHICH LANGUAGE THE UI SPEAKS, AND WHERE THAT ANSWER CAME FROM.

  THE PRECEDENCE (NY4I, 2026-09-19, roadmap 6.3):

    1. a --lang / -l / --lang= switch        -- an explicit instruction
    2. the Language setting in tr4w.json     -- Settings.Display.Language
    3. the operating system's language
    4. the compiled-in English

  The setting exists because a Mac has no practical command line -- an app
  started from Finder or the Dock is given no arguments -- so without it an
  operator could not choose a language at all except by changing the whole
  machine's. It overrides the OS rather than the other way round because an
  operator on a Spanish Windows does not necessarily want a Spanish contest log.

  WHY A UNIT OF ITS OWN, with no logger and no resource access. The rule is a
  PURE FUNCTION (ChooseUILanguage) so the unit tests can pin every arm of it,
  and the OS question (SystemUILanguage) is small enough to compile on its own
  on a Mac, which is the only place its Darwin arm can be proven. Loading a
  catalogue, and logging what happened, stay in uEmbeddedTranslations.

  EVERY CODE IS LOWER CASE here and downstream, because the catalogues are
  named that way (resource TR4W_DE, file languages\de\tr4w.po) and a setting
  or a switch may be typed in either case.
*)

interface

type
   (* Where the chosen code came from. Reported in the log beside the code,
     because "Spanish did not appear" has different causes depending on which
     of these supplied it. *)
   TUILanguageSource = (ulsNone, ulsSwitch, ulsSetting, ulsSystem);

   (* Is there a catalogue for this code? Asked of the SETTING only -- see
     ChooseUILanguage. A plain procedure type so a test can pass a stub. *)
   TUILanguageAvailable = function(const aCode: string): boolean;

(* THE PRECEDENCE, AS A PURE FUNCTION.

  aSwitch, aSetting and aSystem are what each source offers, '' for nothing.
  Returns the chosen code in lower case, or '' when no source offered one --
  which the caller reads as the compiled-in English.

  A SETTING THIS BUILD HAS NO CATALOGUE FOR IS PASSED OVER, and
  aSettingRefused says so. It came from a file: a catalogue can be removed
  from a later build, or the file can be hand-edited, and an operator who
  once chose a language must not be left with English because of it when the
  OS could have supplied one. The caller logs the refusal.

  THE SWITCH AND THE OS ARE NOT CHECKED, which is exactly the behaviour they
  had before the setting existed: an unknown switch is reported by the loader
  as "no catalogue embedded" and the run is English. A switch is typed by the
  person watching, who is told. *)
function ChooseUILanguage(const aSwitch, aSetting, aSystem: string;
                          const aIsAvailable: TUILanguageAvailable;
                          out aSource: TUILanguageSource;
                          out aSettingRefused: boolean): string;

(* The code a --lang / -l / --lang= switch names, or '' with no switch.
  aSwitchName is the spelling that was used, for the log. *)
function UILanguageFromCommandLine(out aSwitchName: string): string;

(* The operating system's language, as a lower-case code ('de'), or ''.
  aDescription says what was read, for the log -- 'the operating system
  locale (de_DE)'.

  WINDOWS: the operator's DISPLAY LANGUAGE first -- what Windows itself is
  shown in -- then the region locale as read by LazUtils. See the
  implementation for why FPC's gettext.GetLanguageIDs is not used here.

  LINUX: FPC's gettext.GetLanguageIDs, unchanged from before this unit
  existed -- LC_ALL / LC_MESSAGES / LANG.

  macOS: the same environment first, so a terminal launch behaves as it
  always did; then the user's PREFERRED LANGUAGES; then the region locale.
  See the implementation for why the environment is not enough there. *)
function SystemUILanguage(out aDescription: string): string;

(* The language half of a locale id: 'de_DE' -> 'de', 'zh-Hans-CN' -> 'zh',
  'pt' -> 'pt'. Lower case. The catalogues are keyed on it. *)
function LanguagePartOf(const aLocaleId: string): string;

(* THE CATALOGUE CODE A PLATFORM'S RAW ANSWER RESOLVES TO, as a pure
  function so it can be pinned without a Japanese Windows to hand.

    'ja-JP'       -> 'ja'        'de-DE'  -> 'de'
    'zh-Hans-CN'  -> 'zh_cn'     'pt-BR'  -> 'pt_br'
    'jp', 'jpn'   -> 'ja'        'mo'     -> 'mn'
    ''            -> ''

  TWO THINGS IT DOES BEYOND TAKING THE LANGUAGE HALF.

  It repairs the spellings Windows' own abbreviations produce. FPC's
  gettext.GetLanguageIDs takes the first two letters of
  LOCALE_SABBREVLANGNAME (gettext.pp:298-299), so JPN becomes 'jp', MON
  becomes 'mo' and CHS becomes 'ch' -- none of which is the ISO 639-1 code a
  catalogue is named after, so those operators silently got English. That
  derivation is no longer the one this unit uses, but the spellings are kept
  in the table below because they are what a stored setting, an older log or
  a hand-typed switch may still say.

  And it keeps the REGION where a catalogue is region-qualified: we ship
  pt_BR as well as pt, and the only Chinese catalogue is Simplified. Every
  other language is keyed on the language alone, which is why the default
  arm drops the region rather than inventing 'de_at'. *)
function SystemLanguageCode(const aLocaleId: string): string;

(* How a source is named in the log line "UI language: "xx" selected by ...". *)
function UILanguageSourceName(const aSource: TUILanguageSource): string;

implementation

uses
   SysUtils
{$IFDEF WINDOWS}
   (* LazUtils', and it is the FALLBACK on Windows -- see SystemUILanguage.
     gettext is deliberately NOT used there: its Windows arm derives the code
     from LOCALE_SABBREVLANGNAME and gets Japanese, Mongolian and Chinese
     wrong. Translations reads LOCALE_SISO639LANGNAME instead. *)
   , Translations
{$ELSE}
   , gettext
{$ENDIF}
{$IFDEF DARWIN}
   (* THE TWO DARWIN-ONLY DEPENDENCIES, and neither is a new library.

     MacOSAll is FPC's own binding to Apple's frameworks (packages/univint);
     CoreFoundation is already linked into every Cocoa LCL program, so this
     adds no library to the link and nothing at all off Darwin.

     Translations is LazUtils', and it is what already answers the region
     locale on a Mac -- see SystemUILanguage. *)
   , MacOSAll
   , Translations
{$ENDIF}
   ;

function LanguagePartOf(const aLocaleId: string): string;
var
   i: integer;
begin
   Result := Trim(aLocaleId);
   for i := 1 to Length(Result) do
      begin
      if (Result[i] = '_') or (Result[i] = '-') or (Result[i] = '.') or
         (Result[i] = '@') then
         begin
         Result := Copy(Result, 1, i - 1);
         Break;
         end;
      end;
   Result := LowerCase(Result);
end;

(* A locale id taken apart: 'zh-Hans-CN' -> 'zh', 'hans', 'cn'.

  BCP 47 and the POSIX spelling are both accepted, because both reach here --
  Windows answers 'ja-JP', a Unix environment says 'ja_JP.UTF-8'. The
  separator is '-' or '_', the codeset and the @modifier are dropped, and a
  four-letter subtag is a script while a two- or three-character one is the
  region. Nothing here knows what any of the values MEAN; that is
  SystemLanguageCode's job. *)
procedure SplitLocaleId(const aLocaleId: string;
                        out aLanguage, aScript, aRegion: string);
var
   text: string;
   part: string;
   i:    integer;
   partIndex: integer;

   procedure TakePart;
   begin
      (* THE FIRST SUBTAG IS THE LANGUAGE EVEN WHEN IT IS EMPTY. A malformed
        id such as '_US' has no language, and must resolve to nothing rather
        than sliding the region up into the language's place. *)
      if partIndex = 0 then
         begin
         aLanguage := part;
         end
      else if part = '' then
         begin
         (* A doubled or trailing separator: nothing to take, and the
           position does not advance. *)
         Exit;
         end
      else if (Length(part) = 4) and (aScript = '') then
         begin
         aScript := part;
         end
      else if (Length(part) >= 2) and (Length(part) <= 3) and (aRegion = '') then
         begin
         aRegion := part;
         end;
      Inc(partIndex);
      part := '';
   end;

begin
   aLanguage := '';
   aScript   := '';
   aRegion   := '';

   text := LowerCase(Trim(aLocaleId));
   i := Pos('.', text);
   if i > 0 then
      begin
      text := Copy(text, 1, i - 1);
      end;
   i := Pos('@', text);
   if i > 0 then
      begin
      text := Copy(text, 1, i - 1);
      end;

   part      := '';
   partIndex := 0;
   for i := 1 to Length(text) do
      begin
      if (text[i] = '-') or (text[i] = '_') then
         begin
         TakePart;
         end
      else
         begin
         part := part + text[i];
         end;
      end;
   TakePart;
end;

function SystemLanguageCode(const aLocaleId: string): string;
const
   (* THE SPELLINGS THAT ARE NOT THE CATALOGUE'S NAME. Windows' three-letter
     abbreviation truncated to two (the gettext derivation), and the ISO
     639-2 three-letter codes for the same languages.

     'mo' -> 'mn' deserves its own sentence: 'mo' was the withdrawn ISO code
     for Moldavian, and it lands here only because MON (Mongolian)
     truncates to it. We ship no Moldavian catalogue and never have, so
     there is nothing for the ambiguity to cost. *)
   LEGACY_LANGUAGES: array[0..8, 0..1] of string = (
      ('jp',  'ja'),
      ('jpn', 'ja'),
      ('mo',  'mn'),
      ('mon', 'mn'),
      ('ch',  'zh'),
      ('chs', 'zh'),
      ('cht', 'zh'),
      ('chi', 'zh'),
      ('zho', 'zh'));

   (* THE CATALOGUES KEYED ON A REGION AS WELL AS A LANGUAGE. Everything
     else drops the region. Chinese is not in this list because it needs a
     rule rather than a match -- see below. Add a row here when a
     region-qualified catalogue is added to i18n\. *)
   REGIONAL_CATALOGUES: array[0..0] of string = ('pt_br');

var
   language, script, region: string;
   i: integer;
begin
   SplitLocaleId(aLocaleId, language, script, region);
   if language = '' then
      begin
      Result := '';
      Exit;
      end;

   (* CHS is Simplified and CHT is Traditional, and the script is the only
     place that survives folding them both to 'zh'. Recorded before the
     fold, and only when the id did not carry a script of its own. *)
   if script = '' then
      begin
      if language = 'cht' then
         begin
         script := 'hant';
         end
      else if (language = 'chs') or (language = 'ch') then
         begin
         script := 'hans';
         end;
      end;

   for i := Low(LEGACY_LANGUAGES) to High(LEGACY_LANGUAGES) do
      begin
      if language = LEGACY_LANGUAGES[i, 0] then
         begin
         language := LEGACY_LANGUAGES[i, 1];
         Break;
         end;
      end;

   (* CHINESE IS A SCRIPT QUESTION, NOT A COUNTRY ONE. Traditional is read
     in Taiwan, Hong Kong and Macau; everywhere else is Simplified, which is
     the only Chinese catalogue this tree carries -- so a Traditional
     operator resolves to 'zh_tw', finds no catalogue, and is told so in the
     log rather than being given text in the wrong script. *)
   if language = 'zh' then
      begin
      if (script = 'hant') or (region = 'tw') or (region = 'hk') or
         (region = 'mo') then
         begin
         Result := 'zh_tw';
         end
      else
         begin
         Result := 'zh_cn';
         end;
      Exit;
      end;

   if region <> '' then
      begin
      for i := Low(REGIONAL_CATALOGUES) to High(REGIONAL_CATALOGUES) do
         begin
         if REGIONAL_CATALOGUES[i] = language + '_' + region then
            begin
            Result := REGIONAL_CATALOGUES[i];
            Exit;
            end;
         end;
      end;

   Result := language;
end;

function ChooseUILanguage(const aSwitch, aSetting, aSystem: string;
                          const aIsAvailable: TUILanguageAvailable;
                          out aSource: TUILanguageSource;
                          out aSettingRefused: boolean): string;
var
   setting: string;
begin
   aSettingRefused := False;

   if Trim(aSwitch) <> '' then
      begin
      aSource := ulsSwitch;
      Result  := LowerCase(Trim(aSwitch));
      Exit;
      end;

   setting := LowerCase(Trim(aSetting));
   if setting <> '' then
      begin
      if Assigned(aIsAvailable) and aIsAvailable(setting) then
         begin
         aSource := ulsSetting;
         Result  := setting;
         Exit;
         end;
      aSettingRefused := True;
      end;

   if Trim(aSystem) <> '' then
      begin
      aSource := ulsSystem;
      Result  := LowerCase(Trim(aSystem));
      Exit;
      end;

   aSource := ulsNone;
   Result  := '';
end;

function UILanguageFromCommandLine(out aSwitchName: string): string;
var
   i:   integer;
   arg: string;
begin
   Result      := '';
   aSwitchName := '';
   for i := 1 to ParamCount do
      begin
      arg := ParamStr(i);
      (* UnicodeSameText: SameText takes AnsiString, and this unit's string is
        UnicodeString -- see uTR4WConfigFile.SettingsPathFromCommandLine for
        the same note. *)
      if (UnicodeSameText(arg, '--lang') or UnicodeSameText(arg, '-l')) and
         (i < ParamCount) then
         begin
         aSwitchName := 'the ' + arg + ' command-line switch';
         Result      := LowerCase(ParamStr(i + 1));
         Exit;
         end;
      if UnicodeSameText(Copy(arg, 1, 7), '--lang=') then
         begin
         aSwitchName := 'the --lang= command-line switch';
         Result      := LowerCase(Copy(arg, 8, MaxInt));
         Exit;
         end;
      end;
end;

function UILanguageSourceName(const aSource: TUILanguageSource): string;
begin
   case aSource of
      ulsSwitch:
         begin
         Result := 'a command-line switch';
         end;
      ulsSetting:
         begin
         Result := 'the Language setting in tr4w.json';
         end;
      ulsSystem:
         begin
         Result := 'the operating system';
         end;
   else
      begin
      Result := 'nothing';
      end;
   end;
end;

{$IFDEF WINDOWS}
(* THE FIRST OF THE OPERATOR'S PREFERRED UI LANGUAGES -- 'ja-JP',
  'zh-Hans-CN' -- or '' if Windows will not say.

  WHY THIS IS A RAW CALL, against the standing rule that an FPC or LCL
  facility comes first. Both facilities that exist answer a DIFFERENT
  QUESTION: gettext.GetLanguageIDs and Translations.GetLanguageID each read
  GetUserDefaultLCID, the regional FORMAT locale. Nothing in FPC or the LCL
  asks which language Windows is DISPLAYED in, and that is the one NY4I
  named. GetLanguageID is still consulted as the fallback beneath this.

  It is exactly the shape of the Darwin arm below, for exactly the same
  reason, and neither is a new library: kernel32 is the OS, not a bundled
  DLL, and MUI_LANGUAGE_NAME has been available since Windows Vista.

  THE PWideChar IS THE C BOUNDARY and goes no further than this routine. The
  API writes a double-NUL-terminated list of BCP 47 names; the first is the
  display language. 256 WideChars holds far more than the handful of
  eight-character tags Windows can return, and the buffer is read out a
  character at a time rather than cast to a string, so a missing terminator
  cannot walk off the end. *)
const
   (* Return BCP 47 names ('en-US') rather than hexadecimal LANGIDs. *)
   MUI_LANGUAGE_NAME = $8;

(* Declared here rather than taken from the Windows unit, which does not
  carry it: FPC 3.2.2's win32 headers stop at GetUserDefaultLCID. LongWord
  for DWORD/ULONG and LongBool for BOOL, so this unit needs no Windows
  import at all. *)
function GetUserPreferredUILanguages(dwFlags: LongWord;
                                     var pulNumLanguages: LongWord;
                                     pwszLanguagesBuffer: PWideChar;
                                     var pcchLanguagesBuffer: LongWord): LongBool;
                                     stdcall;
                                     external 'kernel32'
                                     name 'GetUserPreferredUILanguages';

function WindowsDisplayLanguage: string;
var
   languageCount: LongWord;
   bufferChars:   LongWord;
   buffer:        array[0..255] of WideChar;
   i:             integer;
begin
   Result        := '';
   languageCount := 0;
   bufferChars   := Length(buffer);
   buffer[0]     := #0;

   if not GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, languageCount,
                                      @buffer[0], bufferChars) then
      begin
      Exit;
      end;
   if languageCount = 0 then
      begin
      Exit;
      end;

   i := 0;
   while (i <= High(buffer)) and (buffer[i] <> #0) do
      begin
      Result := Result + buffer[i];
      Inc(i);
      end;
end;
{$ENDIF}

{$IFDEF DARWIN}
(* THE FIRST OF THE USER'S PREFERRED LANGUAGES -- 'de-US' -- or ''.

  WHY THIS IS NOT LEFT TO THE LCL, which does have an answer. LazUtils'
  Translations.GetLanguageID reads the environment and then AppleLocale, and
  AppleLocale is the REGION FORMAT setting: what the dates and the decimal
  separator look like. The language the operator wants to READ is a
  different setting -- the ordered Preferred Languages list in System
  Settings > General > Language & Region -- and CFLocaleCopyPreferredLanguages
  is Apple's documented way to ask for it. Nothing in FPC or the LCL asks it.
  So this is the one raw call, and GetLanguageID is still consulted as the
  fallback below it.

  THE PAnsiChar IS THE C BOUNDARY and goes no further than this routine:
  CFStringGetCString writes UTF-8 into a caller's buffer, and a locale id is
  ASCII, so 64 bytes is ample and the conversion out cannot lose anything. *)
function DarwinPreferredLanguage: string;
var
   languages: CFArrayRef;
   first: CFStringRef;
   buffer: array[0..63] of AnsiChar;
begin
   Result := '';
   languages := CFLocaleCopyPreferredLanguages;
   if languages = nil then
      begin
      Exit;
      end;
   try
      if CFArrayGetCount(languages) > 0 then
         begin
         first := CFStringRef(CFArrayGetValueAtIndex(languages, 0));
         FillChar(buffer, SizeOf(buffer), 0);
         if (first <> nil) and
            CFStringGetCString(first, @buffer[0], SizeOf(buffer),
                               kCFStringEncodingUTF8) then
            begin
            Result := string(AnsiString(PAnsiChar(@buffer[0])));
            end;
         end;
   finally
      CFRelease(languages);
   end;
end;
{$ENDIF}

function SystemUILanguage(out aDescription: string): string;
var
{$IFNDEF WINDOWS}
   (* AnsiString EXPLICITLY: gettext is RTL code compiled with 8-bit strings
     and takes these by VAR, while string here is UnicodeString (tr4w.inc). A
     var parameter has to match exactly. *)
   fullId, shortId: AnsiString;
{$ENDIF}
{$IFDEF WINDOWS}
   displayLanguage: string;
   windowsRegion: TLanguageID;
{$ENDIF}
{$IFDEF DARWIN}
   preferred: string;
   region: TLanguageID;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   (* THE LANGUAGE WINDOWS ITSELF IS SHOWN IN, which is what NY4I asked for:
     "use the windows language if set" (2026-09-19).

     THE REGION FORMAT IS A DIFFERENT SETTING, and this is the same
     distinction the Darwin arm below documents. Both FPC's
     gettext.GetLanguageIDs and LazUtils' Translations.GetLanguageID read
     GetUserDefaultLCID -- Settings > Time & language > Regional format,
     what the dates and the decimal separator look like. The language the
     operator chose to READ is the display language, and
     GetUserPreferredUILanguages is the documented way to ask for it. *)
   displayLanguage := WindowsDisplayLanguage;
   if displayLanguage <> '' then
      begin
      aDescription := 'the Windows display language (' + displayLanguage + ')';
      Result       := SystemLanguageCode(displayLanguage);
      Exit;
      end;

   (* THE REGION LOCALE, and LazUtils rather than gettext deliberately.
     gettext.pp:298-299 takes the first two letters of
     LOCALE_SABBREVLANGNAME, so JPN -> 'jp', MON -> 'mo' and CHS -> 'ch',
     none of which names a catalogue; translations.pas:534 reads
     LOCALE_SISO639LANGNAME, which is the ISO 639-1 code itself.

     It cannot answer nothing: NormalizeLanguageID (translations.pas:455)
     fills in en_US when the locale cannot be read, so this arm ends in
     English rather than in ''. That is the same outcome '' would produce
     and one fewer way to get there. *)
   windowsRegion := Translations.GetLanguageID;
   (* Length rather than <> '': LazUtils' field is an AnsiString and this
     unit's literal is Unicode, so the comparison would convert. *)
   if Length(windowsRegion.LanguageCode) > 0 then
      begin
      aDescription := 'the operating system locale (' +
                      string(windowsRegion.LanguageID) + ')';
      Result       := SystemLanguageCode(string(windowsRegion.LanguageID));
      Exit;
      end;
{$ELSE}
   (* FPC'S OWN, and on Linux this is the whole of it -- the LC_ALL /
     LC_MESSAGES / LANG environment. Unchanged from what ResolveLang did
     before the setting existed. *)
   fullId  := '';
   shortId := '';
   GetLanguageIDs(fullId, shortId);

   if shortId <> '' then
      begin
      aDescription := 'the operating system locale (' + string(fullId) + ')';
      Result       := LowerCase(string(shortId));
      Exit;
      end;
   if fullId <> '' then
      begin
      aDescription := 'the operating system locale (' + string(fullId) + ')';
      Result       := LanguagePartOf(string(fullId));
      Exit;
      end;
{$ENDIF}

{$IFDEF DARWIN}
   (* AN APP STARTED FROM FINDER OR THE DOCK HAS NO LANG. macOS keeps the
     user's language in its own preferences, not in the environment, so
     GetLanguageIDs above answers nothing for every Mac operator who did not
     start TR4W from a terminal -- which is every Mac log to date: "no code
     could be determined from nothing". *)
   preferred := DarwinPreferredLanguage;
   if preferred <> '' then
      begin
      aDescription := 'the macOS preferred language (' + preferred + ')';
      Result       := LanguagePartOf(preferred);
      Exit;
      end;

   region := Translations.GetLanguageID;
   if region.LanguageCode <> '' then
      begin
      aDescription := 'the macOS region locale (' + string(region.LanguageID) + ')';
      Result       := LowerCase(string(region.LanguageCode));
      Exit;
      end;
{$ENDIF}

   aDescription := 'the locale could not be read';
   Result       := '';
end;

end.
