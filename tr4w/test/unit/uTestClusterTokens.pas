unit uTestClusterTokens;

// THE CLUSTER COMMAND TOKEN EXPANDER.
//
// The expander is a small hand-written parser, and every case below is one it
// can get wrong in a way no compiler and no bench session would catch: a
// doubled brace meant as a literal, a brace the operator never closed, a token
// name misspelled.  The important one is the LAST of those.  An unknown token
// must survive verbatim so the operator can see the typo -- returning an empty
// string instead would send a command that is silently missing a field, and
// against a live cluster that reads as the cluster misbehaving.
//
// The segment flags are pinned too, because they are what the preview uses to
// show which text was substituted, and a flag that is merely PLAUSIBLE renders
// as a preview that lies about what is going out.

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TClusterTokensTests = class(TTestCase)
   protected
      procedure TestPlainTextIsUntouched;
      procedure TestSingleTokenExpands;
      procedure TestTokenIsCaseInsensitive;
      procedure TestTokenToleratesSpaces;
      procedure TestUnknownTokenSurvivesVerbatim;
      procedure TestTokenAtStartAndEnd;
      procedure TestTwoTokensAdjacent;
      procedure TestDoubledBraceIsLiteral;
      procedure TestUnterminatedBraceIsLiteral;
      procedure TestEmptyBracesAreUnknown;
      procedure TestEmptySourceGivesNoSegments;
      procedure TestLiteralRunsAreNotFragmented;
      procedure TestSubstitutedFlagMarksOnlyTheValue;
      procedure TestExpandingToEmptyStringDropsTheSegment;
      procedure TestNilLookupLeavesEverythingVerbatim;
      procedure TestNormalizeTrimsAndUpcases;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uClusterTokens;

// The test vocabulary.  MY_EMPTY exists to pin that a token which legitimately
// expands to nothing is FOUND -- it must not fall through to the verbatim path.
function TestLookup(const Token: string; out Value: string): boolean;
begin
   Result := True;
   Value := '';

   if Token = 'MY_CALL' then
      begin
      Value := 'NY4I';
      end
   else if Token = 'MY_GRID' then
      begin
      Value := 'EL88';
      end
   else if Token = 'MY_EMPTY' then
      begin
      Value := '';
      end
   else
      begin
      Result := False;
      end;
end;

procedure TClusterTokensTests.TestPlainTextIsUntouched;
begin
   BeginTest('TestPlainTextIsUntouched');
   CheckEquals('SH/DX 50',
               SegmentsToText(ExpandClusterSegments('SH/DX 50', TestLookup)),
               'text with no braces passes through');
end;

procedure TClusterTokensTests.TestSingleTokenExpands;
begin
   BeginTest('TestSingleTokenExpands');
   CheckEquals('SET/QTH NY4I',
               SegmentsToText(ExpandClusterSegments('SET/QTH {MY_CALL}', TestLookup)),
               'a known token is replaced by its value');
end;

procedure TClusterTokensTests.TestTokenIsCaseInsensitive;
begin
   BeginTest('TestTokenIsCaseInsensitive');
   CheckEquals('NY4I',
               SegmentsToText(ExpandClusterSegments('{my_call}', TestLookup)),
               'a lower-case token name still matches');
end;

procedure TClusterTokensTests.TestTokenToleratesSpaces;
begin
   BeginTest('TestTokenToleratesSpaces');
   CheckEquals('NY4I',
               SegmentsToText(ExpandClusterSegments('{  MY_CALL  }', TestLookup)),
               'spaces inside the braces are trimmed');
end;

procedure TClusterTokensTests.TestUnknownTokenSurvivesVerbatim;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestUnknownTokenSurvivesVerbatim');
   Segments := ExpandClusterSegments('SET/QTH {MY_TYPO}', TestLookup);
   CheckEquals('SET/QTH {MY_TYPO}', SegmentsToText(Segments),
               'an unrecognised token is left alone, braces included');
   CheckEquals(1, Length(Segments),
               'and stays part of the surrounding literal run');
   CheckFalse(Segments[0].Substituted,
              'an unrecognised token is not marked as substituted');
end;

procedure TClusterTokensTests.TestTokenAtStartAndEnd;
begin
   BeginTest('TestTokenAtStartAndEnd');
   CheckEquals('NY4I is at EL88',
               SegmentsToText(ExpandClusterSegments('{MY_CALL} is at {MY_GRID}', TestLookup)),
               'tokens at both ends of the string expand');
end;

procedure TClusterTokensTests.TestTwoTokensAdjacent;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestTwoTokensAdjacent');
   Segments := ExpandClusterSegments('{MY_CALL}{MY_GRID}', TestLookup);
   CheckEquals('NY4IEL88', SegmentsToText(Segments),
               'back-to-back tokens both expand');
   CheckEquals(1, Length(Segments),
               'two adjacent substitutions merge into one run');
   CheckTrue(Segments[0].Substituted, 'and that run is marked substituted');
end;

procedure TClusterTokensTests.TestDoubledBraceIsLiteral;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestDoubledBraceIsLiteral');
   Segments := ExpandClusterSegments('{{MY_CALL}}', TestLookup);
   CheckEquals('{MY_CALL}', SegmentsToText(Segments),
               'doubled braces escape to single ones and suppress expansion');
   CheckFalse(Segments[0].Substituted,
              'an escaped brace is literal text, not a substitution');
end;

procedure TClusterTokensTests.TestUnterminatedBraceIsLiteral;
begin
   BeginTest('TestUnterminatedBraceIsLiteral');
   CheckEquals('SH/DX {MY_CALL',
               SegmentsToText(ExpandClusterSegments('SH/DX {MY_CALL', TestLookup)),
               'a brace the operator never closed emits the rest verbatim');
end;

procedure TClusterTokensTests.TestEmptyBracesAreUnknown;
begin
   BeginTest('TestEmptyBracesAreUnknown');
   CheckEquals('{}',
               SegmentsToText(ExpandClusterSegments('{}', TestLookup)),
               'an empty token name is simply unrecognised');
end;

procedure TClusterTokensTests.TestEmptySourceGivesNoSegments;
begin
   BeginTest('TestEmptySourceGivesNoSegments');
   CheckEquals(0, Length(ExpandClusterSegments('', TestLookup)),
               'an empty command produces no segments');
   CheckEquals('', SegmentsToText(ExpandClusterSegments('', TestLookup)),
               'and no text');
end;

procedure TClusterTokensTests.TestLiteralRunsAreNotFragmented;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestLiteralRunsAreNotFragmented');
   Segments := ExpandClusterSegments('SH/DX 50', TestLookup);
   CheckEquals(1, Length(Segments),
               'eight literal characters are ONE segment, not eight');
end;

procedure TClusterTokensTests.TestSubstitutedFlagMarksOnlyTheValue;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestSubstitutedFlagMarksOnlyTheValue');
   Segments := ExpandClusterSegments('DE {MY_CALL} K', TestLookup);
   CheckEquals(3, Length(Segments), 'literal, value, literal');

   CheckEquals('DE ', Segments[0].Text, 'the leading literal');
   CheckFalse(Segments[0].Substituted, 'which is not substituted');

   CheckEquals('NY4I', Segments[1].Text, 'the substituted value');
   CheckTrue(Segments[1].Substituted, 'which IS substituted');

   CheckEquals(' K', Segments[2].Text, 'the trailing literal');
   CheckFalse(Segments[2].Substituted, 'which is not substituted');
end;

procedure TClusterTokensTests.TestExpandingToEmptyStringDropsTheSegment;
var
   Segments: TClusterSegments;
begin
   BeginTest('TestExpandingToEmptyStringDropsTheSegment');
   // MY_EMPTY is FOUND but has no value -- the token disappears rather than
   // being left verbatim, and contributes no empty segment for the preview to
   // render.
   Segments := ExpandClusterSegments('A{MY_EMPTY}B', TestLookup);
   CheckEquals('AB', SegmentsToText(Segments),
               'a token that expands to nothing simply vanishes');
   CheckEquals(1, Length(Segments),
               'and the literals either side join up');
end;

procedure TClusterTokensTests.TestNilLookupLeavesEverythingVerbatim;
begin
   BeginTest('TestNilLookupLeavesEverythingVerbatim');
   CheckEquals('DE {MY_CALL} K',
               SegmentsToText(ExpandClusterSegments('DE {MY_CALL} K', nil)),
               'with no vocabulary, nothing is recognised and nothing is lost');
end;

procedure TClusterTokensTests.TestNormalizeTrimsAndUpcases;
begin
   BeginTest('TestNormalizeTrimsAndUpcases');
   CheckEquals('MY_CALL', NormalizeClusterToken('  my_call  '), 'trimmed and upcased');
   CheckEquals('MY_CALL', NormalizeClusterToken('MY_CALL'), 'already normal');
   CheckEquals('', NormalizeClusterToken('   '), 'all spaces normalises to empty');
   CheckEquals('', NormalizeClusterToken(''), 'empty stays empty');
   CheckEquals('SH/DX50', NormalizeClusterToken('sh/dx50'),
               'digits and punctuation are left as they are');
end;

procedure TClusterTokensTests.RunAllTests;
begin
   TestPlainTextIsUntouched;
   TestSingleTokenExpands;
   TestTokenIsCaseInsensitive;
   TestTokenToleratesSpaces;
   TestUnknownTokenSurvivesVerbatim;
   TestTokenAtStartAndEnd;
   TestTwoTokensAdjacent;
   TestDoubledBraceIsLiteral;
   TestUnterminatedBraceIsLiteral;
   TestEmptyBracesAreUnknown;
   TestEmptySourceGivesNoSegments;
   TestLiteralRunsAreNotFragmented;
   TestSubstitutedFlagMarksOnlyTheValue;
   TestExpandingToEmptyStringDropsTheSegment;
   TestNilLookupLeavesEverythingVerbatim;
   TestNormalizeTrimsAndUpcases;
end;

end.
