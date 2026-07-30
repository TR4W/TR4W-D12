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
unit uRadioYaesuFT817Group;

{
  SHARED BASE for the small-rig old-binary Yaesus -- FT-817, FT-818, FT-847,
  FT-857 and FT-897.  Registers NOTHING.

  These five share the 5-byte command frame and the 5-byte status answer, as
  distinct from the FT-1000MP's 32-byte block.  Each model lives in its own unit
  and states its own name, mode bytes and the four group traits below.

  WHY THIS BASE EXISTS.  All five used to hang off TYaesuFT817Radio -- the FT-818
  and FT-847 directly, the FT-857 directly, and the FT-897 off the FT-857, three
  models deep.  NY4I: "I still want an individual class for every radio... when I
  look at the project, I should see a class for every single radio", and a model
  must never be another model's base.

  THE ARGUMENT THAT SETTLED IT was that these were RESTRICTIONS, not
  specializations.  The FT-847 had to write

      FHasSplit := False; FHasClarifier := False;
      FModeDIGU := $FF;   FModeDIGL := $FF;
      FCapabilities.Flags := [];        <- undoing the FT-817's [rcReadSplit]

  Every one of those lines existed to UNDO something inherited that the radio does
  not have.  A child that withdraws its parent's promises is not a subtype of it.

  SO THIS BASE PROMISES NOTHING.  The traits default to the restrictive value and
  the capability set starts empty; each model ADDS what it has.  The FT-847 no
  longer subtracts anything -- it simply declines to add.  A model that forgets a
  trait loses a feature (visible, reported) rather than emitting an opcode its
  radio never defined (silent, and potentially harmful).

  THE FOUR GROUP TRAITS -- per-model facts this base acts on:
    FCATEnableOnConnect  the FT-847 answers nothing until a CAT-enable frame
    FHasSplit            the FT-847's chart has no SPLIT row
    FHasClarifier        the FT-847's chart has no CLAR rows
    FModeDIGU/FModeDIGL  $FF (MODEBYTE_NONE) where the radio has no such mode

  NONE OF THE FIVE HAS EVER BEEN BENCHED.  uTestYaesuBinary's FT-847 guard tests
  are the safety net for this file: they assert what goes on the wire, so a lost
  trait shows up as a test failure rather than an undefined opcode on someone's
  radio.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioBand, StrUtils, SysUtils, Math,
     TF, Log4D, VC, uRadioRegistry;

const
   // ---- Poll and framing ----
   // Legacy FT847PollString = $00 $00 $00 $00 $03 -> 5-byte answer:
   //   bytes 1-4 : frequency, packed BCD, 8 digits, in units of 10 Hz
   //   byte  5   : mode
   // Two requests per cycle, ALWAYS in this order.  The radio answers in the order
   // asked, so the replies concatenate into ONE deterministically-delimited frame --
   // the same technique the FT-1000MP driver uses to get split without giving up a
   // single fixed frame length:
   //     $00 $00 $00 $00 $03  -> 5 bytes: frequency + mode   (manual Note 5)
   //     $00 $00 $00 $00 $F7  -> 1 byte : TX status          (manual Note 4)
   FT817_POLL_OPCODE      = $03;
   FT817_TX_STATUS_OPCODE = $F7;
   FT817_FREQMODE_LEN     = 5;
   FT817_TX_STATUS_LEN    = 1;
   FT817_FRAME_LEN        = FT817_FREQMODE_LEN + FT817_TX_STATUS_LEN;   // 6
   FT817_MODE_POS         = 5;
   FT817_TX_STATUS_POS    = FT817_FREQMODE_LEN + 1;   // 6

   // TX status bits (manual Note 4).  NOTE THE INVERSION on split.
   FT817_TXST_SPLIT_BIT = $20;   // bit 5: 0 = SPLIT ON, 1 = SPLIT OFF  (inverted!)
   FT817_TXST_PTT_BIT   = $80;   // bit 7: polarity NOT stated in Note 4 -- unused
   FT817_TXST_SWR_BIT   = $40;   // bit 6: 0 = HI SWR off, 1 = HI SWR on

   // ---- Write opcodes (row: SFOC $01, SMOC $07, MB 0, SW 0) ----
   FT817_SET_FREQ_OPCODE = $01;   // BCD MSD-first, NOT byte-swapped
   FT817_SET_MODE_OPCODE = $07;   // mode byte at [0], not [3]
   FT817_PTT_ON_OPCODE   = $08;   // row TX: $08  (legacy FT817PTTOn)
   FT817_PTT_OFF_OPCODE  = $88;   // row RX: $88  (legacy FT817PTTOff)

   // ---- Clarifier and split, from the FT-817 CAT manual command table.
   // The manual shows all four parameter bytes as "don't care" for these; we send
   // $00.  Note the on/off pairing by bit 7, the same shape as PTT $08/$88. ----
   FT817_CLAR_ON_OPCODE  = $05;
   FT817_CLAR_OFF_OPCODE = $85;
   FT817_SPLIT_ON_OPCODE  = $02;
   FT817_SPLIT_OFF_OPCODE = $82;
   FT817_VFO_TOGGLE_OPCODE = $81;   // VFO-A/B toggle; no TR4W hook drives it today

   // CLAR Frequency: [P1 xx P3 P4 $F5]
   //   P1 = $00 -> "+" offset;  P1 <> $00 -> "-" offset
   //   P3, P4 = the offset, packed BCD: the manual's example "12, 34 = 12.34 kHz"
   //            means P3 is whole kHz and P4 is hundredths of a kHz, i.e. 10 Hz
   //            per count -> Hz = (P3 * 1000) + (P4 * 10).
   FT817_CLAR_FREQ_OPCODE = $F5;
   FT817_CLAR_DIR_PLUS    = $00;
   FT817_CLAR_DIR_MINUS   = $01;   // manual only requires "not $00"
   // Largest value the two BCD bytes can express (99.99 kHz).  This is an ENCODING
   // limit, not a claim about the radio's clarifier range -- the manual's own
   // example (12.34 kHz) already exceeds the +/-9.99 kHz the FT-1000MP allows, so
   // we do not invent a tighter radio limit here.
   FT817_CLAR_MAX_HZ      = 99990;

   // ---- Mode bytes for WRITING (row: CW $02, LSB $00, USB $01, FM $08, AM $04,
   //      DIGL $0C, DIGU $0A).  The READ map is wider -- see StatusModeToMode. ----
   FT817_MODE_LSB  = $00;
   FT817_MODE_USB  = $01;
   FT817_MODE_CW   = $02;
   FT817_MODE_CWR  = $03;
   FT817_MODE_AM   = $04;
   FT817_MODE_WFM  = $06;
   FT817_MODE_FM   = $08;
   FT817_MODE_DIGU = $0A;
   FT817_MODE_DIGL = $0C;

   FT817_MAX_FREQ_HZ = 999999990;  // 8 BCD digits at 10 Hz resolution

   // FT-847 CAT-enable preamble (legacy TurnOn847CATString): the 5-byte frame with
   // opcode $00.  The FT-847 ignores all other CAT traffic until it receives this.
   FT847_CAT_ON_OPCODE = $00;


type
  TYaesuFT817Group = class(TYaesuBinary)
  protected
    FCATEnableOnConnect: Boolean;
    FModeDIGU: Byte;        // rmData  ($FF = radio has no DIG mode)
    FModeDIGL: Byte;        // rmFSK   ($FF = radio has no DIG-L / PKT mode)
    FHasSplit: Boolean;
    FHasClarifier: Boolean;

    function  StatusModeToMode(b: Byte): TRadioMode;
    function  BCDFreqRead(const frame: string; pos1: integer): integer;
  public
    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    function  ValidateFrame(const frame: string): Boolean; override;

    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    procedure Transmit; override;
    procedure Receive; override;
    procedure Split(splitOn: boolean); override;
    procedure RITOn(whichVFO: TVFO); override;
    procedure RITOff(whichVFO: TVFO); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
  end;

implementation

// Transport + framing defaults, and RESTRICTIVE trait defaults.  This base makes
// no claim about split, the clarifier or data modes; each model adds what it has.
constructor TYaesuFT817Group.Create;
begin
   inherited Create;

   SerialFixedFrameLength := FT817_FRAME_LEN;
   // 5 bytes out + 5 back = 10 bytes/cycle, trivial next to the FT-1000MP's 48,
   // so a faster cadence is affordable here.
   pollingInterval        := 100;

   // NO capability claims.  A model states what it can actually read.  (This is
   // what stops the FT-847 having to erase an inherited [rcReadSplit].)
   FCapabilities.Flags := [];
   FCapabilities.CWSpeedMin := 0;
   FCapabilities.CWSpeedMax := 0;

   // Restrictive trait defaults: a model that forgets one loses a feature rather
   // than sending an opcode its radio never defined.
   FCATEnableOnConnect := False;
   FModeDIGU           := MODEBYTE_NONE;
   FModeDIGL           := MODEBYTE_NONE;
   FHasSplit           := False;
   FHasClarifier       := False;
end;

function TYaesuFT817Group.Connect: integer;
begin
   Result := inherited Connect;
   // The FT-847 answers nothing until CAT is enabled (its chart: P1=00 CAT ON,
   // P1=80 CAT OFF).  Legacy sent this from the top of the poll procedure, i.e.
   // once per thread start; connect is the same moment, named honestly.
   if (Result = 0) and FCATEnableOnConnect then
      begin
      logger.Info('[Connect] Sending CAT-enable frame');
      Self.SendBytes($00, $00, $00, $00, FT847_CAT_ON_OPCODE);
      end;
end;

// NOTE ON DEFERRED WRITES -- deliberately NOT ported.
//
// Legacy queued set-freq/set-mode for the FT-857/897 alone and emitted them from
// inside the poll loop, each followed by Sleep(100) + PurgeComm(PURGE_RXCLEAR):
//
//     if RadioModel in [FT857, FT897] then tYaesuSendFreq := True
//     else WriteToCATPort(tYaesuFreq5Bytes, 5);     (LOGRADIO :3508, :3532)
//
// The FT-857D CAT manual (pages 115-118) gives no basis for it: the data protocol,
// the 5-byte structure and every opcode used here are identical to the FT-817's,
// and nothing is said about write timing or a settle delay.  NY4I reached the same
// reading of the manual.
//
// The factory also handles the underlying problem better than a timed purge:
// ValidateFrame discards a byte and resyncs when a frame fails to validate, which
// self-corrects whether or not a unit replies to a set command -- see the ack
// discussion in the unit header.  A Sleep(100) per write would additionally stall
// the poll thread on every QSY.
//
// BENCH WATCH-ITEM: on a real FT-857, watch for repeated "Frame resync: discarded
// N byte(s)" WARNINGS with N > 1 after a QSY.  A single discarded byte is the
// expected ack and is healthy; a persistent pattern would mean the legacy deferral
// was compensating for something real, and this decision should be revisited.

procedure TYaesuFT817Group.PollRadioState;
begin
   // Both requests every cycle, in this fixed order -- see FT817_FRAME_LEN.  The
   // first is the legacy FT847PollString; the second buys us split readback, which
   // the legacy path never had.  Also the keep-alive driving power-cycle recovery.
   Self.SendBytes($00, $00, $00, $00, FT817_POLL_OPCODE);       // -> 5 bytes
   Self.SendBytes($00, $00, $00, $00, FT817_TX_STATUS_OPCODE);  // -> 1 byte
end;

// Frequency: 4 bytes of packed BCD (8 digits) at 1-based pos1, in units of 10 Hz.
// The legacy pFT817_FT847_FT857_FT897 accumulates the eight nibbles and multiplies
// by 10 at the end; this is the same arithmetic, written as a loop.
function TYaesuFT817Group.BCDFreqRead(const frame: string; pos1: integer): integer;
var
   i: integer;
   b: Byte;
   value: integer;
begin
   value := 0;
   for i := 0 to 3 do
      begin
      b := Ord(frame[pos1 + i]);
      value := (value * 10) + ((b and $F0) shr 4);
      value := (value * 10) +  (b and $0F);
      end;
   Result := value * 10;   // radio reports to 10 Hz resolution
end;

// Mode byte (DATA 5), exactly the set the manual's Note 5 documents:
//   00 LSB  01 USB  02 CW  03 CWR  04 AM  06 WFM  08 FM  0A DIG  0C PKT
// The legacy pFT817_FT847_FT857_FT897 also accepted $82/$83/$84/$88 -- those are
// NOT in the FT-817's table (they most likely came from the FT-847, which shares
// that procedure), so they are deliberately not honoured here.  Keeping the map
// tight is a diagnostic asset: if the fixed framing ever slips (see the unit
// header), a shifted byte lands outside the table and gets logged instead of
// silently decoding as a plausible mode.
// The legacy also collapsed everything to Phone/CW/Digital/FM; we keep the finer
// sideband and CW-reverse identity.
function TYaesuFT817Group.StatusModeToMode(b: Byte): TRadioMode;
begin
   case b of
      FT817_MODE_LSB:  Result := rmLSB;
      FT817_MODE_USB:  Result := rmUSB;
      FT817_MODE_CW:   Result := rmCW;
      FT817_MODE_CWR:  Result := rmCWRev;
      FT817_MODE_AM:   Result := rmAM;
      FT817_MODE_WFM,
      FT817_MODE_FM:   Result := rmFM;   // WFM has no distinct TR4W mode
      FT817_MODE_DIGU,
      FT817_MODE_DIGL: Result := rmData;
   else
      begin
      logger.Warn('[StatusModeToMode] unrecognised mode byte $%.2x (framing slip?)', [b]);
      Result := rmNone;
      end;
   end;
end;

// Frame check for the fixed 6-byte framing.  This exists because the CAT manual
// documents the command structure but never says whether a SET command produces a
// reply -- and with no terminator, one undocumented ACK byte would misalign every
// later frame permanently (see the unit header).  Rather than gamble on the answer,
// we make the stream self-correcting: an FT-817 frame is highly self-identifying,
// so a misaligned candidate is nearly always rejected and the reader drops a byte
// and retries.
//   bytes 1-4 : packed BCD frequency -> every nibble must be a decimal digit
//   byte  5   : mode -> one of the nine values in the manual's Note 5
//   byte  6   : TX status -> bit 4 is documented as "dummy", and the remaining bits
//               are all legitimately variable, so there is nothing to test here.
// Odds of random bytes passing are roughly (10/16)^8 * (9/256) ~= 1 in 1200, so a
// wrong alignment is caught almost immediately.
function TYaesuFT817Group.ValidateFrame(const frame: string): Boolean;
var
   i: integer;
   b: Byte;
begin
   Result := False;
   if Length(frame) < FT817_FRAME_LEN then
      begin
      Exit;
      end;
   for i := 1 to 4 do
      begin
      b := Ord(frame[i]);
      if ((b and $0F) > 9) or (((b shr 4) and $0F) > 9) then
         begin
         Exit;
         end;
      end;
   case Ord(frame[FT817_MODE_POS]) of
      FT817_MODE_LSB,  FT817_MODE_USB,  FT817_MODE_CW,
      FT817_MODE_CWR,  FT817_MODE_AM,   FT817_MODE_WFM,
      FT817_MODE_FM,   FT817_MODE_DIGU, FT817_MODE_DIGL: ;
   else
      begin
      Exit;
      end;
   end;
   Result := True;
end;

procedure TYaesuFT817Group.ProcessMsg(msg: string);
begin
   UpdateLastValidResponse;   // any frame proves the radio is answering
   if Length(msg) < FT817_FRAME_LEN then
      begin
      logger.Warn('[ProcessMsg] short frame (%d bytes, expected %d)',[Length(msg), FT817_FRAME_LEN]);
      Exit;
      end;
   // Single VFO reported.  Write the PER-VFO fields (not radio-level scalars):
   // the radio window reads the per-VFO copies on a serial poll radio.
   Self.vfo[nrVFOA].frequency := BCDFreqRead(msg, 1);
   Self.vfo[nrVFOA].band      := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
   Self.vfo[nrVFOA].mode      := StatusModeToMode(Ord(msg[FT817_MODE_POS]));
   // Split, from the appended TX-status byte.  INVERTED per manual Note 4: bit 5
   // clear means SPLIT ON.  Because this IS read back, Split() does not track it
   // locally -- unlike RIT below, which has no readback at all.
   // Guarded: the FT-847 has no split at all, and its Note 2 layout is not the
   // FT-817's, so that bit must not be interpreted as split there.
   if FHasSplit then
      begin
      Self.SetSplitOn((Ord(msg[FT817_TX_STATUS_POS]) and FT817_TXST_SPLIT_BIT) = 0);
      end;
   // PTT is bit 7 of the same byte, but Note 4 does not state its polarity (it
   // gives 0/1 meanings for SPLIT and HI SWR and omits them for PTT).  Not decoded:
   // guessing wrong would report the radio permanently transmitting.  To enable it,
   // key the radio and watch the bit, then set rcReadTXStatus too.
   Self.SetActiveVFO(nrVFOA);
end;

procedure TYaesuFT817Group.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   f10: LongWord;
   bcd: array[0..3] of Byte;
   i: integer;
begin
   if (freq < 0) or (freq > FT817_MAX_FREQ_HZ) then
      begin
      logger.Error('[SetFrequency] %d Hz is outside the encodable range', [freq]);
      Exit;
      end;
   // Packed BCD of (freq div 10), 4 bytes, MSD first.  SW=0 -> NOT byte-swapped,
   // which is the opposite of the FT-1000MP.
   f10 := LongWord(freq div 10);
   for i := 3 downto 0 do
      begin
      bcd[i] := Byte(((f10 mod 10)) or (((f10 div 10) mod 10) shl 4));
      f10 := f10 div 100;
      end;
   Self.SendBytes(bcd[0], bcd[1], bcd[2], bcd[3], FT817_SET_FREQ_OPCODE);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

procedure TYaesuFT817Group.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
begin
   case mode of
      rmLSB:   modeByte := FT817_MODE_LSB;
      rmUSB:   modeByte := FT817_MODE_USB;
      rmCW:    modeByte := FT817_MODE_CW;
      rmCWRev: modeByte := FT817_MODE_CWR;
      rmAM:    modeByte := FT817_MODE_AM;
      rmFM:    modeByte := FT817_MODE_FM;
      rmData:  modeByte := FModeDIGU;
      rmFSK:   modeByte := FModeDIGL;   // no separate RTTY mode; DIG-L/PKT is the
                                        // closest the radio offers
   else
      begin
      logger.Error('[SetMode] unsupported mode %d', [Ord(mode)]);
      Exit;
      end;
   end;
   // $FF marks a mode the radio does not have (the legacy DIGL/DIGU row convention).
   // Refuse rather than transmit $FF, which is not a defined mode byte on any of
   // these radios and would leave the rig in an unpredictable state.
   if modeByte = $FF then
      begin
      logger.Error('[SetMode] %s has no mode %d', [radioModel, Ord(mode)]);
      Exit;
      end;
   // MB=0: mode byte FIRST, opcode $07 last (the FT-1000MP puts it at [3]).
   Self.SendBytes(modeByte, $00, $00, $00, FT817_SET_MODE_OPCODE);
end;

// PTT via CAT (row T:1, TX $08 / RX $88 -- legacy FT817PTTOn / FT817PTTOff).
procedure TYaesuFT817Group.Transmit;
begin
   Self.SendBytes($00, $00, $00, $00, FT817_PTT_ON_OPCODE);
end;

procedure TYaesuFT817Group.Receive;
begin
   Self.SendBytes($00, $00, $00, $00, FT817_PTT_OFF_OPCODE);
end;

// ---------------------------------------------------------------------------
// Clarifier (RIT) and split.  These differ in a way worth keeping straight:
//
//   SPLIT is READ BACK (TX-status bit 5), so the poll is the single source of
//   truth and Split() must NOT write local state -- the FT-1000MP rule.
//
//   RIT is SET-ONLY: nothing in either poll answer reports the clarifier, so we
//   MUST track it locally (SetRITOn / SetRITOffset) or the radio window would never
//   show what the operator just asked for.  The usual set-only caveat applies -- a
//   clarifier change made at the FRONT PANEL goes unnoticed, and TR4W shows what it
//   commanded rather than what the radio is doing.  Same trade as the IC-718.
//
// XIT is NOT implemented: the manual's table has a single CLAR ON/OFF with no TX
// counterpart, so there is nothing to send.  Mapping XIT onto CLAR would be a guess
// about whether the clarifier shifts transmit, so the base's inert stubs stand.
// ---------------------------------------------------------------------------

procedure TYaesuFT817Group.Split(splitOn: boolean);
begin
   // The FT-847 has no SPLIT command in its opcode chart at all (it is a satellite
   // radio -- it uses SAT RX/TX VFOs instead of an A/B split).  Sending $02/$82
   // there would be an undefined opcode.
   if not FHasSplit then
      begin
      logger.Warn('[Split] %s has no CAT split command -- ignored', [radioModel]);
      Exit;
      end;
   if splitOn then
      begin
      Self.SendBytes($00, $00, $00, $00, FT817_SPLIT_ON_OPCODE);
      end
   else
      begin
      Self.SendBytes($00, $00, $00, $00, FT817_SPLIT_OFF_OPCODE);
      end;
   // NOT tracked locally: the TX-status byte reports split back every poll, so that
   // is the single source of truth (the FT-1000MP rule).  Front-panel split changes
   // are therefore picked up here too.
end;

// The FT-847's chart has no CLAR rows at all, so all four clarifier entry points
// are guarded.  Guarding here rather than in a subclass override keeps the four
// checks in one place next to the commands they protect.
procedure TYaesuFT817Group.RITOn(whichVFO: TVFO);
begin
   if not FHasClarifier then
      begin
      logger.Warn('[RITOn] %s has no CAT clarifier command -- ignored', [radioModel]);
      Exit;
      end;
   Self.SendBytes($00, $00, $00, $00, FT817_CLAR_ON_OPCODE);
   Self.SetRITOn(True);
end;

procedure TYaesuFT817Group.RITOff(whichVFO: TVFO);
begin
   if not FHasClarifier then
      begin
      logger.Warn('[RITOff] %s has no CAT clarifier command -- ignored', [radioModel]);
      Exit;
      end;
   Self.SendBytes($00, $00, $00, $00, FT817_CLAR_OFF_OPCODE);
   Self.SetRITOn(False);
end;

// No "clarifier clear" command exists in the table, so clearing is a zero offset.
procedure TYaesuFT817Group.RITClear(whichVFO: TVFO);
begin
   Self.SetRITFreq(whichVFO, 0);
end;

procedure TYaesuFT817Group.SetRITFreq(whichVFO: TVFO; hz: integer);
var
   magnitude: integer;
   steps10: integer;
   kHzPart: integer;
   subKHz: integer;
   p1, p3, p4: Byte;
begin
   if not FHasClarifier then
      begin
      logger.Warn('[SetRITFreq] %s has no CAT clarifier command -- ignored', [radioModel]);
      Exit;
      end;
   magnitude := Abs(hz);
   if magnitude > FT817_CLAR_MAX_HZ then
      begin
      logger.Warn('[SetRITFreq] %d Hz exceeds the encodable +/-%d Hz; clamping',
                  [hz, FT817_CLAR_MAX_HZ]);
      magnitude := FT817_CLAR_MAX_HZ;
      end;
   steps10 := magnitude div 10;      // the radio resolves to 10 Hz
   kHzPart := steps10 div 100;       // whole kHz      -> P3, packed BCD
   subKHz  := steps10 mod 100;       // 10 Hz units    -> P4, packed BCD
   p3 := Byte(((kHzPart div 10) shl 4) or (kHzPart mod 10));
   p4 := Byte(((subKHz  div 10) shl 4) or (subKHz  mod 10));
   if hz < 0 then
      begin
      p1 := FT817_CLAR_DIR_MINUS;
      end
   else
      begin
      p1 := FT817_CLAR_DIR_PLUS;
      end;
   Self.SendBytes(p1, $00, p3, p4, FT817_CLAR_FREQ_OPCODE);
   Self.SetRITOffset(hz);   // set-only: no readback exists, so track it
end;


// This unit registers NOTHING -- it is the shared base.

end.
