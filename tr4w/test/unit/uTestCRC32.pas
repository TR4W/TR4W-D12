unit uTestCRC32;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for uCRC32.GetCRC32.

  uCRC32 implements the standard CRC-32 (polynomial $EDB88320, initial
  $FFFFFFFF, output one's-complemented).  This is the same CRC used by
  PKZIP, Ethernet (IEEE 802.3), ITU-T V.42, PNG, and gzip.  It is also
  what TR4WServer uses for log/packet integrity, so a regression here
  would silently corrupt multi-op log synchronization.

  The implementation is hand-written x86 inline assembly (Crc32Next,
  Crc32Done, Crc32Initialization).  Phase 3 will need to replace those
  asm blocks with Pascal; these tests freeze the D7 behavior bit-exactly
  so the rewrite is provably equivalent.

  Reference vectors are from the published CRC-32 test suite -- see
  https://reveng.sourceforge.io/crc-catalogue/all.htm ("CRC-32/ISO-HDLC")
  and the standard "check" value for "123456789".
}

interface

uses
   SysUtils, uTR4WTestFramework, uCRC32, uTestBytePattern;

type
   TCRC32Tests = class(TTestCase)
   protected
      // Internal helper: assertion with hex formatting.  LongWord values
      // cast to Integer wrap negative for the high half, which produces
      // unreadable "Expected -876016858 got -876016858" messages; hex
      // makes failures investigable.
      procedure CheckCRC(const aData: array of Byte;
                         expected: LongWord; const ctx: string);

      // Reference-vector tests
      procedure Test_EmptyInput_IsZero;
      procedure Test_Standard_Check_123456789;
      procedure Test_SingleByte_a;
      procedure Test_Three_abc;
      procedure Test_QuickBrownFox;

      // Edge / boundary
      procedure Test_SingleZeroByte;
      procedure Test_AllFFsOneByte;
      procedure Test_LongerInput_PreservesAlgorithm;

      // The lookup table used to be rebuilt on EVERY call; it is now built once
      // at unit initialization.  These pin the property that made that safe --
      // repeated and interleaved calls are independent and stable.
      procedure Test_RepeatedCallsAgree;
      procedure Test_InterleavedInputsDoNotContaminate;

      (* P12 (2026-10-18), written BEFORE GetCRC32 lost its untyped buffer and
        run green against it. They pin what a shorter vector cannot: every
        length either side of zlib's word-at-a-time loop, zero bytes in the
        MIDDLE of a buffer, and buffers far longer than any one call's tail. *)
      procedure Test_EveryLengthUpTo70_MatchesBitwiseReference;
      procedure Test_EmbeddedZeroBytesAreHashed;
      procedure Test_LargeBuffers;
      procedure Test_UnicodeBytesAreTheCodeUnits;

   public
      procedure RunAllTests; override;
   end;

implementation

// ---------------------------------------------------------------------------
// Helper: format LongWord as 8-hex-digit uppercase for readable failures.
// ---------------------------------------------------------------------------
function HexLW(v: LongWord): string;
begin
   Result := '$' + IntToHex(Integer(v), 8);
end;

procedure TCRC32Tests.CheckCRC(const aData: array of Byte;
                              expected: LongWord; const ctx: string);
var
   actual: LongWord;
   msg: string;
begin
   actual := GetCRC32(aData);
   if actual = expected then
      begin
      // Reuse the framework's pass path via a true Check
      Check(True, '');
      end
   else
      begin
      msg := Format('%s: expected %s, got %s', [ctx, HexLW(expected), HexLW(actual)]);
      Check(False, msg);
      end;
end;

// ---------------------------------------------------------------------------
// Reference vectors
// ---------------------------------------------------------------------------

procedure TCRC32Tests.Test_EmptyInput_IsZero;
var
   empty: TBytes;
begin
   BeginTest('Test_EmptyInput_IsZero');
   // CRC32("") = 0.  An empty array has no element 0, so this is also the
   // pin that GetCRC32 never indexes one.
   SetLength(empty, 0);
   CheckCRC(empty, $00000000, 'empty input');
end;

procedure TCRC32Tests.Test_Standard_Check_123456789;
var
   s: AnsiString;
begin
   BeginTest('Test_Standard_Check_123456789');
   // The published "check" value for CRC-32/ISO-HDLC.  Every conforming
   // CRC-32 implementation MUST return $CBF43926 for the ASCII string
   // "123456789".  If this ever fails, the algorithm is wrong.
   s := '123456789';
   CheckCRC(BytesOf(s), $CBF43926, 'CRC32("123456789")');
end;

procedure TCRC32Tests.Test_SingleByte_a;
var
   s: AnsiString;
begin
   BeginTest('Test_SingleByte_a');
   s := 'a';
   CheckCRC(BytesOf(s), $E8B7BE43, 'CRC32("a")');
end;

procedure TCRC32Tests.Test_Three_abc;
var
   s: AnsiString;
begin
   BeginTest('Test_Three_abc');
   s := 'abc';
   CheckCRC(BytesOf(s), $352441C2, 'CRC32("abc")');
end;

procedure TCRC32Tests.Test_QuickBrownFox;
var
   s: AnsiString;
begin
   BeginTest('Test_QuickBrownFox');
   // The canonical 43-byte test sentence -- multiple full passes through
   // the inner loop, exercises the asm path with realistic input.
   s := 'The quick brown fox jumps over the lazy dog';
   CheckCRC(BytesOf(s), $414FA339, 'CRC32("The quick brown fox...")');
end;

// ---------------------------------------------------------------------------
// Edge / boundary
// ---------------------------------------------------------------------------

procedure TCRC32Tests.Test_SingleZeroByte;
var
   b: Byte;
begin
   BeginTest('Test_SingleZeroByte');
   // CRC32 of a single $00 byte -- ensures the algorithm produces a
   // non-zero result for non-empty input even when every byte is zero.
   b := $00;
   CheckCRC([b], $D202EF8D, 'CRC32(<$00>)');
end;

procedure TCRC32Tests.Test_AllFFsOneByte;
var
   b: Byte;
begin
   BeginTest('Test_AllFFsOneByte');
   // CRC32 of a single $FF byte.
   b := $FF;
   CheckCRC([b], $FF000000, 'CRC32(<$FF>)');
end;

procedure TCRC32Tests.Test_LongerInput_PreservesAlgorithm;
var
   s: AnsiString;
   i: Integer;
begin
   BeginTest('Test_LongerInput_PreservesAlgorithm');
   // 256-byte input ensures the inner loop iterates many times, and
   // the table-driven step at each byte position is correct across
   // a full byte's worth of distinct values.  CRC32 of bytes 0..255
   // in order.
   SetLength(s, 256);
   for i := 1 to 256 do
      begin
      s[i] := AnsiChar(i - 1);
      end;
   CheckCRC(BytesOf(s), $29058C73, 'CRC32(0x00..0xFF)');
end;

// ---------------------------------------------------------------------------
// Table lifetime
// ---------------------------------------------------------------------------

procedure TCRC32Tests.Test_RepeatedCallsAgree;
var
   s: AnsiString;
   i: Integer;
   first: LongWord;
begin
   BeginTest('Test_RepeatedCallsAgree');
   // The old assembly rebuilt the 256-entry table inside every GetCRC32 call.
   // Building it once at unit initialization is only safe if the table is
   // never mutated by a run -- so call the same input repeatedly and require
   // a stable answer.
   s := '123456789';
   first := GetCRC32(BytesOf(s));
   CheckEquals(Integer($CBF43926), Integer(first), 'first call is the standard check value');

   for i := 1 to 50 do
      begin
      CheckCRC(BytesOf(s), first, Format('call %d agrees with the first', [i]));
      end;
end;

procedure TCRC32Tests.Test_InterleavedInputsDoNotContaminate;
var
   a, b: AnsiString;
   i: Integer;
begin
   BeginTest('Test_InterleavedInputsDoNotContaminate');
   // Different inputs alternating: each must still produce its own value, so
   // no state survives a call.  This is the test that would fail if the shared
   // table were ever written during a computation.
   a := '123456789';
   b := 'abc';
   for i := 1 to 10 do
      begin
      CheckCRC(BytesOf(a), $CBF43926, 'interleaved "123456789"');
      CheckCRC(BytesOf(b), $352441C2, 'interleaved "abc"');
      end;
end;

// ---------------------------------------------------------------------------
// P12 pins -- lengths, embedded zeros, large buffers
// ---------------------------------------------------------------------------

(* CRC-32/ISO-HDLC ONE BIT AT A TIME, straight from the definition: reflected
  polynomial $EDB88320, init $FFFFFFFF, final complement. No table, no word
  loop -- so it shares no shortcut with zlib and is an independent oracle. *)
function BitwiseCRC32(const aBytes: TBytes): LongWord;
var
   crc: LongWord;
   i, bit: integer;
begin
   crc := $FFFFFFFF;
   for i := 0 to Length(aBytes) - 1 do
      begin
      crc := crc xor aBytes[i];
      for bit := 1 to 8 do
         begin
         if (crc and 1) <> 0 then
            begin
            crc := (crc shr 1) xor $EDB88320;
            end
         else
            begin
            crc := crc shr 1;
            end;
         end;
      end;
   Result := not crc;
end;

procedure TCRC32Tests.Test_EveryLengthUpTo70_MatchesBitwiseReference;
var
   n: integer;
   bytes: TBytes;
begin
   BeginTest('Test_EveryLengthUpTo70_MatchesBitwiseReference');
   (* 0..70 covers the empty buffer, one byte, every remainder modulo 4 and 8
     (zlib's unrolled loops) and more than one 32-byte unroll. *)
   for n := 0 to 70 do
      begin
      bytes := TestBytePattern(n);
      CheckCRC(bytes, BitwiseCRC32(bytes), Format('%d bytes', [n]));
      end;
end;

procedure TCRC32Tests.Test_EmbeddedZeroBytesAreHashed;
var
   ab, a0b, a: TBytes;
begin
   BeginTest('Test_EmbeddedZeroBytesAreHashed');
   (* A BYTE BUFFER IS NOT A C STRING. A routine that stopped at the first NUL
     would hash 'a'#0'b' as 'a'. *)
   SetLength(a, 1);
   a[0] := Ord('a');
   SetLength(a0b, 3);
   a0b[0] := Ord('a');
   a0b[1] := 0;
   a0b[2] := Ord('b');
   SetLength(ab, 2);
   ab[0] := Ord('a');
   ab[1] := Ord('b');

   CheckCRC(a0b, BitwiseCRC32(a0b), '''a''#0''b''');
   Check(GetCRC32(a0b) <> GetCRC32(a),
         'the bytes after a zero are part of the hash');
   Check(GetCRC32(a0b) <> GetCRC32(ab),
         'and so is the zero itself');
end;

procedure TCRC32Tests.Test_LargeBuffers;
begin
   BeginTest('Test_LargeBuffers');
   (* Fixed values from Python's zlib.crc32 over the same pattern -- see
     uTestBytePattern. 4,097 is one past a 4 KB boundary; 65,536 is the size
     of the server log reads this CRC is taken over in practice. *)
   CheckCRC(TestBytePattern(4097),  $37C4B1C8, 'pattern(4097)');
   CheckCRC(TestBytePattern(65536), $028D8E58, 'pattern(65536)');
end;

procedure TCRC32Tests.Test_UnicodeBytesAreTheCodeUnits;
var
   s: UnicodeString;
   bytes: TBytes;
   i: integer;
begin
   BeginTest('Test_UnicodeBytesAreTheCodeUnits');
   (* THE SINGLE-INSTANCE MUTEX NAME IS A CRC OF THE INSTALL PATH'S UTF-16
     BYTES (uProgramMain). It used to read them straight out of the string;
     it now asks TEncoding.Unicode for them. That is only the same name if
     GetBytes hands back every code unit, low byte then high on this
     little-endian target, and validates nothing -- so an unpaired surrogate,
     which a Windows path can legally hold, must come through as itself. *)
   s := 'C:\TR4W\' + WideChar($00E9) + WideChar($4E2D)    (* e-acute, a CJK char *)
        + WideChar($D83D) + WideChar($DE00)                (* a surrogate PAIR *)
        + WideChar($DC00) + '\';                           (* a LONE surrogate *)
   bytes := TEncoding.Unicode.GetBytes(s);
   CheckEquals(Length(s) * 2, Length(bytes), 'two bytes per code unit, no BOM');
   for i := 1 to Length(s) do
      begin
      CheckEquals(Ord(s[i]) and $FF, bytes[(i - 1) * 2],     Format('unit %d low byte', [i]));
      CheckEquals(Ord(s[i]) shr 8,   bytes[(i - 1) * 2 + 1], Format('unit %d high byte', [i]));
      end;
   CheckEquals(0, Length(TEncoding.Unicode.GetBytes(UnicodeString(''))),
               'an empty path is no bytes, so CRC 0 as before');
end;

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

procedure TCRC32Tests.RunAllTests;
begin
   Test_EmptyInput_IsZero;
   Test_Standard_Check_123456789;
   Test_SingleByte_a;
   Test_Three_abc;
   Test_QuickBrownFox;
   Test_SingleZeroByte;
   Test_AllFFsOneByte;
   Test_LongerInput_PreservesAlgorithm;
   Test_RepeatedCallsAgree;
   Test_InterleavedInputsDoNotContaminate;
   Test_EveryLengthUpTo70_MatchesBitwiseReference;
   Test_EmbeddedZeroBytesAreHashed;
   Test_LargeBuffers;
   Test_UnicodeBytesAreTheCodeUnits;
end;

end.
