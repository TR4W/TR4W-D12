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
unit uRadioElecraftK2;

{
  Elecraft K2 (serial CAT).  A thin per-model subclass of TElecraftSerial.

  DEFAULT BAUD IS 4800, not the K3/KX3's 38400 (LOGRADIO row 'K2') -- the
  factory takes the rate from the .cfg, so this is a note for whoever benches
  it rather than something set here.

  The K2 is the OLDEST radio in this family and the most likely to diverge:
  its CAT set is smaller than the K3's.  Anything it cannot do belongs here as
  an override or a capability flag, never as a model test inside the base.

  NOT BENCH-TESTED.
}

interface

uses
  uRadioElecraftSerial, uFactoryRadioBase, uRadioRegistry, VC;

type
  TK2Radio = class(TElecraftSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TK2Radio.Create;
begin
  inherited Create;
  radioModel := 'Elecraft K2';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

initialization
  RegisterRadio(K2,
     function: TFactoryRadioBase begin Result := TK2Radio.Create end,
     'Elecraft K2', [rlSerial], 0, False,
     // 1 stop bit: Elecraft serial is 8N1 (NY4I 2026-07-30, corroborated by the
     // Elecraft docs and HamLib's kenwood/elecraft backends).  The old 2 came
     // from the legacy blanket "everything non-CI-V gets 2 stop bits" rule.
     SerialParams(4800, 8, PARITY_NONE, 1)
     );

end.
