unit uCRC16;
{$I tr4w.inc}

{
  CRC-16/X-25 -- the CRC carried in the footer of the Elecraft K4's panadapter
  frames.

  Catalogue entry (reveng CRC catalogue, "CRC-16/X-25"): polynomial $1021
  reflected to $8408, initial value $FFFF, input and output reflected, final
  xor $FFFF.  The published "check" value -- what every conforming
  implementation must return for the ASCII string "123456789" -- is $906E, and
  uTestCRC16 asserts exactly that.

  That vector is the point.  It makes this a NAMED, published algorithm rather
  than "whatever the radio appears to accept", and it was verified against the
  catalogue before a single K4 frame was fed to it.  A CRC that is only ever
  checked against one device's output is untestable the day that device is not
  on the bench.

  WHY THIS UNIT OWNS AN ALGORITHM, WHERE uCRC32 DELIBERATELY DOES NOT.
  uCRC32 is a four-line adapter over each toolchain's standard library, on the
  stated principle (NY4I) that a contest logger should not carry its own copy
  of a standard CRC.  The same search was made here and came up empty: FPC's
  RTL ships no CRC-16 of any kind.  The only Crc16 in the entire FPC tree is
  packages/palmunits/src/crc.pp, a syscall trap declaration for PalmOS -- an
  operating system this program does not run on.  There is nothing to adapt
  to, so the twenty lines below are the smaller cost.  If an RTL CRC-16/X-25
  ever appears, this unit should become an adapter like uCRC32 and the check
  vector above is what proves the swap was safe.

  Implementation note: the table is 16 entries, not 256 -- two lookups per
  byte instead of one, trading a few cycles for 480 fewer bytes of table.  The
  K4 stream is ~36 frames a second of 4,160 bytes, about 150 KB/s, nowhere
  near enough to justify the larger table.  It is a typed constant built at
  compile time; nothing is computed at unit initialization.  (The CRC-32 this
  replaced the shape of used to rebuild its 256-entry table on EVERY call.)
}

interface

// Count = 0 returns $0000: init $FFFF complemented by the final xor $FFFF,
// which is what the catalogue specifies for empty input.
function GetCRC16X25(const data; Count: LongWord): Word;

implementation

const
   // Reflected polynomial $8408, one entry per low nibble.
   CRC16_NIBBLES: array[0..15] of Word = (
      $0000, $1081, $2102, $3183,
      $4204, $5285, $6306, $7387,
      $8408, $9489, $A50A, $B58B,
      $C60C, $D68D, $E70E, $F78F);

function GetCRC16X25(const data; Count: LongWord): Word;
var
   crc: LongWord;
   i: LongWord;
   b: Byte;
   p: PByte;
begin
   // LongWord accumulator, not Word.  Every intermediate stays below $10000
   // anyway -- (crc shr 4) and $0FFF is twelve bits, xored with a sixteen-bit
   // table entry -- but doing the arithmetic in a wider type removes any
   // question about how `not` and the shifts behave on a 16-bit operand
   // across two compilers.
   crc := $FFFF;

   if Count > 0 then
      begin
      p := PByte(@data);

      for i := 0 to Count - 1 do
         begin
         b := p^;
         crc := ((crc shr 4) and $0FFF) xor CRC16_NIBBLES[(crc xor b) and $0F];
         b := b shr 4;
         crc := ((crc shr 4) and $0FFF) xor CRC16_NIBBLES[(crc xor b) and $0F];
         Inc(p);
         end;
      end;

   // Final xor $FFFF.  Word() truncates the 32-bit complement to the low
   // sixteen bits, which is the catalogue's output.
   Result := Word(not crc);
end;

end.
