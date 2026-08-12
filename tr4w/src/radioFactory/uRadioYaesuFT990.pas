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
unit uRadioYaesuFT990;

{
  Yaesu FT-990.

  A thin model on TYaesuFT990Group (uRadioYaesuFT990Group.pas), which holds
  everything this radio and the FT-1000 share.

  Short status is 32 bytes; AM is $05.

  NOT BENCH-TESTED.
}

interface

uses
  uRadioYaesuFT990Group, uRadioYaesuBinary, uFactoryRadioBase,
  uRadioBand, SysUtils, Log4D, VC, uRadioRegistry;

type
  TFT990Radio = class(TYaesuFT990Group)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFT990Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-990';

   // Set-mode row from LOGRADIO's radio table (SMOC $0C, MB 3).
   // MODEBYTE_NONE = the table's $FF, "this radio has no such mode".
   FSetModeOpcode := $0C;
   FModeByteIndex := 3;
   FModeCW   := $03;
   FModeLSB  := $00;
   FModeUSB  := $01;
   FModeAM   := $05;
   FModeFM   := $06;
   FModeDIGL := $08;
   FModeDIGU := $09;
   FStatus1Len := 32;          // FT-990; the FT-1000 subclass sets 16
   RecomputeFrameLength;
   pollingInterval := 200;

   // Capabilities = what this driver actually reads:
   //   rcReadVFOB  -- the $03 $10 block carries both VFOs
   //   rcReadSplit -- the $FA block reports it
   //   rcReadRIT   -- the short status carries the RIT offset and its flags
   // NOT rcReadTXStatus: nothing in these three answers reports PTT.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit, rcReadRIT];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateFT990: TFactoryRadioBase;
begin
   Result := TFT990Radio.Create;
end;

initialization
  RegisterRadio(FT990,
     CreateFT990,
     'Yaesu FT-990', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1016
     );

end.
