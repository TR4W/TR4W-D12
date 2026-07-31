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
unit uRadioElecraftK3;

{
  Elecraft K3 (serial CAT).  A thin per-model subclass of TElecraftSerial -- the
  K3 is the bench exemplar for the serial-Elecraft family, so it only names
  itself and inherits the whole family CAT implementation (extended-mode probe,
  IF/MD/DT poll, DVK via SWT, etc.).  Genuine per-model deviations (if any surface
  on the bench) would be added here as overrides, exactly as TKenwoodTS570Radio
  subclasses TKenwoodSerial and TIcom718Radio subclasses TIcomRadio.

  Serial-only (default 38400 baud, set from the .cfg via the factory -- see the
  K3 row in LOGRADIO.RadioParametersArray).  Registers itself so the factory +
  drop-down pick it up with no parallel array.

  MIGRATION SAFETY: registered here so a factory build routes K3 through the
  factory for bench validation on NY4I's K3.  The legacy path stays intact as the
  fallback until the K3 is hardware-proven.
}

interface

uses
  uRadioElecraftSerial, uFactoryRadioBase, uRadioRegistry, VC;

type
  TK3Radio = class(TElecraftSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TK3Radio.Create;
begin
  inherited Create;
  radioModel := 'Elecraft K3';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

initialization
  RegisterRadio(K3,
     function: TFactoryRadioBase begin Result := TK3Radio.Create end,
     'Elecraft K3', [rlSerial], 0, False,
     // 1 stop bit: Elecraft serial is 8N1 (NY4I 2026-07-30) -- see uRadioElecraftK2.
     SerialParams(38400, 8, PARITY_NONE, 1)
     );

end.
