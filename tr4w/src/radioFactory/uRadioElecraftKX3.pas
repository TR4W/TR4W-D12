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
unit uRadioElecraftKX3;

{
  Elecraft KX3 (serial CAT).  A thin per-model subclass of TElecraftSerial.
  Shares the K3's CAT command set and 38400 default baud (see the KX3 row in
  LOGRADIO.RadioParametersArray, identical to the K3's apart from hamlibID).
  It gets its own class and unit rather than reusing TKX3Radio: a KX3 is not a
  K3, and a later divergence must have somewhere to land that does not make a
  base ask which model it is.

  NOT BENCH-TESTED.  Registered because the legacy path treats it as a plain
  standard-Kenwood-dialect Elecraft, exactly as it treats the K3.
}

interface

uses
  uRadioElecraftSerial, uFactoryRadioBase, uRadioRegistry, VC;

type
  TKX3Radio = class(TElecraftSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TKX3Radio.Create;
begin
  inherited Create;
  radioModel := 'Elecraft KX3';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT];
end;

initialization
  RegisterRadio(KX3,
     function: TFactoryRadioBase begin Result := TKX3Radio.Create end,
     'Elecraft KX3', [rlSerial], 0, False,
     // 1 stop bit: Elecraft serial is 8N1 (NY4I 2026-07-30) -- see uRadioElecraftK2.
     SerialParams(38400, 8, PARITY_NONE, 1)
     ,
     2045
     );

end.
