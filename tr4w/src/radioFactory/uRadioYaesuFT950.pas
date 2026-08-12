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
unit uRadioYaesuFT950;

{
  Yaesu FT-950 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  Manual (via NY4I):

      FT  P1  0,1 = TX/RX TOGGLE   2 = VFO-A TX   3 = VFO-B TX
          P2  (answer) 0 = VFO-A TX, 1 = VFO-B TX
      FR  P1  0 = A RX / B OFF     1 = A Mute / B OFF
              4 = A OFF / B RX     5 = A OFF / B Mute

  Two things follow, and they do NOT group this radio with the same siblings:

    - Split uses the ABSOLUTE pair 2/3.  0/1 exist but are toggles and cannot set
      a definite state -- that is what LOGRADIO Issue #166 was fixing.
    - VFO B is reported by 4 OR 5.  Legacy tested only '4', so a muted VFO B
      (P1 = 5, still the receive VFO) was reported as VFO A.

  By the FT command this radio groups with the FTDX-9000; by the FR command it is
  the odd one out.  Hence flags rather than a class split.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFT950Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT950Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-950';
   FReadsActiveVFO := True;
   FSplitAbsoluteTwoThree := True;      // 2/3 absolute; 0/1 are toggles
   FVFOBReceivingChars := ['4', '5'];   // 5 = VFO-B muted, still the RX VFO
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateYaesuFT950: TFactoryRadioBase;
begin
   Result := TYaesuFT950Radio.Create;
end;

initialization
  RegisterRadio(FT950,
     CreateYaesuFT950,
     'Yaesu FT-950', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1028
     );

end.
