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
unit uRotatorPSTRotator;
{$I ..\tr4w.inc}

{
  PstRotator, over its native UDP interface.

  THE ONE WITH NO SERIAL PORT, which is why the legacy code left the function
  before it ever reached the `case`:

      // Issue #732 -- PSTRotator is a UDP-only rotator type: send its native
      // command and stop (it has no serial port, so the serial path below is N/A).
      if ActiveRotatorType = PSTRotator then
      begin
        SendPSTRotorCommand(Heading);
        Exit;
      end;

  An early return for one type, above a `case` covering the others, is the
  clearest statement available that the function had outgrown its shape: a
  rotator that does not use the transport the whole routine is built around.

  Here it is simply a driver whose bytes go to a different Send.  The base class
  never learns that anything is unusual, because TRotatorSendProc does not care
  what is on the other end -- which is the same reason the drivers are testable
  with no hardware.

  IT IS THE TRANSPORT THAT DIFFERS, NOT THE FORMAT: PstRotator's UDP listener
  takes the azimuth as plain text.
}

interface

uses
   SysUtils,
   uRotatorBase;

type
   TRotatorPSTRotator = class(TRotatorBase)
   protected
      function TurnFrame(const aAzimuth: integer): TBytes; override;
   public
      class function DisplayName: string; override;

      { UDP, not a COM port.  The port-opening path asks this instead of
        checking which rotator it has -- the early return above, made into a
        property of the driver. }
      function UsesSerialPort: boolean; override;
   end;

implementation

uses
   uRotatorRegistry;

class function TRotatorPSTRotator.DisplayName: string;
begin
   Result := 'PstRotator (UDP)';
end;

function TRotatorPSTRotator.UsesSerialPort: boolean;
begin
   Result := False;
end;

function TRotatorPSTRotator.TurnFrame(const aAzimuth: integer): TBytes;
begin
   Result := Ascii(Format('%.3d', [aAzimuth]));
end;

// A NAMED unit-level function, not an anonymous one.  The registry's factory type is a
// plain procedure pointer so that this unit compiles under a Pascal without closures;
// nothing was captured here anyway, so the anonymous form bought nothing.
function CreatePSTRotator(const aSend: TRotatorSendProc): TRotatorBase;
begin
   Result := TRotatorPSTRotator.Create(aSend);
end;

initialization
   RegisterRotator('PSTROTATOR', 'PstRotator (UDP)', CreatePSTRotator);

end.
