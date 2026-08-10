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
unit uRadioYaesuFT990Group;

{
  SHARED BASE for the Yaesu FT-990 and FT-1000 -- registers NOTHING.

  The models live in uRadioYaesuFT990.pas and uRadioYaesuFT1000.pas.  Each states
  only its logger name, its display name, its set-mode row, and the length of its
  short-status answer.  Everything else -- the three-block poll, frame reassembly,
  the BCD frequency and RIT offset readers, the mode map -- is here and is identical
  between the two radios.

  WHY A BASE RATHER THAN MODEL-ON-MODEL.  TFT1000Radio used to descend from
  TFT990Radio.  NY4I: "I still want an individual class for every radio... when I
  look at the project, I should see a class for every single radio."  A model must
  never be another model's base: editing the FT-990 silently changed the FT-1000,
  with nothing at the edit site to say so.

  WHAT IS GENUINELY PER-MODEL -- the reason this is a base and not one class:
    - the $02 $10 short-status answer is 32 bytes on the FT-990 and 16 on the
      FT-1000 (legacy: `if RadioModel = FT1000 then F1 := 16`).  FStatus1Len feeds
      RecomputeFrameLength, so each model sets it and then recomputes.
    - the set-mode rows differ in ONE byte: AM is $05 on the FT-990 and $04 on the
      FT-1000 (LOGRADIO rows 'FT990' and 'FT1000').

  NEITHER RADIO HAS EVER BEEN BENCHED.
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
  TYaesuFT990Group = class(TYaesuBinary)
  protected
    // Length of the $02 $10 short-status answer -- the per-model difference.
    FStatus1Len: integer;
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
    function  RITOffsetRead(const frame: string; pos1: integer): integer;
    procedure RecomputeFrameLength;
  public
    constructor Create; reintroduce;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
  public
    // D7 keyed this radio with the 0F frame -- see the constants in
    // uRadioYaesuBinary.  Declared HERE because the base must never ask
    // which model it is.
    function PTTFrameOn: string; override;
    function PTTFrameOff: string; override;
  end;

implementation

// Group defaults only.  A model sets its logger, radioModel and set-mode row,
// then FStatus1Len, then calls RecomputeFrameLength.
constructor TYaesuFT990Group.Create;
begin
   inherited Create;
   pollingInterval := 200;

   // What this driver actually reads -- the same on both radios:
   //   rcReadVFOB  -- the $03 $10 block carries both VFOs
   //   rcReadSplit -- the $FA block reports it
   //   rcReadRIT   -- the short status carries the RIT offset and its flags
   // NOT rcReadTXStatus: nothing in these three answers reports PTT.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit, rcReadRIT];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

procedure TYaesuFT990Group.RecomputeFrameLength;
begin
   // Must be re-derived whenever FStatus1Len changes -- hence a method, so the
   // FT-1000 subclass cannot set the field and forget the length.
   SerialFixedFrameLength := FStatus1Len + FT990_STATUS2_LEN + FT990_FA_LEN;
end;

procedure TYaesuFT990Group.PollRadioState;
begin
   // Fixed order -- the frame layout in ProcessMsg depends on it.
   Self.SendBytes($00, $00, $00, FT990_STATUS1_P4, FT990_STATUS1_P5);
   Self.SendBytes($00, $00, $00, FT990_STATUS2_P4, FT990_STATUS2_P5);
   Self.SendBytes($00, $00, $00, FT990_FA_P4,      FT990_FA_P5);
end;

// 3 bytes, big-endian, in units of 10 Hz (legacy GetFrequencyForYaesu3).
function TYaesuFT990Group.FreqRead(const frame: string; pos1: integer): integer;
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
function TYaesuFT990Group.RITOffsetRead(const frame: string; pos1: integer): integer;
begin
   Result := 10 * (SmallInt(ShortInt(Ord(frame[pos1]))) * 255 +
                   Ord(frame[pos1 + 1]));
end;

// Status-block mode byte.  Same numbering as the FT-1000MP's status block.
// Legacy collapsed 0/1/3 to "Phone" and 5/6 to "Digital" because its ModeType is
// coarser; the factory keeps the distinction the radio actually reports.
function TYaesuFT990Group.StatusModeToMode(b: Byte): TRadioMode;
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

procedure TYaesuFT990Group.ProcessMsg(msg: string);
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
   // authoritative per-VFO state; block 1 only adds the RIT offset. ----
   Self.vfo[nrVFOA].frequency := FreqRead(msg, s2 + FT990_S2_VFOA_FREQ);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[s2 + FT990_S2_VFOA_MODE]));

   Self.vfo[nrVFOB].frequency := FreqRead(msg, s2 + FT990_S2_VFOB_FREQ);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[s2 + FT990_S2_VFOB_MODE]));

   // ---- Block 1 ($02 $10): RIT offset and its on/off flags ----
   flags := Ord(msg[FT990_S1_FLAGS]);
   Self.SetRITOn((flags and $02) <> 0);        // bit 1
   Self.SetXITOn((flags and $01) <> 0);        // bit 0
   Self.SetRITOffset(RITOffsetRead(msg, FT990_S1_CLAR_POS));

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

procedure TYaesuFT990Group.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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


// This unit registers NOTHING -- it is the shared base.


function TYaesuFT990Group.PTTFrameOn: string;
begin
   Result := YAESU_PTT_ON_0F;
end;

function TYaesuFT990Group.PTTFrameOff: string;
begin
   Result := YAESU_PTT_OFF_0F;
end;

end.
