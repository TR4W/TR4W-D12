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
unit uRadioYaesuFT2000;

{
  Yaesu FT-2000 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  THE MODEL THAT PROVED THE GROUP IS NOT ONE RADIO.  Manual (via NY4I):

      FT  P1  0 = Main (VFO-A) transmitter    1 = Sub (VFO-B) transmitter
              -- and NOTHING ELSE.  There is no 2 and no 3.
      FR  P1  0..3  (Main RX/Sub OFF, Main Mute/Sub OFF, both RX, Main Mute/Sub RX)
              -- there is no 4.

  Both of TR4W's long-standing values were therefore wrong for this radio:

    - LOGRADIO Issue #166 moved the whole rtYaesu2 group from FR0;FT1; to
      FR0;FT3;.  Correct for the FT-950 and FTDX-9000, whose 0/1 are toggles --
      but FT3; is undefined here, so split has not worked on an FT-2000 since.
    - Legacy tested FR reply '4' for VFO B.  '4' cannot occur on this radio, so
      VFO B was never detected as the operating VFO.

  Fixed by declaring both traits, not by special-casing anything in the base.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFT2000Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT2000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-2000';
   FReadsActiveVFO := True;
   FSplitAbsoluteTwoThree := False;     // FT accepts ONLY 0 and 1
   FVFOBReceivingChars := ['3'];        // '4' does not exist here
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync];
end;

initialization
  RegisterRadio(FT2000,
     function: TFactoryRadioBase begin Result := TYaesuFT2000Radio.Create end,
     'Yaesu FT-2000', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
