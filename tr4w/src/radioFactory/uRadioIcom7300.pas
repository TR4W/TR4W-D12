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
unit uRadioIcom7300;

{
  Icom IC-7300 Radio Implementation

  The IC-7300 is an HF/50MHz transceiver that uses the CI-V protocol.
  CI-V address: 0x94

  Features:
  - Full CI-V command support via TIcomRadio base class
  - Polling-based operation (no auto-info mode like K4)
  - Standard polling interval: 100ms
  - Supports all HF bands plus 6 meters

  Usage:
    radio := TIcom7300Radio.Create;
    radio.Connect;  // Opens serial or network connection
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7300Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7300Radio.Create;
begin
  inherited Create;

  // Set IC-7300 specific CI-V address
  RadioAddress := $94;

  // Radio identification
  radioModel := 'Icom IC-7300';

  logger.Info('[TIcom7300Radio.Create] Created IC-7300 radio instance with CI-V address $94');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7300');
  // The IC-7300 (unlike the 7300MK2) is serial/USB-CAT only -- no network.
  RegisterRadio(IC7300,
     function: TFactoryRadioBase begin Result := TIcom7300Radio.Create end,
     'Icom IC-7300', [rlSerial], 0, False,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3073
     , 148);

end.
