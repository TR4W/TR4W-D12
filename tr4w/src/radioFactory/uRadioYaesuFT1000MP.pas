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
unit uRadioYaesuFT1000MP;

{
  Yaesu FT-1000MP (and Mark V).  Old binary CAT -- shares only the 5-byte
  [P1 P2 P3 P4 Opcode] transport with the other rtYaesu1 radios (TYaesuBinary);
  every byte of the parsing below is specific to THIS radio.  See the header of
  uRadioYaesuBinary for why rtYaesu1 is not a protocol.

  BENCH-VALIDATED end to end on NY4I's FT-1000MP, 2026-07-26.

  READ: the radio answers with FIXED-LENGTH blocks and NO terminator, which the
  terminator-based reading thread cannot delimit, so we use the base's
  SerialFixedFrameLength hook.  Each poll cycle sends TWO requests back to back and
  the radio answers in the order asked, so the replies concatenate into ONE
  deterministically-delimited 38-byte frame:
      $00 $00 $00 $03 $10  -> 32-byte dual-VFO status block
      $00 $00 $00 $01 $FA  ->  6-byte status flags (split)
  This is exactly what D7's pFT1000MP does (it polls $FA inside its repeat loop
  every cycle -- there is no separate "startup read"), which is why split shows
  correctly at startup and also tracks front-panel changes.

  The 32-byte block is two 16-byte VFO records.  1-based positions, matching the
  legacy tBuf[] indexing:
    - freq: bytes 2-5 (record 1) / 18-21 (record 2), 4-byte BIG-ENDIAN, * 0.625
    - mode: byte 8 / 24, low 3 bits (0=LSB 1=USB 2=CW 3=AM 4=FM 5=RTTY 6=Data)
    - RIT offset: offset bytes 6-7 signed BE * 0.625, flags byte 10 -- record 1 only
  RECORD ORDER conveys VFO selection: the two records swap wholesale when the
  operator changes VFO, so record 1 is ALWAYS the selected VFO.  Parsing record 1
  as vfo[nrVFOA] is therefore TR4W's swap model (as used for the K4) and is
  correct, not a placeholder -- see ProcessMsg.

  WRITE: set-freq is packed BCD of (Freq div 10) byte-SWAPPED (SW=1) with opcode
  $0A last -- confirmed on air (14020 kHz went out as 00 20 40 01 0A).  Set-mode is
  opcode $0C with the mode byte at byte[3] (MB=3); VFO B ORs +$80 into it.  Split is
  opcode $01 (T = $01 on / $00 off) and is READ BACK, so it is not tracked locally.
  RIT/XIT use CLAR (opcode $09) -- see SendRITOffset.

  CW keying: inert (base stubs) -- legacy path / future CW Keyer Factory.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, StrUtils, SysUtils, Math,
     TF, Log4D, VC, uRadioRegistry;

const
   // ---- Frame composition (see the unit header) ----
   FT1KMP_STATUS_LEN     = 32;    // answer to $00 00 00 03 10
   FT1KMP_FA_LEN         = 6;     // answer to $00 00 00 01 FA
   FT1KMP_FRAME_LEN      = FT1KMP_STATUS_LEN + FT1KMP_FA_LEN;   // 38
   FT1KMP_SPLIT_POS      = FT1KMP_STATUS_LEN + 1;   // $FA byte 1
   FT1KMP_SPLIT_BIT      = $01;
   // $FA byte 2 bit 2 is what D7 reads as the ACTIVE VFO.  BENCH-DISPROVED: this
   // byte is constant ($20) across front-panel VFO switches.  Kept only to document
   // what was ruled out -- selection is conveyed by RECORD ORDER.  See ProcessMsg.
   FT1KMP_ACTIVE_VFO_POS = FT1KMP_STATUS_LEN + 2;
   FT1KMP_ACTIVE_VFO_BIT = $04;

   // ---- RIT offset field map, 1-based positions in the 32-byte block ----
   // DERIVED FROM A CONTROLLED BENCH CAPTURE (2026-07-26): with frequency, mode and
   // split held fixed and only the RIT offset exercised, exactly three byte positions
   // moved -- 6, 7 and 10.  Settle points were exact:
   //   +1.00 kHz -> pos 6,7 = $06 $40 =  1600 * 0.625 =  1000 Hz
   //   -1.00 kHz -> pos 6,7 = $F9 $C0 = -1600 * 0.625 = -1000 Hz
   // RX CLAR alone set pos 10 = $02; TX CLAR alone set pos 10 = $01.  The RIT offset
   // appears in the VFO A record ONLY (pos 22,23,26 never moved), matching a single
   // shared RIT offset -- see rcSharedRITXITOffset.
   FT1KMP_CLAR_OFFSET_POS = 6;    // 2 bytes, SIGNED 16-bit big-endian, * 0.625 Hz
   FT1KMP_CLAR_FLAGS_POS  = 10;
   FT1KMP_CLAR_RX_BIT     = $02;  // RX CLAR = TR4W RIT
   FT1KMP_CLAR_TX_BIT     = $01;  // TX CLAR = TR4W XIT

   // ---- CLAR command (opcode $09), per the FT-1000MP CAT manual ----
   //   [C1 C2 C3 C4 $09]
   //   C1 = Hz offset, packed BCD 00-99  -- in units of 10 Hz (see below)
   //   C2 = kHz offset, BCD 00-09
   //   C3 = direction: $00 = +, $FF = -
   //   C4 = action: RX CLAR off/on $00/$01, TX CLAR off/on $80/$81, CLAR CLEAR $FF
   // C1 is 10 Hz per count, not 1 Hz: that is the only reading under which C1+C2
   // span the radio's documented +/-9.99 kHz RIT offset range (99*10 + 9*1000 =
   // 9990 Hz), and it matches the manual's note that resolution below 10 Hz cannot
   // be displayed.  Confirmed on air.
   FT1KMP_CLAR_OPCODE     = $09;
   FT1KMP_CLAR_RX_OFF     = $00;
   FT1KMP_CLAR_RX_ON      = $01;
   FT1KMP_CLAR_TX_OFF     = $80;
   FT1KMP_CLAR_TX_ON      = $81;
   FT1KMP_CLAR_CLEAR      = $FF;
   FT1KMP_CLAR_DIR_PLUS   = $00;
   FT1KMP_CLAR_DIR_MINUS  = $FF;
   FT1KMP_CLAR_MAX_HZ     = 9990; // +/- 9.99 kHz, in 10 Hz steps

   // ---- Write opcodes (LOGRADIO RadioParametersArray row: SFOC $0A, SMOC $0C,
   //      MB 3, SW 1 -- our own copy, decoupled from the legacy table) ----
   FT1KMP_SET_FREQ_OPCODE = $0A;
   FT1KMP_SET_MODE_OPCODE = $0C;
   FT1KMP_SET_SPLIT_OPCODE = $01;
   FT1KMP_SELECT_VFOA_OPCODE = $05;
   FT1KMP_VFOB_FLAG       = $80;  // VFO B ORs this into the mode/opcode byte

type
  TFT1000MPRadio = class(TYaesuBinary)
  protected
    FCWReverse: boolean;   // CW mode byte $03 (reverse) vs $02; default off
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  YaesuFreqRead(const frame: string; pos1: integer): integer;
    function  RITOffsetRead(const frame: string; pos1: integer): integer;
    procedure SendRITOffset(offsetHz: integer; action: Byte);
  public
    constructor Create; reintroduce;

    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;

    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure XITClear(whichVFO: TVFO); override;
    procedure RITOn(whichVFO: TVFO); override;
    procedure RITOff(whichVFO: TVFO); override;
    procedure XITOn(whichVFO: TVFO); override;
    procedure XITOff(whichVFO: TVFO); override;
    procedure Split(splitOn: boolean); override;
    procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;
  end;

implementation

constructor TFT1000MPRadio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-1000MP';
   FCWReverse := False;

   SerialFixedFrameLength := FT1KMP_FRAME_LEN;  // 32-byte status + 6-byte $FA block
   pollingInterval        := 150;  // BR4800; 48 bytes/cycle is ~65% of the link

   // Capabilities (declarative -- Yaesu does not consume FCapabilities yet), stated
   // as what THIS DRIVER actually does, not what the radio could do:
   //   rcReadRIT            -- RIT offset state+offset ARE decoded (bench-derived);
   //                           this beats D7, which never decoded FT-1000MP RIT.
   //   rcReadSplit          -- split IS read back, from the appended $FA block.
   //   rcSharedRITXITOffset -- one RIT offset register feeds both RIT and XIT.
   FCapabilities.Flags := [rcReadRIT, rcReadSplit, rcSharedRITXITOffset];
   FCapabilities.CWSpeedMin := 4;
   FCapabilities.CWSpeedMax := 60;
end;

procedure TFT1000MPRadio.PollRadioState;
begin
   // Two requests per cycle, ALWAYS in this order -- the radio answers in order, so
   // the replies concatenate into one FT1KMP_FRAME_LEN frame the fixed-frame reader
   // can delimit.  Also the keep-alive that drives serial power-cycle recovery.
   Self.SendBytes($00, $00, $00, $03, $10);   // -> 32-byte dual-VFO status block
   Self.SendBytes($00, $00, $00, $01, $FA);   // -> 6-byte status flags (split)
end;

// 4-byte big-endian binary frequency at 1-based position pos1, * 0.625.
function TFT1000MPRadio.YaesuFreqRead(const frame: string; pos1: integer): integer;
var raw: Int64;
begin
   raw := (Int64(Ord(frame[pos1]))   shl 24) or
          (Int64(Ord(frame[pos1+1])) shl 16) or
          (Int64(Ord(frame[pos1+2])) shl 8)  or
           Int64(Ord(frame[pos1+3]));
   Result := Round(raw * 0.625);
end;

// RIT offset: SIGNED 16-bit big-endian at 1-based position pos1, * 0.625 Hz
// (the same scaling the frequency field uses).  Bench-verified at +/-1.00 kHz.
function TFT1000MPRadio.RITOffsetRead(const frame: string; pos1: integer): integer;
var
   raw: integer;
begin
   raw := (Ord(frame[pos1]) shl 8) or Ord(frame[pos1 + 1]);
   if raw >= $8000 then
      begin
      raw := raw - $10000;   // two's complement -> negative RIT offset
      end;
   Result := Round(raw * 0.625);
end;

function TFT1000MPRadio.StatusModeToMode(b: Byte): TRadioMode;
begin
   case b and $07 of
      0: Result := rmLSB;
      1: Result := rmUSB;
      2: Result := rmCW;
      3: Result := rmAM;
      4: Result := rmFM;
      5: Result := rmFSK;   // RTTY
      6: Result := rmData;
   else
      Result := rmNone;
   end;
end;

procedure TFT1000MPRadio.ProcessMsg(msg: string);
var
   clarFlags: Byte;
   clarHz: integer;
begin
   UpdateLastValidResponse;   // any frame proves the radio is answering
   if Length(msg) < FT1KMP_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',[Length(msg), FT1KMP_FRAME_LEN]);
      Exit;
      end;
   // Record 1: freq bytes 2-5, mode byte 8.
   Self.vfo[nrVFOA].frequency := YaesuFreqRead(msg, 2);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[8]));
   // Record 2: freq bytes 18-21, mode byte 24.
   Self.vfo[nrVFOB].frequency := YaesuFreqRead(msg, 18);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[24]));
   // RIT/XIT.  Routed through the BASE setters, never Self.<scalar>:
   // the radio window reads the PER-VFO copies, which only the setters write (the
   // K3 serial-display bug, commit 1b205ce).  One shared offset feeds both RIT and
   // XIT here -- see rcSharedRITXITOffset.  The radio keeps reporting the offset
   // while the RIT offset is switched off, and we report it faithfully; the display
   // gates on the on/off state.
   clarFlags := Ord(msg[FT1KMP_CLAR_FLAGS_POS]);
   clarHz    := RITOffsetRead(msg, FT1KMP_CLAR_OFFSET_POS);
   Self.SetRITOn((clarFlags and FT1KMP_CLAR_RX_BIT) <> 0);
   Self.SetXITOn((clarFlags and FT1KMP_CLAR_TX_BIT) <> 0);
   Self.SetRITOffset(clarHz);
   Self.SetXITOffset(clarHz);
   // Split, from the appended $FA block (D7 pFT1000MP reads the same bit).
   Self.SetSplitOn((Ord(msg[FT1KMP_SPLIT_POS]) and FT1KMP_SPLIT_BIT) <> 0);
   // Active VFO: SetActiveVFO(nrVFOA) is CORRECT here and is not a placeholder.
   // BENCH-RESOLVED 2026-07-26 (four front-panel A/B switches captured):
   //  - D7 reads the active VFO as ActiveVFOStatusType((tBuf[2] and $04) + 1) from
   //    the $FA block, i.e. our FT1KMP_ACTIVE_VFO_POS/BIT.  That byte NEVER CHANGED
   //    -- $20 in every frame, bit 2 always clear, across all four switches.  So the
   //    D7 decode reads a bit that does not track selection, on top of yielding 1 or
   //    *5* for an enum that only runs 0..3 (it then indexes VFPLETTERARRAY[5] out
   //    of bounds).  DO NOT implement it; the constants stay only to document what
   //    was tested and ruled out.
   //  - What actually indicates selection is the RECORD ORDER: the two 16-byte
   //    records swap wholesale when the operator changes VFO, so record 1 is always
   //    the SELECTED VFO.  Parsing record 1 as vfo[nrVFOA] and declaring VFO A
   //    active is therefore exactly TR4W's swap model (as used for the K4), and the
   //    frequency/mode/RIT offset we report always belong to the operating VFO.
   Self.SetActiveVFO(nrVFOA);
end;

procedure TFT1000MPRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   f10: LongWord;
   bcd: array[0..3] of Byte;
   i: integer;
   opcode: Byte;
begin
   // Packed BCD of (freq div 10), 4 bytes, MSD first, then BYTE-SWAPPED (SW=1).
   // Confirmed on air: 14020000 -> BCD 01 40 20 00 -> sent as 00 20 40 01 0A.
   f10 := LongWord(freq div 10);
   for i := 3 downto 0 do
      begin
      bcd[i] := Byte(((f10 mod 10)) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   opcode := FT1KMP_SET_FREQ_OPCODE;
   if vfo = nrVFOB then
      begin
      opcode := opcode or FT1KMP_VFOB_FLAG;
      end;
   Self.SendBytes(bcd[3], bcd[2], bcd[1], bcd[0], opcode);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
   // Post: set VFO A active (per legacy FT1000MP freq-set postamble).
   Self.SendBytes($00, $00, $00, $00, FT1KMP_SELECT_VFOA_OPCODE);
end;

procedure TFT1000MPRadio.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
begin
   case mode of
      rmLSB:  modeByte := $00;
      rmUSB:  modeByte := $01;
      rmCW:
         begin
         if FCWReverse then
            begin
            modeByte := $03;
            end
         else
            begin
            modeByte := $02;
            end;
         end;
      rmCWRev: modeByte := $03;
      rmFM:   modeByte := $06;
      rmAM:   modeByte := $04;
      rmFSK:  modeByte := $08;
      rmData: modeByte := $09;
   else
      begin
      logger.error('[SetMode] unsupported mode %d',[Ord(mode)]);
      Exit;
      end;
   end;
   if vfo = nrVFOB then
      begin
      modeByte := modeByte or FT1KMP_VFOB_FLAG;   // VFO B: +$80 into the mode byte
      end;
   // MB=3: mode byte at byte[3], opcode $0C at byte[4].
   Self.SendBytes($00, $00, $00, modeByte, FT1KMP_SET_MODE_OPCODE);
end;

procedure TFT1000MPRadio.Split(splitOn: boolean);
begin
   // Split IS read back (rcReadSplit), so the poll is the single source of truth
   // and we do NOT set it locally -- same rule as RIT/XIT here and in the Kenwood
   // serial driver.  Manual: opcode $01, T = $01 on / $00 off.
   if splitOn then
      begin
      Self.SendBytes($00, $00, $00, $01, FT1KMP_SET_SPLIT_OPCODE);
      end
   else
      begin
      Self.SendBytes($00, $00, $00, $00, FT1KMP_SET_SPLIT_OPCODE);
      end;
end;

// Emit one CLAR command.  BOTH halves are always populated -- the offset in
// C1..C3 and the on/off/clear action in C4 -- because the manual page documents
// the two halves of opcode $09 without stating whether a single command carries
// both or whether C4 selects between an "offset" form and an "on/off" form.
// Filling both is the only encoding that is correct under EITHER reading:
//   - if one command carries both, callers pass the offset they want preserved
//     (or changed) and the state they want, and nothing is clobbered;
//   - if C4 selects the form, the ignored half is simply redundant.
// Worst case under the second reading is that an exact-offset set is a no-op,
// which is benign and immediately visible in the log via the decoded readback.
// BENCH CHECK to settle it: with RX CLAR on and a non-zero offset, call RITOn --
// if the offset survives, both halves apply; if it zeroes, C4 selects the form.
procedure TFT1000MPRadio.SendRITOffset(offsetHz: integer; action: Byte);
var
   magnitude: integer;
   steps10: integer;
   kHzDigit: integer;
   hzPart: integer;
   c1, c2, c3: Byte;
begin
   magnitude := Abs(offsetHz);
   if magnitude > FT1KMP_CLAR_MAX_HZ then
      begin
      logger.Warn('[SendRITOffset] offset %d Hz exceeds the +/-%d Hz RIT offset range; clamping',
                  [offsetHz, FT1KMP_CLAR_MAX_HZ]);
      magnitude := FT1KMP_CLAR_MAX_HZ;
      end;
   steps10  := magnitude div 10;          // radio resolution is 10 Hz
   kHzDigit := steps10 div 100;           // 0..9  -> C2
   hzPart   := steps10 mod 100;           // 0..99 -> C1, packed BCD
   c2 := Byte(kHzDigit);
   c1 := Byte(((hzPart div 10) shl 4) or (hzPart mod 10));
   if offsetHz < 0 then
      begin
      c3 := FT1KMP_CLAR_DIR_MINUS;
      end
   else
      begin
      c3 := FT1KMP_CLAR_DIR_PLUS;
      end;
   Self.SendBytes(c1, c2, c3, action, FT1KMP_CLAR_OPCODE);
end;

// The radio has ONE RIT offset (rcSharedRITXITOffset), so CLAR CLEAR is a single
// action -- RITClear and XITClear are necessarily the same command.
procedure TFT1000MPRadio.RITClear(whichVFO: TVFO);
begin
   Self.SendRITOffset(0, FT1KMP_CLAR_CLEAR);
end;

procedure TFT1000MPRadio.XITClear(whichVFO: TVFO);
begin
   Self.RITClear(whichVFO);
end;

// On/off carry the CURRENT offset so that, if a single CLAR command sets both
// halves, merely switching RIT on does not zero the operator's offset.
// State is NOT written locally: this radio reports RIT/XIT back (rcReadRIT), so
// the status poll is the single source of truth -- same rule the Kenwood serial
// driver follows.
procedure TFT1000MPRadio.RITOn(whichVFO: TVFO);
begin
   Self.SendRITOffset(Self.localRITOffset, FT1KMP_CLAR_RX_ON);
end;

procedure TFT1000MPRadio.RITOff(whichVFO: TVFO);
begin
   Self.SendRITOffset(Self.localRITOffset, FT1KMP_CLAR_RX_OFF);
end;

procedure TFT1000MPRadio.XITOn(whichVFO: TVFO);
begin
   Self.SendRITOffset(Self.localXITOffset, FT1KMP_CLAR_TX_ON);
end;

procedure TFT1000MPRadio.XITOff(whichVFO: TVFO);
begin
   Self.SendRITOffset(Self.localXITOffset, FT1KMP_CLAR_TX_OFF);
end;

// Exact offset set.  C4 repeats the state we currently believe is active so the
// command cannot switch the RIT offset on or off as a side effect: whichever of
// RX/TX CLAR is on keeps its action byte, and if neither is on we address RX
// CLAR with its OFF byte (a pure offset write).  Offsets are quantised to the
// radio's 10 Hz step and clamped to +/-9.99 kHz inside SendRITOffset.
procedure TFT1000MPRadio.SetRITFreq(whichVFO: TVFO; hz: integer);
var
   action: Byte;
begin
   if Self.RITState then
      begin
      action := FT1KMP_CLAR_RX_ON;
      end
   else if Self.XITState then
      begin
      action := FT1KMP_CLAR_TX_ON;
      end
   else
      begin
      action := FT1KMP_CLAR_RX_OFF;
      end;
   Self.SendRITOffset(hz, action);
end;

// One shared RIT offset -- setting "XIT" offset is the same register.
procedure TFT1000MPRadio.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SetRITFreq(whichVFO, hz);
end;

initialization
  RegisterRadio(FT1000MP,
     function: TFactoryRadioBase begin Result := TFT1000MPRadio.Create end,
     'Yaesu FT-1000MP', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     1024
     );

end.
