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
unit uRadioKenwoodModels;

{
  Kenwood serial models -- registry roster for the standard-Kenwood serial radios
  that are DATA-identical (same CAT command set + parameters as the TS-570).

  The legacy code routes every one of these through the SAME poll routine
  (uRadioPolling pKenwood2, dispatched uniformly -- the pKenwoodNew/pKenwood2
  split is a compile-time MASKEVENT switch, not per-radio) and their
  RadioParametersArray rows are byte-identical (BR4800, rt:rtKenwood, all-$00
  opcodes).  So they are the concrete TKenwoodSerial base with only a different
  display name -- registered here as data rows rather than as N near-duplicate
  subclass units.  A radio that turns out to deviate on a tester GRADUATES to its
  own subclass (as TS-570 keeps its own unit); this roster is only the identical
  common case.

  The TS-570 (uRadioKenwoodTS570) is the bench-validated exemplar and keeps its
  own unit.  The TS-890/990 are network radios (uRadioKenwoodTS890) and are NOT
  here -- their serial config still uses the legacy path.

  MIGRATION SAFETY: only the models with real hardware behind them (TS-590,
  TS-2000, TS-480 via NY4I's testers/volunteers) are registered so far.  The blind
  siblings (TS-140/440/450/690/850/870/940/950) are held until they have a tester,
  so the legacy path stays the live fallback for the unproven ones.
}

interface

implementation

uses
  uRadioKenwoodSerial, uRadioRegistry, uFactoryRadioBase, VC;

initialization
  // Hardware-testable first (NY4I testers).  Blind siblings added after these pass.
  RegisterRadio(TS590,
     function: TFactoryRadioBase begin Result := TKenwoodSerial.Create end,
     'Kenwood TS-590', [rlSerial], 0, False);
  RegisterRadio(TS2000,
     function: TFactoryRadioBase begin Result := TKenwoodSerial.Create end,
     'Kenwood TS-2000', [rlSerial], 0, False);
  // TS-480: added -- a volunteer has hardware to bench it.
  RegisterRadio(TS480,
     function: TFactoryRadioBase begin Result := TKenwoodSerial.Create end,
     'Kenwood TS-480', [rlSerial], 0, False);

end.
