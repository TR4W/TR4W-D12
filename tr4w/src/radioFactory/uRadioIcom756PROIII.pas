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
unit uRadioIcom756PROIII;

{
  Icom IC-756PROIII -- CI-V address $6E.

  Behaviour comes entirely from TIcomReadLimitedRadio (uRadioIcomReadLimited):
  the full modern Icom profile MINUS the unselected-VFO read ($25/$26) and the
  RIT read, because this model is absent from LOGRADIO's
  IcomRadiosThatSupportVFOB and IcomRadiosThatSupportRIT.  Split ($0F), TX status
  ($1C), the $06 filter byte and the $1A06 data-mode probe all stay -- D7 does
  all four for every Icom except the IC-718.

  Legacy default baud: 9600 (the operator sets this in the CAT dialog; recorded
  here because it is easy to lose once RadioParametersArray retires).

  NOTE: this is a much later radio than most in this profile, so it may well
  support more than the profile claims. NY4I confirmed the VFOB/RIT lists are
  accurate, so those two stay off; anything else is a bench question.

  ****  NOT BENCH-VALIDATED  ****
  If a tester shows this radio deviates, override DefineCapabilities HERE -- never
  add a model test to the shared base.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioIcomReadLimited,
     uRadioRegistry, VC;

type
  TIcom756PROIIIRadio = class(TIcomReadLimitedRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TIcom756PROIIIRadio.Create;
begin
   inherited Create;
   RadioAddress := $6E;
   radioModel := 'Icom IC-756PROIII';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync];
end;

initialization
  RegisterRadio(IC756PROIII,
     function: TFactoryRadioBase begin Result := TIcom756PROIIIRadio.Create end,
     'Icom IC-756PROIII', [rlSerial], 0, False,
     SerialParams(9600, 8, PARITY_NONE, 1)
     );

end.
