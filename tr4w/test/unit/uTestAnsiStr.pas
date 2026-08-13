unit uTestAnsiStr;

{
  Tests for uAnsiStr.pas -- the five PAnsiChar routines TR4W owns rather than
  borrows from System.AnsiStrings (which FPC does not have).

  These are CHARACTERIZATION tests in the same sense as uTestUtilsText's StrComp
  suite: they pin System.AnsiStrings' documented behaviour, so that "we replaced
  the RTL call with our own" has something that can actually say no.  The call
  sites are not incidental -- StrPos and StrPCopy sit under Cabrillo export
  (PostUnit) and config parsing (uCFG), both of which the golden corpus checks
  byte-for-byte, but only for the paths the corpus happens to exercise.

  The three edge cases worth stating, because each is a silent-wrong-answer if
  got backwards rather than a crash:

    StrPos with an EMPTY needle returns the haystack, not nil.  A caller
    searching for a value it never set would otherwise take the "not found"
    branch and look correct while being wrong.

    StrComp compares BYTES, unsigned.  AnsiChar is signed on some targets, which
    would order high-bit characters backwards -- and the non-English builds are
    full of them.

    StrPLCopy's MaxLen counts TEXT, not the terminator, so the buffer must hold
    MaxLen + 1.  Off by one here is a buffer overrun, not a wrong string.
}

interface

uses
   uTR4WTestFramework;

type
   TAnsiStrTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_StrLen;
      procedure Test_StrComp;
      procedure Test_StrComp_HighBitBytesAreUnsigned;
      procedure Test_StrPos;
      procedure Test_StrPos_EmptyNeedleReturnsHaystack;
      procedure Test_StrPCopy;
      procedure Test_StrPLCopy;
      procedure Test_StrPLCopy_TruncatesAndTerminates;
   end;

implementation

uses
   uAnsiStr;

procedure TAnsiStrTests.RunAllTests;
begin
   Test_StrLen;
   Test_StrComp;
   Test_StrComp_HighBitBytesAreUnsigned;
   Test_StrPos;
   Test_StrPos_EmptyNeedleReturnsHaystack;
   Test_StrPCopy;
   Test_StrPLCopy;
   Test_StrPLCopy_TruncatesAndTerminates;
end;

// ---------------------------------------------------------------------------
// StrLen
// ---------------------------------------------------------------------------

procedure TAnsiStrTests.Test_StrLen;
var
   buf: array[0..15] of AnsiChar;
begin
   BeginTest('Test_StrLen');

   CheckEquals(0, Integer(uAnsiStr.StrLen(nil)), 'nil is 0, not a fault');

   buf := 'ABC'#0'XYZ';
   CheckEquals(3, Integer(uAnsiStr.StrLen(@buf[0])), 'stops at the terminator');

   buf[0] := #0;
   CheckEquals(0, Integer(uAnsiStr.StrLen(@buf[0])), 'empty string');
end;

// ---------------------------------------------------------------------------
// StrComp
// ---------------------------------------------------------------------------

procedure TAnsiStrTests.Test_StrComp;
var
   a, b: array[0..15] of AnsiChar;
begin
   BeginTest('Test_StrComp');

   a := 'N4AF'#0;
   b := 'N4AF'#0;
   CheckEquals(0, uAnsiStr.StrComp(@a[0], @b[0]), 'identical is exactly 0');

   a := 'N4AE'#0;
   b := 'N4AF'#0;
   CheckTrue(uAnsiStr.StrComp(@a[0], @b[0]) < 0, 'E sorts before F');
   CheckTrue(uAnsiStr.StrComp(@b[0], @a[0]) > 0, 'and the reverse is positive');

   // A prefix is LESS than the longer string: the shorter one hits #0 first.
   a := 'NY4'#0;
   b := 'NY4I'#0;
   CheckTrue(uAnsiStr.StrComp(@a[0], @b[0]) < 0, 'prefix sorts before the longer string');

   a[0] := #0;
   b[0] := #0;
   CheckEquals(0, uAnsiStr.StrComp(@a[0], @b[0]), 'two empty strings are equal');
end;

procedure TAnsiStrTests.Test_StrComp_HighBitBytesAreUnsigned;
var
   a, b: array[0..7] of AnsiChar;
begin
   BeginTest('Test_StrComp_HighBitBytesAreUnsigned');

   // #200 must compare GREATER than 'A' (#65).  If AnsiChar is treated as a
   // signed byte, #200 reads as -56 and the order silently inverts -- which
   // would mis-sort every accented callsign in the non-English builds.
   a[0] := AnsiChar(200); a[1] := #0;
   b[0] := 'A';           b[1] := #0;
   CheckTrue(uAnsiStr.StrComp(@a[0], @b[0]) > 0, '#200 > #65 (unsigned)');
   CheckTrue(uAnsiStr.StrComp(@b[0], @a[0]) < 0, 'and the reverse');
end;

// ---------------------------------------------------------------------------
// StrPos
// ---------------------------------------------------------------------------

procedure TAnsiStrTests.Test_StrPos;
var
   hay, needle: array[0..31] of AnsiChar;
   found: PAnsiChar;
begin
   BeginTest('Test_StrPos');

   hay    := 'CQ TEST NY4I'#0;
   needle := 'TEST'#0;
   found := uAnsiStr.StrPos(@hay[0], @needle[0]);
   CheckTrue(found <> nil, 'substring is found');
   CheckEquals(3, Integer(found - PAnsiChar(@hay[0])), 'at the right offset');

   needle := 'CQ'#0;
   found := uAnsiStr.StrPos(@hay[0], @needle[0]);
   CheckEquals(0, Integer(found - PAnsiChar(@hay[0])), 'match at the very start');

   needle := 'NY4I'#0;
   found := uAnsiStr.StrPos(@hay[0], @needle[0]);
   CheckEquals(8, Integer(found - PAnsiChar(@hay[0])), 'match at the very end');

   needle := 'W1AW'#0;
   CheckTrue(uAnsiStr.StrPos(@hay[0], @needle[0]) = nil, 'absent substring is nil');

   // A needle longer than the haystack must not run off the end.
   needle := 'CQ TEST NY4I EXTRA'#0;
   CheckTrue(uAnsiStr.StrPos(@hay[0], @needle[0]) = nil, 'needle longer than haystack');

   CheckTrue(uAnsiStr.StrPos(nil, @needle[0]) = nil, 'nil haystack is nil, not a fault');
   CheckTrue(uAnsiStr.StrPos(@hay[0], nil) = nil, 'nil needle is nil, not a fault');
end;

procedure TAnsiStrTests.Test_StrPos_EmptyNeedleReturnsHaystack;
var
   hay, needle: array[0..15] of AnsiChar;
begin
   BeginTest('Test_StrPos_EmptyNeedleReturnsHaystack');

   hay := 'ABC'#0;
   needle[0] := #0;

   // Matches System.AnsiStrings: an empty needle occurs immediately.
   CheckTrue(uAnsiStr.StrPos(@hay[0], @needle[0]) = PAnsiChar(@hay[0]),
      'empty needle returns the haystack, NOT nil');
end;

// ---------------------------------------------------------------------------
// StrPCopy / StrPLCopy
// ---------------------------------------------------------------------------

procedure TAnsiStrTests.Test_StrPCopy;
var
   buf: array[0..31] of AnsiChar;
   ret: PAnsiChar;
begin
   BeginTest('Test_StrPCopy');

   FillChar(buf, SizeOf(buf), $7F);
   ret := uAnsiStr.StrPCopy(@buf[0], 'NY4I');
   CheckTrue(ret = PAnsiChar(@buf[0]), 'returns the destination');
   CheckEquals(4, Integer(uAnsiStr.StrLen(@buf[0])), 'length copied');
   CheckEquals('NY4I', string(AnsiString(PAnsiChar(@buf[0]))), 'content copied');
   CheckEquals(0, Integer(Byte(buf[4])), 'terminated');

   FillChar(buf, SizeOf(buf), $7F);
   uAnsiStr.StrPCopy(@buf[0], '');
   CheckEquals(0, Integer(Byte(buf[0])), 'empty source still terminates');
end;

procedure TAnsiStrTests.Test_StrPLCopy;
var
   buf: array[0..31] of AnsiChar;
begin
   BeginTest('Test_StrPLCopy');

   FillChar(buf, SizeOf(buf), $7F);
   uAnsiStr.StrPLCopy(@buf[0], 'NY4I', 16);
   CheckEquals('NY4I', string(AnsiString(PAnsiChar(@buf[0]))), 'short source copied whole');
   CheckEquals(0, Integer(Byte(buf[4])), 'terminated');
end;

procedure TAnsiStrTests.Test_StrPLCopy_TruncatesAndTerminates;
var
   buf: array[0..31] of AnsiChar;
begin
   BeginTest('Test_StrPLCopy_TruncatesAndTerminates');

   FillChar(buf, SizeOf(buf), $7F);
   uAnsiStr.StrPLCopy(@buf[0], 'ABCDEFGH', 3);

   // MaxLen counts TEXT, so 3 characters plus a terminator at [3].
   CheckEquals(3, Integer(uAnsiStr.StrLen(@buf[0])), 'truncated to MaxLen');
   CheckEquals('ABC', string(AnsiString(PAnsiChar(@buf[0]))), 'the first MaxLen characters');
   CheckEquals(0, Integer(Byte(buf[3])), 'terminator lands at [MaxLen], not [MaxLen-1]');

   // Zero room is legal and must still terminate.
   FillChar(buf, SizeOf(buf), $7F);
   uAnsiStr.StrPLCopy(@buf[0], 'ABC', 0);
   CheckEquals(0, Integer(Byte(buf[0])), 'MaxLen 0 writes only the terminator');
end;

end.
