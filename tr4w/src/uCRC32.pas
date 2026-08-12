{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT. 
If not, ref: 
http://www.gnu.org/licenses/gpl-3.0.txt
 }
unit uCRC32;

{
  Standard CRC-32 (CRC-32/ISO-HDLC): polynomial $EDB88320, initial $FFFFFFFF,
  reflected, output one's-complemented.  The same CRC as PKZIP, Ethernet, PNG
  and gzip.  TR4WServer uses it for log and packet integrity, so a regression
  here corrupts multi-op log synchronization silently -- uTestCRC32 holds the
  published reference vectors.

  This was three blocks of hand-written x86-32 assembly.  Replacing them with
  Pascal was NOT a style exercise: the asm cannot assemble on a 64-bit compiler,
  which made this unit one of two blocking the FPC/Lazarus portability spike
  (see docs/FPC_SPIKE_LOG.md).  The tests came first and did not change.

  Two defects went with it, neither of which the tests could see:

  - The 256-entry lookup table was rebuilt on EVERY call to GetCRC32 -- 2,048
    shift/xor iterations before a single input byte was read.  It is a constant
    table; it is now built once at unit initialization.
  - The table builder set the direction flag (STD) and cleared it (CLD) at the
    end.  Any exception in between would have left DF set, which violates the
    ABI and misbehaves in unrelated code that assumes forward string ops.
}

interface

function GetCRC32(const data; Count: longword): longword; register;

const
  Crc32Init                             = $FFFFFFFF;
  Crc32Polynomial                       = $EDB88320;
implementation

var
  CRC32Table                            : array[Byte] of Cardinal;

{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  Crc32BuildTable

  Entry i holds the CRC of the single byte i.  For each of the 8 bits the value
  is shifted right, and the polynomial is XORed in when the bit shifted OUT was
  set -- which is exactly what the assembly's SHR-then-JNC pair did, since SHR
  leaves the departing bit in the carry flag.

  Called once, from initialization.  The table is read-only afterwards, which is
  what makes GetCRC32 safe to call from more than one thread.
}
procedure Crc32BuildTable;
var
  i                                     : integer;
  bit                                   : integer;
  c                                     : Cardinal;
begin
  for i := 0 to 255 do
    begin
    c := Cardinal(i);
    for bit := 1 to 8 do
      begin
      if (c and 1) <> 0 then
        begin
        c := (c shr 1) xor Crc32Polynomial;
        end
      else
        begin
        c := c shr 1;
        end;
      end;
    CRC32Table[i] := c;
    end;
end;

function GetCRC32(const data; Count: longword): longword; register;
var
  p                                     : PByte;
  i                                     : longword;
begin
  RESULT := Crc32Init;
  p := PByte(@data);

  for i := 1 to Count do
    begin
    RESULT := (RESULT shr 8) xor CRC32Table[Byte(RESULT xor p^)];
    Inc(p);
    end;

  // Count = 0 falls straight through to here, so the empty input yields
  // NOT $FFFFFFFF = 0 -- the same answer the assembly's short-circuit gave.
  RESULT := not RESULT;
end;

initialization
  Crc32BuildTable;

end.
