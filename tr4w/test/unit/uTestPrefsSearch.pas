unit uTestPrefsSearch;
{$I ..\..\src\tr4w.inc}
{
  The Preferences search ranking.

  WHY THIS IS TESTED AT ALL. Search is the kind of feature that looks like it
  works: type something, get rows. What it cannot show you is the row it should
  have returned and did not. Typing 'far' and getting nothing for FARNSWORTH is
  invisible unless someone happens to try that exact word -- so the words are
  pinned here instead.

  The cases are written as an operator's keystrokes, not as unit inputs: what a
  long-time TR4W user would type, and what someone who has never seen Ctrl-J
  would type for the same setting. Both must find it, which is the whole reason
  the legacy command name is in the index alongside the caption.
}

interface

uses
   SysUtils, uTR4WTestFramework, uPrefsSearch;

type
   TPrefsSearchTests = class(TTestCase)
   protected
      procedure Test_EmptyNeedleMatchesNothing;
      procedure Test_TheOldCtrlJNameStillFindsIt;
      procedure Test_TheNewCaptionFindsIt;
      procedure Test_PartialWordFindsIt;
      procedure Test_CaseIsIrrelevant;
      procedure Test_CaptionOutranksCommand;
      procedure Test_ExactOutranksEverything;
      procedure Test_AllTokensMustMatch;
      procedure Test_TokensMayComeFromEitherName;
      procedure Test_NarrowingTypingKeepsMatching;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   { One real setting, in both its spellings. }
   CAP_SAYHI = 'Send a greeting';
   CMD_SAYHI = 'SAY HI ENABLE';

   CAP_FARNS = 'Farnsworth spacing';
   CMD_FARNS = 'FARNSWORTH ENABLE';

   CAP_ZEROCH = 'Leading zero character';
   CMD_ZEROCH = 'LEADING ZERO CHARACTER';

procedure TPrefsSearchTests.Test_EmptyNeedleMatchesNothing;
begin
   // The results list stays SHUT until there is something to search for --
   // opening a 500-row popup on focus is not a feature.
   CheckEquals(PREFS_MATCH_NONE, PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, ''),
               'an empty search must match nothing');
   CheckEquals(PREFS_MATCH_NONE, PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, '   '),
               'whitespace only must match nothing');
end;

procedure TPrefsSearchTests.Test_TheOldCtrlJNameStillFindsIt;
begin
   // THE MIGRATION PROMISE. Every setting that moves to Preferences LEAVES
   // Ctrl-J, where the operator could type its command name. If that name stops
   // working here, the move silently costs them the only way they knew.
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'SAY HI ENABLE') > PREFS_MATCH_NONE,
         'the full legacy command must find its setting');
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'SAY HI') > PREFS_MATCH_NONE,
         'the start of the legacy command must find it');
   Check(PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'FARNSWORTH') > PREFS_MATCH_NONE,
         'a legacy command word must find it');
end;

procedure TPrefsSearchTests.Test_TheNewCaptionFindsIt;
begin
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'greeting') > PREFS_MATCH_NONE,
         'a caption word must find its setting');
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'Send') > PREFS_MATCH_NONE,
         'the start of the caption must find it');
end;

procedure TPrefsSearchTests.Test_PartialWordFindsIt;
begin
   // The point of an incremental box: the operator does not know the whole word.
   Check(PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'far') > PREFS_MATCH_NONE,
         '''far'' must find FARNSWORTH');
   Check(PrefsMatchScore(CAP_ZEROCH, CMD_ZEROCH, 'zero') > PREFS_MATCH_NONE,
         'a word in the middle must match');
   Check(PrefsMatchScore(CAP_ZEROCH, CMD_ZEROCH, 'char') > PREFS_MATCH_NONE,
         'the last word must match');
end;

procedure TPrefsSearchTests.Test_CaseIsIrrelevant;
begin
   CheckEquals(PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'FAR'),
               PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'far'),
               'case must not change the score');
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'sAy Hi') > PREFS_MATCH_NONE,
         'mixed case must still match');
end;

procedure TPrefsSearchTests.Test_CaptionOutranksCommand;
begin
   // What the operator can SEE ranks above the legacy spelling, so a list is
   // ordered the way the panel reads rather than the way the ini does.
   Check(PREFS_MATCH_CAPTION_START > PREFS_MATCH_COMMAND_START,
         'a caption hit must outrank a command hit');
   Check(PREFS_MATCH_CAPTION_WORD > PREFS_MATCH_COMMAND_WORD,
         'a caption word must outrank a command word');
end;

procedure TPrefsSearchTests.Test_ExactOutranksEverything;
begin
   CheckEquals(PREFS_MATCH_EXACT, PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, CAP_SAYHI),
               'the exact caption must score highest');
   CheckEquals(PREFS_MATCH_EXACT, PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, CMD_SAYHI),
               'the exact command must score highest');
end;

procedure TPrefsSearchTests.Test_AllTokensMustMatch;
begin
   // ANDed, not ORed. A second word NARROWS -- 'en' then 'env' in the Windows
   // Settings box. Scoring by the best token instead would let 'farnsworth zzz'
   // return every Farnsworth row, which reads as broken rather than empty.
   CheckEquals(PREFS_MATCH_NONE,
               PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'farnsworth zzz'),
               'a token matching nothing must kill the whole match');
   Check(PrefsMatchScore(CAP_FARNS, CMD_FARNS, 'farns enable') > PREFS_MATCH_NONE,
         'two matching tokens must still match');
end;

procedure TPrefsSearchTests.Test_TokensMayComeFromEitherName;
begin
   // 'greeting' is only in the caption, 'ENABLE' only in the command.
   Check(PrefsMatchScore(CAP_SAYHI, CMD_SAYHI, 'greeting enable') > PREFS_MATCH_NONE,
         'tokens must be allowed to match across caption AND command');
end;

procedure TPrefsSearchTests.Test_NarrowingTypingKeepsMatching;
var
   i: integer;
   typed: string;
begin
   // Type 'FARNSWORTH' one key at a time; every prefix must still match. A gap
   // would show as the row vanishing mid-word and coming back, which is the
   // failure an operator reports as "the search is flaky".
   for i := 1 to Length('FARNSWORTH') do
      begin
      typed := Copy('FARNSWORTH', 1, i);
      Check(PrefsMatchScore(CAP_FARNS, CMD_FARNS, typed) > PREFS_MATCH_NONE,
            Format('prefix "%s" must still match', [typed]));
      end;
end;

procedure TPrefsSearchTests.RunAllTests;
begin
   Test_EmptyNeedleMatchesNothing;
   Test_TheOldCtrlJNameStillFindsIt;
   Test_TheNewCaptionFindsIt;
   Test_PartialWordFindsIt;
   Test_CaseIsIrrelevant;
   Test_CaptionOutranksCommand;
   Test_ExactOutranksEverything;
   Test_AllTokensMustMatch;
   Test_TokensMayComeFromEitherName;
   Test_NarrowingTypingKeepsMatching;
end;

end.
