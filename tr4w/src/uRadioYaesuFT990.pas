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
  Yaesu FT-990 and FT-1000 -- migrated from uRadioPolling.pFT990_FT1000.

  SAME POLL COMMANDS AS THE FT-1000MP, DIFFERENT FREQUENCY ENCODING.  That is the
  whole reason this is its own unit rather than a TFT1000MPRadio subclass:

                        FT-1000MP                 FT-990 / FT-1000
      frequency         4 bytes, raw * 0.625      3 bytes, raw * 10 Hz
                        (GetFrequencyForYaesu4)   (GetFrequencyForYaesu3)
      $FA block         6 bytes                   5 bytes
      short status      not used                  $00 00 00 02 10, for RIT

  A driver that used the FT-1000MP's decoder here would report a frequency roughly
  16x off -- obvious on air, but obvious is not the same as caught, so the two
  decoders stay in separate units named after their lead models.

  POLL CYCLE -- three requests, always in this order, so the replies concatenate
  into ONE deterministically-delimited frame (the same technique the FT-1000MP and
  FT-817 drivers use):

      $00 $00 $00 $02 $10  -> FStatus1Len bytes : current VFO + RIT/XIT
      $00 $00 $00 $03 $10  -> 32 bytes          : VFO A and VFO B
      $00 $00 $00 $01 $FA  -> 5 bytes           : split + which VFO is active

  FStatus1Len IS THE ONLY THING THAT DIFFERS BETWEEN THE TWO MODELS: the FT-1000
  answers the short status in 16 bytes, the FT-990 in 32.  Legacy expressed that
  as `if rig^.RadioModel = FT1000 then F1 := 16 else F1 := 32` -- a model test in
  shared code, exactly what the factory replaces with a field the subclass sets.

  ****  NEITHER IS BENCH-VALIDATED -- keep both on the tester list  ****

  BENCH NOTES:
    - Frame length is the whole risk. A wrong FStatus1Len mis-delimits every
      later field; watch for "Frame resync" warnings and a nonsense frequency.
    - RIT OFFSET IS PORTED WITH A SUSPECTED LEGACY BUG (see ClarifierRead): the
      legacy arithmetic multiplies the high byte by 255, not 256. Preserved
      deliberately -- changing it unverified would swap one wrong answer for
      another. On a bench, set the clarifier to a known offset and compare.
    - Set-mode bytes differ from the READ map. The read map here is the status
      block's (0=LSB..6=PKT, shared with the FT-1000MP); the SET bytes come from
      the radio's own row (CW $03, LSB $00, USB $01, FM $06, AM $05, DIGL $08,
      DIGU $09) and are NOT the same numbering. Do not "unify" them.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   // ---- Poll opcodes (P4 P5 of the 5-byte command) ----
   FT990_STATUS1_P4 = $02;   FT990_STATUS1_P5 = $10;   // short status (RIT)
   FT990_STATUS2_P4 = $03;   FT990_STATUS2_P5 = $10;   // both VFOs, 32 bytes
   FT990_FA_P4      = $01;   FT990_FA_P5      = $FA;   // split / active VFO

   FT990_STATUS2_LEN = 32;
   FT990_FA_LEN      = 5;

   // Offsets WITHIN the short status block (1-based, as the legacy 1-based tBuf).
   FT990_S1_FREQ_POS = 2;    // 3 bytes
   FT990_S1_FLAGS    = 5;    // bit1 = RIT on, bit0 = XIT on
   FT990_S1_CLAR_POS = 6;    // 2 bytes
   FT990_S1_MODE_POS = 8;

   // Offsets WITHIN the 32-byte both-VFO block (1-based).
   FT990_S2_VFOA_FREQ = 2;
   FT990_S2_VFOA_MODE = 8;
   FT990_S2_VFOB_FREQ = 18;
   FT990_S2_VFOB_MODE = 24;

   // Offsets WITHIN the 5-byte $FA block (1-based).
   FT990_FA_FLAGS = 1;       // bit0 = split, bit1 = VFO B is active

   // ---- Write opcodes (row: SFOC $0A, SMOC $0C, SW 1, MB 3) ----
   FT990_SET_FREQ_OPCODE = $0A;
   FT990_SET_MODE_OPCODE = $0C;

type
  TFT990Radio = class(TYaesuBinary)
  protected
    // The ONE per-model difference: length of the $02 $10 answer.
    FStatus1Len: integer;
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
    function  ClarifierRead(const frame: string; pos1: integer): integer;
    procedure RecomputeFrameLength;
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
  end;

  // FT-1000: identical protocol, but its short-status answer is 16 bytes.
  TFT1000Radio = class(TFT990Radio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TFT990Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT990');
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
   //   rcReadRIT   -- the short status carries the clarifier and its flags
   // NOT rcReadTXStatus: nothing in these three answers reports PTT.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit, rcReadRIT];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

constructor TFT1000Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT1000');
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

procedure TFT990Radio.RecomputeFrameLength;
begin
   // Must be re-derived whenever FStatus1Len changes -- hence a method, so the
   // FT-1000 subclass cannot set the field and forget the length.
   SerialFixedFrameLength := FStatus1Len + FT990_STATUS2_LEN + FT990_FA_LEN;
end;

procedure TFT990Radio.PollRadioState;
begin
   // Fixed order -- the frame layout in ProcessMsg depends on it.
   Self.SendBytes($00, $00, $00, FT990_STATUS1_P4, FT990_STATUS1_P5);
   Self.SendBytes($00, $00, $00, FT990_STATUS2_P4, FT990_STATUS2_P5);
   Self.SendBytes($00, $00, $00, FT990_FA_P4,      FT990_FA_P5);
end;

// 3 bytes, big-endian, in units of 10 Hz (legacy GetFrequencyForYaesu3).
function TFT990Radio.FreqRead(const frame: string; pos1: integer): integer;
begin
   Result := (Ord(frame[pos1]) * 65536 + Ord(frame[pos1 + 1]) * 256 +
              Ord(frame[pos1 + 2])) * 10;
end;

// PORTED FAITHFULLY INCLUDING A SUSPECTED BUG.  Legacy is:
//     10 * (SHORTINT(tBuf[6]) * 255 + Ord(tBuf[7]))
// The 255 is almost certainly meant to be 256 -- with 256 this is a plain signed
// 16-bit value, which is what the two bytes obviously are, and 255 makes the
// offset drift by one step per 256 Hz of magnitude.  It is preserved because
// nobody here has an FT-990 to prove the corrected form: swapping one unverified
// answer for another is not an improvement.  See the bench note in the header.
function TFT990Radio.ClarifierRead(const frame: string; pos1: integer): integer;
begin
   Result := 10 * (SmallInt(ShortInt(Ord(frame[pos1]))) * 255 +
                   Ord(frame[pos1 + 1]));
end;

// Status-block mode byte.  Same numbering as the FT-1000MP's status block.
// Legacy collapsed 0/1/3 to "Phone" and 5/6 to "Digital" because its ModeType is
// coarser; the factory keeps the distinction the radio actually reports.
function TFT990Radio.StatusModeToMode(b: Byte): TRadioMode;
begin
   case b and $07 of
      0: Result := rmLSB;
      1: Result := rmUSB;
      2: Result := rmCW;
      3: Result := rmAM;
      4: Result := rmFM;
      5: Result := rmFSK;    // RTTY
      6: Result := rmData;   // PKT
   else
      Result := rmNone;
   end;
end;

procedure TFT990Radio.ProcessMsg(msg: string);
var
   s2, fa: integer;    // 0-based offsets of the 2nd and 3rd blocks
   flags: Byte;
begin
   if Length(msg) < SerialFixedFrameLength then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',
                  [Length(msg), SerialFixedFrameLength]);
      Exit;
      end;
   s2 := FStatus1Len;
   fa := FStatus1Len + FT990_STATUS2_LEN;

   // ---- Block 2 ($03 $10): both VFOs.  Written first because it is the
   // authoritative per-VFO state; block 1 only adds the clarifier. ----
   Self.vfo[nrVFOA].frequency := FreqRead(msg, s2 + FT990_S2_VFOA_FREQ);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[s2 + FT990_S2_VFOA_MODE]));

   Self.vfo[nrVFOB].frequency := FreqRead(msg, s2 + FT990_S2_VFOB_FREQ);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[s2 + FT990_S2_VFOB_MODE]));

   // ---- Block 1 ($02 $10): clarifier and its on/off flags ----
   flags := Ord(msg[FT990_S1_FLAGS]);
   Self.SetRITOn((flags and $02) <> 0);        // bit 1
   Self.SetXITOn((flags and $01) <> 0);        // bit 0
   Self.SetRITOffset(ClarifierRead(msg, FT990_S1_CLAR_POS));

   // ---- Block 3 ($01 $FA): split and which VFO is operating ----
   flags := Ord(msg[fa + FT990_FA_FLAGS]);
   Self.SetSplitOn((flags and $01) <> 0);      // bit 0
   if (flags and $02) <> 0 then                // bit 1
      begin
      Self.SetActiveVFO(nrVFOB);
      end
   else
      begin
      Self.SetActiveVFO(nrVFOA);
      end;
end;

procedure TFT990Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   // Row SW=1: BCD, byte-SWAPPED (the FT-1000MP convention, not the FT-817's).
   // 8 BCD digits of (freq div 10), least-significant byte FIRST.
   f10 := LongWord(freq div 10);
   for i := 0 to 3 do
      begin
      b[i] := Byte((f10 mod 10) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   Self.SendBytes(b[0], b[1], b[2], b[3], FT990_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

initialization
  RegisterRadio(FT990,
     function: TFactoryRadioBase begin Result := TFT990Radio.Create end,
     'Yaesu FT-990', [rlSerial], 0, False);
  RegisterRadio(FT1000,
     function: TFactoryRadioBase begin Result := TFT1000Radio.Create end,
     'Yaesu FT-1000', [rlSerial], 0, False);

end.
