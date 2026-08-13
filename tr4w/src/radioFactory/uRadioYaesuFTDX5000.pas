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
unit uRadioYaesuFTDX5000;
{$I ..\tr4w.inc}

{
  Yaesu FTDX-5000 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  NOT VERIFIED AGAINST A MANUAL -- keeps the base defaults.  See uRadioYaesuFT450.

  Worth a manual check before a contest: this is a dual-receive radio like the
  FTDX-9000, and that is exactly the trait that made the FTDX-9000's FR command
  mean something different from the FT-950's.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFTDX5000Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFTDX5000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-5000';
   // Base defaults kept deliberately -- see the header.
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync, rcPlayDVK];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateYaesuFTDX5000: TFactoryRadioBase;
begin
   Result := TYaesuFTDX5000Radio.Create;
end;

initialization
  RegisterRadio(FTDX5000,
     CreateYaesuFTDX5000,
     'Yaesu FTDX-5000', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1032
     );

end.
