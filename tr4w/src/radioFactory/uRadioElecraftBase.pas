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
unit uRadioElecraftBase;

{
  What every Elecraft radio has in common, regardless of how it is connected.

  Today that is the CW prosign spellings.  The K2/K3/KX3 (serial) and the K4
  (network) are separate classes with separate transports, and they were
  separate all the way down to TFactoryRadioBase -- so any fact true of
  "Elecraft" had to be stated twice.  That is not hypothetical: the K3 and K4
  each parse the same IF response, they drifted, and the same RIT/XIT bug was
  found and fixed twice.

  NEXT, agreed with NY4I 2026-08-04: ParseElecraftIF moves onto this class, so
  the two cannot drift again.  It is a separate commit because the IF parsing is
  bench-verified on both radios and a structural change to it deserves its own
  bisect point.
}

interface

uses
   uFactoryRadioBase, uRadioKYBase;

type
   TElecraftRadio = class(TKYRadio)
   protected
      procedure DeclareCWProsigns; override;
   end;

implementation

procedure TElecraftRadio.DeclareCWProsigns;
begin
   // Elecraft KY spellings.  Order: half space, SN, AR, SK, BT.
   //
   // The half space is a whole space: a KY string has no half space.
   //
   // '' FOR SN IS DELIBERATE AND IS NOT "undeclared".  Elecraft has no SN, so
   // TR4W's '!' is CONSUMED and keys nothing -- which is not the same as
   // letting '!' through to be keyed as a literal character.  See
   // TFactoryRadioBase.CWProsign, where a declared-but-empty spelling and an
   // undeclared grammar are two different answers.
   FCapabilities.CWProsigns := CWProsigns(' ', '', '+', '*', '=');
end;

end.
