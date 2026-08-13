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
unit uRotatorAlfaSpid;
{$I ..\tr4w.inc}

{
  Alfa SPID rot2prog azimuth command -- a BINARY, FIXED-LENGTH frame.

  THIS IS THE DRIVER THAT JUSTIFIES THE FACTORY.  The legacy code formatted it
  like the others and then reached back into the buffer afterwards, because SPID
  does not have the same shape as the rest:

      AlfaSpidRotator:
        begin
          TempPchar := 'W%03u0'#01;
          inc(Heading, 360);
        end;
      ...
      nNumberOfBytesToWrite := Format(wsprintfBuffer, TempPchar, heading);
      if ActiveRotatorType = AlfaSpidRotator then
      begin
        nNumberOfBytesToWrite := 13;
        wsprintfBuffer[11] := #$2F;
        wsprintfBuffer[12] := #$20;
      end;

  A `case` that assigns a format string, followed by an `if` that undoes the
  assumption behind it, is the shape a factory exists to remove.

  THE +360 IS A SPID CONVENTION, not a TR4W one: the protocol carries azimuth
  offset by a full turn so the wire value is never negative.  It happens here,
  in the driver, for exactly that reason -- the base class normalises to 0..359
  and knows nothing about it.

  THE FRAME is 13 bytes: 'W', four azimuth digits, an azimuth resolution byte,
  four elevation digits, an elevation resolution byte, 0x2F ('/') and 0x20.

  ELEVATION IS LEFT AS ZEROS, deliberately.  The legacy path never wrote those
  bytes -- they were whatever ZeroMemory had put there -- and TR4W drives
  azimuth only.  Filling in plausible elevation values here would be a
  behaviour change wearing the costume of a tidy-up, and this port is supposed
  to be byte-identical.  The tests check all thirteen.
}

interface

uses
   SysUtils,
   uRotatorBase;

type
   TRotatorAlfaSpid = class(TRotatorBase)
   protected
      function TurnFrame(const aAzimuth: integer): TBytes; override;
   public
      class function DisplayName: string; override;
   end;

implementation

uses
   uRotatorRegistry;

class function TRotatorAlfaSpid.DisplayName: string;
begin
   Result := 'Alfa SPID';
end;

function TRotatorAlfaSpid.TurnFrame(const aAzimuth: integer): TBytes;
var
   wire: integer;
begin
   // Built explicitly rather than formatted-and-then-patched.  The result is
   // byte-identical to the legacy frame -- that is what the tests assert -- but
   // the patching is what made the original hard to read, and reproducing it
   // would preserve the confusion along with the bytes.
   SetLength(Result, 13);
   FillChar(Result[0], Length(Result), 0);

   wire := aAzimuth + 360;

   Result[0] := Ord('W');
   // Four digits.  The legacy '%03u' ran over a value already >= 360, so it
   // always produced three digits, and the literal '0' that followed in the
   // format string made the fourth.  Same four characters, arrived at without
   // relying on the value never reaching four digits of its own.
   Result[1] := Byte(Ord('0') + (wire div 100) mod 10);
   Result[2] := Byte(Ord('0') + (wire div 10) mod 10);
   Result[3] := Byte(Ord('0') + wire mod 10);
   Result[4] := Byte(Ord('0'));

   Result[5]  := $01;   // azimuth resolution: one degree per unit
   // 6..10 are the elevation digits and their resolution -- left zero, see the
   // unit header.
   Result[11] := $2F;
   Result[12] := $20;
end;

// A NAMED unit-level function, not an anonymous one.  The registry's factory type is a
// plain procedure pointer so that this unit compiles under a Pascal without closures;
// nothing was captured here anyway, so the anonymous form bought nothing.
function CreateAlfaSpid(const aSend: TRotatorSendProc): TRotatorBase;
begin
   Result := TRotatorAlfaSpid.Create(aSend);
end;

initialization
   RegisterRotator('ALFA SPID', 'Alfa SPID', CreateAlfaSpid);

end.
