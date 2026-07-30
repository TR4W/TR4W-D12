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
unit uRadioYaesuFT897;

{
  Yaesu FT-897.

  A thin model on TYaesuFT817Group (uRadioYaesuFT817Group.pas), shared with the
  FT-817, FT-818, FT-847, FT-857 and FT-897.

  Same CAT set as the FT-857, including DIGL $FF.  It used to descend FROM the
  FT-857, making it three models deep off the FT-817.

  Every trait is stated explicitly, even where it matches another model in the
  group.  The base promises nothing, so a trait left unsaid means the feature is
  absent -- which fails visibly rather than emitting an undefined opcode.

  NOT BENCH-TESTED.
}

interface

uses
  uRadioYaesuFT817Group, uRadioYaesuBinary, uFactoryRadioBase, uRadioBand,
  SysUtils, Log4D, VC, uRadioRegistry;

type
  TYaesuFT897Radio = class(TYaesuFT817Group)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT897Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT897');
   radioModel := 'Yaesu FT-897';

   // Group traits.
   FCATEnableOnConnect := False;              // answers without a CAT preamble
   FHasSplit           := True;
   FHasRIT       := True;
   FModeDIGU           := FT817_MODE_DIGU;    // $0A
   FModeDIGL           := MODEBYTE_NONE;      // no PKT-as-RTTY
   // Split IS read back, from the appended TX-status byte.
   //   NOT rcReadRIT      -- the RIT offset is set-only; nothing reports it.
   //   NOT rcReadTXStatus -- the PTT bit exists but Note 4 omits its polarity.
   //   NOT rcReadVFOB     -- only one VFO is reported.
   FCapabilities.Flags := [rcReadSplit];
end;

initialization
  RegisterRadio(FT897,
     function: TFactoryRadioBase begin Result := TYaesuFT897Radio.Create end,
     'Yaesu FT-897', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
