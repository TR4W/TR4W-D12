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
unit uRadioIcom905;

{
  Icom IC-905 Radio Implementation

  The IC-905 is a VHF/UHF/SHF transceiver.
  CI-V address: 0xAC
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom905Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom905Radio.Create;
begin
  inherited Create;
  RadioAddress := $AC;
  radioModel := 'Icom IC-905';
  // IC-905 CI-V transceive is at menu item $0142, not the default $0150 (IC-7610/IC-7760)
  FTransceiveMenuBytes := #$01 + #$42;
  logger.Info('[TIcom905Radio.Create] Created IC-905 instance with CI-V address $AC');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom905');
  RegisterRadio(IC905,
     function: TFactoryRadioBase begin Result := TIcom905Radio.Create end,
     'Icom IC-905', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     0
     );

end.
