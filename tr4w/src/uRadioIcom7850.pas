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
  uRadioIcomBase, VC;

type
  TIcom7850Radio = class(TIcomRadio)
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

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7850');

end.
