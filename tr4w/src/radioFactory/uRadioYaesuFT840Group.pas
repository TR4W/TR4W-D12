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
unit uRadioYaesuFT840Group;

{
  SHARED BASE for the Yaesu FT-840, FT-890 and FT-900 -- registers NOTHING.

  The three models live in uRadioYaesuFT840.pas, uRadioYaesuFT890.pas and
  uRadioYaesuFT900.pas.  Each states only its logger name, its display name and
  its set-mode row; the poll, the frame handling, the BCD frequency reader and the
  status mode map are here and are identical across all three.

  WHY A BASE RATHER THAN MODEL-ON-MODEL.  TFT890Radio and TFT900Radio descended
  from TFT840Radio, so editing the FT-840 silently changed two other radios.
  NY4I: "when I look at the project, I should see a class for every single radio",
  and a model must never be another model's base.

  WHAT IS PER-MODEL: only the set-mode row's AM byte, and the names.  AM is $05 on
  the FT-840 and FT-900 and $04 on the FT-890 (LOGRADIO rows 'FT840', 'FT890',
  'FT900').  None of the three has a data mode -- DIGL and DIGU are $FF in every
  row, so MODEBYTE_NONE, and SetMode refuses those modes rather than transmitting
  an undefined byte.

  NONE OF THE THREE HAS EVER BEEN BENCHED.
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
  TYaesuFT840Group = class(TYaesuBinary)
  protected
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  FreqRead(const frame: string; pos1: integer): integer;
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

// Group defaults only.  Each model sets its logger, radioModel and set-mode row.
constructor TYaesuFT840Group.Create;
begin
   inherited Create;

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

procedure TYaesuFT840Group.PollRadioState;
begin
   Self.SendBytes($00, $00, $00, FT840_POLL_P4, FT840_POLL_P5);
end;

// 3 bytes big-endian, units of 10 Hz (legacy GetFrequencyForYaesu3).
function TYaesuFT840Group.FreqRead(const frame: string; pos1: integer): integer;
begin
   Result := (Ord(frame[pos1]) * 65536 + Ord(frame[pos1 + 1]) * 256 +
              Ord(frame[pos1 + 2])) * 10;
end;

function TYaesuFT840Group.StatusModeToMode(b: Byte): TRadioMode;
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

procedure TYaesuFT840Group.ProcessMsg(msg: string);
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

procedure TYaesuFT840Group.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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


// This unit registers NOTHING -- it is the shared base.


function TYaesuFT840Group.PTTFrameOn: string;
begin
   Result := YAESU_PTT_ON_0F;
end;

function TYaesuFT840Group.PTTFrameOff: string;
begin
   Result := YAESU_PTT_OFF_0F;
end;

end.
