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
unit uRadioTenTecOrion;
{$I ..\tr4w.inc}

{
  Ten-Tec Orion (565) and Orion II (566) -- factory port of uRadioPolling.pOrion3.

  NOT a HamLib-only radio, and not a bridge.  An earlier reading of the task list
  had it grouped with the software bridges; NY4I corrected that -- pOrion3 is a
  complete working driver and NY4I has personally operated an Orion II with TR4W.
  So this is a straight port of proven behaviour, NOT a new driver.

  ONE DRIVER FOR BOTH MODELS.  TR4W's radio table gives ORION hamlibID 16008 =
  RIG_MODEL_TT565, and HamLib's rigs/tentec/orion.c states it "supports the Ten-Tec
  Orion (565) and Orion II (566)" from ONE backend whose only firmware branch is
  the S-meter calibration table -- which TR4W does not display.  NY4I compared the
  565 command reference against the 566 and found no contradiction in the commands
  used here.  Since this port is behaviour-identical to pOrion3, whatever works on
  either radio today keeps working.

  THE COMMAND SET -- seven commands, all '?'/'*' prefixed and CR-terminated,
  replies '@'-framed and CR-terminated:

      poll   ?AF   VFO A frequency          -> @AF<8 digits><CR>
             ?BF   VFO B frequency          -> @BF<8 digits><CR>
             ?KV   which VFO is keyed/RX    -> @K??<A|B>??<CR>
             ?RMM  main receiver mode       -> @RMM<digit><CR>
      set    *AF nn.nnnnn   frequency (byte 1 swapped A/B for VFO B)
             *RMM<digit>    mode  (*RSM for the sub receiver / VFO B)
             *CS<nn>        CW keyer speed
      CW     /<text><CR>    keyed CW text

  READ AND WRITE FREQUENCY FORMATS DIFFER, which is easy to miss.  The SET form is
  `*AF14.02500` -- two digits, a decimal point, five digits.  The READ reply is
  EIGHT PLAIN DIGITS IN Hz, `@AF14025000`, with no point: legacy parsed it with
  BufferToInt(@tBuf[i], 4, 8), and that helper ABORTS and returns 0 on any
  non-digit, so a reply containing '.' could never have produced a frequency.
  The read path is therefore digits-only by proof, not by assumption.

  ** BUG FIXED IN THE PORT -- CW over CAT has never worked. **  LOGRADIO:2744 does

      localMsg := Format('/%s#13', [Msg]);   // ny4i Issue 112

  with #13 INSIDE the quotes, so it emits the literal characters '#', '1', '3' and
  NO carriage return.  Every other Orion command in the tree gets this right by
  putting #13 outside the quotes ('?AF'#13, '*AF%02u.%05u'#13).  So the radio has
  been receiving `/TEST#13` unterminated.  This unit sends the text followed by a
  real CR.  The legacy line is deliberately LEFT ALONE -- the legacy radio path is
  being deleted, and patching it would be throwaway work.

  BOUNDS ADDED: the 565 reference documents the keyer as 10..60 WPM, and legacy's
  `*CS%02u` would happily send `*CS05`.  SetCWSpeed now clamps and logs.

  ONE DELIBERATE IMPROVEMENT over legacy on SET MODE.  Legacy received TR4W's
  ROLL-UP mode (Phone/CW/Digital/FM) and had to guess the sideband from frequency
  (`if Freq < 10000000 then '1' else '0'`).  A factory driver receives the ACTUAL
  mode (rmUSB / rmLSB), so it maps directly and honours what the caller asked for.
  On 40 m with an explicit rmUSB, legacy would have sent LSB; this sends USB.  That
  matches how every other factory driver behaves.

  NOT read, because legacy never polled for it -- so these are gaps carried
  forward, not regressions:
    ?RMR / ?RSR  RIT offset  (so the radio window shows no RIT for an Orion)
    ?S           TX / RX state

  57600 baud, 8/N/1 -- the fastest port in the radio table, and one of only three
  radios named explicitly in the legacy 1-stop-bit exception list.

  NOT BENCH-TESTED AS A FACTORY DRIVER.  NY4I has the hardware.
}

interface

uses
  uFactoryRadioBase, uRadioBand, SysUtils, StrUtils, Math, Log4D, VC,
  uRadioRegistry, uCWFraming;

const
  ORION_CR = #13;

  // Reply layout, 0-based from the '@'.
  ORION_FREQ_DIGITS   = 8;    // @AF<8 digits>  -- Hz, NO decimal point
  ORION_FREQ_POS      = 3;
  ORION_KEYEDVFO_POS  = 3;    // @K??<A|B>
  ORION_MODE_POS      = 4;    // @RMM<digit>

  // Mode digits, shared by the ?RMM reply and the *RMM set command.
  ORION_MODE_USB  = '0';
  ORION_MODE_LSB  = '1';
  ORION_MODE_CW   = '2';
  ORION_MODE_CWR  = '3';
  ORION_MODE_AM   = '4';
  ORION_MODE_FM   = '5';
  ORION_MODE_RTTY = '6';

  ORION_CW_MIN_WPM = 10;      // 565 reference: keyer range is 10..60
  ORION_CW_MAX_WPM = 60;

type
  TTenTecOrionRadio = class(TFactoryRadioBase)
  protected
    FCWBuffer: string;
    function  ModeDigitToMode(c: Char): TRadioMode;
    function  ModeToModeDigit(mode: TRadioMode; out digit: Char): Boolean;
  public
    constructor Create; reintroduce;

    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;

    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    procedure SetCWSpeed(speed: integer); override;
    procedure BufferCW(cwChars: string); override;
    procedure SendCW; override;
    procedure StopCW; override;
   procedure DeclareCWProsigns; override;
    // True: this driver keys the Orion's CW itself ('/c<cr>' per character,
    // '*TU<cr>' to unkey).  The legacy rtOrion arms are buggy/empty.
    function CWIsFactoryOwned: Boolean; override;

    // ---- remaining TFactoryRadioBase abstracts ------------------------------
    // Abstract in the base, so an omission is an EAbstractError the first time
    // TR4W calls it -- exactly what killed the program on the Flex's first run.
    // Implemented here even where the honest answer is "legacy never did this".
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
    procedure Transmit; override;
    procedure Receive; override;
    function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
    procedure Split(splitOn: boolean); override;
    procedure RITOn(whichVFO: TVFO); override;
    procedure RITOff(whichVFO: TVFO); override;
    procedure XITOn(whichVFO: TVFO); override;
    procedure XITOff(whichVFO: TVFO); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure XITClear(whichVFO: TVFO); override;
    procedure RITBumpDown; override;
    procedure RITBumpUp; override;
    procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
    function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
    procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
    function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
    function  MemoryKeyer(mem: integer): boolean; override;
    procedure VFOBumpDown(whichVFO: TVFO); override;
    procedure VFOBumpUp(whichVFO: TVFO); override;
  end;

implementation

constructor TTenTecOrionRadio.Create;
begin
   // MUST pass ProcessMsg.  The base ctor is overloaded, so a bare
   // `inherited Create` compiles and silently resolves to TObject.Create,
   // leaving baseProcMsg nil so nothing is ever parsed.  That cost a bench
   // session on the Flex.
   inherited Create(ProcessMsg);
   radioModel := 'Ten-Tec Orion';

   // Replies are '@'-framed and CR-terminated.
   Self.readTerminator := ORION_CR;
   pollingInterval := 200;

   // What this driver actually reads:
   //   rcReadVFOB    -- ?AF and ?BF give both VFOs
   //   rcCWByCAT     -- '/<text>' keys CW (legacy RadioSupportsCWByCAT includes ORION)
   //   rcCWSpeedSync -- *CS pushes the keyer speed (legacy RadioSupportsCWSpeedSync)
   // NOT rcReadSplit / rcReadRIT / rcReadTXStatus: legacy polls none of them, so
   // claiming them would promise more than this driver delivers.
   FCapabilities.Flags := [rcReadVFOB, rcCWByCAT, rcCWSpeedSync];
   FCapabilities.CWSpeedMin := ORION_CW_MIN_WPM;
   FCapabilities.CWSpeedMax := ORION_CW_MAX_WPM;
   // ---- CW-by-CAT framing --------------------------------------------------
   // No length limit and no padding: the Orion keys with '/<text>', not a KY,
   // and uCWFraming's model table never named it -- it fell to the default arm,
   // which is exactly this.  Stated explicitly now that the default is on the
   // radio: a rule left unstated is indistinguishable from a zeroed record.
   FCapabilities.CWFrame := CWFrameRule(0, False);
   // Kenwood spellings, preserving the legacy fall-through: uCWFraming's
   // CWVendorOf had no ORION arm and returned cvKenwood for anything that was
   // not Elecraft or Icom, so this is what the Orion has always been keyed.
   // NOT verified against a Ten-Tec manual -- inherited behaviour, recorded as
   // such rather than dressed up as a protocol fact.
end;

// ---------------------------------------------------------------------------
// Poll -- the same four queries, in the same order, as pOrion3.
// ---------------------------------------------------------------------------
procedure TTenTecOrionRadio.PollRadioState;
begin
   Self.SendToRadio('?AF' + ORION_CR);
   Self.SendToRadio('?BF' + ORION_CR);
   Self.SendToRadio('?KV' + ORION_CR);
   Self.SendToRadio('?RMM' + ORION_CR);
end;

function TTenTecOrionRadio.ModeDigitToMode(c: Char): TRadioMode;
begin
   case c of
      ORION_MODE_USB:  Result := rmUSB;
      ORION_MODE_LSB:  Result := rmLSB;
      ORION_MODE_CW:   Result := rmCW;
      ORION_MODE_CWR:  Result := rmCWRev;
      ORION_MODE_AM:   Result := rmAM;
      ORION_MODE_FM:   Result := rmFM;
      ORION_MODE_RTTY: Result := rmFSK;   // legacy: Digital / eRTTY
   else
      begin
      logger.Warn('[Orion.ProcessMsg] Invalid mode character from Orion = %s', [c]);
      Result := rmNone;
      end;
   end;
end;

// The reading thread strips the CR, so msg is the '@'-framed body alone.
procedure TTenTecOrionRadio.ProcessMsg(msg: string);
var
   hz: integer;
   m: TRadioMode;
begin
   msg := Trim(msg);
   if (Length(msg) < 2) or (msg[1] <> '@') then
      begin
      Exit;
      end;

   UpdateLastValidResponse;

   case msg[2] of
      'A':
         begin
         // EIGHT PLAIN DIGITS IN Hz -- see the unit header on why the read form
         // cannot carry the '.' that the *AF set form uses.
         hz := StrToIntDef(Copy(msg, ORION_FREQ_POS + 1, ORION_FREQ_DIGITS), -1);
         if hz > 0 then
            begin
            Self.vfo[nrVFOA].frequency := hz;
            Self.vfo[nrVFOA].band      := FreqToRadioBand(hz);
            end;
         end;

      'B':
         begin
         hz := StrToIntDef(Copy(msg, ORION_FREQ_POS + 1, ORION_FREQ_DIGITS), -1);
         if hz > 0 then
            begin
            Self.vfo[nrVFOB].frequency := hz;
            Self.vfo[nrVFOB].band      := FreqToRadioBand(hz);
            end;
         end;

      'K':
         begin
         // @K??<A|B> -- which VFO the radio is actually on.  Selectable-model
         // radio, like the Kenwoods and the Flex: RX is POINTED at a VFO rather
         // than A always being RX (the Elecraft swap model).
         if Length(msg) > ORION_KEYEDVFO_POS then
            begin
            if msg[ORION_KEYEDVFO_POS + 1] = 'A' then
               begin
               Self.SetActiveVFO(nrVFOA);
               end
            else
               begin
               Self.SetActiveVFO(nrVFOB);
               end;
            end;
         end;

      'R':
         begin
         // @RMM<digit>.  Legacy filed the mode against the OPERATING VFO only.
         if Length(msg) > ORION_MODE_POS then
            begin
            m := ModeDigitToMode(msg[ORION_MODE_POS + 1]);
            if m <> rmNone then
               begin
               Self.vfo[Self.GetActiveVFO].mode := m;
               Self.localMode := m;
               end;
            end;
         end;
   end;
end;

// ---------------------------------------------------------------------------
// Sets
// ---------------------------------------------------------------------------

// *AF nn.nnnnn -- note the DECIMAL POINT, which the read reply does not have.
// Byte 1 becomes 'B' for VFO B, exactly as legacy patched tOrionFreq[1].
procedure TTenTecOrionRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   cmd: string;
begin
   if freq <= 0 then
      begin
      logger.Error('[Orion.SetFrequency] non-positive frequency %d', [freq]);
      Exit;
      end;
   cmd := Format('*AF%.2d.%.5d', [freq div 1000000, (freq mod 1000000) div 10]);
   if vfo = nrVFOB then
      begin
      cmd[2] := 'B';
      end;
   Self.SendToRadio(cmd + ORION_CR);
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

function TTenTecOrionRadio.ModeToModeDigit(mode: TRadioMode; out digit: Char): Boolean;
begin
   Result := True;
   case mode of
      rmUSB:    digit := ORION_MODE_USB;
      rmLSB:    digit := ORION_MODE_LSB;
      rmCW:     digit := ORION_MODE_CW;
      rmCWRev:  digit := ORION_MODE_CWR;
      rmAM:     digit := ORION_MODE_AM;
      rmFM:     digit := ORION_MODE_FM;
      rmFSK:    digit := ORION_MODE_RTTY;
      rmData:   digit := ORION_MODE_RTTY;   // legacy mapped Digital to '6'
   else
      begin
      digit := #0;
      Result := False;
      end;
   end;
end;

// *RMM<digit> for the main receiver, *RSM<digit> for the sub -- legacy swapped
// byte 2 from 'M' to 'S' for VFO B.
procedure TTenTecOrionRadio.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   cmd: string;
   d: Char;
begin
   if not ModeToModeDigit(mode, d) then
      begin
      logger.Error('[Orion.SetMode] unsupported mode %d', [Ord(mode)]);
      Exit;
      end;
   cmd := '*RMM' + d;
   if vfo = nrVFOB then
      begin
      cmd[3] := 'S';
      end;
   Self.SendToRadio(cmd + ORION_CR);
end;

// *CS<nn>.  Clamped: the 565 reference documents 10..60 WPM and legacy's
// '*CS%02u' would have sent an out-of-range '*CS05' without comment.
procedure TTenTecOrionRadio.SetCWSpeed(speed: integer);
var
   wpm: integer;
begin
   wpm := speed;
   if wpm < ORION_CW_MIN_WPM then
      begin
      wpm := ORION_CW_MIN_WPM;
      end;
   if wpm > ORION_CW_MAX_WPM then
      begin
      wpm := ORION_CW_MAX_WPM;
      end;
   if wpm <> speed then
      begin
      logger.Debug('[Orion.SetCWSpeed] %d WPM clamped to %d (radio range %d..%d)',
                   [speed, wpm, ORION_CW_MIN_WPM, ORION_CW_MAX_WPM]);
      end;
   Self.localCWSpeed := wpm;
   Self.SendToRadio(Format('*CS%.2d', [wpm]) + ORION_CR);
end;

// ---- CW send: ONE COMMAND PER CHARACTER ---------------------------------
// Per the Orion 565/566 manual, "CW Character Send" (firmware 1.367+):
//
//     /c<cr>   Send the CW character or Procedural Symbol indicated by 'c'
//     example: /b<cr> sends 'b',  /w<cr> sends 'w'
//
// It is a SINGLE-CHARACTER command -- there is no string form.  This code
// previously emitted '/' + the whole buffer + CR, which the manual does not
// define; the legacy path is worse still, emitting a literal '#13' instead of
// a carriage return (Format('/%s#13', [Msg]) -- '#13' inside a Pascal string
// literal is three characters, not CR).  Both are corrected here: one command
// per character, with a real CR.
//
// The manual also notes the INTERNAL KEYER MUST BE ENABLED or the Send CW
// command is ignored -- worth checking first if a bench test shows silence.
procedure TTenTecOrionRadio.BufferCW(cwChars: string);
begin
   FCWBuffer := FCWBuffer + cwChars;
end;

procedure TTenTecOrionRadio.SendCW;
var
   i: integer;
begin
   if FCWBuffer = '' then
      begin
      Exit;
      end;
   for i := 1 to Length(FCWBuffer) do
      begin
      Self.SendToRadio('/' + FCWBuffer[i] + ORION_CR);
      end;
   FCWBuffer := '';
end;

procedure TTenTecOrionRadio.StopCW;
begin
   // Drop anything we have not sent yet...
   FCWBuffer := '';
   // ...then UNKEY THE TRANSMITTER.  Manual, "Keying Command":
   //     *TK<cr> keys the transmitter, *TU<cr> unkeys it.
   // This is the Orion's equivalent of the 'RX;' half of the abort TR4W sends
   // to a K3/Kenwood, and NY4I (Orion owner) identified it as the stop.
   //
   // VERIFIED: *TU is documented and unkeys the transmitter.
   // NOT VERIFIED: whether it also DISCARDS characters already accepted by the
   // radio's CW buffer, or merely drops the carrier while the buffer drains.
   // If a bench test shows CW resuming after Escape, that is the reason, and
   // the fix is an additional buffer-clear command -- not more *TU.
   Self.SendToRadio('*TU' + ORION_CR);
end;

function TTenTecOrionRadio.CWIsFactoryOwned: Boolean;
begin
   // This driver owns the Orion's CW: SendCW issues the per-character '/c<cr>'
   // commands and StopCW issues '*TU<cr>'.  The legacy path must NOT be used --
   // its rtOrion send arm has the literal-'#13' bug and its rtOrion stop arm is
   // EMPTY (commented-out code only), so Escape there does nothing at all.
   Result := True;
end;

// ---------------------------------------------------------------------------
// Commands legacy never issued for this radio.  Refused rather than invented:
// an undefined command is answered unpredictably at best.  ?RMR/?RSR (RIT) and
// ?S (TX state) are documented in the 565 reference and could be added once
// someone can verify them on hardware.
// ---------------------------------------------------------------------------
procedure TTenTecOrionRadio.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   Self.SendToRadio(sCmd + sData + ORION_CR);
end;

procedure TTenTecOrionRadio.Transmit;
begin
   // The 565 reference has *TK / *TU (key / unkey), which is NOT a TX-mode
   // select, and legacy issued neither.  Left unimplemented on purpose.
   logger.Debug('[Orion.Transmit] not implemented -- legacy never keyed this radio via CAT');
end;

procedure TTenTecOrionRadio.Receive;
begin
   logger.Debug('[Orion.Receive] not implemented -- see Transmit');
end;

function TTenTecOrionRadio.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
begin
   Result := Self.vfo[vfo].mode;
end;

procedure TTenTecOrionRadio.Split(splitOn: boolean);
begin
   logger.Debug('[Orion.Split] not implemented -- legacy issued no split command here');
end;

procedure TTenTecOrionRadio.RITOn(whichVFO: TVFO);      begin end;
procedure TTenTecOrionRadio.RITOff(whichVFO: TVFO);     begin end;
procedure TTenTecOrionRadio.XITOn(whichVFO: TVFO);      begin end;
procedure TTenTecOrionRadio.XITOff(whichVFO: TVFO);     begin end;
procedure TTenTecOrionRadio.RITClear(whichVFO: TVFO);   begin end;
procedure TTenTecOrionRadio.XITClear(whichVFO: TVFO);   begin end;
procedure TTenTecOrionRadio.RITBumpDown;                begin end;
procedure TTenTecOrionRadio.RITBumpUp;                  begin end;

procedure TTenTecOrionRadio.SetRITFreq(whichVFO: TVFO; hz: integer);
begin
   // ?RMR / ?RSR read it; the reference documents a write too, but legacy never
   // used either, so nothing is sent rather than guessing the syntax.
   logger.Debug('[Orion.SetRITFreq] not implemented -- legacy never set RIT here');
end;

procedure TTenTecOrionRadio.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   logger.Debug('[Orion.SetXITFreq] not implemented -- see SetRITFreq');
end;

procedure TTenTecOrionRadio.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var
   freq: LongInt;
begin
   // No band command; change band by tuning, as the Kenwood serial base does.
   freq := BandToFreq(band);
   if freq > 0 then
      begin
      Self.SetFrequency(freq, vfo, Self.vfo[vfo].mode);
      end;
end;

function TTenTecOrionRadio.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
   Result := Self.vfo[vfo].band;
end;

procedure TTenTecOrionRadio.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
   logger.Debug('[Orion.SetFilter] not implemented -- legacy set no filter here');
end;

function TTenTecOrionRadio.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   Result := 0;   // 0 = not supported
end;

function TTenTecOrionRadio.MemoryKeyer(mem: integer): boolean;
begin
   Result := True;   // True = error / unsupported, the factory convention
end;

procedure TTenTecOrionRadio.VFOBumpDown(whichVFO: TVFO);
begin
   logger.Debug('[Orion.VFOBumpDown] no VFO step command in the Orion set');
end;

procedure TTenTecOrionRadio.VFOBumpUp(whichVFO: TVFO);
begin
   logger.Debug('[Orion.VFOBumpUp] no VFO step command in the Orion set');
end;



procedure TTenTecOrionRadio.DeclareCWProsigns;
begin
   // The Orion is NOT a KY radio -- it keys '/<char><CR>', one character at a
   // time -- so it does not descend from the Kenwood base.  These spellings are
   // the ones LOGRADIO's Orion arm used, which took them from its Kenwood arm.
   // Stated here rather than inherited, so the class hierarchy keeps claiming
   // only what is true about the protocol.
   //
   // UNVERIFIED on hardware: NY4I is sourcing an Orion (bench item C-5).  If it
   // spells a prosign differently, this one line is where it changes.
   FCapabilities.CWProsigns := CWProsigns(' ', '%', '_', '>', '[');
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateTenTecOrion: TFactoryRadioBase;
begin
   Result := TTenTecOrionRadio.Create;
end;

initialization
  // 57600 8/N/1 -- the fastest port in the radio table, and ORION is one of only
  // three radios named explicitly in the legacy 1-stop-bit exception list
  // (`[IC78..IC9700, FT100, Orion]`).
  RegisterRadio(ORION,
     CreateTenTecOrion,
     'Ten-Tec Orion', [rlSerial], 0, False,
     SerialParams(57600, 8, PARITY_NONE, 1)
     ,
     16008
     );


end.
