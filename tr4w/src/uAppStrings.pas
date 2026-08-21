unit uAppStrings;
{$I tr4w.inc}

{
  USER-FACING TEXT AS resourcestring -- the start of the I18N replacement.

  TR4W has translated its UI by COMPILING a different binary per language: a
  `TC_...` constant per string in src\lang\tr4w_consts_<LANG>.pas, selected by
  a LANG_xxx define.  Nine binaries, nine constant files that drift, and each
  one an ANSI file in its own codepage -- 1251 for Russian, 1250 for Czech and
  Serbian, 1252 for German -- which is why a blanket encoding conversion was
  wrong and why a file that loses its BOM silently corrupts.

  The replacement is `resourcestring` and ONE binary per platform (NY4I,
  2026-08-13).  Resource DLLs are out: they have no FMX/macOS/Linux equivalent.

  THIS UNIT IS THE FIRST STEP, and deliberately a small one.  New dialogs and
  message boxes declare their text here; nothing existing was converted, because
  a sweep of the whole TC_ table belongs with the translation work and not with
  a feature commit.  Do NOT add a TC_ constant for new UI text -- add it here.

  WHY resourcestring RATHER THAN const: the compiler places these in a
  resource string table, so a translation tool can enumerate and replace them
  without recompiling, and FPC/Lazarus already understand the format.  A plain
  const is invisible to all of that.

  NAMING: S<Area><Thing>.  No TC_ prefix -- that prefix means "lives in the
  per-language const files", and these deliberately do not.
}

interface

resourcestring
   { ---------------------------------------------- retiring the legacy ini - }

   // Shown ONCE, after the settings have been carried into settings\tr4w.json.
   // The wording states what has already happened before it asks for anything:
   // an operator who is told "may I delete your configuration" reasonably says
   // no, and an operator who is told "your settings have already been copied,
   // this file is no longer read" can answer the question that is actually
   // being asked.
   SIniRetireTitle = 'Old settings file';

   SIniRetirePrompt =
      'Your settings have been moved to:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'The old file is no longer read:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'Remove it now?' + sLineBreak + sLineBreak +
      'Choosing No keeps the file and TR4W will not ask again. ' +
      'The file is ignored either way.';

   SIniRetireRemoved  = 'Removed %s.';
   SIniRetireFailed   = 'Could not remove %s -- %s.' + sLineBreak +
                        'It is ignored regardless, so nothing is broken.';

implementation

end.
