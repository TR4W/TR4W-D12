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
unit uRadioYaesuFT450;

{
  Yaesu FT-450 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  NOT VERIFIED AGAINST A MANUAL.  It keeps the base defaults, which are the
  behaviour legacy gave the whole group:

      split          FR0;FT3; / FR0;FT2;   (FSplitAbsoluteTwoThree = True)
      FR read        not polled            (FReadsActiveVFO = False)

  The FT-950, FT-2000 and FTDX-9000 have each been checked against their manuals
  and DIVERGE from these defaults in different ways -- see uRadioYaesuFT2000 for
  the clearest example, where FT3; is not even a defined parameter.  So treat
  these defaults as unverified, not as "the same as the others".

  BENCH: confirm the FT command accepts 2/3 (absolute) rather than only 0/1.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFT450Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT450Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-450';
   // Base defaults kept deliberately -- see the header.
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateYaesuFT450: TFactoryRadioBase;
begin
   Result := TYaesuFT450Radio.Create;
end;

initialization
  RegisterRadio(FT450,
     CreateYaesuFT450,
     'Yaesu FT-450', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1027
     );

end.
