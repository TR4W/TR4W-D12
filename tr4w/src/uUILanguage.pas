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

  WINDOWS AND LINUX: FPC's gettext.GetLanguageIDs, unchanged from before this
  unit existed -- GetLocaleInfo on Windows, LC_ALL / LC_MESSAGES / LANG on
  Unix.

  macOS: the same environment first, so a terminal launch behaves as it
  always did; then the user's PREFERRED LANGUAGES; then the region locale.
  See the implementation for why the environment is not enough there. *)
function SystemUILanguage(out aDescription: string): string;

(* The language half of a locale id: 'de_DE' -> 'de', 'zh-Hans-CN' -> 'zh',
  'pt' -> 'pt'. Lower case. The catalogues are keyed on it. *)
function LanguagePartOf(const aLocaleId: string): string;

(* How a source is named in the log line "UI language: "xx" selected by ...". *)
function UILanguageSourceName(const aSource: TUILanguageSource): string;

implementation

uses
   SysUtils,
   gettext
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
   (* AnsiString EXPLICITLY: gettext is RTL code compiled with 8-bit strings
     and takes these by VAR, while string here is UnicodeString (tr4w.inc). A
     var parameter has to match exactly. *)
   fullId, shortId: AnsiString;
{$IFDEF DARWIN}
   preferred: string;
   region: TLanguageID;
{$ENDIF}
begin
   (* FPC'S OWN, and on Windows and Linux this is the whole of it --
     GetLocaleInfo on Windows, the LC_ALL / LC_MESSAGES / LANG environment on
     Unix. Unchanged from what ResolveLang did before the setting existed. *)
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
