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
unit uRadioYaesuFT920;

{
  Yaesu FT-920 -- migrated from uRadioPolling.pFT920.

  Shares the old-binary transport and the $0A/$0C write opcodes with its
  siblings, and differs from every one of them in BOTH of the things that matter:

  1. FREQUENCY IS A RAW 4-BYTE BIG-ENDIAN VALUE (GetFrequencyForYaesu4) with no
     scaling -- not the 3-byte x10 Hz form of the FT-840/FT-990, and not the
     FT-1000MP's 4-byte x0.625, and not the FT-100's 4-byte x1.25.  Four models,
     four different frequency encodings, same opcodes.

  2. THE MODE NUMBERING IS ITS OWN:

         FT-920 (this unit)        FT-990 / FT-840 / FT-1000MP
           1 = CW                    2 = CW
           3 = FM                    4 = FM
           4,5,6 = Digital           5,6 = Digital
           anything else = Phone     0/1/3 = LSB/USB/AM

     Legacy reads it as `case (Ord(tBuf[8]) and $07)` with an `else` arm, so
     everything outside 1/3/4/5/6 is Phone.  That `else` is why this map cannot
     be refined the way the siblings' were: legacy never distinguished LSB from
     USB here, and the numbering is demonstrably not the sibling one, so
     guessing which of 0/2/7 is LSB and which is USB would be invention.
     rmUSB is used for all of them, and the bench note below says what to check.

  POLL CYCLE -- two requests, always in this order, concatenating into one frame:

      $00 $00 $00 $02 $10  -> 28 bytes : current VFO, mode, RIT/XIT flags
      $00 $00 $00 $03 $10  -> 28 bytes : VFO A and VFO B

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - THE MODE MAP IS THE THING TO CHECK.  Put the radio in LSB and then USB and
      read the log: both currently report USB.  Whichever byte values appear,
      write them into StatusModeToMode -- the information simply is not in the
      legacy code.
    - Confirm the frequency needs no scaling.  If it reads ~1.25x or 0.625x off,
      this radio shares an encoding with the FT-100 or FT-1000MP instead.
    - Nothing here reports split, so rcReadSplit is not claimed.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   FT920_STATUS1_P4 = $02;   FT920_STATUS1_P5 = $10;
   FT920_STATUS2_P4 = $03;   FT920_STATUS2_P5 = $10;

   FT920_BLOCK_LEN = 28;
   FT920_FRAME_LEN = FT920_BLOCK_LEN * 2;   // 56

   // Within block 1 (1-based).
   FT920_S1_FREQ_POS  = 2;    // 4 bytes, big-endian, raw
   FT920_S1_MODE_POS  = 8;
   FT920_S1_FLAGS_POS = 9;    // bit0 = XIT, bit1 = RIT

   // Within block 2 (1-based).
   FT920_S2_VFOA_FREQ = 2;
   FT920_S2_VFOA_MODE = 8;
   FT920_S2_VFOB_FREQ = 16;
   FT920_S2_VFOB_MODE = 22;

   FT920_SET_FREQ_OPCODE = $0A;

type
  TFT920Radio = class(TYaesuBinary)
  protected
    // hz is needed because this radio's mode byte reports only "phone" for
    // several values; the sideband comes from the frequency (see
    // TYaesuBinary.PhoneModeForFreq).
    function  StatusModeToMode(b: Byte; hz: integer): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
  end;

implementation

constructor TFT920Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT920');
   radioModel := 'Yaesu FT-920';

   // Set-mode row from LOGRADIO's radio table (SMOC $0C, MB 3).
   // MODEBYTE_NONE = the table's $FF, "this radio has no such mode".
   FSetModeOpcode := $0C;
   FModeByteIndex := 3;
   FModeCW   := $02;
   FModeLSB  := $00;
   FModeUSB  := $01;
   FModeAM   := $04;
   FModeFM   := $06;
   FModeDIGL := $08;
   FModeDIGU := $0A;
   SerialFixedFrameLength := FT920_FRAME_LEN;
   pollingInterval := 200;

   // rcReadVFOB -- block 2 carries both VFOs.
   // rcReadRIT  -- block 1 byte 9 reports RIT and XIT on/off.  NOTE: the OFFSET
   //               is not in either answer, so TR4W knows the clarifier is on
   //               but not by how much.
   // NOT rcReadSplit, NOT rcReadTXStatus: neither answer carries them.
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

procedure TFT920Radio.PollRadioState;
begin
   Self.SendBytes($00, $00, $00, FT920_STATUS1_P4, FT920_STATUS1_P5);
   Self.SendBytes($00, $00, $00, FT920_STATUS2_P4, FT920_STATUS2_P5);
end;

// 4 bytes, big-endian, RAW (legacy GetFrequencyForYaesu4, no scaling here).
function TFT920Radio.FreqRead(const frame: string; pos1: integer): integer;
begin
   Result := Ord(frame[pos1])     * 16777216 +
             Ord(frame[pos1 + 1]) * 65536 +
             Ord(frame[pos1 + 2]) * 256 +
             Ord(frame[pos1 + 3]);
end;

function TFT920Radio.StatusModeToMode(b: Byte; hz: integer): TRadioMode;
begin
   // FT-920 numbering -- NOT the sibling map.  Legacy's `else -> Phone` is the
   // ROLL-UP level (ModeType); it does not distinguish LSB from USB, and the
   // legacy poller never sets ExtendedMode for this radio either.  So the
   // sideband is derived from frequency by convention rather than asserted.
   case b and $07 of
      1: Result := rmCW;
      3: Result := rmFM;
      4: Result := rmData;
      5: Result := rmData;
      6: Result := rmData;
   else
      Result := PhoneModeForFreq(hz);
   end;
end;

procedure TFT920Radio.ProcessMsg(msg: string);
var
   s2: integer;
   flags: Byte;
begin
   if Length(msg) < FT920_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',
                  [Length(msg), FT920_FRAME_LEN]);
      Exit;
      end;
   s2 := FT920_BLOCK_LEN;

   Self.vfo[nrVFOA].frequency := FreqRead(msg, s2 + FT920_S2_VFOA_FREQ);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[s2 + FT920_S2_VFOA_MODE]),
                                                  Self.vfo[nrVFOA].frequency);

   Self.vfo[nrVFOB].frequency := FreqRead(msg, s2 + FT920_S2_VFOB_FREQ);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[s2 + FT920_S2_VFOB_MODE]),
                                                  Self.vfo[nrVFOB].frequency);

   flags := Ord(msg[FT920_S1_FLAGS_POS]);
   Self.SetXITOn((flags and $01) <> 0);   // bit 0
   Self.SetRITOn((flags and $02) <> 0);   // bit 1

   Self.SetActiveVFO(nrVFOA);
end;

procedure TFT920Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   Self.SendBytes(b[0], b[1], b[2], b[3], FT920_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

initialization
  RegisterRadio(FT920,
     function: TFactoryRadioBase begin Result := TFT920Radio.Create end,
     'Yaesu FT-920', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
