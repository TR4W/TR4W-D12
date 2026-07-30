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
unit uRadioYaesuFT747;

{
  Yaesu FT-747GX -- migrated from uRadioPolling.pFT747GX.

  ONE REQUEST, A 344-BYTE ANSWER, AND ONLY THE FIRST 22 BYTES ARE USED.

      $00 $00 $00 $00 $10  ->  344 bytes

  That is the radio's whole memory image; TR4W reads all of it because the frame
  must be consumed to stay in sync, but everything it needs is in the head.  The
  length is NOT negotiable -- reading fewer bytes leaves the remainder in the
  driver buffer and every later frame is misaligned.

  FIFTH FREQUENCY ENCODING in this family: 5 bytes of PACKED BCD, ten digits,
  most-significant nibble first (legacy GetFrequencyForYaesuFT747).  Not the
  3-byte x10, not the 4-byte raw, not x0.625, not x1.25.

  FIELD LAYOUT (1-based, matching the legacy 1-based tBuf):

      byte  1      flags -- bit 1 SPLIT, bit 2 RIT on, bit 3 VFO B is active
      bytes 2-6    current VFO frequency, 5-byte packed BCD
      bytes 9-13   VFO A frequency
      bytes 17-21  VFO B frequency
      byte  22     mode

  MODE BYTE IS A BITMASK, NOT AN ORDINAL.  Legacy reads it with no mask and no
  `else`:  1 -> FM,  2 / 8 / 16 -> Phone,  4 -> CW.  Those are single bits
  (1, 2, 4, 8, 16), so the byte is a one-hot mode selector and any other value --
  including 0 -- leaves the mode UNCHANGED in legacy.  Reproduced here by
  returning rmNone for unknown values and only writing the mode when it decodes,
  so an unexpected byte cannot silently rewrite the log to the wrong mode.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - 344 is from legacy and is the single most important number here. If frames
      resync repeatedly, this is why.
    - The mode bitmask groups 2, 8 and 16 as "Phone"; they are probably LSB, USB
      and AM in some order. Cycle the modes and record which bit is which.
    - Byte 1 bit 2 reports RIT ON but no offset appears anywhere, so rcReadRIT is
      claimed for the on/off state only and the offset stays whatever the
      operator last commanded.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   FT747_POLL_P4 = $00;
   FT747_POLL_P5 = $10;
   FT747_FRAME_LEN = 344;      // the radio's full memory image

   FT747_FLAGS_POS     = 1;
   FT747_SPLIT_BIT     = $02;  // bit 1
   FT747_RIT_BIT       = $04;  // bit 2
   FT747_VFOB_BIT      = $08;  // bit 3
   FT747_CUR_FREQ_POS  = 2;    // 5 bytes packed BCD
   FT747_VFOA_FREQ_POS = 9;
   FT747_VFOB_FREQ_POS = 17;
   FT747_MODE_POS      = 22;

   FT747_FREQ_BCD_BYTES = 5;

   // Mode is a ONE-HOT bitmask, not an ordinal.
   FT747_MODE_FM    = 1;
   FT747_MODE_SSB_A = 2;
   FT747_MODE_CW    = 4;
   FT747_MODE_SSB_B = 8;
   FT747_MODE_SSB_C = 16;

   FT747_SET_FREQ_OPCODE = $0A;
   FT747_SET_MODE_OPCODE = $0C;   // SMOC, LOGRADIO radio table row 'FT747GX'

   // Set-mode bytes, from the same table row (CW $03 / LSB $00 / USB $01 /
   // AM $05 / FM $06).  These are the SET values and are NOT the status-frame
   // mode bits above (FT747_MODE_*), which are a different encoding.
   FT747_SETMODE_LSB = $00;
   FT747_SETMODE_USB = $01;
   FT747_SETMODE_CW  = $03;
   FT747_SETMODE_AM  = $05;
   FT747_SETMODE_FM  = $06;

type
  TFT747GXRadio = class(TYaesuBinary)
  protected
    function  StatusModeToMode(b: Byte; hz: integer): TRadioMode;
    function  BCDFreqRead(const frame: string; pos1: integer): integer;
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
  end;

implementation

constructor TFT747GXRadio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-747GX';
   SerialFixedFrameLength := FT747_FRAME_LEN;
   // 344 bytes at 4800 baud is ~720 ms of wire time, so a fast cadence would
   // simply queue up behind itself.
   pollingInterval := 1000;

   // rcReadVFOB  -- both VFO frequencies are in the frame.
   // rcReadSplit -- byte 1 bit 1.
   // rcReadRIT   -- byte 1 bit 2 gives the ON/OFF state (offset is NOT reported).
   // NOT rcReadTXStatus.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit, rcReadRIT];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

procedure TFT747GXRadio.PollRadioState;
begin
   Self.SendBytes($00, $00, $00, FT747_POLL_P4, FT747_POLL_P5);
end;

// 5 bytes of packed BCD, ten digits, most-significant nibble first.
// Legacy GetFrequencyForYaesuFT747, written as the same accumulation.
function TFT747GXRadio.BCDFreqRead(const frame: string; pos1: integer): integer;
var
   c: integer;
   acc: Int64;
   b: Byte;
begin
   acc := 0;
   for c := 0 to FT747_FREQ_BCD_BYTES - 1 do
      begin
      b := Ord(frame[pos1 + c]);
      acc := (acc * 10) + (b div 16);
      acc := (acc * 10) + (b mod 16);
      end;
   Result := integer(acc);
end;

function TFT747GXRadio.StatusModeToMode(b: Byte; hz: integer): TRadioMode;
begin
   // One-hot bitmask.  rmNone for anything unrecognised so ProcessMsg can leave
   // the previous mode alone, matching legacy's case-without-else.
   // 2 / 8 / 16 are three distinct radio modes that legacy reports at the
   // ROLL-UP level only ("Phone"), so the sideband is derived from frequency
   // rather than asserted -- see TYaesuBinary.PhoneModeForFreq.
   case b of
      FT747_MODE_FM:    Result := rmFM;
      FT747_MODE_CW:    Result := rmCW;
      FT747_MODE_SSB_A: Result := PhoneModeForFreq(hz);
      FT747_MODE_SSB_B: Result := PhoneModeForFreq(hz);
      FT747_MODE_SSB_C: Result := PhoneModeForFreq(hz);
   else
      Result := rmNone;
   end;
end;

procedure TFT747GXRadio.ProcessMsg(msg: string);
var
   flags: Byte;
   m: TRadioMode;
begin
   if Length(msg) < FT747_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',
                  [Length(msg), FT747_FRAME_LEN]);
      Exit;
      end;

   flags := Ord(msg[FT747_FLAGS_POS]);
   Self.SetSplitOn((flags and FT747_SPLIT_BIT) <> 0);
   Self.SetRITOn((flags and FT747_RIT_BIT) <> 0);

   Self.vfo[nrVFOA].frequency := BCDFreqRead(msg, FT747_VFOA_FREQ_POS);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOB].frequency := BCDFreqRead(msg, FT747_VFOB_FREQ_POS);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);

   // Only ONE mode byte exists, describing the current VFO.  Apply it to
   // whichever VFO byte 1 says is active rather than assuming VFO A.
   if (flags and FT747_VFOB_BIT) <> 0 then
      begin
      m := StatusModeToMode(Ord(msg[FT747_MODE_POS]), Self.vfo[nrVFOB].frequency);
      Self.SetActiveVFO(nrVFOB);
      if m <> rmNone then
         begin
         Self.vfo[nrVFOB].mode := m;
         end;
      end
   else
      begin
      m := StatusModeToMode(Ord(msg[FT747_MODE_POS]), Self.vfo[nrVFOA].frequency);
      Self.SetActiveVFO(nrVFOA);
      if m <> rmNone then
         begin
         Self.vfo[nrVFOA].mode := m;
         end;
      end;
end;

procedure TFT747GXRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   Self.SendBytes(b[0], b[1], b[2], b[3], FT747_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

// SetMode is ABSTRACT in TFactoryRadioBase and TYaesuBinary does not supply one,
// so omitting it here is not a missing feature -- it is an EAbstractError the
// first time anyone selects this radio and changes mode.  (Caught by W1020 on a
// full rebuild; an incremental build does not recompile this unit and stays
// silent, which is how it was missed.)
procedure TFT747GXRadio.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
begin
   case mode of
      rmLSB: modeByte := FT747_SETMODE_LSB;
      rmUSB: modeByte := FT747_SETMODE_USB;
      rmCW:  modeByte := FT747_SETMODE_CW;
      rmAM:  modeByte := FT747_SETMODE_AM;
      rmFM:  modeByte := FT747_SETMODE_FM;
   else
      begin
      // The table row carries no DIGL/DIGU value for this radio, and it has no
      // CW-reverse.  Refuse rather than send a byte the radio never defined.
      logger.Error('[SetMode] FT-747GX has no mode %d', [Ord(mode)]);
      Exit;
      end;
   end;
   // Row MB=3: the mode byte sits at index 3, opcode last.
   Self.SendBytes($00, $00, $00, modeByte, FT747_SET_MODE_OPCODE);
end;

initialization
  RegisterRadio(FT747GX,
     function: TFactoryRadioBase begin Result := TFT747GXRadio.Create end,
     'Yaesu FT-747GX', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
