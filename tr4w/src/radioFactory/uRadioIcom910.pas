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
unit uRadioIcom910;
{$I ..\tr4w.inc}

{
  Icom IC-910 -- CI-V address $60.

  Behaviour comes entirely from TIcomReadLimitedRadio (uRadioIcomReadLimited):
  the full modern Icom profile MINUS the unselected-VFO read ($25/$26) and the
  RIT read, because this model is absent from LOGRADIO's
  IcomRadiosThatSupportVFOB and IcomRadiosThatSupportRIT.  Split ($0F), TX status
  ($1C), the $06 filter byte and the $1A06 data-mode probe all stay -- D7 does
  all four for every Icom except the IC-718.

  Legacy default baud: 9600 (the operator sets this in the CAT dialog; recorded
  here because it is easy to lose once RadioParametersArray retires).

  ****  NOT BENCH-VALIDATED  ****
  If a tester shows this radio deviates, override DefineCapabilities HERE -- never
  add a model test to the shared base.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioIcomReadLimited,
     uRadioRegistry, VC;

type
  TIcom910Radio = class(TIcomReadLimitedRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TIcom910Radio.Create;
begin
   inherited Create;
   RadioAddress := $60;
   radioModel := 'Icom IC-910';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom910: TFactoryRadioBase;
begin
   Result := TIcom910Radio.Create;
end;

initialization
  RegisterRadio(IC910,
     CreateIcom910,
     'Icom IC-910', [rlSerial], 0, False,
     SerialParams(9600, 8, PARITY_NONE, 1)
     ,
     3044
     , 96);


  { HISTORICAL SPELLING. tr4w.ini has always written this model as 'IC910H',
    which is not its enum name, so it is declared rather than derived --
    otherwise every existing config naming this radio would stop parsing. }
  MarkConfigToken(IC910, 'IC910H');

end.
