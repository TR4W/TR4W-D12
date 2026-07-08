{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uIcomCIV;

{
  Pure CI-V utility functions for Icom radio control.

  Extracted from TIcomRadio so they can be tested independently and reused
  without a class instance.  All functions are stateless — they take inputs
  and return outputs with no side effects.

  D12 migration note:
    The BCD string functions return raw byte sequences (CI-V wire format).
    In Phase 2 of the Delphi 12 migration, change the string return types
    to AnsiString and update callers in uRadioIcomBase.pas accordingly.
    Using string (= AnsiString in D7) for now keeps the codebase consistent.
}

interface

uses
   SysUtils;

// ---------------------------------------------------------------------------
// BCD byte encode / decode
// ---------------------------------------------------------------------------

// Pack a two-digit decimal (0-99) into one BCD byte: tens in upper nibble,
// units in lower nibble.  Example: ByteToBCD(45) = $45.
function IcomByteToBCD(value: Byte): Byte;

// Unpack one BCD byte back to a two-digit decimal.
// Example: IcomBCDToByte($45) = 45.
function IcomBCDToByte(bcd: Byte): Byte;

// ---------------------------------------------------------------------------
// Frequency BCD encoding (5 bytes, LSB first — CI-V $03/$05 format)
// ---------------------------------------------------------------------------

function IcomFreqToBCD(freq: LongInt): AnsiString;
function IcomBCDToFreq(bcd: AnsiString): LongInt;

// ---------------------------------------------------------------------------
// RIT/XIT offset BCD encoding (2 bytes, LSB first, magnitude only)
// The sign byte is appended separately by the caller.
// ---------------------------------------------------------------------------

function IcomOffsetToBCD(offset: Integer): AnsiString;

// ---------------------------------------------------------------------------
// CW speed conversion  (CI-V $14 $0C format)
//
// Icom maps 6–48 WPM linearly onto CI-V values 0–255.
// Encode formula (spec): value = (WPM - 6) * 255 / 42  (round to nearest)
// Decode formula (spec): WPM  = 6 + value * 42 / 255   (round to nearest)
// Integer round-to-nearest: add half-divisor before integer divide.
// ---------------------------------------------------------------------------

function IcomWPMToValue(wpm: Integer): Byte;    // 6-48 WPM -> 0-255
function IcomValueToWPM(value: Byte): Integer;  // 0-255 -> 6-48 WPM

implementation

function IcomByteToBCD(value: Byte): Byte;
begin
   Result := ((value div 10) shl 4) or (value mod 10);
end;

function IcomBCDToByte(bcd: Byte): Byte;
begin
   Result := ((bcd shr 4) * 10) + (bcd and $0F);
end;

function IcomFreqToBCD(freq: LongInt): AnsiString;
var
   i       : Integer;
   freqStr : string;
   bcdByte : Byte;
begin
   // Format as 10-digit string so every pair of digits is well-defined.
   freqStr := Format('%.10d', [freq]);

   // Build 5 BCD bytes, LSB first (pair 5 = digits 9-10 = Hz ones/tens).
   Result := '';
   for i := 5 downto 1 do
      begin
      bcdByte := IcomByteToBCD(StrToIntDef(Copy(freqStr, i * 2 - 1, 2), 0));
      Result  := Result + AnsiChar(bcdByte);
      end;
end;

function IcomBCDToFreq(bcd: AnsiString): LongInt;
var
   i       : Integer;
   freqStr : string;
begin
   // BCD is LSB first — walk backwards to get MSB first decimal string.
   freqStr := '';
   for i := Length(bcd) downto 1 do
      freqStr := freqStr + Format('%.2d', [IcomBCDToByte(Ord(bcd[i]))]);
   Result := StrToInt64Def(freqStr, 0);
end;

function IcomOffsetToBCD(offset: Integer): AnsiString;
var
   absOffset : Integer;
   offsetStr : string;
   bcdByte   : Byte;
   i         : Integer;
begin
   absOffset := Abs(offset);
   offsetStr := Format('%.4d', [absOffset]);  // 4 digits, max 9999 Hz
   Result := '';
   for i := 2 downto 1 do
      begin
      bcdByte := IcomByteToBCD(StrToIntDef(Copy(offsetStr, i * 2 - 1, 2), 0));
      Result  := Result + AnsiChar(bcdByte);
      end;
end;

function IcomWPMToValue(wpm: Integer): Byte;
var
   v: Integer;
begin
   if wpm < 6  then wpm := 6;
   if wpm > 48 then wpm := 48;
   v := ((wpm - 6) * 255 + 21) div 42;
   if v > 255 then v := 255;
   Result := Byte(v);
end;

function IcomValueToWPM(value: Byte): Integer;
begin
   Result := 6 + (Integer(value) * 42 + 127) div 255;
end;

end.
