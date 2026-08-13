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
unit uRadioIcomModern;
{$I ..\tr4w.inc}

{
  The MODERN CI-V read profile, shared by the current Icoms (IC-705, 7100, 7300,
  7300MK2, 7600, 7610, 7700, 7760, 7800, 7850, 7851, 905, 9700).  Registers
  NOTHING -- every model registers itself from its own unit.

  These radios can all READ:
    - the unselected VFO's frequency and mode ($25/$26)  -> rcReadVFOB
    - the RIT offset ($21)                               -> rcReadRIT
    - the split state ($0F)                              -> rcReadSplit
    - the TX status ($1C)                                -> rcReadTXStatus
    - and set/read data mode ($1A $06)                   -> rcDataMode
  with the CW keyer spanning 6..48 wpm for the $14 $0C level encode.

  WHY AN INTERMEDIATE CLASS AND NOT A BASE-CLASS DEFAULT.  This profile used to
  live in TIcomRadio.DefineCapabilities, which made the family default
  PERMISSIVE: an Icom subclass whose author forgot DefineCapabilities silently
  CLAIMED all five reads, and if the real rig NAKs them the failure shows up as
  bus collisions and misparsed frames on a bench -- exactly the class of bug the
  IC-718 work was about.  Now TIcomRadio promises nothing and a forgotten
  declaration fails SAFELY (a feature is visibly missing; nothing wrong ever
  goes on the wire).  The modern profile is a protocol fact shared by thirteen
  radios, so it is stated once here rather than pasted thirteen times.

  A modern radio that turns out to deviate overrides DefineCapabilities in its
  OWN unit (call inherited, then adjust) -- never here, and never by testing
  which model it is.
}

interface

uses uRadioIcomBase, uFactoryRadioBase;   // uFactoryRadioBase for TRadioCapability

type
  TIcomModernRadio = class(TIcomRadio)
  protected
    procedure DefineCapabilities; override;
  end;

implementation

procedure TIcomModernRadio.DefineCapabilities;
begin
  FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus, rcDataMode];
  FCapabilities.CWSpeedMin := 6;
  FCapabilities.CWSpeedMax := 48;
end;

end.
