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
unit uRadioYaesuFT890;

{
  Yaesu FT-890.

  A thin model on TYaesuFT840Group (uRadioYaesuFT840Group.pas), shared with the
  FT-840, FT-890 and FT-900.  Stated here: the display name and the set-mode row.

  AM is $04, unlike the FT-840 and FT-900; no data mode.

  NOT BENCH-TESTED.
}

interface

uses
  uRadioYaesuFT840Group, uRadioYaesuBinary, uFactoryRadioBase, uRadioBand,
  SysUtils, Log4D, VC, uRadioRegistry;

type
  TFT890Radio = class(TYaesuFT840Group)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFT890Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-890';

   // Set-mode row from LOGRADIO's radio table (SMOC $0C, MB 3).
   // MODEBYTE_NONE = the table's $FF, "this radio has no such mode".
   FSetModeOpcode := $0C;
   FModeByteIndex := 3;
   FModeCW   := $03;
   FModeLSB  := $00;
   FModeUSB  := $01;
   FModeAM   := $04;
   FModeFM   := $06;
   FModeDIGL := MODEBYTE_NONE;
   FModeDIGU := MODEBYTE_NONE;
end;

initialization
  RegisterRadio(FT890,
     function: TFactoryRadioBase begin Result := TFT890Radio.Create end,
     'Yaesu FT-890', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
