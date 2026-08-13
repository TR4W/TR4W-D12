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
unit uRadioYaesuFT100;
{$I ..\tr4w.inc}

{
  Yaesu FT-100 -- migrated from uRadioPolling.pFT100.

  FOURTH FREQUENCY ENCODING IN THE SAME FAMILY.  All these radios share the
  $0A/$0C write opcodes, and every one reads frequency differently:

      FT-840/890/900   3 bytes big-endian x 10 Hz
      FT-990/FT-1000   3 bytes big-endian x 10 Hz
      FT-920           4 bytes big-endian, raw
      FT-1000MP        4 bytes big-endian x 0.625
      FT-100           4 bytes big-endian x 1.25     <- this unit

  POLL CYCLE -- two requests, concatenating into one frame:

      $00 $00 $00 $00 $10  -> 32 bytes : frequency, mode, RIT offset
      $00 $00 $00 $01 $FA  ->  8 bytes : split + active VFO

  MODE NUMBERING is its own again -- 2 AND 3 are both CW here, where the
  FT-990 uses 2 for CW and 3 for AM:

      0,1,4 -> Phone      2,3 -> CW      5 -> Digital      6,7 -> FM

  Legacy has no `else` arm on this one, so a byte outside 0..7 & $07 cannot occur
  and every value is accounted for.  Unlike the FT-920, 0/1 vs 4 still cannot be
  split into LSB/USB/AM from the legacy source, so they share rmUSB -- see the
  bench note.

  ONLY ONE VFO IS REPORTED.  The 32-byte answer carries the current VFO; the $FA
  answer says WHICH one it is but not the other's frequency, so rcReadVFOB is not
  claimed.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - Confirm the x1.25 scaling first; it is the most likely thing to be wrong
      and shows up immediately as a frequency off by a constant ratio.
    - Mode: 0, 1 and 4 all report USB today. Cycle LSB/USB/AM and record which
      byte is which -- the legacy code collapsed them and the information is not
      recoverable from it.
    - The RIT offset carries the same suspected x255 quirk as the FT-990; see
      RITOffsetRead.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, SysUtils, Math,
     Log4D, VC, uRadioRegistry;

const
   FT100_STATUS_P4 = $00;   FT100_STATUS_P5 = $10;
   FT100_FLAGS_P4  = $01;   FT100_FLAGS_P5  = $FA;

   FT100_STATUS_LEN = 32;
   FT100_FLAGS_LEN  = 8;
   FT100_FRAME_LEN  = FT100_STATUS_LEN + FT100_FLAGS_LEN;   // 40

   // Within the 32-byte status block (1-based).
   FT100_FREQ_POS = 2;     // 4 bytes, big-endian, x 1.25
   FT100_MODE_POS = 6;
   FT100_CLAR_POS = 11;    // 2 bytes

   // Within the 8-byte $FA block (1-based).
   FT100_FA_SPLIT_POS = 1;   // bit 0
   FT100_FA_VFO_POS   = 2;   // bit 2 set -> VFO B

   FT100_SET_FREQ_OPCODE = $0A;

type
  TFT100Radio = class(TYaesuBinary)
  protected
    function  StatusModeToMode(b: Byte; hz: integer): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
    function  RITOffsetRead(const frame: string; pos1: integer): integer;
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

constructor TFT100Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-100';

   // Set-mode row from LOGRADIO's radio table (SMOC $0C, MB 3).
   // MODEBYTE_NONE = the table's $FF, "this radio has no such mode".
   FSetModeOpcode := $0C;
   FModeByteIndex := 3;
   FModeCW   := $02;
   FModeLSB  := $00;
   FModeUSB  := $01;
   FModeAM   := $04;
   FModeFM   := $06;
   FModeDIGL := $05;
   FModeDIGU := $05;
   SerialFixedFrameLength := FT100_FRAME_LEN;
   pollingInterval := 200;

   // rcReadSplit -- the $FA block reports it.
   // NOT rcReadVFOB: only the current VFO's frequency is in the frame.
   // NOT rcReadRIT: the offset is present but nothing reports RIT offset on/off.
   // NOT rcReadTXStatus.
   FCapabilities.Flags := [rcReadSplit];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;
end;

procedure TFT100Radio.PollRadioState;
begin
   Self.SendBytes($00, $00, $00, FT100_STATUS_P4, FT100_STATUS_P5);
   Self.SendBytes($00, $00, $00, FT100_FLAGS_P4,  FT100_FLAGS_P5);
end;

// 4 bytes big-endian, scaled by 1.25 (legacy: round(GetFrequencyForYaesu4 * 1.25)).
function TFT100Radio.FreqRead(const frame: string; pos1: integer): integer;
var
   raw: Int64;
begin
   raw := Int64(Ord(frame[pos1]))     * 16777216 +
          Int64(Ord(frame[pos1 + 1])) * 65536 +
          Int64(Ord(frame[pos1 + 2])) * 256 +
          Int64(Ord(frame[pos1 + 3]));
   Result := Round(raw * 1.25);
end;

// PORTED FAITHFULLY INCLUDING THE SUSPECTED x255 QUIRK, exactly as in the FT-990
// driver:  round(1.25 * (SHORTINT(tBuf[11]) * 255 + Ord(tBuf[12])))
// 255 is almost certainly meant to be 256 -- with 256 these two bytes are a
// plain signed 16-bit value. Not "fixed" here because nobody has the radio to
// confirm, and swapping one unverified answer for another is not progress.
function TFT100Radio.RITOffsetRead(const frame: string; pos1: integer): integer;
begin
   Result := Round(1.25 * (SmallInt(ShortInt(Ord(frame[pos1]))) * 255 +
                           Ord(frame[pos1 + 1])));
end;

function TFT100Radio.StatusModeToMode(b: Byte; hz: integer): TRadioMode;
begin
   // FT-100 numbering: note 2 AND 3 are both CW (the FT-990 uses 3 for AM).
   case b and $07 of
      2: Result := rmCW;
      3: Result := rmCW;
      5: Result := rmData;
      6: Result := rmFM;
      7: Result := rmFM;
   else
      // 0, 1, 4 -- legacy reports these only at the ROLL-UP level ("Phone"), so
      // the sideband is a frequency-based convention, not a radio report.
      Result := PhoneModeForFreq(hz);
   end;
end;

procedure TFT100Radio.ProcessMsg(msg: string);
var
   fa: integer;
begin
   if Length(msg) < FT100_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',
                  [Length(msg), FT100_FRAME_LEN]);
      Exit;
      end;
   fa := FT100_STATUS_LEN;

   Self.vfo[nrVFOA].frequency := FreqRead(msg, FT100_FREQ_POS);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[FT100_MODE_POS]),
                                                  Self.vfo[nrVFOA].frequency);
   Self.SetRITOffset(RITOffsetRead(msg, FT100_CLAR_POS));

   Self.SetSplitOn((Ord(msg[fa + FT100_FA_SPLIT_POS]) and $01) <> 0);
   // Legacy: ActiveVFOStatusType((Ord(tBuf[2]) and (1 shl 2)) + 1) -- bit 2 set
   // means VFO B.
   if (Ord(msg[fa + FT100_FA_VFO_POS]) and $04) <> 0 then
      begin
      Self.SetActiveVFO(nrVFOB);
      end
   else
      begin
      Self.SetActiveVFO(nrVFOA);
      end;
end;

procedure TFT100Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   Self.SendBytes(b[0], b[1], b[2], b[3], FT100_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;


function TFT100Radio.PTTFrameOn: string;
begin
   Result := YAESU_PTT_ON_0F;
end;

function TFT100Radio.PTTFrameOff: string;
begin
   Result := YAESU_PTT_OFF_0F;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateFT100: TFactoryRadioBase;
begin
   Result := TFT100Radio.Create;
end;

initialization
  RegisterRadio(FT100,
     CreateFT100,
     'Yaesu FT-100', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 1)
     ,
     1021
     );

end.
