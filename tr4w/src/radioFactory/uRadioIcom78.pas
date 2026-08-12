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
unit uRadioIcom78;

{
  Icom IC-78 -- CI-V address $62.

  Behaviour comes entirely from TIcomReadLimitedRadio (uRadioIcomReadLimited):
  the full modern Icom profile MINUS the unselected-VFO read ($25/$26) and the
  RIT read, because this model is absent from LOGRADIO's
  IcomRadiosThatSupportVFOB and IcomRadiosThatSupportRIT.  Split ($0F), TX status
  ($1C), the $06 filter byte and the $1A06 data-mode probe all stay -- D7 does
  all four for every Icom except the IC-718.

  Legacy default baud: 1200 (the operator sets this in the CAT dialog; recorded
  here because it is easy to lose once RadioParametersArray retires).

  ****  NOT BENCH-VALIDATED  ****
  If a tester shows this radio deviates, override DefineCapabilities HERE -- never
  add a model test to the shared base.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioIcomReadLimited,
     uRadioRegistry, VC;

type
  TIcom78Radio = class(TIcomReadLimitedRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TIcom78Radio.Create;
begin
   inherited Create;
   RadioAddress := $62;
   radioModel := 'Icom IC-78';
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom78: TFactoryRadioBase;
begin
   Result := TIcom78Radio.Create;
end;

initialization
  RegisterRadio(IC78,
     CreateIcom78,
     'Icom IC-78', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     ,
     3045
     , 98);

end.
