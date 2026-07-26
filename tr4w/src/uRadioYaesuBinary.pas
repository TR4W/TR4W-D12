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
unit uRadioYaesuBinary;

{
  Yaesu binary CAT -- old 5-byte binary family base (legacy rtYaesu1) for the
  FT-1000MP (this batch) and later FT1000/FT990/FT920/FT847/FT817-18/FT767 etc.
  Its own family base (NOT shared with the ASCII rtYaesu4 Yaesu serial -- the
  survey confirmed zero shared parsing between the two).

  PORTED from the bench-proven legacy path (uRadioPolling.pFT1000MP +
  LOGRADIO rtYaesu1 send arm).  Yaesu old-CAT convention: every command is
  [P1 P2 P3 P4 Opcode] (opcode LAST), 5 bytes, sent byte-exact
  (SerialProtocolIsBinary = True, no CR/LF).

  READ: the FT1000MP answers a poll with a FIXED-LENGTH block and NO terminator,
  which the terminator-based reading thread cannot delimit.  This base uses the
  new SerialFixedFrameLength hook (= 32) so the reading thread hands over 32-byte
  frames.  We poll the dual-VFO status ($00 $00 $00 $03 $10 -> 32 bytes) each
  cycle -- it carries both VFOs' freq+mode, so ONE constant frame length covers
  the display:
    - VFO A freq: bytes 2-5, 4-byte BIG-ENDIAN, * 0.625 (FT1000MP scaling)
    - VFO A mode: byte 8 and $07  (0=LSB 1=USB 2=CW 3=AM 4=FM 5=RTTY 6=Data)
    - VFO B freq: bytes 18-21 (+16), * 0.625;  VFO B mode: byte 24 and $07
    - Clarifier (RIT/XIT): offset bytes 6-7 signed BE * 0.625, flags byte 10
      (bit1 = RX CLAR/RIT, bit0 = TX CLAR/XIT) -- VFO A record only; see the
      const block below for the bench capture this was derived from.
  (Positions are 1-based, matching the legacy tBuf[] indexing.)

  WRITE: set-freq is packed BCD of (Freq div 10), byte-swapped (SW=1), with
  opcode $0A last.  Set-mode uses opcode $0C with the mode byte at byte[3]
  (mb=3); VFO B ORs +$80 into the opcode/mode byte.  Split is SET-ONLY here (tracked
  locally, like the
  minimal Icoms) -- the legacy split-read came from a separate 6-byte $FA poll,
  which we skip to keep ONE frame length.

  RIT/XIT: the READ path is bench-derived and certain (see the const block).  The
  SET path (CLAR, opcode $09) is implemented from the FT-1000MP CAT manual, which
  NY4I supplied -- read side proven on air, set side NOT yet bench-confirmed.  The
  one thing the manual page leaves open is whether a single $09 carries both the
  offset and the on/off action or whether C4 selects between two forms; see
  SendClarifier for the encoding chosen to be safe under either reading, and for
  the one-step bench check that settles it.
  RITBumpUp/Down stay stubs: this radio has no bump command (the offset would have
  to be re-sent), and the caller does not define a step size -- the Icom base
  leaves them unimplemented for the same reason.

  CW keying: inert stubs (legacy path / future CW Keyer Factory).

  ****  BENCH VALIDATION REQUIRED (flag to NY4I / parent)  ****
    (1) The SerialFixedFrameLength=32 read path is a NEW base mechanism and is
        UNPROVEN on hardware -- fixed-length framing can drift if a byte is
        dropped (no self-syncing terminator).  Confirm on the real FT1000MP; if
        it drifts, we add a per-poll buffer-clear/resync.
    (2) The BCD set-freq byte order (swap) and the binary write path
        (byte-exact, no CR/LF) need on-air confirmation.
    (3) The x0.625 read scaling + mode-bit table are from the survey; verify.
}

interface

uses uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uRadioRegistry;

const
   // ---- FT-1000MP dual-VFO status block field map (1-based frame positions) ----
   // The block is two 16-byte VFO records: VFO A = 1..16, VFO B = 17..32.
   // DERIVED FROM A CONTROLLED BENCH CAPTURE on NY4I's FT-1000MP (2026-07-26):
   // with frequency/mode/split held fixed and only the clarifier exercised, exactly
   // three byte positions moved -- 6, 7 and 10.  Settle points were exact:
   //   +1.00 kHz -> pos 6,7 = $06 $40 =  1600 * 0.625 =  1000 Hz
   //   -1.00 kHz -> pos 6,7 = $F9 $C0 = -1600 * 0.625 = -1000 Hz
   // RX CLAR alone set pos 10 = $02; TX CLAR alone set pos 10 = $01.
   // The clarifier is reported in the VFO A record ONLY (pos 22,23,26 never moved),
   // which matches the radio having a single shared clarifier -- see
   // rcSharedRITXITOffset on the capability set.
   YB_CLAR_OFFSET_POS = 6;     // 2 bytes, SIGNED 16-bit big-endian, * 0.625 Hz
   YB_CLAR_FLAGS_POS  = 10;    // clarifier on/off bits
   YB_CLAR_RX_BIT     = $02;   // RX CLAR = TR4W RIT
   YB_CLAR_TX_BIT     = $01;   // TX CLAR = TR4W XIT

   // ---- CLAR command (opcode $09), per the FT-1000MP CAT manual ----
   //   [C1 C2 C3 C4 $09]
   //   C1 = Hz offset, packed BCD 00-99  -- in units of 10 Hz (see below)
   //   C2 = kHz offset, BCD 00-09
   //   C3 = direction: $00 = +, $FF = -
   //   C4 = action: RX CLAR off/on $00/$01, TX CLAR off/on $80/$81, CLAR CLEAR $FF
   // C1 is 10 Hz per count, not 1 Hz: that is the only reading under which C1+C2
   // span the radio's documented +/-9.99 kHz clarifier range (99*10 + 9*1000 =
   // 9990 Hz), and it matches the manual's note that resolution below 10 Hz
   // cannot be displayed.
   YB_CLAR_OPCODE     = $09;
   YB_CLAR_RX_OFF     = $00;
   YB_CLAR_RX_ON      = $01;
   YB_CLAR_TX_OFF     = $80;
   YB_CLAR_TX_ON      = $81;
   YB_CLAR_CLEAR      = $FF;
   YB_CLAR_DIR_PLUS   = $00;
   YB_CLAR_DIR_MINUS  = $FF;
   YB_CLAR_MAX_HZ     = 9990;  // +/- 9.99 kHz, in 10 Hz steps

type
  TYaesuBinary = class(TFactoryRadioBase)
  protected
    logger: TLogLogger;
    FCWReverse: boolean;   // CW mode byte $03 (reverse) vs $02; default off
    procedure SendBytes(b0, b1, b2, b3, b4: Byte);
    function  StatusModeToMode(b: Byte): TRadioMode;
    function  YaesuFreqRead(const frame: string; pos1: integer): integer;
    function  ClarifierOffsetRead(const frame: string; pos1: integer): integer;
    procedure SendClarifier(offsetHz: integer; action: Byte);
  public
    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;

    procedure Transmit; override;
    procedure Receive; override;
    procedure BufferCW(cwChars: string); override;
    procedure SendCW; override;
    procedure StopCW; override;

    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
    procedure SetCWSpeed(speed: integer); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure XITClear(whichVFO: TVFO); override;
    procedure RITBumpDown; override;
    procedure RITBumpUp; override;
    procedure RITOn(whichVFO: TVFO); override;
    procedure RITOff(whichVFO: TVFO); override;
    procedure XITOn(whichVFO: TVFO); override;
    procedure XITOff(whichVFO: TVFO); override;
    procedure Split(splitOn: boolean); override;
    procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
    function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
    procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
    function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
    function  MemoryKeyer(mem: integer): boolean; override;
    procedure VFOBumpDown(whichVFO: TVFO); override;
    procedure VFOBumpUp(whichVFO: TVFO); override;

    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
  end;

  // FT-1000MP (and Mark V) -- the rtYaesu1 exemplar.
  TFT1000MPRadio = class(TYaesuBinary)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuBinary.Create;
begin
   // The reading thread dispatches through the handler handed to the base ctor
   // (baseProcMsg), NOT through the virtual ProcessMsg.  Passing nil here left
   // rt.msgHandler unassigned, so every 32-byte frame was read, logged and then
   // silently DROPPED -- no freq/mode ever reached the radio window and the
   // liveness watchdog (fed by UpdateLastValidResponse inside ProcessMsg) kept
   // declaring the radio dead.  Wire our own ProcessMsg, as every other radio does.
   inherited Create(ProcessMsg);
   logger := TLogLogger.GetLogger('TR4WDebugLog.YaesuBinary');
   FCWReverse := False;

   SerialProtocolIsBinary  := True;    // byte-exact 5-byte frames, no codepage decode
   bAddTermination         := False;   // NO CR/LF on binary CAT
   SerialFixedFrameLength  := 32;      // dual-VFO status block; reading thread hands over 32-byte frames
   requiresPolling         := True;
   pollingInterval         := 150;     // BR4800; give the 32-byte answer time
   honorsFreqPollRate      := False;
end;

constructor TFT1000MPRadio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-1000MP';
   // Capabilities (declarative -- Yaesu does not consume FCapabilities yet), stated
   // as what THIS DRIVER actually does, not what the radio could do:
   //   rcReadRIT            -- clarifier state+offset ARE decoded from the status
   //                           block (bench-derived 2026-07-26); this beats the D7
   //                           legacy path, which never decoded RIT for the FT1000MP.
   //   rcSharedRITXITOffset -- one clarifier register feeds both RIT and XIT.
   //   NOT rcReadSplit      -- split is SET-ONLY here.  The legacy path read it from
   //                           a third 6-byte $FA poll, which we skip to keep a single
   //                           fixed frame length; declaring it would be a lie.
   FCapabilities.Flags := [rcReadRIT, rcSharedRITXITOffset];
   FCapabilities.CWSpeedMin := 4;
   FCapabilities.CWSpeedMax := 60;
end;

// Send one 5-byte Yaesu command byte-exact (opcode last).
procedure TYaesuBinary.SendBytes(b0, b1, b2, b3, b4: Byte);
begin
   Self.SendToRadio(Chr(b0) + Chr(b1) + Chr(b2) + Chr(b3) + Chr(b4));
end;

function TYaesuBinary.Connect: integer;
begin
   Result := Inherited Connect;
   // No prime needed -- PollRadioState pulls status each cycle.
end;

procedure TYaesuBinary.PollRadioState;
begin
   // Dual-VFO status: $00 $00 $00 $03 $10 -> 32-byte block (both VFOs).  Also the
   // keep-alive that drives serial power-cycle recovery.
   Self.SendBytes($00, $00, $00, $03, $10);
end;

// 4-byte big-endian binary frequency at 1-based position pos1, * 0.625.
function TYaesuBinary.YaesuFreqRead(const frame: string; pos1: integer): integer;
var raw: Int64;
begin
   raw := (Int64(Ord(frame[pos1]))   shl 24) or
          (Int64(Ord(frame[pos1+1])) shl 16) or
          (Int64(Ord(frame[pos1+2])) shl 8)  or
           Int64(Ord(frame[pos1+3]));
   Result := Round(raw * 0.625);
end;

// Clarifier offset: SIGNED 16-bit big-endian at 1-based position pos1, * 0.625 Hz
// (the same scaling the frequency field uses).  Bench-verified at +/-1.00 kHz.
function TYaesuBinary.ClarifierOffsetRead(const frame: string; pos1: integer): integer;
var
   raw: integer;
begin
   raw := (Ord(frame[pos1]) shl 8) or Ord(frame[pos1 + 1]);
   if raw >= $8000 then
      begin
      raw := raw - $10000;   // two's complement -> negative clarifier
      end;
   Result := Round(raw * 0.625);
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
procedure TYaesuBinary.SendClarifier(offsetHz: integer; action: Byte);
var
   magnitude: integer;
   steps10: integer;
   kHzDigit: integer;
   hzPart: integer;
   c1, c2, c3: Byte;
begin
   magnitude := Abs(offsetHz);
   if magnitude > YB_CLAR_MAX_HZ then
      begin
      logger.Warn('[SendClarifier] offset %d Hz exceeds the +/-%d Hz clarifier range; clamping',
                  [offsetHz, YB_CLAR_MAX_HZ]);
      magnitude := YB_CLAR_MAX_HZ;
      end;
   steps10  := magnitude div 10;          // radio resolution is 10 Hz
   kHzDigit := steps10 div 100;           // 0..9  -> C2
   hzPart   := steps10 mod 100;           // 0..99 -> C1, packed BCD
   c2 := Byte(kHzDigit);
   c1 := Byte(((hzPart div 10) shl 4) or (hzPart mod 10));
   if offsetHz < 0 then
      begin
      c3 := YB_CLAR_DIR_MINUS;
      end
   else
      begin
      c3 := YB_CLAR_DIR_PLUS;
      end;
   Self.SendBytes(c1, c2, c3, action, YB_CLAR_OPCODE);
end;

function TYaesuBinary.StatusModeToMode(b: Byte): TRadioMode;
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

procedure TYaesuBinary.ProcessMsg(msg: string);
var
   clarFlags: Byte;
   clarHz: integer;
begin
   UpdateLastValidResponse;   // any frame proves the radio is answering
   if Length(msg) < 32 then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes)',[Length(msg)]);
      Exit;
      end;
   // VFO A: freq bytes 2-5, mode byte 8.
   Self.vfo[nrVFOA].frequency := YaesuFreqRead(msg, 2);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[8]));
   // VFO B: freq bytes 18-21, mode byte 24.
   Self.vfo[nrVFOB].frequency := YaesuFreqRead(msg, 18);
   Self.vfo[nrVFOB].band      := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
   Self.vfo[nrVFOB].mode      := StatusModeToMode(Ord(msg[24]));
   // Clarifier -> RIT/XIT.  Routed through the BASE setters, never Self.<scalar>:
   // the radio window reads the PER-VFO copies, which only the setters write (the
   // K3 serial-display bug, commit 1b205ce).  One shared offset feeds both RIT and
   // XIT here -- see rcSharedRITXITOffset.  The radio keeps reporting the offset
   // while the clarifier is switched off, and we report it faithfully; the display
   // gates on the on/off state.
   clarFlags := Ord(msg[YB_CLAR_FLAGS_POS]);
   clarHz    := ClarifierOffsetRead(msg, YB_CLAR_OFFSET_POS);
   Self.SetRITOn((clarFlags and YB_CLAR_RX_BIT) <> 0);
   Self.SetXITOn((clarFlags and YB_CLAR_TX_BIT) <> 0);
   Self.SetRITOffset(clarHz);
   Self.SetXITOffset(clarHz);
   Self.SetActiveVFO(nrVFOA);
end;

procedure TYaesuBinary.Transmit;
begin
   // PTT via command not implemented in the factory path yet (legacy T:1).
   logger.Warn('[Transmit] PTT-via-CAT not implemented for Yaesu binary');
end;

procedure TYaesuBinary.Receive;
begin
   logger.Warn('[Receive] PTT-via-CAT not implemented for Yaesu binary');
end;

procedure TYaesuBinary.BufferCW(cwChars: string);
begin
end;

procedure TYaesuBinary.SendCW;
begin
end;

procedure TYaesuBinary.StopCW;
begin
end;

procedure TYaesuBinary.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   f10: LongWord;
   bcd: array[0..3] of Byte;
   i: integer;
   opcode: Byte;
begin
   // Packed BCD of (freq div 10), 4 bytes, MSD first, then BYTE-SWAPPED (SW=1).
   f10 := LongWord(freq div 10);
   for i := 3 downto 0 do
      begin
      bcd[i] := Byte(((f10 mod 10)) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   opcode := $0A;
   if vfo = nrVFOB then
      begin
      opcode := opcode or $80;
      end;
   // SW=1 -> reverse the 4 BCD bytes, opcode last.  (Bench-verify byte order.)
   Self.SendBytes(bcd[3], bcd[2], bcd[1], bcd[0], opcode);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
   // Post: set VFO A active (per legacy FT1000MP freq-set postamble).
   Self.SendBytes($00, $00, $00, $00, $05);
end;

procedure TYaesuBinary.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
   opcode: Byte;
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
   opcode := $0C;
   if vfo = nrVFOB then
      begin
      modeByte := modeByte or $80;   // VFO B: +$80 into the mode byte (legacy)
      end;
   // mb=3: mode byte at byte[3], opcode $0C at byte[4].
   Self.SendBytes($00, $00, $00, modeByte, opcode);
end;

function TYaesuBinary.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
begin
   Result := Self.vfo[vfo].mode;
end;

procedure TYaesuBinary.SetCWSpeed(speed: integer);
begin
   logger.Warn('[SetCWSpeed] not implemented for Yaesu binary (%d)',[speed]);
end;

// The radio has ONE clarifier (rcSharedRITXITOffset), so CLAR CLEAR is a single
// action -- RITClear and XITClear are necessarily the same command.
procedure TYaesuBinary.RITClear(whichVFO: TVFO);
begin
   Self.SendClarifier(0, YB_CLAR_CLEAR);
end;

procedure TYaesuBinary.XITClear(whichVFO: TVFO);
begin
   Self.RITClear(whichVFO);
end;

procedure TYaesuBinary.RITBumpDown;
begin
end;

procedure TYaesuBinary.RITBumpUp;
begin
end;

// On/off carry the CURRENT offset so that, if a single CLAR command sets both
// halves, merely switching RIT on does not zero the operator's offset.
// State is NOT written locally: this radio reports RIT/XIT back (rcReadRIT), so
// the status poll is the single source of truth -- same rule the Kenwood serial
// driver follows.
procedure TYaesuBinary.RITOn(whichVFO: TVFO);
begin
   Self.SendClarifier(Self.localRITOffset, YB_CLAR_RX_ON);
end;

procedure TYaesuBinary.RITOff(whichVFO: TVFO);
begin
   Self.SendClarifier(Self.localRITOffset, YB_CLAR_RX_OFF);
end;

procedure TYaesuBinary.XITOn(whichVFO: TVFO);
begin
   Self.SendClarifier(Self.localXITOffset, YB_CLAR_TX_ON);
end;

procedure TYaesuBinary.XITOff(whichVFO: TVFO);
begin
   Self.SendClarifier(Self.localXITOffset, YB_CLAR_TX_OFF);
end;

procedure TYaesuBinary.Split(splitOn: boolean);
begin
   // Split is SET-ONLY (no readback in this poll).  Track locally so the window
   // reflects the commanded state (like the minimal Icoms / IC-718).
   if splitOn then
      begin
      Self.SendBytes($00, $00, $00, $01, $01);
      end
   else
      begin
      Self.SendBytes($00, $00, $00, $00, $01);
      end;
   Self.SetSplitOn(splitOn);
end;

// Exact offset set.  C4 repeats the state we currently believe is active so the
// command cannot switch the clarifier on or off as a side effect: whichever of
// RX/TX CLAR is on keeps its action byte, and if neither is on we address RX
// CLAR with its OFF byte (a pure offset write).  Offsets are quantised to the
// radio's 10 Hz step and clamped to +/-9.99 kHz inside SendClarifier.
procedure TYaesuBinary.SetRITFreq(whichVFO: TVFO; hz: integer);
var
   action: Byte;
begin
   if Self.RITState then
      begin
      action := YB_CLAR_RX_ON;
      end
   else if Self.XITState then
      begin
      action := YB_CLAR_TX_ON;
      end
   else
      begin
      action := YB_CLAR_RX_OFF;
      end;
   Self.SendClarifier(hz, action);
end;

// One shared clarifier -- setting "XIT" offset is the same register.
procedure TYaesuBinary.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SetRITFreq(whichVFO, hz);
end;

procedure TYaesuBinary.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
begin
   logger.Warn('[SetBand] rides freq set for Yaesu binary');
end;

function TYaesuBinary.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
   Result := rbNone;
end;

procedure TYaesuBinary.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
end;

function TYaesuBinary.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   Result := 0;
end;

function TYaesuBinary.MemoryKeyer(mem: integer): boolean;
begin
   Result := True;   // unsupported
end;

procedure TYaesuBinary.VFOBumpDown(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.VFOBumpUp(whichVFO: TVFO);
begin
end;

// Not used for the binary protocol (commands are 5-byte frames via SendBytes).
procedure TYaesuBinary.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   logger.Warn('[SendToRadio(vfo,cmd,data)] not used by Yaesu binary');
end;

initialization
  RegisterRadio(FT1000MP,
     function: TFactoryRadioBase begin Result := TFT1000MPRadio.Create end,
     'Yaesu FT-1000MP', [rlSerial], 0, False);

end.
