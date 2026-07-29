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

unit uRadioYaesuFTDX10;

{
  Yaesu FTDX-10 -- the rtYaesu4 exemplar, and the model the Yaesu ASCII CAT base
  was ported from.

  The protocol lives in uRadioYaesuASCII (TYaesuSerial); this unit is the MODEL:
  display name, capabilities, and any genuine per-model deviation.  Today there are
  none, so the class is just a constructor.  That is the intended shape of a
  per-model unit, not a sign that something is missing.

  Adding a near-identical Yaesu?  Copy THIS file, not the base -- you get a model
  unit with nothing to delete, and you override only what actually differs.  See
  the contract at the top of uRadioYaesuASCII, and uRadioYaesuFT991 for a live
  example (it overrides exactly one mode character).

  BENCH NOTES (flag for validation on real FTDX-10 hardware):
    - The full mode-char map at IF pos 22 is the common Yaesu set; verify the
      less-common chars (DATA/PSK variants) on the radio.
    - The clarifier (RIT offset) field at pos 15-19 is parsed as sign + 4 digits;
      confirm the FTDX-10 returns "+0000"/"-0000" there.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, VC;

type

  // FTDX-10 -- the rtYaesu4 exemplar (28-byte IF/OI, FT3;/FT2; split).
  TFTDX10Radio = class(TYaesuSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFTDX10Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-10';
   // Capabilities (declarative -- Yaesu does not consume FCapabilities yet; drives
   // the '-u' dump).  FTDX10 reads VFO B (OI;), RIT/clarifier, split (FT;), TX (TX;).
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
end;

initialization
  RegisterRadio(FTDX10,
     function: TFactoryRadioBase begin Result := TFTDX10Radio.Create end,
     'Yaesu FTDX-10', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
