unit uTestCRC16;
{$I ..\..\src\tr4w.inc}

(*
  CRC-16/X-25 BEYOND ITS CHECK VALUE.

  The published "123456789" -> $906E vector and the empty-input case live in
  uTestK4Spectrum, beside the frames they protect. These pins were added for
  P12 (docs/POINTER_AUDIT.md, 2026-10-18) and written BEFORE GetCRC16X25 lost
  its untyped buffer, so they ran green against the pointer walk first:

    every length 0..40       against a ONE-BIT-AT-A-TIME reference written
                             from the catalogue definition -- it shares no
                             nibble table with the unit, so it is independent
    zero bytes mid-buffer    a byte buffer is not a C string
    the largest K4 frame     4,160 bytes, the exact span the decoder hashes

  A frame's CRC is checked ~36 times a second on a network K4, so a wrong one
  drops every panadapter frame -- quietly, as k4BadCRC.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TCRC16Tests = class(TTestCase)
   protected
      procedure Test_EveryLengthUpTo40_MatchesBitwiseReference;
      procedure Test_EmbeddedZeroBytesAreHashed;
      procedure Test_LargestK4Frame;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uCRC16, uK4Spectrum, uTestBytePattern;

(* From the catalogue entry: reflected polynomial $8408, init $FFFF, reflected
  in and out, final xor $FFFF -- one bit at a time. *)
function BitwiseCRC16X25(const aBytes: TBytes): Word;
var
   crc: LongWord;
   i, bit: integer;
begin
   crc := $FFFF;
   for i := 0 to Length(aBytes) - 1 do
      begin
      crc := crc xor aBytes[i];
      for bit := 1 to 8 do
         begin
         if (crc and 1) <> 0 then
            begin
            crc := (crc shr 1) xor $8408;
            end
         else
            begin
            crc := crc shr 1;
            end;
         end;
      end;
   Result := Word(not crc);
end;

procedure TCRC16Tests.Test_EveryLengthUpTo40_MatchesBitwiseReference;
var
   n: integer;
   bytes: TBytes;
begin
   BeginTest('Test_EveryLengthUpTo40_MatchesBitwiseReference');
   for n := 0 to 40 do
      begin
      bytes := TestBytePattern(n);
      CheckEquals(IntToHex(BitwiseCRC16X25(bytes), 4), IntToHex(GetCRC16X25(bytes), 4),
                  Format('%d bytes', [n]));
      end;
end;

procedure TCRC16Tests.Test_EmbeddedZeroBytesAreHashed;
var
   a, a0b: TBytes;
begin
   BeginTest('Test_EmbeddedZeroBytesAreHashed');
   SetLength(a, 1);
   a[0] := Ord('a');
   SetLength(a0b, 3);
   a0b[0] := Ord('a');
   a0b[1] := 0;
   a0b[2] := Ord('b');

   CheckEquals(IntToHex(BitwiseCRC16X25(a0b), 4), IntToHex(GetCRC16X25(a0b), 4),
               '''a''#0''b''');
   Check(GetCRC16X25(a0b) <> GetCRC16X25(a), 'the bytes after a zero are hashed');
end;

procedure TCRC16Tests.Test_LargestK4Frame;
var
   bytes: TBytes;
begin
   BeginTest('Test_LargestK4Frame');
   (* EXACTLY what TK4SpectrumDecoder hashes: the whole frame but its footer. *)
   bytes := TestBytePattern(K4_PACKET_SIZE - K4_FOOTER_SIZE);
   CheckEquals(4160, Length(bytes), 'the K4 hashes 4,160 bytes per frame');
   CheckEquals(IntToHex(BitwiseCRC16X25(bytes), 4), IntToHex(GetCRC16X25(bytes), 4),
               'the largest frame the K4 sends');
end;

procedure TCRC16Tests.RunAllTests;
begin
   Test_EveryLengthUpTo40_MatchesBitwiseReference;
   Test_EmbeddedZeroBytesAreHashed;
   Test_LargestK4Frame;
end;

end.
