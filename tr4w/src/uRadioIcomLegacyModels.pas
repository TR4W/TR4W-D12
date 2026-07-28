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
unit uRadioIcomLegacyModels;

{
  The remaining read-limited CI-V radios: 25 older Icoms plus the Ten-Tec Omni VI,
  which speaks CI-V and is grouped with them in the legacy table.

  Protocol and behaviour come entirely from TIcomLegacyRadio (uRadioIcomLegacy) --
  the conservative profile already bench-proven on the IC-706 family and IC-7000:
  active-VFO frequency via $03 only, no $25/$26 VFO-B reads, no RIT read, split
  set-only, no TX-status read.

  WHY THESE 26 AND NOT OTHERS.  Not a judgement call -- LOGRADIO's own capability
  table decides it.  IcomRadiosThatSupportRIT and IcomRadiosThatSupportVFOB name
  the thirteen Icoms that can read RIT and VFO B:

     IC-705, IC-7100, IC-7300, IC-7300MK2, IC-7600, IC-7610, IC-7700, IC-7760,
     IC-7800, IC-7850, IC-7851, IC-905, IC-9700

  Eleven of those thirteen already had their own units before this batch; the two
  that did not, IC-7700 and IC-7800, got units here.  So EVERY model left for this
  table is absent from both sets -- which is precisely the minimal profile
  TIcomLegacyRadio implements.  Those sets were built up from bench work over
  years, so they are better evidence than anything inferred from model numbers.

  That correspondence is not left to prose: uTestIcomRegistry walks every
  registered CI-V radio and asserts its rcReadRIT / rcReadVFOB flags agree with
  those two sets, so adding a model here that belongs in a set fails the build.

  CI-V ADDRESSES AND BAUD RATES are copied from RadioParametersArray in LOGRADIO
  (the RA and BR fields), one per model.  They are transcribed here rather than
  read from that array at runtime, following the rule the rest of the factory
  observes: the factory does not depend on the legacy data tables, so those tables
  can eventually retire.

  WHY A TABLE INSTEAD OF 26 UNITS.  These radios differ ONLY by CI-V address and
  name -- there is no protocol difference between them to write down, and 26 files
  containing a constructor apiece would obscure that rather than document it.  The
  established precedent is uRadioKenwoodModels (several models, one class) and
  uRadioIcomLegacy itself (four).

  Each still gets its own registry entry and its own display name, which is the
  part that matters to an operator: a model with no name of its own is invisible in
  the radio list.

  PROMOTION PATH -- the moment one of these needs to differ, give it a real class:

      TIcom756PROIIIRadio = class(TIcomLegacyRadio)   // in its own unit
      ...overrides the one thing that differs...

  and move its RegisterRadio call there.  Nothing else changes.  That is what
  happened to the IC-706 family, and it is why the split above is by CAPABILITY
  rather than by age.

  ****  NONE OF THESE IS BENCH-VALIDATED  ****

  BENCH NOTES, and the honest state of this profile: the minimal capability set is
  a SAFE assumption, not a verified one.  Several of these radios likely support
  more than $03 -- the IC-746PRO, IC-756PROIII and IC-9100 are all much newer than
  the IC-735 -- but reading a command the radio NAKs is worse than not asking, so
  the conservative profile is the right default until someone has one on the
  bench.  If a tester reports more capability, add the model to the relevant set
  and promote it to its own class.

  Specifically worth checking per radio: whether $0F split status reads back
  (currently assumed set-only), whether $1C TX status reads back, and whether
  $25/$26 answer at all.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioRegistry, VC;

type
  // ---------------------------------------------------------------------------
  // The profile for these 26: the FULL Icom profile MINUS the two reads that
  // LOGRADIO's sets say these radios do not have.  Nothing else is removed.
  //
  // WHY NOT TIcomLegacyRadio.  That class carries the conservative profile NY4I's
  // testers BENCH-PROVED on the IC-706 family and the IC-7000 -- its own header
  // says the siblings "fan out as more subclasses here ONCE THESE VALIDATE".
  // Attaching 26 unvalidated models to a profile derived empirically from four
  // OTHER radios silently withheld three things D7 does (NY4I caught this):
  //
  //     $0F split read     D7 polls it     -- IcomRadiosSplitSetOnly       = [IC718]
  //     $1C TX status      D7 polls it     -- IcomRadiosTXStatusUnreadable = [IC718]
  //     $06 filter byte    D7 sends it     -- IcomRadiosModeSetNoFilter    = [IC718]
  //
  // Every one of those deny-lists contains the IC-718 and nothing else, so for
  // these 26 radios D7's answer is "yes" in all three cases.  Data mode likewise:
  // D7 does not gate $1A06 on a list at all, it PROBES (icomHasDataMode, LOGRADIO
  // :283/:1565), so it sends $1A06 to every Icom -- meaning rcDataMode in, not out.
  //
  // The only two traits the sets genuinely withhold are VFO-B and RIT reads
  // (IcomRadiosThatSupportVFOB / ...RIT -- NY4I confirms those lists are accurate).
  //
  // uTestIcomRegistry now checks all FOUR sets against these flags, not two; the
  // two-set version passed this file while it was wrong.
  // ---------------------------------------------------------------------------
  TIcomReadLimitedRadio = class(TIcomRadio)
  protected
    procedure DefineCapabilities; override;
  end;

implementation

procedure TIcomReadLimitedRadio.DefineCapabilities;
begin
  inherited;   // full modern profile
  // These two, and ONLY these two, per LOGRADIO's capability sets.
  Exclude(FCapabilities.Flags, rcReadVFOB);
  Exclude(FCapabilities.Flags, rcReadRIT);
end;

// One constructor for all of them: identity only.  Anything beyond identity means
// the model has earned its own class -- see the promotion path in the header.
function MakeLegacyIcom(addr: Byte; const name: string): TFactoryRadioBase;
var
   r: TIcomReadLimitedRadio;
begin
   r := TIcomReadLimitedRadio.Create;
   r.RadioAddress := addr;
   r.radioModel := name;
   Result := r;
end;

initialization
  // CI-V address (RA) from RadioParametersArray.  The comment on each line is the
  // legacy default baud, which the operator sets in the CAT dialog -- recorded
  // here because it is easy to lose once RadioParametersArray retires.
  RegisterRadio(IC78,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($62, 'Icom IC-78') end,
     'Icom IC-78', [rlSerial], 0, False);           // 1200
  RegisterRadio(IC707,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($3E, 'Icom IC-707') end,
     'Icom IC-707', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC725,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($28, 'Icom IC-725') end,
     'Icom IC-725', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC726,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($30, 'Icom IC-726') end,
     'Icom IC-726', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC728,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($38, 'Icom IC-728') end,
     'Icom IC-728', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC729,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($3A, 'Icom IC-729') end,
     'Icom IC-729', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC735,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($04, 'Icom IC-735') end,
     'Icom IC-735', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC736,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($40, 'Icom IC-736') end,
     'Icom IC-736', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC737,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($3C, 'Icom IC-737') end,
     'Icom IC-737', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC738,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($44, 'Icom IC-738') end,
     'Icom IC-738', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC746,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($56, 'Icom IC-746') end,
     'Icom IC-746', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC746PRO,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($66, 'Icom IC-746PRO') end,
     'Icom IC-746PRO', [rlSerial], 0, False);       // 1200
  RegisterRadio(IC756,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($50, 'Icom IC-756') end,
     'Icom IC-756', [rlSerial], 0, False);          // 1200
  RegisterRadio(IC756PRO,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($5C, 'Icom IC-756PRO') end,
     'Icom IC-756PRO', [rlSerial], 0, False);       // 9600
  RegisterRadio(IC756PROII,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($64, 'Icom IC-756PROII') end,
     'Icom IC-756PROII', [rlSerial], 0, False);     // 9600
  RegisterRadio(IC756PROIII,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($6E, 'Icom IC-756PROIII') end,
     'Icom IC-756PROIII', [rlSerial], 0, False);    // 9600
  RegisterRadio(IC761,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($1E, 'Icom IC-761') end,
     'Icom IC-761', [rlSerial], 0, False);          // 9600
  RegisterRadio(IC765,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($2C, 'Icom IC-765') end,
     'Icom IC-765', [rlSerial], 0, False);          // 9600
  RegisterRadio(IC775,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($46, 'Icom IC-775') end,
     'Icom IC-775', [rlSerial], 0, False);          // 19200
  RegisterRadio(IC781,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($26, 'Icom IC-781') end,
     'Icom IC-781', [rlSerial], 0, False);          // 9600
  RegisterRadio(IC910,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($60, 'Icom IC-910') end,
     'Icom IC-910', [rlSerial], 0, False);          // 9600
  RegisterRadio(IC970D,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($2E, 'Icom IC-970D') end,
     'Icom IC-970D', [rlSerial], 0, False);         // 9600
  RegisterRadio(IC7200,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($76, 'Icom IC-7200') end,
     'Icom IC-7200', [rlSerial], 0, False);         // 19200
  RegisterRadio(IC7410,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($80, 'Icom IC-7410') end,
     'Icom IC-7410', [rlSerial], 0, False);         // 19200
  RegisterRadio(IC9100,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($7C, 'Icom IC-9100') end,
     'Icom IC-9100', [rlSerial], 0, False);         // 19200

  // Ten-Tec Omni VI -- NOT an Icom, but it speaks CI-V and the legacy table
  // classes it as rtIcom with address $04.  Named honestly in the radio list.
  RegisterRadio(OMNI6,
     function: TFactoryRadioBase begin Result := MakeLegacyIcom($04, 'Ten-Tec Omni VI') end,
     'Ten-Tec Omni VI (CI-V)', [rlSerial], 0, False);   // 9600

end.
