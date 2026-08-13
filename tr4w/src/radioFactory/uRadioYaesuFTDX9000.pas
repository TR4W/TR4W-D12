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
unit uRadioYaesuFTDX9000;
{$I ..\tr4w.inc}

{
  Yaesu FTDX-9000 -- rtYaesu2 generation.  Protocol lives in uRadioYaesuASCIILegacy.

  Manual (via NY4I):

      FT  P1  0,1 = TX/RX TOGGLE   2 = TX on Main (VFO-A)   3 = TX on Sub (VFO-B)
          P2  (answer) 0 = Main, 1 = Sub
      FR  P1  0 = Main RX / Sub OFF    1 = Main Mute / Sub OFF
              2 = Main RX / Sub RX     3 = Main Mute / Sub RX

  TRUE DUAL RECEIVE -- P1 = 2 means BOTH receivers are live.  TR4W has a single
  "operating VFO", so only 3 (Main muted, Sub RX) is treated as VFO B; with both
  live the Main is the primary.  That is a judgement call, not a manual statement.

  Note FR here is 0..3, NOT the FT-950's 0,1,4,5 -- legacy's '4' test could never
  fire on this radio, so VFO B was never detected.  Split, by contrast, uses the
  same absolute 2/3 as the FT-950.  The two commands group this radio with
  different siblings, which is why both are flags.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  TYaesuFTDX9000Radio = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFTDX9000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-9000';
   FReadsActiveVFO := True;
   FSplitAbsoluteTwoThree := True;      // FT like the FT-950
   FVFOBReceivingChars := ['3'];        // FR like the FT-2000; 2 = both live
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync, rcPlayDVK];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateYaesuFTDX9000: TFactoryRadioBase;
begin
   Result := TYaesuFTDX9000Radio.Create;
end;

initialization
  RegisterRadio(FTDX9000,
     CreateYaesuFTDX9000,
     'Yaesu FTDX-9000', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1030
     );

end.
