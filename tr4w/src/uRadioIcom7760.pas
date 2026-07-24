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
unit uRadioIcom7760;

{
  Icom IC-7760 Radio Implementation

  The IC-7760 has several protocol differences from standard Icom radios:
    - CI-V address: 0xB2
    - Controller address: 0xE1 (NOT the typical 0xE0)
    - VFO B commands use $25/$26 extended format (FSupportsExtendedVFOBCommands = True,
      which is the base class default — no override needed)
    - Shared RIT/XIT offset (single offset for both)
}

interface

uses
  uRadioIcomBase, VC, uRadioRegistry;

type
  TIcom7760Radio = class(TIcomRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7760Radio.Create;
begin
  inherited Create;
  RadioAddress := $B2;
  ControllerAddress := $E1;  // NOT the typical $E0
  radioModel := 'Icom IC-7760';
  FSupportsActiveVFOQuery := True;  // IC-7760 supports $07 $D2 to read active VFO
  logger.Info('[TIcom7760Radio.Create] Created IC-7760 instance, CI-V=$B2, Controller=$E1');
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7760');
  RegisterRadio(IC7760,
     function: TNetRadioBase begin Result := TIcom7760Radio.Create end,
     'Icom IC-7760', [rlSerial, rlNetwork], 50001, True);

end.
