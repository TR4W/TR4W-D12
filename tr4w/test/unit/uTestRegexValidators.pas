unit uTestRegexValidators;
{$I ..\..\src\tr4w.inc}

{
  Pins the two regular-expression validators left in LOGSTUFF: GUID and POTA
  park.

  THERE WERE FIVE. The three CALLSIGN patterns -- RX_CALLSIGN, RX_US_PREFIX and
  RX_US_CALLSIGN -- were retired on 2026-08-21 in favour of hand-written tests in
  uCallSignRoutines (IsAGoodCall, IsAUSPrefix, IsAGoodUSCall), and their cases
  moved to uTestCallSignRoutines. The reason was measured, not assumed
  (tr4w\test\bench\bench_callsign.lpr, 234,467 callsigns from ARRL's LOTW
  activity file):

     IsAGoodCall     327 ns/call    accepted 234,466
     RX_CALLSIGN   1,367 ns/call    accepted 234,335

  Four times slower AND stricter in the wrong direction: 131 real callsigns that
  IsAGoodCall accepts and RX_CALLSIGN refused -- 3DA/G3SXW, 5JSTAYHOME,
  7L3DNX/1/QRP -- against none the other way. A contest logger meets those
  shapes constantly.

  RX_US_PREFIX also carried a typo that this suite had PINNED AS EXPECTED
  BEHAVIOUR: '^[AaWaKkNn][a-zA-Z]?' has 'a' twice and no lowercase 'w', so
  'w1aw' failed the US test and silently skipped the strict US check. A test
  that documents a bug is how a bug survives; IsAUSPrefix answers the question
  directly and the new test asserts the fix.

  WHAT REMAINS IS GENUINELY REGEX-SHAPED. A GUID and a POTA reference are fixed
  formats with no domain knowledge in them, they are validated rarely, and a
  pattern reads better than the character walk would. The engine still changes
  per compiler -- PCRE under Delphi, TRegExpr under FPC -- and two engines
  answering one question is exactly what needs a test rather than an assurance.

  The three 4-digit groups in RX_GUID are written out rather than as a repeated
  group
  because TRegExpr throws on the grouped form when a near-miss forces it to
  backtrack into the repetition. Both engines agree on the expanded spelling.
}

interface

uses
   uTR4WTestFramework;

type
   TRegexValidatorTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_IsValidGUID;
      procedure Test_IsValidPOTAPark;
   end;

implementation

uses
   LOGSTUFF;

procedure TRegexValidatorTests.RunAllTests;
begin
   Test_IsValidGUID;
   Test_IsValidPOTAPark;
end;

// ---------------------------------------------------------------------------
// IsValidGUID
// ---------------------------------------------------------------------------

procedure TRegexValidatorTests.Test_IsValidGUID;
begin
   BeginTest('Test_IsValidGUID');

   CheckTrue(IsValidGUID('6B29FC40-CA47-1067-B31D-00DD010662DA'),
             'hyphenated 8-4-4-4-12');
   CheckTrue(IsValidGUID('{6B29FC40-CA47-1067-B31D-00DD010662DA}'),
             'the same wrapped in braces');
   CheckTrue(IsValidGUID('6b29fc40ca471067b31d00dd010662da'),
             '32 raw hex characters, lower case');

   CheckFalse(IsValidGUID(''), 'empty is not a GUID');
   CheckFalse(IsValidGUID('notaguid'), 'letters outside hex');
   CheckFalse(IsValidGUID('6B29FC40-CA47-1067-B31D-00DD010662D'),
              'one hex digit short');
   CheckFalse(IsValidGUID('ZB29FC40-CA47-1067-B31D-00DD010662DA'),
              'Z is not a hex digit');
end;

// ---------------------------------------------------------------------------
// IsValidPOTAPark
// ---------------------------------------------------------------------------

procedure TRegexValidatorTests.Test_IsValidPOTAPark;
begin
   BeginTest('Test_IsValidPOTAPark');

   CheckTrue(IsValidPOTAPark('US-1234'),  'two letters, four digits');
   CheckTrue(IsValidPOTAPark('US-12345'), 'two letters, five digits');
   CheckTrue(IsValidPOTAPark('CA-0001'),  'leading zeros are kept');
   CheckTrue(IsValidPOTAPark('us-1234'),  'lower case');

   // The reason the pattern is this tight: a park reference and an RST report
   // arrive in the same exchange field, and '59' must not look like a park.
   CheckFalse(IsValidPOTAPark('59'),       'an RST report is not a park');
   CheckFalse(IsValidPOTAPark('599'),      'nor is a CW RST');
   CheckFalse(IsValidPOTAPark('US-123'),   'three digits is too few');
   CheckFalse(IsValidPOTAPark('US-123456'), 'six digits is too many');
   CheckFalse(IsValidPOTAPark('USA-1234'), 'three letters');
   CheckFalse(IsValidPOTAPark('U-1234'),   'one letter');
   CheckFalse(IsValidPOTAPark('US1234'),   'no hyphen');
   CheckFalse(IsValidPOTAPark(''),         'empty');
end;

end.
