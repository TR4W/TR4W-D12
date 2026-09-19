unit uTestUtilsText;
{$I ..\..\src\tr4w.inc}

{
  Tests for utils_text.pas string predicate functions.

  Functions NOT tested here (easily replaced by Delphi 12 stdlib):
    UpperCase, StringHas, PostcedingString, PrecedingString,
    tPos, safeFloat.

  StrComp and StrUpper WERE tested here, and the tests came first: both were
  hand-written x86-32 assembly with no coverage at all, and they were load-bearing
  -- StrComp drove the CTY.DAT prefix search and every config-command lookup,
  StrUpper normalized callsigns and CTY records.  Those were CHARACTERIZATION
  tests: they were written against the assembly, run green against it, and only
  then was the assembly replaced with Pascal.  They pinned the exact return
  values, not merely the sign, so a "behaviour-preserving" rewrite had something
  that could actually say no.

  Both routines were deleted on 2026-09-15 with no production caller left, and
  their tests went with them.  CompareCharBuffer carries StrComp's job, and its
  tests below state each expected sign outright.

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

      (* THE FIXED-BUFFER HELPERS, WHICH HAD NO TESTS AT ALL UNTIL THEY MOVED.
        They lived in TF, and TF pulls the LCL and the config model in behind
        it, so tr4w_unit_tests could not link them. Being untestable was not a
        property of the code -- it was a property of where it was parked. *)
      procedure Test_SetCharBuffer_RoundTrips;
      procedure Test_SetCharBuffer_TruncatesAndTerminates;
      procedure Test_SetCharBuffer_EmptyStringGivesEmptyBuffer;

      (* The operator login (MainUnit menu_login) wrote CurrentOperator with a
        fixed 6-byte Move: no terminator, no room for a 7-character call. It
        cannot be linked here; the field's type and the helper it now uses
        can, and this pins what the login relies on. *)
      procedure Test_SetCharBuffer_OperatorLogin;
      procedure Test_CharBufferText_StopsAtNul;
      procedure Test_CharBufferText_IgnoresBytesPastTheNul;
      procedure Test_CharBufferSlice_ByPosition;
      procedure Test_CharBufferSlice_StopsAtNul;
      procedure Test_CharBufferSlice_OutOfRangeIsEmpty;

      (* CompareCharBuffer is StrComp WITHOUT THE POINTERS. It was once tested
        against StrComp; StrComp is deleted, so each case states the sign it
        must give. The sign is the CTY prefix table's sort order, not just
        equality. *)
      procedure Test_CompareCharBuffer_SignsForRealPrefixes;
      procedure Test_CompareCharBuffer_Ordering;
      procedure Test_CompareCharBuffer_HighBitBytesAreUnsigned;
      procedure Test_CompareCharBuffer_PrefixIsLess;
      procedure Test_LeadingInt_ParsesAndStops;
      procedure Test_LeadingInt_NegativeAndDegenerate;
      procedure Test_LeadingInt_MatchesTheRoutineItReplaced;
      procedure Test_SetCharBufferBytes_CopiesBytesUnchanged;
      procedure Test_SetCharBufferBytes_TruncatesAndTerminates;
      procedure Test_SameTextAscii;
      procedure Test_CharBufferBytes_ReadsBytesUnchanged;

      (* SetShortStringFromBytes bounds the copy EnumerateLinesInFile used to do
        with an unbounded Move -- a line over 255 bytes wrote past the
        ShortString on the stack. *)
      procedure Test_SetShortStringFromBytes_CopiesALine;
      procedure Test_SetShortStringFromBytes_TruncatesAt255;
      procedure Test_SetShortStringFromBytes_ZeroesTheTail;
      procedure Test_SetShortStringFromBytes_OutOfRangeIsEmpty;
      procedure Test_AnsiStringFromBytes_Slices;
      procedure Test_AnsiStringFromBytes_OutOfRangeIsEmpty;
      procedure Test_AnsiStringFromBytes_KeepsHighBytes;
   end;

implementation

uses
   VC,           (* OperatorType only -- FIRST, so nothing it declares shadows the rest *)
   SysUtils,     (* TBytes -- the line tests; BEFORE utils_text, so its routines win *)
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
// Suite entry point
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// SetCharBuffer / CharBufferText / CharBufferSlice
//
// These replace StrPCopy / StrPLCopy / StrLCopy / StrPas and the
// PAnsiChar(@buf[0]) idiom.  The shim forms took a destination, a byte count
// and a conversion as three arguments that had to agree BY HAND; an open array
// carries its own High(), so the count cannot disagree with the destination.
// ---------------------------------------------------------------------------

procedure TUtilsTextTests.Test_SetCharBuffer_RoundTrips;
var
   buf: array[0..31] of AnsiChar;
begin
   BeginTest('SetCharBuffer then CharBufferText returns the same text');
   SetCharBuffer(buf, 'NY4I');
   CheckEquals('NY4I', CharBufferText(buf), 'plain ASCII');

   SetCharBuffer(buf, 'C:\tr4w\dom\FL.dom');
   CheckEquals('C:\tr4w\dom\FL.dom', CharBufferText(buf), 'a path with separators');
end;

procedure TUtilsTextTests.Test_SetCharBuffer_TruncatesAndTerminates;
var
   buf: array[0..7] of AnsiChar;
begin
   BeginTest('SetCharBuffer bounds by the BUFFER, and always terminates');
   (* High(buf) is 7, so seven characters plus the NUL.  This is the whole
     reason the helper exists: the old form was told the size by the CALLER
     and nothing checked that the number belonged to the array named. *)
   SetCharBuffer(buf, 'ABCDEFGHIJKL');
   CheckEquals('ABCDEFG', CharBufferText(buf), 'truncated to High(buf)');
   CheckEquals(0, Ord(buf[7]), 'the last byte is the terminator');
end;

procedure TUtilsTextTests.Test_SetCharBuffer_EmptyStringGivesEmptyBuffer;
var
   buf: array[0..15] of AnsiChar;
begin
   BeginTest('SetCharBuffer with an empty string');
   SetCharBuffer(buf, 'SOMETHING');
   SetCharBuffer(buf, '');
   CheckEquals('', CharBufferText(buf), 'empties what was there');
   CheckEquals(0, Ord(buf[0]), 'byte 0 is the terminator');
end;

procedure TUtilsTextTests.Test_SetCharBuffer_OperatorLogin;
var
   op: OperatorType;
begin
   BeginTest('SetCharBuffer on an OperatorType: whole calls, no stale tail');

   (* The width the login prompt is capped at. If OperatorType is ever
     widened, this changes with it and the prompt follows automatically. *)
   CheckEquals(10, High(op), 'OperatorType holds ten characters and a NUL');

   SetCharBuffer(op, 'VP2E/W1ABC');
   CheckEquals('VP2E/W1ABC', CharBufferText(op), 'a 10-character call survives whole');

   (* THE DEFECT: a 6-byte Move over that left 'W1ABCD' + '1ABC' with no NUL
     until byte 10, so it read back as 'W1ABCD1ABC'. *)
   SetCharBuffer(op, 'W1ABCD');
   CheckEquals('W1ABCD', CharBufferText(op), 'a 6-character call after a longer one');

   SetCharBuffer(op, 'OH2ABCD');
   CheckEquals('OH2ABCD', CharBufferText(op), 'a 7-character call is not cut to 6');

   SetCharBuffer(op, 'N4AF');
   CheckEquals('N4AF', CharBufferText(op), 'a 4-character call after a 7-character one');
   CheckEquals(0, Ord(op[4]), 'terminated right after the call');

   SetCharBuffer(op, 'VP2E/W1ABC/P');
   CheckEquals('VP2E/W1ABC', CharBufferText(op), 'an over-long call is cut to High(op)');
   CheckEquals(0, Ord(op[10]), 'and the last byte is still the terminator');
end;

procedure TUtilsTextTests.Test_CharBufferText_StopsAtNul;
var
   buf: array[0..15] of AnsiChar;
   i: integer;
begin
   BeginTest('CharBufferText stops at the NUL, not at the end of the array');
   for i := Low(buf) to High(buf) do
      begin
      buf[i] := 'X';
      end;
   buf[3] := #0;
   CheckEquals('XXX', CharBufferText(buf), 'three characters then the NUL');
end;

procedure TUtilsTextTests.Test_CharBufferText_IgnoresBytesPastTheNul;
var
   buf: array[0..15] of AnsiChar;
   i: integer;
begin
   (* THE TRAP CLAUDE.md NAMES: AnsiString(aFixedCharArray) takes the PADDING
     too -- every byte to the end of the array, stale bytes included.  A path
     built that way carries rubbish after it and reads as a missing file. *)
   BeginTest('CharBufferText ignores stale bytes after the terminator');
   for i := Low(buf) to High(buf) do
      begin
      buf[i] := '#';
      end;
   SetCharBuffer(buf, 'AB');
   buf[5] := 'Z';                  // stale byte beyond the NUL
   CheckEquals('AB', CharBufferText(buf), 'only up to the NUL');
end;

procedure TUtilsTextTests.Test_CharBufferSlice_ByPosition;
var
   buf: array[0..63] of AnsiChar;
begin
   BeginTest('CharBufferSlice takes a slice by offset and length');
   SetCharBuffer(buf, 'DX de W3LPL:  14025.0  NY4I');
   CheckEquals('W3LPL', CharBufferSlice(buf, 6, 5), 'the spotter');
   CheckEquals('NY4I',  CharBufferSlice(buf, 23, 4), 'the spotted call');
   CheckEquals('D',     CharBufferSlice(buf, 0, 1), 'a single character');
end;

procedure TUtilsTextTests.Test_CharBufferSlice_StopsAtNul;
var
   buf: array[0..63] of AnsiChar;
begin
   (* The buffer is a whole cluster LINE and the slice is cut to a COLUMN
     width, so the requested length routinely runs past the text.  StrLCopy
     stopped at the NUL and so does this. *)
   BeginTest('CharBufferSlice stops at the NUL even when asked for more');
   SetCharBuffer(buf, 'AB');
   CheckEquals('B', CharBufferSlice(buf, 1, 30), 'asked for 30, text has 1');
   CheckEquals('AB', CharBufferSlice(buf, 0, 30), 'asked for 30, text has 2');
end;

procedure TUtilsTextTests.Test_CharBufferSlice_OutOfRangeIsEmpty;
var
   buf: array[0..15] of AnsiChar;
begin
   BeginTest('CharBufferSlice refuses a start or length outside the buffer');
   SetCharBuffer(buf, 'ABCDEF');
   CheckEquals('', CharBufferSlice(buf, 99, 4), 'start past High(buf)');
   CheckEquals('', CharBufferSlice(buf, -1, 4), 'negative start');
   CheckEquals('', CharBufferSlice(buf, 2, 0),  'zero length');
   CheckEquals('', CharBufferSlice(buf, 2, -5), 'negative length');
end;


// ---------------------------------------------------------------------------
// CompareCharBuffer -- StrComp's answer without StrComp's pointers.
//
// These buffers are the CTY.DAT prefix table, which may hold
// CP1251/CP1250.  That is why the comparison stays BYTES: decoding them
// as UTF-8 would change which prefixes match, and the sign defines the order
// the binary search in ctyFindCallsign depends on.
// ---------------------------------------------------------------------------


(* ===========================================================================
  LeadingInt -- THE PARSE TF.PCharToInt DID, NOW IN A UNIT THAT CAN BE TESTED.

  It is lenient on purpose: the fields it reads are slices of fixed-width
  records that may be padded or truncated, so a partial number is the answer
  and there is no failure to report. Everything below pins a property the two
  deleted copies had, because a caller two units away depends on each of them:
  cty.dat's UTC-offset column arrives as "-5.0" and must give -5, and
  logstuff's exchange tokeniser hands it a 32-byte buffer with one number in
  the front of it. *)
procedure TUtilsTextTests.Test_LeadingInt_ParsesAndStops;
begin
   BeginTest('LeadingInt reads the leading digits and stops at the first that is not');

   CheckEquals(0,     LeadingInt('0'),        'a single zero');
   CheckEquals(7,     LeadingInt('7'),        'one digit');
   CheckEquals(1234,  LeadingInt('1234'),     'several');
   CheckEquals(59,    LeadingInt('59ABC'),    'stops at a letter');
   CheckEquals(5,     LeadingInt('5.0'),      'stops at a decimal point -- cty.dat''s UTC column');
   CheckEquals(14,    LeadingInt('14:  27:'), 'stops at a colon -- the same file''s zone columns');
   CheckEquals(3,     LeadingInt('3 '),       'stops at a blank');
   CheckEquals(42,    LeadingInt('42' + #0 + '99'), 'stops at a NUL, and ignores what follows');
   CheckEquals(7,     LeadingInt('007'),      'leading zeros');
end;

procedure TUtilsTextTests.Test_LeadingInt_NegativeAndDegenerate;
begin
   BeginTest('LeadingInt on a minus sign, and on text with no number at all');

   CheckEquals(-5,   LeadingInt('-5.0'),   'a negative UTC offset');
   CheckEquals(-123, LeadingInt('-123'),   'a negative integer');
   CheckEquals(0,    LeadingInt('-'),      'a lone minus is 0, not an error');
   CheckEquals(0,    LeadingInt(''),       'the empty string');
   CheckEquals(0,    LeadingInt('ABC'),    'no digits at all');

   (* IT DOES NOT SKIP LEADING BLANKS, and that is deliberate rather than an
     oversight -- the routine it replaces did not either, and a caller handing
     it a right-aligned column would otherwise silently start working. *)
   CheckEquals(0, LeadingInt('  42'), 'a leading blank stops it before any digit');

   (* '+' is not accepted, for the same reason. *)
   CheckEquals(0, LeadingInt('+42'), 'a leading plus is not a sign here');

   (* A minus in the middle is just a terminator. *)
   CheckEquals(12, LeadingInt('12-34'), 'the second minus ends the number');
end;

(* The two deleted copies walked a PAnsiChar with two labels and two gotos.
  This is that algorithm restated over the inputs the live call sites actually
  produce -- a fixed AnsiChar buffer, read through CharBufferText, which is
  exactly what both callers now do. *)
procedure TUtilsTextTests.Test_LeadingInt_MatchesTheRoutineItReplaced;
var
   buf: array[0..31] of AnsiChar;
begin
   BeginTest('LeadingInt over a fixed buffer, the way both callers reach it');

   SetCharBuffer(buf, '-5.0');
   CheckEquals(-5 * 60, LeadingInt(CharBufferText(buf)) * 60,
               'cty.dat UTC offset in minutes, as uCTYDAT computes it');

   SetCharBuffer(buf, '599');
   CheckEquals(599, LeadingInt(CharBufferText(buf)),
               'an RST out of logstuff''s exchange tokeniser');

   SetCharBuffer(buf, '');
   CheckEquals(0, LeadingInt(CharBufferText(buf)),
               'an empty buffer');
end;


(* ===========================================================================
  SetCharBufferBytes -- StrPLCopy's CONTRACT, carried over from uAnsiStr's
  tests when that unit was deleted.

  The distinction from SetCharBuffer is the whole reason it exists:
  SetCharBuffer UTF-8-ENCODES, and the multi-op server password is compared
  byte for byte against what a client sends, so re-encoding it would change
  the wire format and break an existing station. *)
procedure TUtilsTextTests.Test_SetCharBufferBytes_CopiesBytesUnchanged;
var
   buf: array[0..31] of AnsiChar;
begin
   BeginTest('SetCharBufferBytes copies the bytes it is given and terminates');

   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, 'NY4I');
   CheckEquals('NY4I', CharBufferText(buf), 'a short source is copied whole');
   CheckEquals(0, Integer(Byte(buf[4])), 'and terminated');

   (* THE POINT OF THE ROUTINE: a byte above $7F goes in as itself. The same
     text through SetCharBuffer would arrive as two UTF-8 bytes. *)
   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, AnsiString('A') + AnsiChar($E9) + AnsiString('B'));
   CheckEquals($41, Integer(Byte(buf[0])), 'the A');
   CheckEquals($E9, Integer(Byte(buf[1])), 'the high byte is UNCHANGED, not re-encoded');
   CheckEquals($42, Integer(Byte(buf[2])), 'the B');
   CheckEquals(0,   Integer(Byte(buf[3])), 'terminated after three bytes');
end;

procedure TUtilsTextTests.Test_SetCharBufferBytes_TruncatesAndTerminates;
var
   buf: array[0..3] of AnsiChar;
   one: array[0..0] of AnsiChar;
begin
   BeginTest('SetCharBufferBytes truncates to the buffer rather than overrunning');

   (* High(buf) is 3, so three bytes of text and a terminator at [3] -- the
     same rule StrPLCopy was given at every call site (High(dest)). *)
   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, 'ABCDEFGH');
   CheckEquals('ABC', CharBufferText(buf), 'the first High(buf) bytes');
   CheckEquals(0, Integer(Byte(buf[3])), 'terminator at [High], not past it');

   (* A one-element buffer has room for the terminator and nothing else, and
     must still be terminated rather than left as it was. *)
   FillChar(one, SizeOf(one), $7F);
   SetCharBufferBytes(one, 'ABC');
   CheckEquals(0, Integer(Byte(one[0])), 'zero room still terminates');

   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, '');
   CheckEquals('', CharBufferText(buf), 'an empty source gives an empty buffer');
   CheckEquals(0, Integer(Byte(buf[0])), 'terminated at the start');
end;


(* SameTextAscii exists because SysUtils.SameText takes AnsiString -- SysUtils
  is compiled without UnicodeStrings -- so calling it from this program
  narrows BOTH arguments at the call. It is an ASCII fold, like this unit's
  UpperCase, because what it compares is config-file vocabulary. *)
procedure TUtilsTextTests.Test_SameTextAscii;
begin
   BeginTest('SameTextAscii folds ASCII case and nothing else');

   CheckTrue (SameTextAscii('SERIAL 1', 'serial 1'), 'the config vocabulary, folded');
   CheckTrue (SameTextAscii('None', 'NONE'),         'mixed case');
   CheckTrue (SameTextAscii('', ''),                 'two empty strings');
   CheckFalse(SameTextAscii('SERIAL 1', 'SERIAL 2'), 'a real difference');
   CheckFalse(SameTextAscii('NONE', ''),             'empty matches only empty');
   CheckFalse(SameTextAscii('AB', 'ABC'),            'a prefix is not a match');

   (* ASCII ONLY, stated rather than assumed: a non-ASCII letter is compared
     by its bytes, so the two cases of it do NOT fold. That is deliberate --
     the tables this serves are ASCII, and a locale-aware fold is neither
     needed nor byte-stable. *)
   CheckFalse(SameTextAscii(WideChar($00C9), WideChar($00E9)),
              'E-acute does not fold to e-acute -- ASCII only, by design');
end;


(* CharBufferBytes is the mirror of SetCharBufferBytes: the buffer's bytes up
  to the first NUL, undecoded. It exists because cty.dat's country names are
  CP1251/CP1250, and CharBufferText would decode them as UTF-8 on the way to
  an ASCII comparison. *)
procedure TUtilsTextTests.Test_CharBufferBytes_ReadsBytesUnchanged;
var
   buf: array[0..7] of AnsiChar;
   got: AnsiString;
begin
   BeginTest('CharBufferBytes reads to the NUL and does not decode');

   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, 'NY4I');
   CheckEquals('NY4I', string(CharBufferBytes(buf)), 'a plain ASCII buffer');

   (* THE POINT OF IT: a byte above $7F comes back as itself. Through
     CharBufferText the same buffer is not valid UTF-8 at all. *)
   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, AnsiString('A') + AnsiChar($E9) + AnsiString('B'));
   got := CharBufferBytes(buf);
   CheckEquals(3, Length(got), 'three bytes back');
   CheckEquals($41, Integer(Byte(got[1])), 'the A');
   CheckEquals($E9, Integer(Byte(got[2])), 'the high byte, UNCHANGED');
   CheckEquals($42, Integer(Byte(got[3])), 'the B');

   (* It stops at the NUL, and an unterminated buffer stops at its end. *)
   FillChar(buf, SizeOf(buf), $7F);
   SetCharBufferBytes(buf, 'AB');
   buf[3] := 'X';
   CheckEquals('AB', string(CharBufferBytes(buf)), 'nothing past the terminator');

   FillChar(buf, SizeOf(buf), Ord('Z'));
   CheckEquals(8, Length(CharBufferBytes(buf)),
               'an unterminated buffer yields the whole buffer, not an overrun');

   FillChar(buf, SizeOf(buf), 0);
   CheckEquals('', string(CharBufferBytes(buf)), 'an empty buffer');
end;

(* THE SIGN, CASE BY CASE, AGAINST EXPLICIT EXPECTATIONS.

  This test used to compare CompareCharBuffer's sign with StrComp's. StrComp
  was deleted on 2026-09-15 with no production caller, and a reference that is
  itself gone cannot anchor anything -- so each pair states the sign it must
  give. That is strcmp order over unsigned bytes: the shorter of two prefixes
  sorts first, and the first differing byte decides. *)
procedure TUtilsTextTests.Test_CompareCharBuffer_SignsForRealPrefixes;
var
   a, b: array[0..13] of AnsiChar;

   procedure Sign(const s1, s2: string; const expected: integer; const label_: string);
   var
      got: integer;
   begin
      FillChar(a, SizeOf(a), 0);
      FillChar(b, SizeOf(b), 0);
      SetCharBuffer(a, s1);
      SetCharBuffer(b, s2);
      got := CompareCharBuffer(a, b);
      // The SIGN is the contract, not the magnitude.
      if got < 0 then
         begin
         got := -1;
         end
      else if got > 0 then
         begin
         got := 1;
         end;
      CheckEquals(expected, got, label_);
   end;

begin
   BeginTest('CompareCharBuffer gives strcmp''s sign for real prefixes');
   Sign('K',    'K',     0, 'K vs K');
   Sign('K',    'KH6',  -1, 'K vs KH6: the shorter prefix sorts first');
   Sign('KH6',  'K',     1, 'KH6 vs K');
   Sign('VE',   'VK',   -1, 'VE vs VK: E before K');
   Sign('VK',   'VE',    1, 'VK vs VE');
   Sign('',     'K',    -1, 'empty vs K');
   Sign('K',    '',      1, 'K vs empty');
   Sign('',     '',      0, 'empty vs empty');
   Sign('UA9',  'UA',    1, 'UA9 vs UA');
   Sign('3DA0', '3D2',   1, '3DA0 vs 3D2: A (65) after 2 (50)');
end;

procedure TUtilsTextTests.Test_CompareCharBuffer_Ordering;
var
   a, b: array[0..13] of AnsiChar;
begin
   BeginTest('CompareCharBuffer orders by byte value');
   SetCharBuffer(a, 'A');
   SetCharBuffer(b, 'B');
   Check(CompareCharBuffer(a, b) < 0, 'A sorts before B');
   Check(CompareCharBuffer(b, a) > 0, 'B sorts after A');
   SetCharBuffer(b, 'A');
   CheckEquals(0, CompareCharBuffer(a, b), 'A equals A');
end;

procedure TUtilsTextTests.Test_CompareCharBuffer_HighBitBytesAreUnsigned;
var
   a, b: array[0..13] of AnsiChar;
begin
   (* $80..$FF MUST SORT ABOVE ASCII.  AnsiChar is unsigned and the old
     StrComp returned Ord() - Ord(), so a CP1251 byte sorted above 'Z'.  If
     this ever came back SIGNED, the prefix table would sort differently and
     the binary search would stop finding those prefixes. *)
   BeginTest('CompareCharBuffer treats high-bit bytes as unsigned');
   FillChar(a, SizeOf(a), 0);
   FillChar(b, SizeOf(b), 0);
   a[0] := #$C0;          // a CP1251 letter
   b[0] := 'Z';
   Check(CompareCharBuffer(a, b) > 0, '$C0 sorts ABOVE Z');
   Check(CompareCharBuffer(b, a) < 0, 'Z sorts below $C0');
end;

procedure TUtilsTextTests.Test_CompareCharBuffer_PrefixIsLess;
var
   a, b: array[0..13] of AnsiChar;
   i: integer;
begin
   (* A buffer FULL to its last byte has no terminator inside it.  Reading
     past the end has to behave as the NUL did, or a 14-character prefix
     would compare against whatever followed it in memory. *)
   BeginTest('CompareCharBuffer handles a buffer with no room for a NUL');
   FillChar(a, SizeOf(a), 0);
   FillChar(b, SizeOf(b), 0);
   (* Filled BY INDEX, because SetCharBuffer deliberately cannot make a
     buffer with no terminator -- and that is exactly the case being
     tested. *)
   for i := 0 to 13 do
      begin
      a[i] := AnsiChar(Ord('A') + i);
      b[i] := AnsiChar(Ord('A') + i);
      end;
   CheckEquals(0, CompareCharBuffer(a, b), 'two full buffers are equal');
   b[13] := 'Z';
   Check(CompareCharBuffer(a, b) < 0, 'differing in the last byte');
end;

(* A file's bytes, for the line tests. *)
function TestBytes(const aText: AnsiString): TBytes;
var
   i: integer;
begin
   SetLength(Result, Length(aText));
   for i := 1 to Length(aText) do
      begin
      Result[i - 1] := Ord(aText[i]);
      end;
end;

procedure TUtilsTextTests.Test_SetShortStringFromBytes_CopiesALine;
var
   raw: TBytes;
   line: ShortString;
begin
   BeginTest('SetShortStringFromBytes copies one line out of a file''s bytes');
   raw := TestBytes('CQ TEST NY4I'#13#10'NEXT');
   SetShortStringFromBytes(line, raw, 0, 12);
   CheckEquals('CQ TEST NY4I', string(line), 'the first line');
   SetShortStringFromBytes(line, raw, 14, 4);
   CheckEquals('NEXT', string(line), 'the last line, which has no line break');
end;

procedure TUtilsTextTests.Test_SetShortStringFromBytes_TruncatesAt255;
var
   raw: TBytes;
   line: ShortString;
   i: integer;
begin
   (* THE DEFECT THIS REPLACES. A 300-byte line went to Move(..., 300) into a
     256-byte ShortString, and its length byte wrapped to 300 mod 256 = 44. *)
   BeginTest('SetShortStringFromBytes keeps the first 255 bytes of a longer line');
   SetLength(raw, 300);
   for i := 0 to 299 do
      begin
      raw[i] := Ord('A') + (i mod 26);
      end;
   SetShortStringFromBytes(line, raw, 0, 300);
   CheckEquals(255, Length(line), 'the length is 255, not 300 mod 256');
   CheckEquals(Ord('A'), Ord(line[1]), 'the first byte');
   CheckEquals(Ord('A') + (254 mod 26), Ord(line[255]), 'the 255th byte is the line''s 255th');
end;

procedure TUtilsTextTests.Test_SetShortStringFromBytes_ZeroesTheTail;
var
   raw: TBytes;
   line: ShortString;
begin
   (* TempString is reused line after line, so a short line follows a long one,
     and a callback reading the text as a C string needs a zero after it. *)
   BeginTest('SetShortStringFromBytes leaves zeros after the text');
   line := StringOfChar('X', 200);
   raw := TestBytes('AB');
   SetShortStringFromBytes(line, raw, 0, 2);
   CheckEquals('AB', string(line), 'the text');
   CheckEquals(0, Ord(line[3]), 'the byte after the text');
   CheckEquals(0, Ord(line[200]), 'where the longer line before it ended');
   CheckEquals(0, Ord(line[255]), 'the last byte');
end;

procedure TUtilsTextTests.Test_SetShortStringFromBytes_OutOfRangeIsEmpty;
var
   raw: TBytes;
   line: ShortString;
begin
   BeginTest('SetShortStringFromBytes reads nothing outside the bytes');
   raw := TestBytes('ABCDEF');
   SetShortStringFromBytes(line, raw, 99, 4);
   CheckEquals('', string(line), 'start past the end');
   SetShortStringFromBytes(line, raw, -1, 4);
   CheckEquals('', string(line), 'negative start');
   SetShortStringFromBytes(line, raw, 2, 0);
   CheckEquals('', string(line), 'zero length');
   SetShortStringFromBytes(line, raw, 4, 10);
   CheckEquals('EF', string(line), 'a length past the end stops at the end');
end;

procedure TUtilsTextTests.Test_AnsiStringFromBytes_Slices;
var
   raw: TBytes;
begin
   BeginTest('AnsiStringFromBytes takes a slice by position and length');
   raw := TestBytes('CQ TEST NY4I');
   CheckEquals('CQ', string(AnsiStringFromBytes(raw, 0, 2)), 'the first field');
   CheckEquals('TEST', string(AnsiStringFromBytes(raw, 3, 4)), 'a middle field');
   CheckEquals('NY4I', string(AnsiStringFromBytes(raw, 8, 99)), 'a length past the end stops at the end');
end;

procedure TUtilsTextTests.Test_AnsiStringFromBytes_OutOfRangeIsEmpty;
var
   raw: TBytes;
begin
   (* The cty.dat parser computes lengths in Cardinal arithmetic, where a
     negative result wraps. Handed here as an integer, it is below one. *)
   BeginTest('AnsiStringFromBytes reads nothing outside the bytes');
   raw := TestBytes('ABCDEF');
   CheckEquals('', string(AnsiStringFromBytes(raw, 99, 4)), 'start past the end');
   CheckEquals('', string(AnsiStringFromBytes(raw, -1, 4)), 'negative start');
   CheckEquals('', string(AnsiStringFromBytes(raw, 2, 0)),  'zero length');
   CheckEquals('', string(AnsiStringFromBytes(raw, 2, -3)), 'negative length');
end;

procedure TUtilsTextTests.Test_AnsiStringFromBytes_KeepsHighBytes;
var
   raw: TBytes;
   s: AnsiString;
begin
   (* cty.dat holds CP1251/CP1250 country names. The slice must be those bytes,
     not a decoding of them. *)
   BeginTest('AnsiStringFromBytes carries high bytes unchanged');
   SetLength(raw, 3);
   raw[0] := $C0;
   raw[1] := $41;
   raw[2] := $FF;
   s := AnsiStringFromBytes(raw, 0, 3);
   CheckEquals(3, Length(s), 'three bytes in, three out');
   CheckEquals($C0, Ord(s[1]), 'the first high byte');
   CheckEquals($FF, Ord(s[3]), 'the last high byte');
end;

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


   // The fixed-buffer helpers
   Test_SetCharBuffer_RoundTrips;
   Test_SetCharBuffer_TruncatesAndTerminates;
   Test_SetCharBuffer_EmptyStringGivesEmptyBuffer;
   Test_SetCharBuffer_OperatorLogin;
   Test_CharBufferText_StopsAtNul;
   Test_CharBufferText_IgnoresBytesPastTheNul;
   Test_CharBufferSlice_ByPosition;
   Test_CharBufferSlice_StopsAtNul;
   Test_CharBufferSlice_OutOfRangeIsEmpty;

   Test_CompareCharBuffer_SignsForRealPrefixes;
   Test_CompareCharBuffer_Ordering;
   Test_CompareCharBuffer_HighBitBytesAreUnsigned;
   Test_CompareCharBuffer_PrefixIsLess;
   Test_LeadingInt_ParsesAndStops;
   Test_LeadingInt_NegativeAndDegenerate;
   Test_LeadingInt_MatchesTheRoutineItReplaced;
   Test_SetCharBufferBytes_CopiesBytesUnchanged;
   Test_SetCharBufferBytes_TruncatesAndTerminates;
   Test_SameTextAscii;
   Test_CharBufferBytes_ReadsBytesUnchanged;

   Test_SetShortStringFromBytes_CopiesALine;
   Test_SetShortStringFromBytes_TruncatesAt255;
   Test_SetShortStringFromBytes_ZeroesTheTail;
   Test_SetShortStringFromBytes_OutOfRangeIsEmpty;
   Test_AnsiStringFromBytes_Slices;
   Test_AnsiStringFromBytes_OutOfRangeIsEmpty;
   Test_AnsiStringFromBytes_KeepsHighBytes;
end;

end.
