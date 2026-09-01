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
   { The single-instance warning's title.  It used to be tr4w_ClassName -- the
     WINDOW CLASS NAME -- which happens to read as 'TR4W' and so looked
     deliberate.  A caption is user-facing text and belongs here. }
   SAlreadyRunningTitle = 'TR4W';

   SIniRetireTitle = 'Old settings file';

   SIniRetirePrompt =
      'Your settings have been moved to:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'The old file is no longer read:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'Remove it now?' + sLineBreak + sLineBreak +
      'The file is ignored either way.';

   { THE SECOND QUESTION, ASKED SEPARATELY.  It used to be a sentence in the
     prompt above saying that No would also stop TR4W asking -- so an operator
     who was simply not ready to delete a file today gave a permanent answer
     without meaning to.  Two questions, two controls. }
   SIniRetireDontAsk = 'Do not ask me about this file again';

   SIniRetireRemoved  = 'Removed %s.';
   SIniRetireFailed   = 'Could not remove %s -- %s.' + sLineBreak +
                        'It is ignored regardless, so nothing is broken.';

   { ------------------------------------------------- downloads that fail --- }

   { WHY THIS NAMES THE INSTALLER.  A missing OpenSSL pair almost always means
     tr4w.exe was copied somewhere on its own -- the installer ships
     libeay32.dll and ssleay32.dll beside it (buildull.nsi). The operator
     cannot deduce that from "download failed", so ASK THE QUESTION (NY4I,
     2026-08-26: "They should be asked if they ran the INSTALLER"). }
   SDownloadNoSSLLibrary =
      'the OpenSSL libraries could not be loaded.' + sLineBreak + sLineBreak +
      'libeay32.dll and ssleay32.dll must sit in the same folder as tr4w.exe. ' +
      'The TR4W installer puts them there -- was this folder installed, or is ' +
      'it a copy of tr4w.exe on its own?';

   { The reason is the POINT of this dialog. It used to advise checking the
     network and the folder permissions -- neither of which was ever the
     problem in the one case anybody hit, and the real reason was sitting in
     the log the whole time. }
   SCtyDownloadFailedTitle = 'CTY.DAT';

   { The refusal paths. Rare and close to programmer error, but they reach the
     same dialog, so they are text like any other -- not literals. }
   SDownloadCouldNotStart = 'the download was refused before it began (bad URL).';
   SDownloadRenameFailed  = 'the file downloaded but could not be saved under its final name.';

   SCtyDownloadFailed =
      'Could not download CTY.DAT to:' + sLineBreak + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'Reason: %s' + sLineBreak + sLineBreak +
      'tr4w.log records the full detail.';

   { ------------------------------------------------ multi-op networking - }

   // NAMES THE SETTING, because that is what the operator has to change.
   // "Connection refused" would send him to look at the network cable; the
   // problem is a letter in his own configuration, and two stations cannot
   // share one -- the whole protocol indexes station status BY that letter.
   SNetComputerIDInUse =
      'Computer ID %s is already in use by another station on this network.' +
      sLineBreak + sLineBreak +
      'Change COMPUTER ID to a letter no other station is using, then ' +
      'reconnect.';

implementation

end.
