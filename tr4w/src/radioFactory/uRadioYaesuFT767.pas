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
unit uRadioYaesuFT767;

{
  Yaesu FT-767 -- migrated from uRadioPolling.pFT767.

  THE ONLY RADIO IN THE FAMILY WITH A TWO-PHASE HANDSHAKE.  Every other old-binary
  Yaesu answers a request with one frame.  This one answers with a 5-byte
  acknowledgement, then waits for an ACK command before sending the 86-byte
  status block:

      -> $00 $00 $00 $00 $00   (CAT enable, odd cycles)
         $00 $00 $00 $01 $00   (poll, even cycles)      -- legacy alternates these
      <- 5 bytes               handshake
      -> $00 $00 $00 $00 $0B   ACK
      <- 86 bytes              status

  HOW THAT IS DONE HERE, and why it is worth a careful look.  The factory's
  fixed-frame reader delimits by a byte count held in the reading thread's
  `fixedFrameLength`, which it re-reads on every pass of its loop.  So the frame
  size is switched at runtime: 5 while awaiting the handshake, 86 after the ACK
  goes out, back to 5 afterwards.  ProcessMsg runs ON the reading thread, so the
  change takes effect on that thread's next iteration with no cross-thread write.

  The phase is inferred from the frame LENGTH rather than tracked in a variable,
  which makes it self-correcting: if the link drops mid-handshake and resumes,
  whichever frame arrives selects the right branch instead of leaving a state
  machine stuck.

  ** REVIEW POINT -- this is the first driver to vary frame length at runtime. **
  If it proves fragile on hardware, the alternative is a dedicated two-phase mode
  in the reading thread rather than a per-driver trick.

  ALTERNATING FIRST COMMAND is legacy behaviour (`if tPollCount mod 2 <> 0`) and
  is preserved: the CAT-enable frame doubles as a keep-alive on the odd cycles.

  FIELD LAYOUT of the 86-byte status block (1-based, matching the legacy tBuf):

      bytes 63-66   VFO B frequency, 4-byte packed BCD, x10 Hz
      bytes 75-78   VFO A frequency
      bytes 82-85   current VFO frequency
      byte  86      mode

  (Legacy writes these as 82, 82-7 and 82-19.)

  MODE:  0,1,3 -> Phone   2 -> CW   4 -> FM   5 -> Digital, read as `mod 8`.
  As with the other models in this family, legacy collapsed LSB/USB/AM, so 0/1/3
  all report rmUSB until a bench separates them.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - The handshake is the risk. Watch for repeated "Frame resync" or a poll
      cycle that stalls; either means the 5/86 switch is not tracking.
    - Confirm the alternation is actually needed. If the radio answers the poll
      without the CAT-enable frame on alternate cycles, this can simplify to a
      single command per cycle.
    - Modes 0, 1 and 3 all report USB today; record which is which.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   // Commands (5-byte frames, opcode last).
   FT767_CATENABLE_P4 = $00;   FT767_CATENABLE_P5 = $00;
   FT767_POLL_P4      = $01;   FT767_POLL_P5      = $00;
   FT767_ACK_P4       = $00;   FT767_ACK_P5       = $0B;

   FT767_HANDSHAKE_LEN = 5;
   FT767_STATUS_LEN    = 86;

   // Within the 86-byte status block (1-based).
   FT767_VFOB_FREQ_POS = 63;   // legacy 82 - 19
   FT767_VFOA_FREQ_POS = 75;   // legacy 82 - 7
   FT767_CUR_FREQ_POS  = 82;
   FT767_MODE_POS      = 86;

   FT767_FREQ_BCD_BYTES = 4;

   // Write opcodes (row: SFOC $08, SMOC $0A -- NOT the $0A/$0C the rest of the
   // family uses; the FT-767 is the only model with this pair).
   FT767_SET_FREQ_OPCODE = $08;
   FT767_SET_MODE_OPCODE = $0A;   // SMOC, LOGRADIO radio table row 'FT767'

   // Set-mode bytes from the same table row.  Note these are a DIFFERENT
   // encoding from the status-frame mode byte read at FT767_MODE_POS.
   FT767_SETMODE_LSB  = $10;
   FT767_SETMODE_USB  = $11;
   FT767_SETMODE_CW   = $12;
   FT767_SETMODE_AM   = $13;
   FT767_SETMODE_FM   = $14;
   FT767_SETMODE_DIG  = $15;   // row lists the SAME value for DIGL and DIGU

type
  TFT767Radio = class(TYaesuBinary)
  protected
    FCycle: integer;
    function  StatusModeToMode(b: Byte; hz: integer): TRadioMode;
    function  BCDFreqRead(const frame: string; pos1: integer): integer;
    procedure ExpectFrameLength(n: integer);
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
  end;

implementation

constructor TFT767Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-767';
   SerialFixedFrameLength := FT767_HANDSHAKE_LEN;   // first frame expected
   pollingInterval := 500;
   FCycle := 0;

   // rcReadVFOB -- both VFO frequencies are in the status block.
   // NOT rcReadSplit, NOT rcReadRIT, NOT rcReadTXStatus: legacy reads none of
   // them for this radio, and only one mode byte exists.
   FCapabilities.Flags := [rcReadVFOB];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

// Switch what the reader delimits on.  Thin wrapper so the intent reads locally;
// the base owns the mechanism because the reading thread is private to it.
procedure TFT767Radio.ExpectFrameLength(n: integer);
begin
   Self.SetExpectedFrameLength(n);
end;

procedure TFT767Radio.PollRadioState;
begin
   // Legacy alternates the CAT-enable frame and the poll on odd/even cycles.
   Inc(FCycle);
   ExpectFrameLength(FT767_HANDSHAKE_LEN);
   if (FCycle mod 2) <> 0 then
      begin
      Self.SendBytes($00, $00, $00, FT767_CATENABLE_P4, FT767_CATENABLE_P5);
      end
   else
      begin
      Self.SendBytes($00, $00, $00, FT767_POLL_P4, FT767_POLL_P5);
      end;
end;

// 4 bytes packed BCD, most-significant nibble first, in units of 10 Hz
// (legacy GetFrequencyFromBCD(4, ...) * 10).
function TFT767Radio.BCDFreqRead(const frame: string; pos1: integer): integer;
var
   c: integer;
   acc: Int64;
   b: Byte;
begin
   acc := 0;
   for c := 0 to FT767_FREQ_BCD_BYTES - 1 do
      begin
      b := Ord(frame[pos1 + c]);
      acc := (acc * 10) + (b div 16);
      acc := (acc * 10) + (b mod 16);
      end;
   Result := integer(acc * 10);
end;

function TFT767Radio.StatusModeToMode(b: Byte; hz: integer): TRadioMode;
begin
   case b mod 8 of
      2: Result := rmCW;
      4: Result := rmFM;
      5: Result := rmData;
   else
      // 0, 1, 3 -- reported at the ROLL-UP level only ("Phone"); sideband by
      // frequency convention, not asserted.
      Result := PhoneModeForFreq(hz);
   end;
end;

procedure TFT767Radio.ProcessMsg(msg: string);
begin
   // Phase is inferred from the frame length, not tracked -- self-correcting.
   if Length(msg) = FT767_HANDSHAKE_LEN then
      begin
      // Handshake seen: ask for the status block and widen the frame.
      ExpectFrameLength(FT767_STATUS_LEN);
      Self.SendBytes($00, $00, $00, FT767_ACK_P4, FT767_ACK_P5);
      Exit;
      end;

   if Length(msg) < FT767_STATUS_LEN then
      begin
      logger.Warn('[ProcessMsg] unexpected frame (%d bytes; expected %d or %d)',
                  [Length(msg), FT767_HANDSHAKE_LEN, FT767_STATUS_LEN]);
      ExpectFrameLength(FT767_HANDSHAKE_LEN);
      Exit;
      end;

   Self.vfo[nrVFOA].frequency := BCDFreqRead(msg, FT767_VFOA_FREQ_POS);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOB].frequency := BCDFreqRead(msg, FT767_VFOB_FREQ_POS);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);

   // One mode byte, describing the current VFO.  Legacy assigns it to the
   // radio-level mode; nothing here says which VFO is operating, so VFO A.
   Self.vfo[nrVFOA].mode := StatusModeToMode(Ord(msg[FT767_MODE_POS]),
                                             Self.vfo[nrVFOA].frequency);
   Self.SetActiveVFO(nrVFOA);

   // Back to waiting for the next handshake.
   ExpectFrameLength(FT767_HANDSHAKE_LEN);
end;

procedure TFT767Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   // Row SW=1: BCD, byte-swapped.  NOTE the opcode is $08 here, not the $0A the
   // rest of the family uses.
   f10 := LongWord(freq div 10);
   for i := 0 to 3 do
      begin
      b[i] := Byte((f10 mod 10) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   Self.SendBytes(b[0], b[1], b[2], b[3], FT767_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

// SetMode is ABSTRACT in TFactoryRadioBase and TYaesuBinary supplies none, so
// leaving it out is an EAbstractError the first time a mode is set -- not a
// missing feature.  (W1020 on a full rebuild; an incremental build is silent.)
procedure TFT767Radio.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
begin
   case mode of
      rmLSB:  modeByte := FT767_SETMODE_LSB;
      rmUSB:  modeByte := FT767_SETMODE_USB;
      rmCW:   modeByte := FT767_SETMODE_CW;
      rmAM:   modeByte := FT767_SETMODE_AM;
      rmFM:   modeByte := FT767_SETMODE_FM;
      rmData: modeByte := FT767_SETMODE_DIG;
      rmFSK:  modeByte := FT767_SETMODE_DIG;   // row gives DIGL and DIGU the same value
   else
      begin
      logger.Error('[SetMode] FT-767 has no mode %d', [Ord(mode)]);
      Exit;
      end;
   end;
   // Row MB=0: mode byte FIRST, opcode last.
   Self.SendBytes(modeByte, $00, $00, $00, FT767_SET_MODE_OPCODE);
end;

initialization
  RegisterRadio(FT767,
     function: TFactoryRadioBase begin Result := TFT767Radio.Create end,
     'Yaesu FT-767', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
