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
unit uRadioKenwoodTS570;

{
  Kenwood TS-570 (serial CAT).  A thin per-model subclass of TKenwoodSerial --
  the TS-570 is a plain standard-Kenwood serial radio, so it only names itself
  and inherits the whole family CAT implementation.  Genuine per-model
  deviations (if any surface on the bench) would be added here as overrides,
  exactly as TIcom718Radio overrides TIcomRadio.

  Serial-only (default 4800 baud, set from the .cfg via the factory).  Registers
  itself so the factory + drop-down pick it up with no parallel array.
}

interface

uses
  uRadioKenwoodSerial, uFactoryRadioBase, uRadioRegistry, VC;

type
  TKenwoodTS570Radio = class(TKenwoodSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TKenwoodTS570Radio.Create;
begin
  inherited Create;
  radioModel := 'Kenwood TS-570';
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

initialization
  RegisterRadio(TS570,
     function: TFactoryRadioBase begin Result := TKenwoodTS570Radio.Create end,
     'Kenwood TS-570', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
