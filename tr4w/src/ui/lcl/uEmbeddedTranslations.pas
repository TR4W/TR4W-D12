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

(* Load the UI language and return what was loaded, or '' for none.

  aSetting is the Language setting as stored in tr4w.json -- read by
  uTR4WConfigFile.StartupUILanguage, because this runs before the settings
  object is loaded. '' means "follow the operating system".

  THE PRECEDENCE is uUILanguage.ChooseUILanguage -- in order: a --lang
  switch, aSetting, the OS, and the compiled-in English. *)
function LoadEmbeddedTranslation(const aSetting: string): string;

(* Is there a catalogue for this code -- embedded, or a file beside the exe
  that would override one? 'en' always is: it is the compiled-in language. *)
function IsUILanguageAvailable(const aCode: string): boolean;

(* WHAT PREFERENCES SHOWS FOR A LANGUAGE CODE: the language in its OWN name,
  as its catalogue spells it, with the code beside it -- 'Deutsch (de)'. The
  code alone when the catalogue carries no reviewed name, and a translated
  "System default" for ''.

  The name is TC_TRANSLATION_LANGUAGE in that language's catalogue, which is
  what the About box credits. Read once per run and cached: it costs one
  parse of each catalogue, and Preferences can open many times. *)
function UILanguageCaption(const aCode: string): string;

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
   (* NO Windows -- AND THE REASON THAT STOOD HERE WAS WRONG (2026-09-08).

     It said the resource API "is not a call that can be swapped -- it is a
     decision about where translations LIVE off Windows". There is no decision
     to make: FPC's SYSTEM UNIT declares this whole API for every target, in
     rtl\inc
esh.inc --

         function EnumResourceNames(ModuleHandle: TFPResourceHMODULE;
                    ResourceType: PChar; EnumFunc: EnumResNameProc;
                    lParam: PtrInt): LongBool;
         function FindResource / LoadResource / SizeofResource / LockResource
         function Is_IntResource(aStr: PChar): boolean;

     -- with RT_RCDATA defined for the non-Windows case and the implementation
     picked by fpintres.pp: the PE reader on Windows, its own reader
     elsewhere. FPC ships elfreader and machoreader to back it. So the
     embedded design PORTS AS IT IS; only the A suffixes had to go.

     WHAT IS STILL UNVERIFIED, and it is one thing rather than a design: that
     Make-LanguageRes.ps1's output survives the ELF/Mach-O resource pipeline,
     where fpcres embeds a section rather than a PE resource directory. If it
     does not, this unit already documents the fallback -- a loose
     languages/<lang>/tr4w.po beside the binary wins over the embedded copy
     -- so the failure degrades to the file design rather than to English. *)
   SysUtils, Classes,
   Generics.Collections,   // TDictionary -- the cached language names
{$IFDEF WINDOWS}
   (* FOR RT_RCDATA ALONE, and only on Windows. The RTL declares the resource
     FUNCTIONS for every target, but it declares the RT_* constants under
     {$ifndef MSWINDOWS} -- on Windows they are expected to come from the
     Windows unit, which is where this one still comes from. One constant, and
     the rest of the API is the RTL's on both. *)
   Windows,
{$ENDIF}
   uUILanguage,       // the precedence, the switch and the OS language
   uSettingsModel,    // RegisterSettingAllowedValues -- see initialization
   uSettingsCaptions, // RS_APPEARANCE_LANGUAGE_SYSTEM
   Translations,      // TPOFile, TranslateResourceStrings
   LResources,        // LRSTranslator -- the hook the LFM reader consults
   LCLTranslator,     // TPOTranslator, SetDefaultLang
   MainUnit,          // logger
  uTR4WStrings,
  utils_text,
   uAppPaths;

(* THE CODE TO LOAD, AND A SENTENCE SAYING WHERE IT CAME FROM.

  The rule is uUILanguage.ChooseUILanguage; this gathers what each source
  offers and words the answer for the log.

  WHERE the code came from is reported alongside WHICH it was. "Spanish did
  not appear" has several different causes -- the switch was not read, the
  setting named a language this build lacks, or the code was right and the
  catalogue did nothing -- and without the source in the log they all look
  identical from the outside. *)
function ResolveLang(const aSetting: string; out aSource: string): string;
var
   switchCode, switchName: string;
   systemCode, systemName: string;
   source: TUILanguageSource;
   refused: boolean;
begin
   switchCode := UILanguageFromCommandLine(switchName);
   (* The OS is asked only when it can matter, so a run with a switch or a
     setting does not log a locale it never used. *)
   systemCode := '';
   systemName := '';
   if (switchCode = '') and
      ((Trim(aSetting) = '') or (not IsUILanguageAvailable(Trim(aSetting)))) then
      begin
      systemCode := SystemUILanguage(systemName);
      end;

   Result := ChooseUILanguage(switchCode, aSetting, systemCode,
                              @IsUILanguageAvailable, source, refused);

   (* REPORTED, NOT SILENT: a stored language this build cannot load. The
     run falls back to the OS, which is better than English, but the operator
     chose something and is not getting it, so the log says why. *)
   if refused then
      begin
      logger.Warn('UI language: the Language setting in tr4w.json says "' +
                  Trim(aSetting) + '", and this build carries no catalogue ' +
                  'for it (it has: ' + AvailableLanguages + '); ' +
                  'following the operating system instead');
      end;

   case source of
      ulsSwitch:
         begin
         aSource := switchName;
         end;
      ulsSetting:
         begin
         aSource := UILanguageSourceName(ulsSetting);
         end;
      ulsSystem:
         begin
         aSource := systemName;
         end;
   else
      begin
      aSource := 'nothing -- no switch, no Language setting, and ' + systemName;
      end;
   end;
end;


var
   (* THE CATALOGUE BELONGS TO THE TRANSLATOR, AND TO NOTHING ELSE.

     TPOTranslator does not copy the TPOFile -- it keeps the pointer and
     dereferences it for every translatable property the LFM reader streams,
     for as long as the program runs. So the catalogue must outlive the hook.
     Freeing it once the hook was installed left that pointer dangling, and
     the first form property to ask was TR4WMainForm.Caption:

       unhandled EReadError -- Error reading TR4WMainForm.Caption:
       Access violation

     AND TPOTranslator.Destroy FREES IT (lcltranslator.pas: `FPOFile.Free`).
     That is the other half, and missing it cost every translated run its
     exit. A GActiveCatalogue global stood here until 2026-09-19 to keep the
     catalogue alive, and was freed in finalization right after the
     translator -- which had just freed the same object. The second Free ran
     a destructor through a freed VMT, and every run in any language other
     than English ended in an access violation inside FinalizeUnits, exit
     217, with the crash address a fragment of whatever string had since
     been allocated there ('s\de', 'rg>'). /EXPORT reported it as a crash;
     it was measured on the 5.0.9 binary too, so it predates the Language
     setting -- which would have made it reachable without a switch.

     So there is ONE owner. ApplyCatalogue hands the catalogue to a new
     TPOTranslator and keeps no reference; freeing LRSTranslator frees both.
     English never reached any of this, because LoadEmbeddedTranslation
     installs nothing for the compiled-in language. *)
   GActiveLang:      string;


function EnumLangProc(hModule: TFPResourceHMODULE; lpType, lpName: PAnsiChar;
                      lParam: PtrInt): LongBool; stdcall;
{ EnumResourceNames hands an ordinal in the low word when a resource is
  numbered rather than named; ours are all named TR4W_<CODE>.  Is_IntResource
  is the RTL's own test for that encoding -- it was a hand-rolled
  `PtrUInt(lpName) <= $FFFF` here, which is the same rule but ours to get
  wrong. }
var
   s: string;
begin
   Result := True;
   if Is_IntResource(lpName) then
      begin
      Exit;
      end;
   s := string(AnsiString(lpName));
   if Copy(s, 1, 5) = 'TR4W_' then
      begin
      TStringList(lParam).Add(LowerCase(Copy(s, 6, MaxInt)));
      end;
end;

(* The embedded codes, sorted -- the one enumeration both the usage text and
  the Language setting's vocabulary are built from. *)
function EmbeddedLanguageCodes: TArray<string>;
var
   list: TStringList;
   i: integer;
begin
   Result := nil;
   list := TStringList.Create;
   try
      list.Sorted := True;
      list.Duplicates := dupIgnore;
      EnumResourceNames(HInstance, RT_RCDATA, @EnumLangProc, PtrInt(list));
      SetLength(Result, list.Count);
      for i := 0 to list.Count - 1 do
         begin
         Result[i] := list[i];
         end;
   finally
      list.Free;
   end;
end;

function AvailableLanguages: string;
var
   code: string;
begin
   Result := '';
   for code in EmbeddedLanguageCodes do
      begin
      if Result <> '' then
         begin
         Result := Result + ' ';
         end;
      Result := Result + code;
      end;
end;

(* The file a catalogue dropped beside the exe would be read from. One
  derivation, shared by the loader and the availability test, so the two
  cannot disagree about where to look. *)
function LanguageFilePath(const aCode: string): string;
begin
   Result := DataFilePath('languages\' + aCode + '\tr4w.po');
end;

function IsUILanguageAvailable(const aCode: string): boolean;
var
   code: string;
   (* The resource name as bytes, for FindResource -- ASCII by construction. *)
   resBytes: AnsiString;
begin
   code := LowerCase(Trim(aCode));
   if code = '' then
      begin
      Result := False;
      Exit;
      end;
   if code = 'en' then
      begin
      Result := True;
      Exit;
      end;
   resBytes := AnsiString('TR4W_' + UpperCase(code));
   Result := (FindResource(HInstance, PAnsiChar(resBytes), RT_RCDATA) <> 0) or
             FileExists(LanguageFilePath(code));
end;

var
   (* code -> name, filled on first use by UILanguageCaption and never again
     -- see the interface comment. A dictionary of string rather than a
     TStringList: the names are Greek, Cyrillic and CJK, and TStringList
     holds AnsiString. Freed in finalization. *)
   GLanguageNames: TDictionary<string, string> = nil;

(* TC_TRANSLATION_LANGUAGE as one catalogue spells it, or ''. The identifier
  is the resourcestring's unit-qualified name, which is the #: line
  Make-LanguageRes keeps in the embedded copy. *)
function CatalogueLanguageName(const aCode: string): string;
var
   rs: TResourceStream;
   po: TPOFile;
   item: TPOFileItem;
   resBytes: AnsiString;
begin
   Result := '';
   resBytes := AnsiString('TR4W_' + UpperCase(aCode));
   if FindResource(HInstance, PAnsiChar(resBytes), RT_RCDATA) = 0 then
      begin
      Exit;
      end;
   try
      (* resBytes, not a fresh string: the RTL's resource name is an
        AnsiString, and the bytes are already built above. *)
      rs := TResourceStream.Create(HInstance, resBytes, RT_RCDATA);
      try
         po := TPOFile.Create(rs, False);
         try
            item := po.FindPoItem('utr4wstrings.tc_translation_language');
            if item <> nil then
               begin
               (* UTF-8 bytes in LazUtils' AnsiString; decoded explicitly
                 rather than left to the code page of the moment. *)
               Result := UTF8Decode(item.Translation);
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
         (* A caption is never worth a failure: the code alone still
           identifies the language. *)
         Result := '';
         end;
   end;
end;

function UILanguageCaption(const aCode: string): string;
var
   code: string;
   name: string;
begin
   code := LowerCase(Trim(aCode));
   if code = '' then
      begin
      Result := RS_APPEARANCE_LANGUAGE_SYSTEM;
      Exit;
      end;

   if GLanguageNames = nil then
      begin
      GLanguageNames := TDictionary<string, string>.Create;
      end;
   if not GLanguageNames.TryGetValue(code, name) then
      begin
      name := CatalogueLanguageName(code);
      GLanguageNames.Add(code, name);
      end;

   if name = '' then
      begin
      Result := code;
      end
   else
      begin
      Result := name + ' (' + code + ')';
      end;
end;

procedure LoadLCLCatalogue(const aLang: string);
{ Translate the LCL's OWN strings -- standard buttons, common dialogs, RTL
  error text -- from the lclstrconsts catalogue Lazarus ships, embedded beside
  ours by Make-LanguageRes.

  SetDefaultLang did this automatically (lcltranslator.pas: "This unit localizes
  LCL too"). Replacing it with LoadEmbeddedTranslation dropped it, so every
  LCL-supplied string had been English in every language -- including the Yes
  and No buttons, which Lazarus translates better than we do: its Spanish is
  '&Si' with the accelerator correctly moved, ours was 'Si' with none at all.

  Unlike the form translator, this one may free its catalogue:
  TranslateUnitResourceStrings copies into the resource string table there and
  then, where TPOTranslator keeps the pointer. That asymmetry is exactly what
  the --lang crash was, so it is worth stating rather than inferring.

  Absent is normal: Lazarus ships 15 of our 21 languages. }
var
   rs: TResourceStream;
   po: TPOFile;
   (* The resource name FindResource reads, owned by this routine rather than
     built as a temporary in the argument list. *)
   resBytes: AnsiString;
begin
   resBytes := AnsiString('LCL_' + UpperCase(aLang));
   if (aLang = '') or (FindResource(HInstance,
          PAnsiChar(resBytes), RT_RCDATA) = 0) then
      begin
      Exit;
      end;
   try
      rs := TResourceStream.Create(HInstance, 'LCL_' + UpperCase(aLang), RT_RCDATA);
      try
         po := TPOFile.Create(rs, False);
         try
            if Translations.TranslateUnitResourceStrings('lclstrconsts', po) then
               begin
               logger.Info('UI language: the Lazarus catalogue for "' + aLang +
                           '" was applied, so the LCL own strings translate too');
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
         logger.Warn('UI language: the Lazarus catalogue for "' + aLang +
                     '" could not be applied -- ' + E.Message);
         end;
   end;
end;

function ActiveUILanguage: string;
begin
   Result := GActiveLang;
end;

function ApplyCatalogue(po: TPOFile): boolean;
{ TAKES OWNERSHIP of po. The caller must not free it, and neither may this
  unit once it is installed: the TPOTranslator it is handed to frees it. See
  the note on GActiveLang's var block. }
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

   // The outgoing translator frees the catalogue it was reading -- the only
   // owner, so nothing here frees it a second time.
   if Assigned(LRSTranslator) then
      begin
      LRSTranslator.Free;
      LRSTranslator := nil;
      end;

   LRSTranslator := TPOTranslator.Create(po);
end;


function LoadEmbeddedTranslation(const aSetting: string): string;
var
   lang:   string;
   source: string;
   resName: string;
   (* resName as bytes, for FindResource. Named for the same reason as every
     other boundary pointer here. *)
   resBytes: AnsiString;
   rs:     TResourceStream;
   po:     TPOFile;
   fileCandidate: string;
begin
   Result := '';
   GActiveLang := '';
   lang := ResolveLang(aSetting, source);
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
   fileCandidate := LanguageFilePath(lang);
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
            LoadLCLCatalogue(lang);
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
   (* ASCII by construction -- 'TR4W_' and an upper-cased language tag. *)
   resBytes := AnsiString(resName);
   if FindResource(HInstance, PAnsiChar(resBytes), RT_RCDATA) = 0 then
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
            LoadLCLCatalogue(lang);
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

(* THE LANGUAGE SETTING'S VOCABULARY: '' ("System default") and every
  catalogue this binary carries.

  REGISTERED HERE because this is the unit that knows what is loadable -- the
  same reason uCFG registers the vocabularies it owns. From the RCDATA names,
  never from a typed list, so Preferences cannot offer a language the binary
  lacks, and a config line naming one is refused. English is in the list
  because Make-LanguageRes embeds tr4w_en.po like any other. *)
(* GENERATED, NOT TYPED -- and Lint-SpellingTables knows this name as one,
  the way it knows uRadioRegistry.RadioTypeTokensA. Its '' is deliberate
  and is not the blank-spelling defect that lint hunts: this is a STRING
  setting, where '' is a value ("System default"), not a spelling that
  selects an enum ordinal. *)
function LanguageVocabulary: TArray<string>;
var
   codes: TArray<string>;
   i: integer;
begin
   codes := EmbeddedLanguageCodes;
   SetLength(Result, Length(codes) + 1);
   Result[0] := '';
   for i := 0 to High(codes) do
      begin
      Result[i + 1] := codes[i];
      end;
end;

initialization
   RegisterSettingAllowedValues('Display.Language', LanguageVocabulary);

finalization
   (* The translator, and with it the catalogue it owns -- see the note on
     GActiveLang's var block for why there is no second Free here. Nil'd
     because LCLTranslator's own finalization frees LRSTranslator too, and
     runs after this one. *)
   if Assigned(LRSTranslator) then
      begin
      LRSTranslator.Free;
      LRSTranslator := nil;
      end;
   FreeAndNil(GLanguageNames);

end.
