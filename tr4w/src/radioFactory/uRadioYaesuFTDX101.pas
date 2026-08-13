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
unit uRadioYaesuFTDX101;
{$I ..\tr4w.inc}

{
  Yaesu FTDX-101D / FTDX-101MP -- rtYaesu4, migrated from uRadioPolling.

  NO DEVIATIONS from the FTDX-10.  The legacy poller pFTDX10_FTDX101 handles both
  with the same code and the same Type5 mode map, and every LOGRADIO send arm
  lists FTDX101 next to FTDX10 -- split (FT3;/FT2;), UP, DN, MemoryKeyer.  So this
  unit is a constructor and nothing else, which is the intended shape of a model
  unit rather than a sign that something is missing.

  It exists as its own unit and its own registry entry because an operator buys an
  FTDX-101, not "an FTDX-10 that also covers the 101": a model without its own
  display name is invisible in the radio list.  It also gives the 101 somewhere to
  put a deviation the day one is found, without disturbing the FTDX-10.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES: the whole driver, since nothing here has been exercised against a
  real 101.  The riskiest assumption is that the IF/OI response is 28 bytes with
  the same field offsets as the FTDX-10 -- the FTX-1F, a later radio in the same
  ASCII family, moved every field by two and grew to 30 bytes (see
  uRadioYaesuFTX1F), so this is exactly the kind of thing that changes between
  generations.  If frequency reads as nonsense, check the response length first.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, VC;

type
  TFTDX101Radio = class(TYaesuSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFTDX101Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-101';
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
   // FModeCharE stays rmPSK -- the 101 has no C4FM.
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync, rcPlayDVK];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateFTDX101: TFactoryRadioBase;
begin
   Result := TFTDX101Radio.Create;
end;

initialization
  RegisterRadio(FTDX101,
     CreateFTDX101,
     'Yaesu FTDX-101', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1040
     );

end.
