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
unit uRotatorOrion;
{$I ..\tr4w.inc}

{
  Orion rotator azimuth command.

  NOT THE TEN-TEC ORION, despite sharing the name (NY4I).  The radio factory has
  a Ten-Tec Orion transceiver, and calling this one "Ten-Tec Orion" in a
  drop-down would invite an operator to pick their radio's manufacturer for
  their rotator.  It is just "Orion" here.

  PORTED EXACTLY from LOGSTUFF.RotorControl: '#%03u'#$D.

  THE LEGACY ALIAS THIS REPLACES is worth recording, because it looks like a
  setting and is not.  'ORION PORT' in CommandsArray shares list index 40 with
  'ROTATOR PORT', so both write ActiveRotatorPort, and its crA hook
  F_ORION_PORT does nothing but

      ActiveRotatorType := OrionRotator;

  So 'ORION PORT = COM5' was shorthand for "the rotator is an Orion, on COM5" --
  a second spelling of two other settings, in the same family as MY QTH being
  MY STATE.  With a rotator library that shorthand has nowhere to live, so the
  row is deleted rather than migrated.
}

interface

uses
   SysUtils,
   uRotatorBase;

type
   TRotatorOrion = class(TRotatorBase)
   protected
      function TurnFrame(const aAzimuth: integer): TBytes; override;
   public
      class function DisplayName: string; override;
   end;

implementation

uses
   uRotatorRegistry;

class function TRotatorOrion.DisplayName: string;
begin
   Result := 'Orion';
end;

function TRotatorOrion.TurnFrame(const aAzimuth: integer): TBytes;
begin
   Result := Ascii(Format('#%.3d', [aAzimuth]) + #$0D);
end;

// A NAMED unit-level function, not an anonymous one.  The registry's factory type is a
// plain procedure pointer so that this unit compiles under a Pascal without closures;
// nothing was captured here anyway, so the anonymous form bought nothing.
function CreateOrion(const aSend: TRotatorSendProc): TRotatorBase;
begin
   Result := TRotatorOrion.Create(aSend);
end;

initialization
   RegisterRotator('ORION', 'Orion', CreateOrion);

end.
