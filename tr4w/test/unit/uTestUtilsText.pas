unit uTestUtilsText;
{$I ..\..\src\tr4w.inc}

{
  Tests for utils_text.pas string predicate functions.

  Functions NOT tested here (easily replaced by Delphi 12 stdlib):
    UpperCase, StringHas, PostcedingString, PrecedingString,
    tPos, pPos, safeFloat.

  StrComp and StrUpper ARE tested here, and the tests came first: both were
  hand-written x86-32 assembly with no coverage at all, and they are load-bearing
  -- StrComp drives the CTY.DAT prefix search and every config-command lookup,
  StrUpper normalizes callsigns and CTY records.  These are CHARACTERIZATION
  tests: they were written against the assembly, run green against it, and only
  then was the assembly replaced with Pascal.  They pin the exact return values,
  not merely the sign, so a "behaviour-preserving" rewrite has something that can
  actually say no.

  Functions tested:
    StringIsAllNumbers               -- used in exchange field parsing
    StringIsAllNumbersOrSpaces       -- used in exchange field validation
    StringIsAllNumbersOrDecimal      -- used in frequency/RST parsing
    StringIsAllAlphanumericOrDash    -- park/callsign validation; bNoCase added Issue #877
    StringWithFirstWordDeleted       -- no stdlib equivalent; edge cases non-obvious

  Exchange-field classification predicates (Issue #1035, roadmap item 4).
  These "has-digit / has-letter / mixed / char-class" primitives are the
  foundation the extracted exchange parser (#1038) will lean on, and each
  is a candidate for Delphi 12 stdlib replacement -- so they get a
  regression net now, before the freeze, even though they currently have
  no external call sites of their own:
    StringHasNumber                  -- "has a digit" (mixed-field detection)
    StringHasLetters                 -- "has a letter" (case-insensitive via UpCase)
    StringHasLowerCase               -- case detection for exchange normalization
    tCharIsNumbers                   -- char-level digit test (underlies the numeric predicates)
    tCharIsAlphaNumericOrDash        -- char-level callsign-shape test (A-Z/0-9/dash, uppercase only)
}

interface

uses
   uTR4WTestFramework;

type
   TUtilsTextTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_StringIsAllNumbers;
      procedure Test_StringIsAllNumbersOrSpaces;
      procedure Test_StringIsAllNumbersOrDecimal;
      procedure Test_StringIsAllAlphanumericOrDash;
      procedure Test_StringWithFirstWordDeleted;

      // Issue #1035 -- exchange-field classification predicates
      procedure Test_StringHasNumber;
      procedure Test_StringHasLetters;
      procedure Test_StringHasLowerCase;
      procedure Test_tCharIsNumbers;
      procedure Test_tCharIsAlphaNumericOrDash;

      // Asm eradication -- characterization tests, written against the assembly
      procedure Test_StrComp;
      procedure Test_StrComp_HighBitBytesAreUnsigned;
      procedure Test_StrUpper;
      procedure Test_StrUpper_LeavesNonAsciiAlone;
   end;

implementation

uses
   utils_text;

// ---------------------------------------------------------------------------
// StringIsAllNumbers
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringIsAllNumbers;
begin
   BeginTest('Test_StringIsAllNumbers');

   // Empty string must return false — the function guards explicitly
   CheckFalse(StringIsAllNumbers(''), 'empty string');

   // Pure digit strings
   CheckTrue(StringIsAllNumbers('0'), 'single zero');
   CheckTrue(StringIsAllNumbers('12345'), 'multi-digit');
   CheckTrue(StringIsAllNumbers('001'), 'leading zeros');

   // Any non-digit character must reject
   CheckFalse(StringIsAllNumbers('12.3'), 'decimal point');
   CheckFalse(StringIsAllNumbers('12 3'), 'embedded space');
   CheckFalse(StringIsAllNumbers('1A3'), 'embedded letter');
   CheckFalse(StringIsAllNumbers('-1'), 'leading minus');
end;

// ---------------------------------------------------------------------------
// StringIsAllNumbersOrSpaces
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringIsAllNumbersOrSpaces;
begin
   BeginTest('Test_StringIsAllNumbersOrSpaces');

   // Empty string must return false
   CheckFalse(StringIsAllNumbersOrSpaces(''), 'empty string');

   // Valid combinations
   CheckTrue(StringIsAllNumbersOrSpaces('123'), 'digits only');
   CheckTrue(StringIsAllNumbersOrSpaces('12 34'), 'digits and space');
   CheckTrue(StringIsAllNumbersOrSpaces('   '), 'spaces only');
   CheckTrue(StringIsAllNumbersOrSpaces(' 1 '), 'leading/trailing spaces');

   // Any other character must reject
   CheckFalse(StringIsAllNumbersOrSpaces('12.3'), 'decimal point');
   CheckFalse(StringIsAllNumbersOrSpaces('1A3'), 'letter');
end;

// ---------------------------------------------------------------------------
// StringIsAllNumbersOrDecimal
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringIsAllNumbersOrDecimal;
begin
   BeginTest('Test_StringIsAllNumbersOrDecimal');

   // Empty string must return false
   CheckFalse(StringIsAllNumbersOrDecimal(''), 'empty string');

   // Valid combinations
   CheckTrue(StringIsAllNumbersOrDecimal('14150'), 'integer frequency');
   CheckTrue(StringIsAllNumbersOrDecimal('14.150'), 'standard decimal');
   CheckTrue(StringIsAllNumbersOrDecimal('.5'), 'leading decimal');
   CheckTrue(StringIsAllNumbersOrDecimal('3.'), 'trailing decimal');

   // The function accepts any number of dots — documents current behavior
   // (no structural validation, only character-level)
   CheckTrue(StringIsAllNumbersOrDecimal('1.4.1'), 'two dots passes char check');

   // Non-digit, non-dot characters must reject
   CheckFalse(StringIsAllNumbersOrDecimal('14,150'), 'comma');
   CheckFalse(StringIsAllNumbersOrDecimal('14 150'), 'space');
   CheckFalse(StringIsAllNumbersOrDecimal('14MHz'), 'letters');
end;

// ---------------------------------------------------------------------------
// StringIsAllAlphanumericOrDash
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringIsAllAlphanumericOrDash;
begin
   BeginTest('Test_StringIsAllAlphanumericOrDash');

   // Empty string must return false
   CheckFalse(StringIsAllAlphanumericOrDash(''), 'empty string');

   // --- bNoCase = false (default) ---

   // Uppercase and digits pass
   CheckTrue(StringIsAllAlphanumericOrDash('K4A'), 'uppercase letters');
   CheckTrue(StringIsAllAlphanumericOrDash('123'), 'digits');
   CheckTrue(StringIsAllAlphanumericOrDash('K4A-1234'), 'uppercase with dash');
   CheckTrue(StringIsAllAlphanumericOrDash('-'), 'dash alone');

   // tCharIsAlphaNumericOrDash only accepts A-Z (uppercase); lowercase is rejected
   CheckFalse(StringIsAllAlphanumericOrDash('k4a'), 'lowercase rejected without bNoCase');
   CheckFalse(StringIsAllAlphanumericOrDash('k4a-1234'), 'lowercase with dash rejected');

   // Special characters always reject
   CheckFalse(StringIsAllAlphanumericOrDash('K4A!'), 'exclamation mark');
   CheckFalse(StringIsAllAlphanumericOrDash('K 4A'), 'embedded space');
   CheckFalse(StringIsAllAlphanumericOrDash('K4A.1'), 'dot');

   // --- bNoCase = true ---

   // Lowercase now passes because input is uppercased before checking
   CheckTrue(StringIsAllAlphanumericOrDash('k4a', True), 'lowercase passes with bNoCase');
   CheckTrue(StringIsAllAlphanumericOrDash('k4a-1234', True), 'lowercase with dash, bNoCase');
   CheckTrue(StringIsAllAlphanumericOrDash('K4A', True), 'uppercase still passes with bNoCase');

   // Special characters still reject even with bNoCase
   CheckFalse(StringIsAllAlphanumericOrDash('k4a!', True), 'special char rejected with bNoCase');
   CheckFalse(StringIsAllAlphanumericOrDash('', True), 'empty string with bNoCase');
end;

// ---------------------------------------------------------------------------
// StringWithFirstWordDeleted
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringWithFirstWordDeleted;
begin
   BeginTest('Test_StringWithFirstWordDeleted');

   // Empty string returns empty
   CheckEquals('', StringWithFirstWordDeleted(''), 'empty string');

   // No space — the whole string is one word, returns empty
   CheckEquals('', StringWithFirstWordDeleted('HELLO'), 'single word');

   // Normal two-word case
   CheckEquals('WORLD', StringWithFirstWordDeleted('HELLO WORLD'), 'two words');

   // Three words — only the first word is deleted
   CheckEquals('TWO THREE', StringWithFirstWordDeleted('ONE TWO THREE'), 'three words');

   // Multiple spaces between words — collapses to the next non-space token
   CheckEquals('WORLD', StringWithFirstWordDeleted('HELLO   WORLD'), 'multiple spaces between words');

   // Leading space — the first "word" is empty (chars before the first space),
   // so everything after the first space is returned
   CheckEquals('HELLO WORLD', StringWithFirstWordDeleted(' HELLO WORLD'), 'leading space');

   // String is only spaces — no non-space token follows any space, so
   // the loop empties the string and returns empty
   CheckEquals('', StringWithFirstWordDeleted('   '), 'only spaces');
end;

// ---------------------------------------------------------------------------
// StringHasNumber -- true if the string contains at least one 0-9 digit.
// Explicit empty-string guard returns false.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringHasNumber;
begin
   BeginTest('Test_StringHasNumber');

   // Empty string returns false (explicit guard)
   CheckFalse(StringHasNumber(''), 'empty string');

   // Positive: a digit anywhere
   CheckTrue(StringHasNumber('599'), 'all digits (RST shape)');
   CheckTrue(StringHasNumber('A1C'), 'digit in the middle (mixed)');
   CheckTrue(StringHasNumber('K4'), 'trailing digit');
   CheckTrue(StringHasNumber('3ABC'), 'leading digit');

   // Negative: no digit
   CheckFalse(StringHasNumber('ABC'), 'letters only');
   CheckFalse(StringHasNumber('   '), 'spaces only');
   CheckFalse(StringHasNumber('-/.'), 'punctuation only');
end;

// ---------------------------------------------------------------------------
// StringHasLetters -- true if the string contains at least one A-Z letter.
// Case-insensitive: the function UpCase()s each char before the range test,
// so lowercase letters also count.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringHasLetters;
begin
   BeginTest('Test_StringHasLetters');

   // Empty string returns false (zero-iteration loop)
   CheckFalse(StringHasLetters(''), 'empty string');

   // Positive: an uppercase or lowercase letter anywhere
   CheckTrue(StringHasLetters('ABC'), 'uppercase letters');
   CheckTrue(StringHasLetters('abc'), 'lowercase letters (UpCase-folded)');
   CheckTrue(StringHasLetters('12A'), 'letter in the middle (mixed)');
   CheckTrue(StringHasLetters('599x'), 'trailing lowercase letter');

   // Negative: no letters
   CheckFalse(StringHasLetters('123'), 'digits only');
   CheckFalse(StringHasLetters('1-2'), 'digits and dash');
   CheckFalse(StringHasLetters('   '), 'spaces only');
end;

// ---------------------------------------------------------------------------
// StringHasLowerCase -- true if the string contains at least one a-z char.
// Uppercase-only strings return false (used to detect un-normalized input).
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StringHasLowerCase;
begin
   BeginTest('Test_StringHasLowerCase');

   // Empty string returns false
   CheckFalse(StringHasLowerCase(''), 'empty string');

   // Positive: a lowercase letter anywhere
   CheckTrue(StringHasLowerCase('abc'), 'all lowercase');
   CheckTrue(StringHasLowerCase('Kx4'), 'one lowercase among upper/digit');

   // Negative: no lowercase
   CheckFalse(StringHasLowerCase('ABC'), 'uppercase only');
   CheckFalse(StringHasLowerCase('123'), 'digits only');
   CheckFalse(StringHasLowerCase('K4A-1'), 'uppercase callsign shape');
end;

// ---------------------------------------------------------------------------
// tCharIsNumbers -- single-char digit test (c in ['0'..'9']).
// Underlies StringIsAllNumbers / StringHasNumber, so it is pinned directly.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_tCharIsNumbers;
begin
   BeginTest('Test_tCharIsNumbers');

   // Positive: every digit
   CheckTrue(tCharIsNumbers('0'), 'zero');
   CheckTrue(tCharIsNumbers('9'), 'nine');
   CheckTrue(tCharIsNumbers('5'), 'five');

   // Negative, including chars adjacent to '0'..'9' in ASCII
   CheckFalse(tCharIsNumbers('A'), 'letter');
   CheckFalse(tCharIsNumbers(' '), 'space');
   CheckFalse(tCharIsNumbers('-'), 'dash');
   CheckFalse(tCharIsNumbers('/'), 'slash (ASCII 47, just below 0)');
   CheckFalse(tCharIsNumbers(':'), 'colon (ASCII 58, just above 9)');
end;

// ---------------------------------------------------------------------------
// tCharIsAlphaNumericOrDash -- single-char callsign-shape test:
// c in ['0'..'9'] or ['A'..'Z'] or ['-'].  UPPERCASE ONLY (no a-z).
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_tCharIsAlphaNumericOrDash;
begin
   BeginTest('Test_tCharIsAlphaNumericOrDash');

   // Positive: uppercase letters, digits, dash
   CheckTrue(tCharIsAlphaNumericOrDash('A'), 'uppercase A');
   CheckTrue(tCharIsAlphaNumericOrDash('Z'), 'uppercase Z');
   CheckTrue(tCharIsAlphaNumericOrDash('0'), 'digit 0');
   CheckTrue(tCharIsAlphaNumericOrDash('9'), 'digit 9');
   CheckTrue(tCharIsAlphaNumericOrDash('-'), 'dash');

   // Negative: lowercase is NOT accepted, plus other punctuation/space
   CheckFalse(tCharIsAlphaNumericOrDash('a'), 'lowercase a rejected');
   CheckFalse(tCharIsAlphaNumericOrDash('z'), 'lowercase z rejected');
   CheckFalse(tCharIsAlphaNumericOrDash(' '), 'space');
   CheckFalse(tCharIsAlphaNumericOrDash('/'), 'slash');
   CheckFalse(tCharIsAlphaNumericOrDash('.'), 'dot');
end;

// ---------------------------------------------------------------------------
// StrComp -- returns Ord(first differing byte of Str1) - Ord(same of Str2),
// comparing to and including the NUL.  NOT normalized to -1/0/+1: callers use
// only the sign, but the magnitude is pinned here so a rewrite cannot quietly
// change what "difference" means.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StrComp;
begin
   BeginTest('Test_StrComp');

   // Equal, including both-empty
   CheckEquals(0, StrComp('ABC', 'ABC'), 'equal strings');
   CheckEquals(0, StrComp('', ''), 'both empty');
   CheckEquals(0, StrComp('K4A-1234', 'K4A-1234'), 'equal callsign shape');

   // Same length, one byte differs -- the difference IS the byte difference
   CheckEquals(-1, StrComp('ABC', 'ABD'), 'C(67) - D(68)');
   CheckEquals(1, StrComp('ABD', 'ABC'), 'D(68) - C(67)');
   CheckEquals(-3, StrComp('ABC', 'ABF'), 'C(67) - F(70)');

   // Prefix cases stop at Str1's NUL, so the difference is 0 - Ord(next byte)
   CheckEquals(-67, StrComp('AB', 'ABC'), 'prefix shorter: #0 - C(67)');
   CheckEquals(67, StrComp('ABC', 'AB'), 'prefix longer: C(67) - #0');

   // Empty against non-empty
   CheckEquals(-65, StrComp('', 'A'), 'empty vs A: #0 - A(65)');
   CheckEquals(65, StrComp('A', ''), 'A vs empty: A(65) - #0');

   // Case sensitive -- 'a'(97) - 'A'(65) = 32.  This is why callers uppercase
   // first; StrComp itself does no folding.
   CheckEquals(32, StrComp('a', 'A'), 'lowercase sorts after uppercase');
   CheckEquals(-32, StrComp('A', 'a'), 'uppercase sorts before lowercase');

   // First difference wins even when later bytes differ more
   CheckEquals(-1, StrComp('AZZZ', 'BAAA'), 'first byte decides');
end;

// ---------------------------------------------------------------------------
// StrComp -- bytes >= $80 compare UNSIGNED.  This matters: CTY.DAT and the
// language files carry codepage-specific high-bit bytes, and a signed compare
// would sort them before ASCII instead of after, silently reordering the
// prefix table the country lookup binary-searches.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StrComp_HighBitBytesAreUnsigned;
var
   hi, lo: array[0..3] of AnsiChar;
begin
   BeginTest('Test_StrComp_HighBitBytesAreUnsigned');

   hi[0] := AnsiChar($E1);  hi[1] := #0;
   lo[0] := 'A';            lo[1] := #0;   // 'A' = $41

   CheckEquals(160, StrComp(@hi[0], @lo[0]), '$E1(225) - A(65) -- unsigned');
   CheckEquals(-160, StrComp(@lo[0], @hi[0]), 'A(65) - $E1(225) -- unsigned');

   // $FF is the largest byte, not -1
   hi[0] := AnsiChar($FF);  hi[1] := #0;
   CheckEquals(255, StrComp(@hi[0], ''), '$FF(255) - #0 -- unsigned');
end;

// ---------------------------------------------------------------------------
// StrUpper -- in place, ASCII 'a'..'z' ONLY.  Everything else, including every
// byte >= $80, is left untouched.  That restriction is deliberate and load
// bearing: uCTYDAT and MainUnit run it over buffers that may hold CP1251 or
// CP1250 text, where a locale-aware uppercase would corrupt the bytes.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_StrUpper;
var
   buf: array[0..31] of AnsiChar;

   procedure Upper(const src: AnsiString);
   begin
      FillChar(buf, SizeOf(buf), 0);
      if src <> '' then
         begin
         Move(src[1], buf[0], Length(src));
         end;
      StrUpper(@buf[0]);
   end;

begin
   BeginTest('Test_StrUpper');

   Upper('abc');
   CheckEquals('ABC', AnsiString(PAnsiChar(@buf[0])), 'all lowercase');

   Upper('ABC');
   CheckEquals('ABC', AnsiString(PAnsiChar(@buf[0])), 'already uppercase is unchanged');

   Upper('K4a-1234');
   CheckEquals('K4A-1234', AnsiString(PAnsiChar(@buf[0])), 'mixed callsign, digits and dash survive');

   Upper('');
   CheckEquals('', AnsiString(PAnsiChar(@buf[0])), 'empty string');

   Upper('a b c');
   CheckEquals('A B C', AnsiString(PAnsiChar(@buf[0])), 'spaces survive');

   // The two bytes flanking 'a'..'z' in ASCII must NOT be touched:
   // '`' is $60 (one below 'a'), '{' is $7B (one above 'z').
   Upper('`az{');
   CheckEquals('`AZ{', AnsiString(PAnsiChar(@buf[0])), 'range boundaries are exclusive');
end;

procedure TUtilsTextTests.Test_StrUpper_LeavesNonAsciiAlone;
var
   buf: array[0..7] of AnsiChar;
begin
   BeginTest('Test_StrUpper_LeavesNonAsciiAlone');

   // $E0..$FF is lowercase Cyrillic in CP1251.  The asm compared UNSIGNED, so
   // these are above 'z' and skipped.  A rewrite that used a signed compare, or
   // a locale-aware UpCase, would rewrite these bytes -- and CTY.DAT would stop
   // matching.
   buf[0] := AnsiChar($E0);
   buf[1] := AnsiChar($FF);
   buf[2] := AnsiChar($80);
   buf[3] := 'a';
   buf[4] := #0;

   StrUpper(@buf[0]);

   CheckEquals($E0, Ord(buf[0]), '$E0 untouched');
   CheckEquals($FF, Ord(buf[1]), '$FF untouched');
   CheckEquals($80, Ord(buf[2]), '$80 untouched');
   CheckEquals(Ord('A'), Ord(buf[3]), 'ASCII in the same buffer still folds');
end;

// ---------------------------------------------------------------------------
// Suite entry point
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.RunAllTests;
begin
   Test_StringIsAllNumbers;
   Test_StringIsAllNumbersOrSpaces;
   Test_StringIsAllNumbersOrDecimal;
   Test_StringIsAllAlphanumericOrDash;
   Test_StringWithFirstWordDeleted;

   // Issue #1035 -- exchange-field classification predicates
   Test_StringHasNumber;
   Test_StringHasLetters;
   Test_StringHasLowerCase;
   Test_tCharIsNumbers;
   Test_tCharIsAlphaNumericOrDash;

   // Asm eradication
   Test_StrComp;
   Test_StrComp_HighBitBytesAreUnsigned;
   Test_StrUpper;
   Test_StrUpper_LeavesNonAsciiAlone;
end;

end.
