unit uEmbeddedTranslations;
{$I ..\..\tr4w.inc}

{
  THE UI LANGUAGE, CARRIED INSIDE THE BINARY.

  TR4W used to translate by COMPILING A DIFFERENT BINARY per language: one TC_
  constant per string in src\lang\tr4w_consts_<LANG>.pas, selected by a LANG_xxx
  define. Nine binaries, nine constant files that drift, each an ANSI file in its
  own codepage. The replacement is ONE binary whose resourcestrings and form
  properties are REPLACED AT RUN TIME from a .po (NY4I, 2026-08-13).

  WHERE THE .po LIVES WAS THE DECISION. A file beside the exe works and is what
  SetDefaultLang does; NY4I chose INSIDE the binary (2026-08-26), because the
  language data is already embedded today via an $R on res\tr4w_<lang>.res
  (written without its braces here, because a brace comment ENDS at the first
  closing brace -- quoting a compiler directive inside one truncates it) and a
  loose file is one more thing to lose, to forget to install, or to have go
  stale against the exe beside it.

  So build\Make-LanguageRes.ps1 compiles i18n\tr4w_<lang>.po into
  res\tr4w_languages.res as RCDATA named TR4W_<LANG>, and this reads it back.
  514 KB for sixteen languages, because only REVIEWED entries are shipped.

  A FILE STILL WINS IF ONE IS PRESENT, deliberately. languages\<lang>\tr4w.po
  beside the exe overrides the embedded copy, so a corrected translation can be
  dropped on a running installation without a rebuild, and so this can be tested
  without one. The embedded copy is the floor, not the ceiling -- which is why a
  missing file is not an error here, unlike the file-only design where it meant
  a silently English UI.

  WHAT IT TRANSLATES. Both halves, from one catalogue:

    resourcestrings   Translations.TranslateResourceStrings(po)
    form properties   LRSTranslator := TPOTranslator.Create(po)

  LazUtils loads a translation "only if it exists and is NOT fuzzy"
  (translations.pas:1220), which is the same gate po2pas applies to the Pascal
  side: machine output cannot reach a screen until a human clears it in Poedit.
  Make-LanguageRes drops fuzzy entries before they are ever embedded, so the
  binary cannot carry unreviewed text at all.
}

interface

{ Load the UI language and return what was loaded, or '' for none.

  aLang is a two-letter code ('es'); empty means ask the LCL, which honours a
  --lang switch and then the OS locale. }
function LoadEmbeddedTranslation(const aLang: string): string;

implementation

uses
   SysUtils, Classes, Windows,
   Translations,      // TPOFile, TranslateResourceStrings
   LResources,        // LRSTranslator -- the hook the LFM reader consults
   LCLTranslator,     // TPOTranslator, SetDefaultLang
   MainUnit;          // logger

{ The two-letter code the LCL would pick, without loading anything.

  SetDefaultLang does this internally and then goes looking for files; there is
  no exported way to ask it for the code alone, so the switch is read here and
  the OS locale is the fallback. Kept deliberately small: language SELECTION is
  still an open question (a TR4W setting should override both -- an operator on
  Spanish Windows does not necessarily want a Spanish contest log) and this is
  the seam that setting plugs into. }
function ResolveLang(const aLang: string): string;
var
   i:   integer;
   arg: string;
   { AnsiChar and the ...A entry point EXPLICITLY. PChar binds to PAnsiChar in
     this project, so a plain `array of Char` is wide and will not pass -- and a
     bare @buffer handed to a GENERIC Win32 name compiles silently even with
     warnings on, which is the class of defect that made TR4WServer reject every
     client (CLAUDE.md, 1bea7af4). Name the variant. }
   buf: array[0..15] of AnsiChar;
begin
   if aLang <> '' then
      begin
      Result := LowerCase(aLang);
      Exit;
      end;

   for i := 1 to ParamCount do
      begin
      arg := ParamStr(i);
      if (SameText(arg, '--lang') or SameText(arg, '-l')) and (i < ParamCount) then
         begin
         Result := LowerCase(ParamStr(i + 1));
         Exit;
         end;
      if SameText(Copy(arg, 1, 7), '--lang=') then
         begin
         Result := LowerCase(Copy(arg, 8, MaxInt));
         Exit;
         end;
      end;

   Result := '';
   if GetLocaleInfoA(LOCALE_USER_DEFAULT, LOCALE_SISO639LANGNAME,
                    buf, Length(buf)) > 0 then
      begin
      Result := LowerCase(StrPas(buf));
      end;
end;


function ApplyCatalogue(po: TPOFile): boolean;
begin
   // BOTH HALVES FROM ONE CATALOGUE, and the order does not matter: the first
   // rewrites the resource string table, the second installs the hook the LFM
   // reader asks on every translatable property as a form streams.
   Result := Translations.TranslateResourceStrings(po);

   if Assigned(LRSTranslator) then
      begin
      LRSTranslator.Free;
      end;
   LRSTranslator := TPOTranslator.Create(po);
end;


function LoadEmbeddedTranslation(const aLang: string): string;
var
   lang:   string;
   resName: string;
   rs:     TResourceStream;
   po:     TPOFile;
   fileCandidate: string;
begin
   Result := '';
   lang := ResolveLang(aLang);
   if (lang = '') or SameText(lang, 'en') then
      begin
      // English is what the binary already holds; loading a catalogue to
      // replace English with English would be work to no effect.
      Exit;
      end;

   // A FILE BESIDE THE EXE WINS. Same layout SetDefaultLang searches, so a
   // catalogue dropped there for testing or as a patch behaves the same way it
   // did before this unit existed.
   fileCandidate := ExtractFilePath(ParamStr(0)) + 'languages\' + lang + '\tr4w.po';
   if FileExists(fileCandidate) then
      begin
      try
         po := TPOFile.Create(fileCandidate, True);
         try
            if ApplyCatalogue(po) then
               begin
               Result := lang;
               logger.Info('UI language: "' + lang + '" from ' + fileCandidate +
                           ' (overriding the embedded catalogue)');
               Exit;
               end;
         finally
            po.Free;
         end;
      except
         on E: Exception do
            begin
            // Fall through to the embedded copy rather than failing: a bad file
            // on disk must not cost the operator the language that ships.
            logger.Warn('UI language: could not read ' + fileCandidate + ' -- ' +
                        E.Message + '; using the embedded catalogue');
            end;
      end;
      end;

   resName := 'TR4W_' + UpperCase(lang);
   if FindResourceA(HInstance, PAnsiChar(AnsiString(resName)), RT_RCDATA) = 0 then
      begin
      logger.Info('UI language: no catalogue for "' + lang +
                  '" is embedded; using the compiled-in English');
      Exit;
      end;

   try
      rs := TResourceStream.Create(HInstance, resName, RT_RCDATA);
      try
         // Full=False is what LazUtils' own comment prescribes when loading
         // from an internal resource.
         po := TPOFile.Create(rs, False);
         try
            if ApplyCatalogue(po) then
               begin
               Result := lang;
               logger.Info('UI language: "' + lang + '" from the embedded catalogue');
               end;
         finally
            po.Free;
         end;
      finally
         rs.Free;
      end;
   except
      on E: Exception do
         begin
         logger.Error('UI language: embedded catalogue "' + resName +
                      '" could not be loaded -- ' + E.ClassName + ': ' + E.Message);
      end;
   end;
end;

end.
