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
unit uRadioIcom7100;

{
  Icom IC-7100 Radio Implementation

  The IC-7100 is an HF/VHF/UHF all-mode transceiver (serial CI-V only).
  CI-V address: 0x88
  Controller address: 0xE0 (standard)
  CI-V transceive menu: 1A 05 00 95
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7100Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7100Radio.Create;
begin
  inherited Create;
  RadioAddress := $88;
  radioModel := 'Icom IC-7100';
  // IC-7100 CI-V transceive is at menu item $0095 (1A 05 00 95)
  FTransceiveMenuBytes := #$00 + #$95;
  // The IC-7100 has no $07 $D2 active-VFO query, so route the $00 transceive
  // frequency push straight to the active VFO instead of firing a $25 $00/$01
  // query pair per push. Without this, fast VFO spins lag: each push triggers a
  // query round-trip and intermediate pushes are skipped while it's in flight.
  FDirectFreqRoute := True;
  logger.Info('[TIcom7100Radio.Create] Created IC-7100 instance with CI-V address $88');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync];
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7100');
  RegisterRadio(IC7100,
     function: TFactoryRadioBase begin Result := TIcom7100Radio.Create end,
     'Icom IC-7100', [rlSerial], 0, False,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3070
     );

end.
