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
unit uRadioYaesuFT840;

{
  Yaesu FT-840, FT-890 and FT-900 -- migrated from uRadioPolling.pFT840_FT890_FT900.

  The SIMPLEST driver in the old-binary family: ONE request, ONE 19-byte answer
  carrying everything TR4W reads.

      $00 $00 $00 $02 $10  ->  19 bytes

  Compare the siblings, all of which share these write opcodes ($0A / $0C) yet
  need different readers -- which is why each has its own unit:

      FT-840/890/900   19 bytes, one poll        <- this unit
      FT-920           28 bytes, one poll
      FT-990           32 + 32 + 5, three polls  (uRadioYaesuFT990)
      FT-1000          16 + 32 + 5, three polls  (same unit, different length)
      FT-1000MP        32 + 6,      two polls    (uRadioYaesuFT1000MP)
      FT-747GX        344 bytes(!), one poll
      FT-100           32 bytes, frequency x 1.25

  FIELD LAYOUT of the 19-byte answer (1-based, matching the legacy 1-based tBuf):

      byte  1     flags -- bit 6 ($40) = SPLIT
      bytes 3-5   VFO A frequency, 3 bytes big-endian, units of 10 Hz
      bytes 6-7   clarifier offset, SIGNED 16-bit LITTLE-endian (see below)
      byte  8     VFO A mode
      bytes 12-14 VFO B frequency, same encoding
      byte  17    VFO B mode

  THE CLARIFIER IS LITTLE-ENDIAN WHILE THE FREQUENCY IS BIG-ENDIAN.  Legacy reads
  it by pointing a ^SmallInt at the buffer:

      RITFreqPtr := @rig.tBuf[6];  RITFreq := RITFreqPtr^;

  On x86 that is a little-endian signed 16-bit load, so the two fields genuinely
  use opposite byte orders in the same frame.  Reproduced explicitly here rather
  than by pointer-casting a string, which would be both unsafe and silently
  endian-dependent.

  NO RIT ON/OFF FLAG.  The frame carries the clarifier OFFSET but nothing that
  says whether the clarifier is switched on, so rcReadRIT is NOT claimed: TR4W
  cannot tell "clarifier off" from "clarifier on at 0 Hz".

  ****  NONE OF THESE IS BENCH-VALIDATED -- keep all three on the tester list  ****

  BENCH NOTES:
    - Confirm bit 6 of byte 1 really is split (legacy's only split source here).
    - Confirm the clarifier byte order on a real radio by setting a known
      positive offset: if it reads back as a large or negative number, the two
      bytes want swapping.
    - The three models share one legacy procedure with no model tests at all, so
      they are believed identical. If a tester finds otherwise, the deviating
      model gets its own subclass here -- not an `if` in this class.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   FT840_POLL_P4 = $02;
   FT840_POLL_P5 = $10;
   FT840_FRAME_LEN = 19;

   FT840_FLAGS_POS     = 1;
   FT840_SPLIT_BIT     = $40;    // bit 6
   FT840_VFOA_FREQ_POS = 3;      // 3 bytes, big-endian, x10 Hz
   FT840_CLAR_POS      = 6;      // 2 bytes, signed, LITTLE-endian
   FT840_VFOA_MODE_POS = 8;
   FT840_VFOB_FREQ_POS = 12;
   FT840_VFOB_MODE_POS = 17;

   // Write opcodes (row: SFOC $0A, SMOC $0C, SW 1, MB 3).
   FT840_SET_FREQ_OPCODE = $0A;

type
  TFT840Radio = class(TYaesuBinary)
  protected
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
  end;

  // Identity-only subclasses: one registry entry per model an operator can buy,
  // so each appears in the radio list under its own name.
  TFT890Radio = class(TFT840Radio)
  public
    constructor Create; reintroduce;
  end;

  TFT900Radio = class(TFT840Radio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFT840Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT840');
   radioModel := 'Yaesu FT-840';
   SerialFixedFrameLength := FT840_FRAME_LEN;
   pollingInterval := 200;

   // rcReadVFOB  -- both VFOs are in the frame.
   // rcReadSplit -- byte 1 bit 6.
   // NOT rcReadRIT: the offset is present but nothing reports RIT on/off, so we
   // cannot distinguish "off" from "on at zero" (see the unit header).
   // NOT rcReadTXStatus: nothing in the frame reports PTT.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

constructor TFT890Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT890');
   radioModel := 'Yaesu FT-890';
end;

constructor TFT900Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT900');
   radioModel := 'Yaesu FT-900';
end;

procedure TFT840Radio.PollRadioState;
begin
   Self.SendBytes($00, $00, $00, FT840_POLL_P4, FT840_POLL_P5);
end;

// 3 bytes big-endian, units of 10 Hz (legacy GetFrequencyForYaesu3).
function TFT840Radio.FreqRead(const frame: string; pos1: integer): integer;
begin
   Result := (Ord(frame[pos1]) * 65536 + Ord(frame[pos1 + 1]) * 256 +
              Ord(frame[pos1 + 2])) * 10;
end;

function TFT840Radio.StatusModeToMode(b: Byte): TRadioMode;
begin
   // Same status-block numbering as the FT-990 and FT-1000MP.  Legacy collapsed
   // 0/1/3 to "Phone" and 5/6 to "Digital"; the factory keeps what the radio says.
   case b and $07 of
      0: Result := rmLSB;
      1: Result := rmUSB;
      2: Result := rmCW;
      3: Result := rmAM;
      4: Result := rmFM;
      5: Result := rmFSK;
      6: Result := rmData;
   else
      Result := rmNone;
   end;
end;

procedure TFT840Radio.ProcessMsg(msg: string);
var
   clarRaw: Word;
begin
   if Length(msg) < FT840_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',
                  [Length(msg), FT840_FRAME_LEN]);
      Exit;
      end;

   Self.SetSplitOn((Ord(msg[FT840_FLAGS_POS]) and FT840_SPLIT_BIT) <> 0);

   Self.vfo[nrVFOA].frequency := FreqRead(msg, FT840_VFOA_FREQ_POS);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[FT840_VFOA_MODE_POS]));

   Self.vfo[nrVFOB].frequency := FreqRead(msg, FT840_VFOB_FREQ_POS);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[FT840_VFOB_MODE_POS]));

   // LITTLE-endian signed 16-bit, unlike the big-endian frequency above -- see
   // the unit header.  Built explicitly instead of casting a pointer.
   clarRaw := Word(Ord(msg[FT840_CLAR_POS])) or
              (Word(Ord(msg[FT840_CLAR_POS + 1])) shl 8);
   Self.SetRITOffset(SmallInt(clarRaw));

   Self.SetActiveVFO(nrVFOA);
end;

procedure TFT840Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   f10: LongWord;
   b: array[0..3] of Byte;
   i: integer;
begin
   if freq < 0 then
      begin
      logger.Error('[SetFrequency] negative frequency %d', [freq]);
      Exit;
      end;
   // Row SW=1: BCD, byte-swapped (least-significant byte first).
   f10 := LongWord(freq div 10);
   for i := 0 to 3 do
      begin
      b[i] := Byte((f10 mod 10) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   Self.SendBytes(b[0], b[1], b[2], b[3], FT840_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

initialization
  RegisterRadio(FT840,
     function: TFactoryRadioBase begin Result := TFT840Radio.Create end,
     'Yaesu FT-840', [rlSerial], 0, False);
  RegisterRadio(FT890,
     function: TFactoryRadioBase begin Result := TFT890Radio.Create end,
     'Yaesu FT-890', [rlSerial], 0, False);
  RegisterRadio(FT900,
     function: TFactoryRadioBase begin Result := TFT900Radio.Create end,
     'Yaesu FT-900', [rlSerial], 0, False);

end.
