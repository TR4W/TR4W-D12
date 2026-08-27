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

{ The catalogue actually in force, or '' for none -- which is what an English
  run reports, since English loads no catalogue.

  Asked by the About box, which credits the translator only when there is one.
  It answers from what the loader DID, not by testing whether some string looks
  translated: a catalogue that happens to leave TC_TRANSLATION_LANGUAGE alone is
  still a loaded catalogue. }
function ActiveUILanguage: string;

{ The language codes this binary actually carries, space separated, e.g.
  'cs da de el en es fi fr ...'.

  Read from the RCDATA names rather than from a list, so it cannot disagree
  with what Make-LanguageRes embedded. Used by the --lang usage text. }
function AvailableLanguages: string;

implementation

uses
   SysUtils, Classes, Windows,
   gettext,           // GetLanguageIDs -- the locale, the platform's own way
   Translations,      // TPOFile, TranslateResourceStrings
   LResources,        // LRSTranslator -- the hook the LFM reader consults
   LCLTranslator,     // TPOTranslator, SetDefaultLang
   MainUnit,          // logger
  uTR4WStrings,
  uAnsiStr;

{ The two-letter code the LCL would pick, without loading anything.

  SetDefaultLang does this internally and then goes looking for files; there is
  no exported way to ask it for the code alone, so the switch is read here and
  the OS locale is the fallback. Kept deliberately small: language SELECTION is
  still an open question (a TR4W setting should override both -- an operator on
  Spanish Windows does not necessarily want a Spanish contest log) and this is
  the seam that setting plugs into. }
function ResolveLang(const aLang: string; out aSource: string): string;
var
   i:   integer;
   arg: string;
   { GetLanguageIDs yields the full id and a fallback -- 'es_ES' and 'es' for a
     Spanish (Spain) machine. The catalogues are keyed on the two-letter code,
     so the fallback is normally the one wanted.

     AnsiString EXPLICITLY, and the compiler is what says so: gettext is RTL
     code compiled with 8-bit strings and takes these by VAR, while string in
     this unit is UnicodeString (tr4w.inc). A var parameter has to match
     exactly -- no conversion is possible through one. }
   fullId, shortId: AnsiString;
begin
   { WHERE the code came from is reported alongside WHICH it was. "Spanish did
     not appear" has two completely different causes -- the switch was not read,
     or it was read and the catalogue did nothing -- and without the source in
     the log the two look identical from the outside. }
   if aLang <> '' then
      begin
      aSource := 'the caller';
      Result  := LowerCase(aLang);
      Exit;
      end;

   for i := 1 to ParamCount do
      begin
      arg := ParamStr(i);
      if (SameText(arg, '--lang') or SameText(arg, '-l')) and (i < ParamCount) then
         begin
         aSource := 'the ' + arg + ' command-line switch';
         Result  := LowerCase(ParamStr(i + 1));
         Exit;
         end;
      if SameText(Copy(arg, 1, 7), '--lang=') then
         begin
         aSource := 'the --lang= command-line switch';
         Result  := LowerCase(Copy(arg, 8, MaxInt));
         Exit;
         end;
      end;

   { FPC'S OWN, rather than a GetLocaleInfoA call and an AnsiChar buffer.
     gettext.GetLanguageIDs reads the locale the way the platform states it --
     GetLocaleInfo on Windows, the LC_ALL / LC_MESSAGES / LANG environment on
     Unix -- so this line does not have to know which platform it is on, and
     the Windows-only call and its buffer are gone. }
   fullId  := '';
   shortId := '';
   GetLanguageIDs(fullId, shortId);

   if shortId <> '' then
      begin
      aSource := 'the operating system locale (' + fullId + ')';
      Result  := LowerCase(shortId);
      end
   else if fullId <> '' then
      begin
      // No fallback offered: take the language half of 'xx_YY' ourselves.
      aSource := 'the operating system locale (' + fullId + ')';
      Result  := LowerCase(Copy(fullId, 1, 2));
      end
   else
      begin
      aSource := 'nothing -- no switch given and the locale could not be read';
      Result  := '';
      end;
end;


var
   { THE CATALOGUE HAS TO OUTLIVE THE TRANSLATOR, and this variable is what
     makes it. TPOTranslator does not copy the TPOFile -- it keeps the pointer
     and dereferences it for every translatable property the LFM reader streams,
     for as long as the program runs.

     Freeing the catalogue once the hook was installed left that pointer
     dangling, and the first form property to ask a question of it was
     TR4WMainForm.Caption, which is the first thing CreateTR4WMainForm streams:

       unhandled EReadError -- Error reading TR4WMainForm.Caption:
       Access violation

     English never reached it, because LoadEmbeddedTranslation exits before
     installing anything when the language is English. So the crash appeared
     only under --lang, and looked like a translation-data problem rather than a
     lifetime one. LCLTranslator.SetDefaultLang, which this replaced, keeps its
     own TPOFile in a global for exactly this reason.

     Released in finalization, as a PAIR and translator-first. }
   GActiveCatalogue: TPOFile;
   GActiveLang:      string;


function EnumLangProc(hModule: HMODULE; lpType, lpName: PAnsiChar;
                      lParam: PtrInt): LongBool; stdcall;
{ EnumResourceNamesA hands an ordinal in the low word when a resource is
  numbered rather than named; ours are all named TR4W_<CODE>. }
var
   s: string;
begin
   Result := True;
   if PtrUInt(lpName) <= $FFFF then
      begin
      Exit;
      end;
   s := string(AnsiString(lpName));
   if Copy(s, 1, 5) = 'TR4W_' then
      begin
      TStringList(lParam).Add(LowerCase(Copy(s, 6, MaxInt)));
      end;
end;

function AvailableLanguages: string;
var
   list: TStringList;
begin
   list := TStringList.Create;
   try
      list.Sorted := True;
      list.Duplicates := dupIgnore;
      EnumResourceNamesA(HInstance, RT_RCDATA, @EnumLangProc, PtrInt(list));
      Result := Trim(StringReplace(list.Text, sLineBreak, ' ', [rfReplaceAll]));
   finally
      list.Free;
   end;
end;

function ActiveUILanguage: string;
begin
   Result := GActiveLang;
end;

function ApplyCatalogue(po: TPOFile): boolean;
{ TAKES OWNERSHIP of po, on every path. The caller must not free it: an earlier
  version left ownership with the caller and that is the whole of the bug
  described above. }
begin
   // BOTH HALVES FROM ONE CATALOGUE, and the order does not matter: the first
   // rewrites the resource string table, the second installs the hook the LFM
   // reader asks on every translatable property as a form streams.
   //
   // Only the FIRST is reported. TranslateResourceStrings says nothing about
   // whether form properties will translate, and the hook is installed either
   // way -- a catalogue that carries .lfm captions but no resourcestrings is a
   // legitimate catalogue.
   Result := Translations.TranslateResourceStrings(po);

   // Translator first, then the catalogue it was reading. The reverse order
   // would leave the outgoing translator pointing at freed memory for as long
   // as it took to reach the next statement.
   if Assigned(LRSTranslator) then
      begin
      LRSTranslator.Free;
      LRSTranslator := nil;
      end;
   FreeAndNil(GActiveCatalogue);

   GActiveCatalogue := po;
   LRSTranslator := TPOTranslator.Create(po);
end;


function LoadEmbeddedTranslation(const aLang: string): string;
var
   lang:   string;
   source: string;
   resName: string;
   rs:     TResourceStream;
   po:     TPOFile;
   fileCandidate: string;
begin
   Result := '';
   GActiveLang := '';
   lang := ResolveLang(aLang, source);
   if (lang = '') or SameText(lang, 'en') then
      begin
      // English is what the binary already holds; loading a catalogue to
      // replace English with English would be work to no effect.
      //
      // Reported rather than passed over in silence: this is the COMMONEST
      // outcome, and an operator who expected a translation needs to see
      // that the code resolved to English and where that came from.
      if lang = '' then
         begin
         logger.Info('UI language: no code could be determined from ' +
                     source + '; using the compiled-in English');
         end
      else
         begin
         logger.Info('UI language: "' + lang + '" from ' + source +
                     '; that is the compiled-in language, so no catalogue is loaded');
         end;
      Exit;
      end;

   // A FILE BESIDE THE EXE WINS. Same layout SetDefaultLang searches, so a
   // catalogue dropped there for testing or as a patch behaves the same way it
   // did before this unit existed.
   fileCandidate := ExtractFilePath(ParamStr(0)) + 'languages\' + lang + '\tr4w.po';
   if FileExists(fileCandidate) then
      begin
      try
         // No try..finally around po: ApplyCatalogue owns it from here, and the
         // translator it installs goes on reading it for the life of the
         // program. Freeing it here is what crashed the first form load.
         po := TPOFile.Create(fileCandidate, True);
         if ApplyCatalogue(po) then
            begin
            Result := lang;
            GActiveLang := lang;
            logger.Info('UI language: "' + lang + '" selected by ' + source +
                        ', loaded from ' + fileCandidate +
                        ' (overriding the embedded catalogue)');
            Exit;
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
   if FindResourceA(HInstance, PAnsiChar(WinAnsi(resName)), RT_RCDATA) = 0 then
      begin
      logger.Info('UI language: "' + lang + '" selected by ' + source +
                  ', but no catalogue for it is embedded; using the ' +
                  'compiled-in English');
      Exit;
      end;

   try
      rs := TResourceStream.Create(HInstance, resName, RT_RCDATA);
      try
         // Full=False is what LazUtils' own comment prescribes when loading
         // from an internal resource.
         // Owned by ApplyCatalogue from here -- see the comment on the file
         // path above. rs may be freed straight after: TPOFile reads the whole
         // stream during construction.
         po := TPOFile.Create(rs, False);
         if ApplyCatalogue(po) then
            begin
            Result := lang;
            GActiveLang := lang;
            logger.Info('UI language: "' + lang + '" selected by ' + source +
                        ', loaded from the embedded catalogue');
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

finalization
   { Translator first, then the catalogue it reads -- the same order and the
     same reason as in ApplyCatalogue. Guarded because a program that never
     loaded a catalogue (English, or any failure path) has neither. }
   if Assigned(LRSTranslator) then
      begin
      LRSTranslator.Free;
      LRSTranslator := nil;
      end;
   FreeAndNil(GActiveCatalogue);

end.
