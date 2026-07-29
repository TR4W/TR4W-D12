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
unit uRadioKenwoodTS850;

{
  Kenwood TS-850 (serial CAT).  A thin per-model subclass of TKenwoodSerial --
  the TS-850 is a plain standard-Kenwood serial radio, so it only names itself
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
  TKenwoodTS850Radio = class(TKenwoodSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TKenwoodTS850Radio.Create;
begin
  inherited Create;
  radioModel := 'Kenwood TS-850';
end;

initialization
  RegisterRadio(TS850,
     function: TFactoryRadioBase begin Result := TKenwoodTS850Radio.Create end,
     'Kenwood TS-850', [rlSerial], 0, False);

end.
