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
unit uCommandHelp;

(*
  THE HELP TEXT FOR A CONFIG COMMAND, in the operator's language.

  WHERE IT COMES FROM. i18n/help_<code>.po, installed as help\help_<code>.po
  beside the program (full.nsi; build-unix.sh stages help/ and moves it into
  Contents/Resources on macOS). tools/i18n/ini2po.py builds those catalogues
  from tr4w/target/commands_help_<lang>.ini, which is the AUTHORING source and
  is not read here: the non-English ini files are cp1250/cp1251/cp1252 bytes,
  while the catalogues are UTF-8 in every language and carry eleven languages
  to the ini's seven. docs/I18N_PLAN.md step 9 and the full.nsi comment both
  say the pane reads the catalogues.

  WHY NOT LazUtils' TPOFile. It files an entry under its `#:` line and drops
  an entry that has none -- and no help catalogue has a single `#:` line.
  Each is keyed by msgctxt alone ("TC_HELP_ALT_D_CQ_ENABLE"), so this unit
  reads exactly that much of the format: msgctxt, msgid, msgstr, continuation
  lines and the C escapes. Obsolete (#~) entries are skipped; fuzzy entries
  are KEPT, by NY4I's standing decision that unreviewed text ships
  (2026-09-19 / 2026-09-21), the same rule the UI catalogues follow.

  THE FALLBACK. The language's catalogue, then help_en.po. Within one entry a
  blank msgstr means "not translated" and the msgid -- which IS the English --
  is used. A region code that has no catalogue of its own ('pt_br') tries its
  language ('pt') before English.

  A LEAF, with no globals and no LCL. The caller decides the directory and the
  language and owns the object; uSettingsBinding turns the text into a hint.
*)

{$I tr4w.inc}

interface

uses
   SysUtils,
   Classes,
   Generics.Collections;

const
   (* The msgctxt prefix ini2po.key_for writes. *)
   COMMAND_HELP_KEY_PREFIX = 'TC_HELP_';
   ENGLISH_HELP_CODE       = 'en';

   (* THE HINT SHAPE -- see FormatHelpHint. *)
   HELP_HINT_WIDTH     = 70;
   HELP_HINT_MAX_CHARS = 600;

type
   (* ONE help catalogue: msgctxt -> the text to show. *)
   TCommandHelpCatalogue = class(TObject)
   private
      FTexts: TDictionary<string, string>;
      procedure AddEntry(const aContext, aEnglish, aTranslation: string);
   public
      constructor Create;
      destructor Destroy; override;

      (* Replaces what was loaded. False, and empty, when the file cannot be
        read; a malformed line is skipped, never raised. *)
      function LoadFromFile(const aFileName: string): boolean;
      procedure LoadFromText(const aText: string);

      (* The text for a msgctxt key; False when the key is absent or its text
        is empty. *)
      function TryGetText(const aKey: string; out aText: string): boolean;
      function Count: integer;
   end;

   (* THE LANGUAGE'S CATALOGUE OVER ENGLISH -- what a caller asks. *)
   TCommandHelp = class(TObject)
   private
      FLanguage: TCommandHelpCatalogue;
      FEnglish: TCommandHelpCatalogue;
      FLanguageFile: string;
      FEnglishFile: string;
   public
      (* aHelpDir holds help_<code>.po; aLanguageCode is the UI language in
        force ('' or 'en' for English, 'es', 'pt_br'). Missing files are not an
        error: Describe then answers ''. *)
      constructor Create(const aHelpDir, aLanguageCode: string);
      destructor Destroy; override;

      (* The help for a command NAME ('ALT-D CQ ENABLE'), or '' when there is
        none in either catalogue. Exactly the name asked for: no alias is
        consulted, because a former name's help describes what the name USED
        to mean (BACKUP LOG FILE NAME named a file; BACKUP DESTINATION is a
        folder). *)
      function Describe(const aCommand: string): string;

      (* The files actually loaded, '' for none -- for the log line. *)
      property LanguageFile: string read FLanguageFile;
      property EnglishFile: string read FEnglishFile;

      (* True when NO catalogue was read, English included: every Describe
        answers '' and no tooltip will ever show. The caller logs it. *)
      function NothingLoaded: boolean;
   end;

(* 'S&P EXCHANGE' -> 'TC_HELP_S_P_EXCHANGE'. Exactly ini2po.key_for:
  upper-cased, every run of characters other than A-Z and 0-9 becomes one
  '_', and leading and trailing '_' are dropped. *)
function CommandHelpKey(const aCommand: string): string;

(* The catalogue file for a language code, searched in aHelpDir: the code as
  given, then its language part, then English. '' when none exists. *)
function HelpCatalogueFile(const aHelpDir, aLanguageCode: string): string;

(* HELP TEXT AS A HINT.

  Whitespace runs collapse to one space. '|' becomes '/', because the LCL
  splits a Hint at the first '|' into a short and a long hint and would show
  only the part before it. Text longer than aMaxChars is cut at the last space
  before the limit and ends in ' ...'. The result is wrapped at word
  boundaries to aWidth columns with LineEnding, since a hint window is only as
  wide as its longest line and some descriptions run to 900 characters. A word
  longer than aWidth gets a line of its own rather than being broken. *)
function FormatHelpHint(const aText: string;
                        const aWidth: integer = HELP_HINT_WIDTH;
                        const aMaxChars: integer = HELP_HINT_MAX_CHARS): string;

implementation

uses
   uUILanguage;   // LanguagePartOf

(* ---------------------------------------------------------- free functions - *)

function IsKeyChar(const aChar: char): boolean;
begin
   Result := ((aChar >= 'A') and (aChar <= 'Z')) or
             ((aChar >= '0') and (aChar <= '9'));
end;

function CommandHelpKey(const aCommand: string): string;
var
   upper: string;
   i: integer;
   pendingSeparator: boolean;
begin
   upper  := UpperCase(Trim(aCommand));
   Result := '';
   pendingSeparator := False;
   for i := 1 to Length(upper) do
      begin
      if IsKeyChar(upper[i]) then
         begin
         if pendingSeparator and (Result <> '') then
            begin
            Result := Result + '_';
            end;
         pendingSeparator := False;
         Result := Result + upper[i];
         end
      else
         begin
         pendingSeparator := True;
         end;
      end;
   Result := COMMAND_HELP_KEY_PREFIX + Result;
end;

function CatalogueFileName(const aHelpDir, aCode: string): string;
begin
   Result := IncludeTrailingPathDelimiter(aHelpDir) + 'help_' + aCode + '.po';
end;

(* 'pt_br' -> 'pt_BR', 'zh_cn' -> 'zh_CN': the spelling the catalogue FILE
  carries (i18n/help_pt_BR.po, the gettext ll_RR convention, the same as
  tr4w_pt_BR.po). The language code arrives lower-cased, and on a
  case-sensitive file system (Linux) help_pt_br.po does not find
  help_pt_BR.po -- Brazilian Portuguese got European Portuguese and Chinese
  got English. A code with no region is returned as it is. *)
function CatalogueSpelling(const aCode: string): string;
var
   separator: integer;
begin
   separator := Pos('_', aCode);
   if separator = 0 then
      begin
      Result := aCode;
      end
   else
      begin
      Result := Copy(aCode, 1, separator) +
                UpperCase(Copy(aCode, separator + 1, MaxInt));
      end;
end;

function HelpCatalogueFile(const aHelpDir, aLanguageCode: string): string;
var
   code: string;
   language: string;
begin
   code := LowerCase(Trim(aLanguageCode));
   if code <> '' then
      begin
      (* The catalogue's own spelling first, so on Linux the file is found
        and on Windows the path names it as it is on disk; then the code
        as given, for a catalogue saved in lower case. *)
      Result := CatalogueFileName(aHelpDir, CatalogueSpelling(code));
      if FileExists(Result) then
         begin
         Exit;
         end;
      Result := CatalogueFileName(aHelpDir, code);
      if FileExists(Result) then
         begin
         Exit;
         end;
      language := LanguagePartOf(code);
      if (language <> '') and (language <> code) then
         begin
         Result := CatalogueFileName(aHelpDir, language);
         if FileExists(Result) then
            begin
            Exit;
            end;
         end;
      end;
   Result := CatalogueFileName(aHelpDir, ENGLISH_HELP_CODE);
   if not FileExists(Result) then
      begin
      Result := '';
      end;
end;

function FormatHelpHint(const aText: string; const aWidth: integer;
                        const aMaxChars: integer): string;
var
   flat: string;
   i: integer;
   lastWasSpace: boolean;
   cut: integer;
   wordEnd: integer;
   line: string;
   w: string;
begin
   (* One line of single-spaced text, '|' made harmless. *)
   flat := '';
   lastWasSpace := False;
   for i := 1 to Length(aText) do
      begin
      if (aText[i] = ' ') or (aText[i] = #9) or (aText[i] = #10) or
         (aText[i] = #13) then
         begin
         lastWasSpace := True;
         Continue;
         end;
      if lastWasSpace and (flat <> '') then
         begin
         flat := flat + ' ';
         end;
      lastWasSpace := False;
      if aText[i] = '|' then
         begin
         flat := flat + '/';
         end
      else
         begin
         flat := flat + aText[i];
         end;
      end;

   if (aMaxChars > 0) and (Length(flat) > aMaxChars) then
      begin
      cut := aMaxChars;
      while (cut > 1) and (flat[cut] <> ' ') do
         begin
         Dec(cut);
         end;
      if cut <= 1 then
         begin
         cut := aMaxChars;   // one enormous word: cut it where it stands
         end;
      flat := TrimRight(Copy(flat, 1, cut)) + ' ...';
      end;

   if aWidth <= 0 then
      begin
      Result := flat;
      Exit;
      end;

   (* Word by word over the single-spaced text. Not a TStringList: in FPC
     3.2.2 it holds AnsiString, and a UnicodeString through it is a narrowing
     conversion that can lose every non-Latin character. *)
   Result := '';
   line   := '';
   i      := 1;
   while i <= Length(flat) do
      begin
      wordEnd := i;
      while (wordEnd <= Length(flat)) and (flat[wordEnd] <> ' ') do
         begin
         Inc(wordEnd);
         end;
      w := Copy(flat, i, wordEnd - i);
      i := wordEnd + 1;
      if w = '' then
         begin
         Continue;
         end;
      if line = '' then
         begin
         line := w;
         end
      else if Length(line) + 1 + Length(w) <= aWidth then
         begin
         line := line + ' ' + w;
         end
      else
         begin
         Result := Result + line + LineEnding;
         line   := w;
         end;
      end;
   Result := Result + line;
end;

(* ------------------------------------------------- the .po subset reader - *)

(* The text between the first and last double quote, with the C escapes the
  gettext tools write undone. Anything else after a backslash is kept as the
  character itself. *)
function UnquotePoString(const aLine: string; out aValue: string): boolean;
var
   first, last: integer;
   i: integer;
   c: char;
begin
   aValue := '';
   first  := Pos('"', aLine);
   last   := Length(aLine);
   while (last > first) and (aLine[last] <> '"') do
      begin
      Dec(last);
      end;
   Result := (first > 0) and (last > first);
   if not Result then
      begin
      Exit;
      end;

   i := first + 1;
   while i < last do
      begin
      c := aLine[i];
      if (c = '\') and (i + 1 < last) then
         begin
         Inc(i);
         case aLine[i] of
            'n':
               begin
               aValue := aValue + #10;
               end;
            't':
               begin
               aValue := aValue + #9;
               end;
            'r':
               begin
               aValue := aValue + #13;
               end;
         else
            begin
            aValue := aValue + aLine[i];
            end;
         end;
         end
      else
         begin
         aValue := aValue + c;
         end;
      Inc(i);
      end;
end;

(* The lines of aText, CRLF, LF and CR alike.

  NOT A TStringList, which holds AnsiString in FPC 3.2.2: Russian help passed
  through one is a narrowing conversion, and under a non-UTF-8 code page a
  lossy one. *)
function SplitTextLines(const aText: string): TArray<string>;
var
   lineStart, lineEnd, n: integer;
begin
   Result := nil;
   n := 0;
   lineStart := 1;
   while lineStart <= Length(aText) do
      begin
      lineEnd := lineStart;
      while (lineEnd <= Length(aText)) and (aText[lineEnd] <> #10) and
            (aText[lineEnd] <> #13) do
         begin
         Inc(lineEnd);
         end;
      if n >= Length(Result) then
         begin
         SetLength(Result, 2 * n + 64);
         end;
      Result[n] := Copy(aText, lineStart, lineEnd - lineStart);
      Inc(n);
      if (lineEnd < Length(aText)) and (aText[lineEnd] = #13) and
         (aText[lineEnd + 1] = #10) then
         begin
         lineStart := lineEnd + 2;
         end
      else
         begin
         lineStart := lineEnd + 1;
         end;
      end;
   SetLength(Result, n);
end;

constructor TCommandHelpCatalogue.Create;
begin
   inherited Create;
   FTexts := TDictionary<string, string>.Create;
end;

destructor TCommandHelpCatalogue.Destroy;
begin
   FreeAndNil(FTexts);
   inherited Destroy;
end;

procedure TCommandHelpCatalogue.AddEntry(const aContext, aEnglish,
                                         aTranslation: string);
var
   text: string;
begin
   if aContext = '' then
      begin
      Exit;   // the header, or an entry this format does not key
      end;
   text := Trim(aTranslation);
   if text = '' then
      begin
      text := Trim(aEnglish);   // untranslated: the msgid is the English
      end;
   FTexts.AddOrSetValue(UpperCase(aContext), text);
end;

procedure TCommandHelpCatalogue.LoadFromText(const aText: string);
type
   TPoField = (pfNone, pfContext, pfId, pfStr);
var
   lines: TArray<string>;
   raw: string;
   line: string;
   value: string;
   field: TPoField;
   context, english, translation: string;

   procedure Flush;
   begin
      AddEntry(context, english, translation);
      context     := '';
      english     := '';
      translation := '';
      field       := pfNone;
   end;

   procedure Append(const aValue: string);
   begin
      case field of
         pfContext:
            begin
            context := context + aValue;
            end;
         pfId:
            begin
            english := english + aValue;
            end;
         pfStr:
            begin
            translation := translation + aValue;
            end;
      else
         begin
         // a stray string line outside any field: ignored
         end;
      end;
   end;

begin
   FTexts.Clear;
   field       := pfNone;
   context     := '';
   english     := '';
   translation := '';

   lines := SplitTextLines(aText);
   for raw in lines do
      begin
      line := Trim(raw);
      if line = '' then
         begin
         Flush;
         Continue;
         end;
      if line[1] = '#' then
         begin
         (* '#~' is an obsolete entry and never live; every other comment
           -- '#.', '#:', '#,' fuzzy, '# ' -- carries nothing shown. *)
         Continue;
         end;

      if Copy(line, 1, 8) = 'msgctxt ' then
         begin
         if field = pfStr then
            begin
            Flush;   // a new entry with no blank line before it
            end;
         field := pfContext;
         if UnquotePoString(Copy(line, 9, MaxInt), value) then
            begin
            context := value;
            end;
         end
      else if Copy(line, 1, 6) = 'msgid ' then
         begin
         if field = pfStr then
            begin
            Flush;
            end;
         field := pfId;
         if UnquotePoString(Copy(line, 7, MaxInt), value) then
            begin
            english := value;
            end;
         end
      else if Copy(line, 1, 7) = 'msgstr ' then
         begin
         field := pfStr;
         if UnquotePoString(Copy(line, 8, MaxInt), value) then
            begin
            translation := value;
            end;
         end
      else if line[1] = '"' then
         begin
         if UnquotePoString(line, value) then
            begin
            Append(value);
            end;
         end
      else
         begin
         (* msgid_plural / msgstr[n]: no help entry has a plural. Close the
           field so a continuation line cannot land in the wrong one. *)
         field := pfNone;
         end;
      end;
   Flush;
end;

function TCommandHelpCatalogue.LoadFromFile(const aFileName: string): boolean;
var
   stream: TFileStream;
   bytes: RawByteString;
begin
   FTexts.Clear;
   Result := False;
   if (aFileName = '') or not FileExists(aFileName) then
      begin
      Exit;
      end;
   try
      (* AnsiString(), the tree's idiom (uLogDatabase, uctydat): TFileStream
        takes the RTL's 8-bit string, which is UTF-8 in the LCL program. *)
      stream := TFileStream.Create(AnsiString(aFileName), fmOpenRead or fmShareDenyWrite);
      try
         bytes := '';
         SetLength(bytes, stream.Size);
         if Length(bytes) > 0 then
            begin
            stream.ReadBuffer(bytes[1], Length(bytes));
            end;
      finally
         stream.Free;
      end;
   except
      on Exception do
         begin
         Exit;   // unreadable is the same as absent: no help, no crash
         end;
   end;

   (* UTF-8, decoded once. A BOM is dropped first. *)
   if (Length(bytes) >= 3) and (bytes[1] = #$EF) and (bytes[2] = #$BB) and
      (bytes[3] = #$BF) then
      begin
      Delete(bytes, 1, 3);
      end;
   LoadFromText(UTF8Decode(bytes));
   Result := True;
end;

function TCommandHelpCatalogue.TryGetText(const aKey: string;
                                          out aText: string): boolean;
begin
   Result := FTexts.TryGetValue(UpperCase(aKey), aText) and (aText <> '');
   if not Result then
      begin
      aText := '';
      end;
end;

function TCommandHelpCatalogue.Count: integer;
begin
   Result := FTexts.Count;
end;

(* ------------------------------------------------------------ TCommandHelp - *)

constructor TCommandHelp.Create(const aHelpDir, aLanguageCode: string);
var
   englishPath: string;
begin
   inherited Create;
   FLanguage := TCommandHelpCatalogue.Create;
   FEnglish  := TCommandHelpCatalogue.Create;

   englishPath  := CatalogueFileName(aHelpDir, ENGLISH_HELP_CODE);
   FEnglishFile := englishPath;
   if not FEnglish.LoadFromFile(FEnglishFile) then
      begin
      FEnglishFile := '';
      end;

   (* Both paths come from CatalogueFileName, so equal text is the same file. *)
   FLanguageFile := HelpCatalogueFile(aHelpDir, aLanguageCode);
   if (FLanguageFile = '') or (FLanguageFile = englishPath) then
      begin
      FLanguageFile := '';   // English is the fallback; never load it twice
      end
   else if not FLanguage.LoadFromFile(FLanguageFile) then
      begin
      FLanguageFile := '';
      end;
end;

destructor TCommandHelp.Destroy;
begin
   FreeAndNil(FLanguage);
   FreeAndNil(FEnglish);
   inherited Destroy;
end;

function TCommandHelp.NothingLoaded: boolean;
begin
   Result := (FLanguageFile = '') and (FEnglishFile = '');
end;

function TCommandHelp.Describe(const aCommand: string): string;
var
   key: string;
begin
   Result := '';
   if Trim(aCommand) = '' then
      begin
      Exit;
      end;
   key := CommandHelpKey(aCommand);
   if FLanguage.TryGetText(key, Result) then
      begin
      Exit;
      end;
   if not FEnglish.TryGetText(key, Result) then
      begin
      Result := '';
      end;
end;

end.
