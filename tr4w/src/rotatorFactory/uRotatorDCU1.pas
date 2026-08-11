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
unit uRotatorDCU1;

{
  Hy-Gain DCU-1 azimuth command.

  PORTED EXACTLY from LOGSTUFF.RotorControl: 'AP1%03u;AM1;' -- set the target
  azimuth, then start the move.  BOTH HALVES GO IN ONE WRITE, as they did
  before: AP1 without AM1 leaves the rotator holding a target it never turns to,
  which on the bench is indistinguishable from a dead rotator.

  DCU-1 IS THE ONE WITH A BAUD RATE OF ITS OWN.  LogCfg.pas:293 opened the
  rotator port at 4800 for this type and 9600 for everything else:

      if ActiveRotatorType = DCU1Rotator then BaudRate := 4800;

  That was the only per-type branch in the port-opening path, and it belongs to
  the driver.  PreferredBaudRate is how the port-opening code stops having to
  ask what kind of rotator it is -- the same move that took the CI-V address and
  the startup command off LOGRADIO and onto each radio.
}

interface

uses
   System.SysUtils,
   uRotatorBase;

type
   TRotatorDCU1 = class(TRotatorBase)
   protected
      function TurnFrame(const aAzimuth: integer): TBytes; override;
   public
      class function DisplayName: string; override;

      { 4800, where every other rotator here wants the default. }
      function PreferredBaudRate: integer; override;
   end;

implementation

uses
   uRotatorRegistry;

class function TRotatorDCU1.DisplayName: string;
begin
   Result := 'Hy-Gain DCU-1';
end;

function TRotatorDCU1.PreferredBaudRate: integer;
begin
   Result := 4800;
end;

function TRotatorDCU1.TurnFrame(const aAzimuth: integer): TBytes;
begin
   Result := Ascii(Format('AP1%.3d;AM1;', [aAzimuth]));
end;

initialization
   RegisterRotator('DCU1', 'Hy-Gain DCU-1',
      function (const aSend: TRotatorSendProc): TRotatorBase
      begin
         Result := TRotatorDCU1.Create(aSend);
      end);

end.
