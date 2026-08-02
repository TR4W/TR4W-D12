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
unit uRadioYaesuFT1000;

{
  Yaesu FT-1000.

  A thin model on TYaesuFT990Group (uRadioYaesuFT990Group.pas), which holds
  everything this radio and the FT-990 share.

  Short status is 16 bytes, not the FT-990's 32; AM is $04, not $05.

  NOT BENCH-TESTED.
}

interface

uses
  uRadioYaesuFT990Group, uRadioYaesuBinary, uFactoryRadioBase,
  uRadioBand, SysUtils, Log4D, VC, uRadioRegistry;

type
  TFT1000Radio = class(TYaesuFT990Group)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFT1000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-1000';

   // Set-mode row from LOGRADIO's radio table (SMOC $0C, MB 3).
   // MODEBYTE_NONE = the table's $FF, "this radio has no such mode".
   FSetModeOpcode := $0C;
   FModeByteIndex := 3;
   FModeCW   := $03;
   FModeLSB  := $00;
   FModeUSB  := $01;
   FModeAM   := $04;
   FModeFM   := $06;
   FModeDIGL := $08;
   FModeDIGU := $09;
   FStatus1Len := 16;          // legacy: `if RadioModel = FT1000 then F1 := 16`
   RecomputeFrameLength;
end;

initialization
  RegisterRadio(FT1000,
     function: TFactoryRadioBase begin Result := TFT1000Radio.Create end,
     'Yaesu FT-1000', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1003
     );

end.
