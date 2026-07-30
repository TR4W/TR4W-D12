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
unit uRadioYaesuFTDX3000;

{
  Yaesu FTDX-3000 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  NOT VERIFIED AGAINST A MANUAL -- keeps the base defaults.  See uRadioYaesuFT450.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFTDX3000Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFTDX3000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-3000';
   // Base defaults kept deliberately -- see the header.
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync, rcPlayDVK];
end;

initialization
  RegisterRadio(FTDX3000,
     function: TFactoryRadioBase begin Result := TYaesuFTDX3000Radio.Create end,
     'Yaesu FTDX-3000', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
