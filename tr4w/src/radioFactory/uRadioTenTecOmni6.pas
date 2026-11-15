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
unit uRadioTenTecOmni6;
{$I ..\tr4w.inc}

{
  Ten-Tec Omni VI (CI-V) -- CI-V address $04.

  Behaviour comes entirely from TIcomReadLimitedRadio (uRadioIcomReadLimited):
  the full modern Icom profile MINUS the unselected-VFO read ($25/$26) and the
  RIT read, because this model is absent from LOGRADIO's
  IcomRadiosThatSupportVFOB and IcomRadiosThatSupportRIT.  Split ($0F), TX status
  ($1C) and the $1A06 data-mode probe stay.

  THE $06 FILTER BYTE IS DROPPED IN CW (issue 181).  This header used to say D7
  sent it for every Icom but the IC-718; it did not.  D7's SetRadioFreq had
  `if (RadioModel = OMNI6) and (Mode = CW)` -> a frame with no filter byte
  (n4af 4.43.3), and the D7 report that became issue 181 ("Orion and Omni
  mode change ALT-M does not work") names the Omni.  FCWModeSetOmitsFilter
  carries that arm; phone and the other modes keep the filter byte, as in D7.
  NOT BENCHED: no Omni VI was available.

  Legacy default baud: 9600 (the operator sets this in the CAT dialog; recorded
  here because it is easy to lose once RadioParametersArray retires).

  NOT AN ICOM.  The Ten-Tec Omni VI speaks CI-V and the legacy table classes it
  as rtIcom with address $04 (the same address as the IC-735). Named honestly in
  the radio list so an operator is not hunting under Icom.

  ****  NOT BENCH-VALIDATED  ****
  If a tester shows this radio deviates, override DefineCapabilities HERE -- never
  add a model test to the shared base.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioIcomReadLimited,
     uRadioRegistry, VC;

type
  TTenTecOmni6Radio = class(TIcomReadLimitedRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TTenTecOmni6Radio.Create;
begin
   inherited Create;
   RadioAddress := $04;
   radioModel := 'Ten-Tec Omni VI (CI-V)';
   // CW mode set is $06 <mode> with no filter byte -- see the unit header.
   FCWModeSetOmitsFilter := True;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateTenTecOmni6: TFactoryRadioBase;
begin
   Result := TTenTecOmni6Radio.Create;
end;

initialization
  RegisterRadio(OMNI6,
     CreateTenTecOmni6,
     'Ten-Tec Omni VI (CI-V)', [rlSerial], 0, False,
     SerialParams(9600, 8, PARITY_NONE, 1)
     ,
     3051
     , 4);

end.
