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
unit uRotatorYaesu;

{
  Yaesu GS-232 style azimuth command.

  PORTED EXACTLY from LOGSTUFF.RotorControl, which formatted 'M%03u'#$D -- an
  'M', three zero-padded digits, and a carriage return.  The old format string
  and this frame are pinned against each other in the unit tests, byte for byte:
  "behaviour preserving" is a claim to be checked rather than asserted, which is
  what the radio factory's RIT capability swap taught when the obvious
  substitution turned out to be wrong in both directions.
}

interface

uses
   SysUtils,
   uRotatorBase;

type
   TRotatorYaesu = class(TRotatorBase)
   protected
      function TurnFrame(const aAzimuth: integer): TBytes; override;
   public
      class function DisplayName: string; override;
   end;

implementation

uses
   uRotatorRegistry;

class function TRotatorYaesu.DisplayName: string;
begin
   Result := 'Yaesu';
end;

function TRotatorYaesu.TurnFrame(const aAzimuth: integer): TBytes;
begin
   Result := Ascii(Format('M%.3d', [aAzimuth]) + #$0D);
end;

// A NAMED unit-level function, not an anonymous one.  The registry's factory type is a
// plain procedure pointer so that this unit compiles under a Pascal without closures;
// nothing was captured here anyway, so the anonymous form bought nothing.
function CreateYaesu(const aSend: TRotatorSendProc): TRotatorBase;
begin
   Result := TRotatorYaesu.Create(aSend);
end;

initialization
   RegisterRotator('YAESU', 'Yaesu', CreateYaesu);

end.
