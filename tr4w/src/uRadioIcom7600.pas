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
unit uRadioIcom7600;

{
  Icom IC-7600 Radio Implementation

  The IC-7600 is an HF/50MHz transceiver with network capability.
  CI-V address: 0x7A
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)
}

interface

uses
  uRadioIcomBase, VC, uRadioRegistry;

type
  TIcom7600Radio = class(TIcomRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7600Radio.Create;
begin
  inherited Create;
  RadioAddress := $7A;
  radioModel := 'Icom IC-7600';
  FSupportsActiveVFOQuery := True;  // Supports $07 $D2 Main/Sub band selection
  logger.Info('[TIcom7600Radio.Create] Created IC-7600 instance with CI-V address $7A');
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7600');
  RegisterRadio(IC7600,
     function: TFactoryRadioBase begin Result := TIcom7600Radio.Create end,
     'Icom IC-7600', [rlSerial, rlNetwork], 50001, True);

end.
