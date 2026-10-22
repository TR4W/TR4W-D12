unit uTestBytePattern;
{$I ..\..\src\tr4w.inc}

(*
  ONE BYTE PATTERN FOR EVERY TEST THAT HASHES OR FRAMES A BUFFER.

  The CRC-32, CRC-16 and SHA-256 pins each need the same thing: a buffer of a
  chosen length whose bytes are not all alike and which carries ZERO BYTES IN
  THE MIDDLE. An all-'a' buffer cannot catch an implementation that stops at a
  NUL, and a short string cannot reach the word-at-a-time and block paths. It
  is written once so the three suites hash the same bytes, and so the Python
  that produced the fixed vectors in them has exactly one definition to match:

     byte i = 0                        when i mod 7 = 3
            = (i * 37 + 11) and $FF    otherwise

  (Python 3.12, zlib.crc32 and hashlib.sha256 -- independent implementations,
  2026-10-18.)
*)

interface

uses
   SysUtils;

function TestBytePattern(const aCount: integer): TBytes;

(* The same bytes in a RawByteString, for an API that takes one. *)
function TestBytePatternRaw(const aCount: integer): RawByteString;

implementation

function TestBytePattern(const aCount: integer): TBytes;
var
   i: integer;
begin
   SetLength(Result, aCount);
   for i := 0 to aCount - 1 do
      begin
      if i mod 7 = 3 then
         begin
         Result[i] := 0;
         end
      else
         begin
         Result[i] := Byte((i * 37 + 11) and $FF);
         end;
      end;
end;

function TestBytePatternRaw(const aCount: integer): RawByteString;
var
   bytes: TBytes;
   i: integer;
begin
   bytes := TestBytePattern(aCount);
   SetLength(Result, aCount);
   for i := 0 to aCount - 1 do
      begin
      Result[i + 1] := AnsiChar(bytes[i]);
      end;
end;

end.
