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
unit uRadioIcom7850;

{
  Icom IC-7850/IC-7851 Radio Implementation

  The IC-7850 and IC-7851 are identical from a protocol perspective.
  CI-V address: 0x8E
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)
}

interface

uses
  uRadioIcomBase, VC, uRadioRegistry;

type
  TIcom7850Radio = class(TIcomRadio)
  public
    constructor Create; reintroduce;
  end;

  // The IC-7851 is protocol-identical to the IC-7850, but it gets its OWN class and
  // its OWN registry entry so the operator sees THEIR radio in the selection list.
  // Listing one model as a stand-in for two is counter-intuitive: a 7851 owner finds
  // no 7851 and reasonably concludes the build does not support it.  It also keeps
  // radioModel honest, so that operator's log says IC-7851 and their bug report
  // reads correctly.  Same rule as the Yaesu FT-817/FT-818 pair.
  TIcom7851Radio = class(TIcom7850Radio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7850Radio.Create;
begin
  inherited Create;
  RadioAddress := $8E;
  radioModel := 'Icom IC-7850';
  FSupportsActiveVFOQuery := True;  // Supports $07 $D2 Main/Sub band selection
  logger.Info('[TIcom7850Radio.Create] Created IC-7850 instance with CI-V address $8E');
end;

constructor TIcom7851Radio.Create;
begin
  inherited Create;
  radioModel := 'Icom IC-7851';   // identical protocol; only the identity differs
  logger.Info('[TIcom7851Radio.Create] Created IC-7851 instance with CI-V address $8E');
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7850');
  // Register each model under its OWN name -- see TIcom7851Radio.
  RegisterRadio(IC7850,
     function: TFactoryRadioBase begin Result := TIcom7850Radio.Create end,
     'Icom IC-7850', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     );
  RegisterRadio(IC7851,
     function: TFactoryRadioBase begin Result := TIcom7851Radio.Create end,
     'Icom IC-7851', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     );

end.
