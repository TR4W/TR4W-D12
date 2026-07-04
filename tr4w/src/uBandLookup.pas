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
unit uBandLookup;

{
  Map an HF/VHF/UHF frequency in Hz to the TR4W legacy BandType + ModeType.

  Extracted verbatim from tree.pas (procedure CalculateBandMode) so the
  function can be unit-tested without dragging the rest of tree.pas
  (5,292 lines, Win32-dependent) into the test EXE.

  tree.pas still exports a public CalculateBandMode with the same
  signature; that implementation is now a one-line forward into this
  unit so every existing caller continues to work unchanged.

  Data source: FreqModeArray in VC.pas (25 entries, 160 m through 23 cm).
  Behavior: linear scan, first range hit wins, no match returns
  Band = NoBand and Mode = NoMode.

  Pre-migration test target -- see docs/tr4w-migration-strategy.md
  ("Tier 1 Extraction Pattern").
}

interface

uses VC;

procedure CalculateBandMode(Freq: Cardinal; var Band: BandType; var Mode: ModeType);

implementation

procedure CalculateBandMode(Freq: Cardinal; var Band: BandType; var Mode: ModeType);
var
   i: integer;
begin
   for i := 1 to FreqModeArraySize do
      begin
      if (Freq >= FreqModeArray[i].frMin) and (Freq <= FreqModeArray[i].frMax) then
         begin
         Band := FreqModeArray[i].frBand;
         Mode := FreqModeArray[i].frMode;
         Exit;
         end;
      end;
   Band := NoBand;
   Mode := NoMode;
end;

end.
