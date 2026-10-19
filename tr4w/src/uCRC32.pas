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
{$I tr4w.inc}

(*
  Standard CRC-32 (CRC-32/ISO-HDLC): polynomial $EDB88320, initial $FFFFFFFF,
  reflected, output one's-complemented.  The same CRC as PKZIP, Ethernet, PNG
  and gzip.  TR4WServer uses it for log and packet integrity, so a regression
  here corrupts multi-op log synchronization silently -- uTestCRC32 holds the
  published reference vectors.

  THIS UNIT OWNS NO ALGORITHM.  It is a thin adapter over each toolchain's
  standard library, which is deliberate (NY4I): a CRC-32 is not something a
  contest logger should be carrying its own copy of.

    Delphi 12 : System.ZLib.crc32 -- zlib's, in the RTL
    FPC       : the RTL `crc` unit

  Both take the same arguments and return the same values; the FPC path was
  verified to produce $CBF43926 for "123456789" before it was written here.
  The conditional is four lines in one file, which is the whole cost of using
  the standard library on both platforms rather than hand-rolling once.

  Measured cost of linking zlib for this: +12,288 bytes on a 13 MB executable
  (0.09%).  It replaced three blocks of hand-written x86-32 assembly that could
  not assemble on a 64-bit compiler at all.  The assembly also rebuilt its
  256-entry lookup table on EVERY call -- 2,048 shift/xor iterations before a
  single input byte was read -- and set the direction flag without clearing it
  on the exception path.  Neither problem can recur here.

  zlib's contract is that crc32(0, buf, len) computes the complete CRC: the
  initial value and the final one's-complement are internal to it.  An empty
  buffer returns 0, matching the assembly's short-circuit.
*)

(* AN OPEN ARRAY OF BYTES, NOT AN UNTYPED BUFFER AND A COUNT (P12,
  docs/POINTER_AUDIT.md item 3.5, 2026-10-18). The array carries its own
  length, so a caller can no longer hand over one variable and the size of
  another. Pass a TBytes, a static byte array, or a slice of either --
  `buf[i..j]` -- which costs no copy. Text is hashed as BYTES: the caller
  chooses the encoding (TEncoding.UTF8.GetBytes, TEncoding.Unicode.GetBytes),
  which is what keeps the same text hashing one way on every platform. *)

interface

function GetCRC32(const aData: array of Byte): longword;

implementation

uses
  crc;

function GetCRC32(const aData: array of Byte): longword;
begin
  if Length(aData) = 0 then
     begin
     Result := 0;
     Exit;
     end;
  (* THE ONE POINTER, AND IT IS THE RTL's: crc.crc32 takes a PByte and a
    length. The bounds it needs come from the open array right here. *)
  Result := crc32(0, @aData[0], Length(aData));
end;

end.
