unit uTestRegexValidators;
{$I ..\..\src\tr4w.inc}

{
  Pins the five regular-expression validators in LOGSTUFF.

  WHY THESE EXIST NOW.  The engine behind them changed: TPerlRegEx links the
  vendored PCRE library as Borland-format .obj files that FPC's linker cannot
  read, so uRegex now picks the engine per compiler -- PCRE under Delphi,
  TRegExpr under FPC.  Two engines answering the same question is precisely the
  situation that needs a test rather than an assurance.

  One pattern also had to CHANGE.  RX_CALLSIGN's optional prefix group was
  written with PCRE's possessive quantifier `?+`, which TRegExpr rejects
  outright ("nested *?+").  Equivalence was established empirically before the
  `+` was removed -- both spellings through the shipping PCRE engine over 67,681
  real callsigns from the golden corpus and TRMASTER.DTA, then TRegExpr over the
  same 67,681 compared line by line against the PCRE answers, 0 differences each
  time (spike\rxprobe).  A bulk probe is not a regression test, though: it ran
  once, against data that is not checked in.  These cases are the permanent
  guard, chosen to cover the SHAPES that probe swept -- plain calls, portable
  and prefix forms with '/', the branch the possessive quantifier could have
  affected, and the near-misses each pattern must REFUSE.

  On IsValidUSPrefix: it is deliberately NOT anchored at the end, so it answers
  "does this begin like a US call", not "is this a US call".  'W1AW/KH6' is a
  US prefix and is not a US callsign -- both are asserted below so the
  distinction cannot be quietly lost.
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
      procedure Test_IsValidUSPrefix;
      procedure Test_IsValidUSCallsign;
      procedure Test_IsValidCallsign;
      procedure Test_IsValidCallsign_SlashForms;
      procedure Test_IsValidPOTAPark;
   end;

implementation

uses
   LOGSTUFF;

procedure TRegexValidatorTests.RunAllTests;
begin
   Test_IsValidGUID;
   Test_IsValidUSPrefix;
   Test_IsValidUSCallsign;
   Test_IsValidCallsign;
   Test_IsValidCallsign_SlashForms;
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
// IsValidUSPrefix -- a PREFIX test, unanchored at the end
// ---------------------------------------------------------------------------

procedure TRegexValidatorTests.Test_IsValidUSPrefix;
begin
   BeginTest('Test_IsValidUSPrefix');

   CheckTrue(IsValidUSPrefix('W1AW'),   'W');
   CheckTrue(IsValidUSPrefix('K1TTT'),  'K');
   CheckTrue(IsValidUSPrefix('N6TR'),   'N');
   CheckTrue(IsValidUSPrefix('AA1K'),   'A');
   CheckTrue(IsValidUSPrefix('NY4I'),   'NY4I');
   // LOWER CASE IS ASYMMETRIC, and not on purpose.  RX_US_PREFIX's character
   // class is [AaWaKkNn] -- read it slowly: A a W a K k N n.  The second pair
   // is 'Wa', not 'Ww', so upper-case W is accepted and LOWER-CASE W IS NOT,
   // while a/k/n all have both cases.  Almost certainly a typo, and it is
   // PRE-EXISTING and engine-independent: PCRE and TRegExpr agree on it.
   //
   // Pinned as-is rather than fixed.  Changing it changes what the Login
   // command accepts, which is NY4I's call, not a side effect of a compiler
   // port.  In practice the effect is small -- MainUnit's menu_login falls
   // through to IsValidCallsign, which accepts 'w1aw' anyway -- but it does
   // mean a lower-case entry skips the US-shape check that an upper-case one
   // gets.  If the class is ever corrected to [AaWwKkNn], this assertion is
   // the one that should flip.
   CheckTrue(IsValidUSPrefix('a1aw'),   'lower case a IS accepted');
   CheckTrue(IsValidUSPrefix('k1ttt'),  'lower case k IS accepted');
   CheckTrue(IsValidUSPrefix('n6tr'),   'lower case n IS accepted');
   CheckFalse(IsValidUSPrefix('w1aw'),  'lower case w is NOT -- see the note above');

   // Unanchored at the end ON PURPOSE -- see the unit header.
   CheckTrue(IsValidUSPrefix('W1AW/KH6'),
             'a portable US call still BEGINS like a US call');

   CheckFalse(IsValidUSPrefix('DL1ABC'), 'German');
   CheckFalse(IsValidUSPrefix('G3XYZ'),  'British');
   CheckFalse(IsValidUSPrefix('1A0KM'),  'leading digit');
   CheckFalse(IsValidUSPrefix(''),       'empty');
end;

// ---------------------------------------------------------------------------
// IsValidUSCallsign -- fully anchored
// ---------------------------------------------------------------------------

procedure TRegexValidatorTests.Test_IsValidUSCallsign;
begin
   BeginTest('Test_IsValidUSCallsign');

   CheckTrue(IsValidUSCallsign('W1AW'),  '1x2');
   CheckTrue(IsValidUSCallsign('K1TTT'), '1x3');
   CheckTrue(IsValidUSCallsign('NY4I'),  '2x1');
   CheckTrue(IsValidUSCallsign('AA1K'),  '2x1 with a double-letter prefix');
   CheckTrue(IsValidUSCallsign('N6TR'),  '1x2');

   CheckFalse(IsValidUSCallsign('DL1ABC'), 'not a US prefix');
   CheckFalse(IsValidUSCallsign('W1AWXYZ'), 'suffix too long');
   CheckFalse(IsValidUSCallsign('W1'),      'no suffix at all');

   // The distinction that makes the two functions different.
   CheckFalse(IsValidUSCallsign('W1AW/KH6'),
              'anchored: a portable call is NOT a bare US callsign');
end;

// ---------------------------------------------------------------------------
// IsValidCallsign -- the general form
// ---------------------------------------------------------------------------

procedure TRegexValidatorTests.Test_IsValidCallsign;
begin
   BeginTest('Test_IsValidCallsign');

   CheckTrue(IsValidCallsign('W1AW'),   'US 1x2');
   CheckTrue(IsValidCallsign('DL1ABC'), 'German');
   CheckTrue(IsValidCallsign('G3XYZ'),  'British');
   CheckTrue(IsValidCallsign('JA1ZZZ'), 'Japanese');
   CheckTrue(IsValidCallsign('9A5Y'),   'prefix starting with a digit');
   CheckTrue(IsValidCallsign('OH2BH'),  'Finnish');

   CheckFalse(IsValidCallsign(''),      'empty');
   CheckFalse(IsValidCallsign('ABCDE'), 'no digit anywhere');

   // RX_CALLSIGN is \w+[0-9]+\w+, and \w INCLUDES DIGITS, so an all-numeric
   // string satisfies it -- '12345' splits as '1' + '2' + '345'.  The pattern
   // is a shape filter, not a callsign authority, and this is what it has
   // always answered on both engines.  Asserted so the looseness is visible
   // rather than assumed away.
   CheckTrue(IsValidCallsign('12345'),
             'all digits PASSES: \w matches digits too');
end;

procedure TRegexValidatorTests.Test_IsValidCallsign_SlashForms;
begin
   BeginTest('Test_IsValidCallsign_SlashForms');

   // THE BRANCH THE POSSESSIVE QUANTIFIER GUARDED.  RX_CALLSIGN's optional
   // leading group is the only part of any pattern `?+` could have changed, and
   // every one of its alternatives ends in '/', so these are the cases that
   // would have moved if removing it had not been equivalent.
   CheckTrue(IsValidCallsign('W1/AB2CD'),   'one-or-two-char prefix then /');
   CheckTrue(IsValidCallsign('DL/W1AW'),    'two-char prefix then /');
   CheckTrue(IsValidCallsign('K/DL1ABC'),   'one-char prefix then /');
   CheckTrue(IsValidCallsign('W1AW/4'),     'trailing area number');
   CheckTrue(IsValidCallsign('DL1ABC/P'),   'portable suffix');

   CheckFalse(IsValidCallsign('/W1AW'),  'a leading slash is not a prefix');
   CheckFalse(IsValidCallsign('/'),      'a bare slash');
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
