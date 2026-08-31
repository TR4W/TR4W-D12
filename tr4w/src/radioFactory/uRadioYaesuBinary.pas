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
{$I ..\tr4w.inc}

{
  Yaesu OLD BINARY CAT -- the SHARED TRANSPORT base only.

  Every radio here speaks the same 5-byte wire convention:

      [P1 P2 P3 P4 Opcode]     -- opcode LAST, sent byte-exact, no CR/LF

  ...and NOTHING ELSE is shared.  That is the whole point of this unit, and it is
  worth being blunt about, because the legacy typeset invites the opposite
  assumption:

  **`rtYaesu1` IS A PORT-SETTINGS BUCKET, NOT A PROTOCOL.**  Measured from
  LOGRADIO's own RadioParametersArray and uRadioPolling's procedure set:

    model              SFOC  SMOC  SW  MB   legacy polling procedure
    FT-990 / FT-1000   $0A   $0C   1   3    pFT990_FT1000
    FT-1000MP          $0A   $0C   1   3    pFT1000MP
    FT-920             $0A   $0C   1   3    pFT920
    FT-747GX           $0A   $0C   1   3    pFT747GX
    FT-100             $0A   $0C   1   3    pFT100
    FT-767             $08   $0A   1   0    pFT767
    FT-817/847/857/897 $01   $07   0   0    pFT817_FT847_FT857_FT897

  Note the FT-990/FT-1000 share the FT-1000MP's WRITE parameters exactly yet still
  needed their own polling procedure -- the read formats diverge where the writes
  agree, so the variation does not fall along one axis.  Answer lengths differ too
  (FT-1000MP 32+6 bytes; FT-817 group 5 bytes), as do the frequency encodings
  (big-endian binary * 0.625 vs packed BCD * 10 Hz) and the mode maps.

  CONSEQUENCE FOR MAINTAINERS: do NOT add a model's parsing to this base.  Give it
  its own unit named after a real LEAD MODEL (uRadioYaesuFT1000MP, uRadioYaesuFT817)
  so the file name says what it drives; a unit may serve several models internally,
  but the name must not be an invented category.  What belongs HERE is only what is
  true for every old-binary Yaesu: the 5-byte frame, byte-exact transport with no
  terminator, and neutral "this family cannot do that" defaults.

  TERMINOLOGY.  Yaesu's manuals and command charts say "clarifier" -- RX clarifier
  for what everyone else calls RIT, TX clarifier for XIT.  TR4W uses RIT and XIT
  throughout, including for the Yaesus, because those are the recognised terms.
  Where a chart ROW NAME is quoted the original spelling is kept ("CLAR ON/OFF"),
  since that is what a reader will be looking for in the manual.

  In particular SerialFixedFrameLength is deliberately NOT set here -- the answer
  length is per-model, and a wrong value silently mis-delimits every frame.
}

interface

uses uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC;

const
   // "This radio has no such mode" -- the convention already used by the DIGL /
   // DIGU columns of LOGRADIO's radio table.  SetMode refuses instead of putting
   // $FF on the wire, which is not a defined mode byte on any of these radios.
   MODEBYTE_NONE    = $FF;

const
   // PTT frames, taken from the D7 tree's tPTTVIACAT dispatch -- the code this
   // factory was ported from, and the authority on what these radios actually
   // accept.  They are NOT guesses: the port simply never carried them over,
   // so TYaesuBinary.Transmit has been a logged no-op since.
   //
   //   D7:  FT747GX, FT100, FT840, FT890, FT900, FT990, FT1000, FT1000MP
   //           on  00 00 00 01 0F      off  00 00 00 00 0F
   //        FT736R, FT817, FT818, FT847
   //           on  00 00 00 00 08      off  00 00 00 00 88
   //
   // Radios in NEITHER list -- the FT-920 and FT-767 among them -- are left
   // unable to key by CAT, because that is what D7 did and inventing a frame
   // for a transmitter is not a guess worth making.
   YAESU_PTT_ON_0F  = #$00#$00#$00#$01#$0F;
   YAESU_PTT_OFF_0F = #$00#$00#$00#$00#$0F;
   YAESU_PTT_ON_08  = #$00#$00#$00#$00#$08;
   YAESU_PTT_OFF_08 = #$00#$00#$00#$00#$88;
   // A model that has not declared its set-mode row.  Distinct from a real
   // opcode so the base can tell "not declared" from "declared as 0".
   MODEOPCODE_UNSET = $00;

type
  TYaesuBinary = class(TFactoryRadioBase)
  protected
    // ---- SET-MODE TRAITS ----------------------------------------------------
    // Every rtYaesu1 model sets mode with the same 5-byte shape and differs only
    // in the opcode, which byte slot the mode goes in, and the mode byte values.
    // Those three things come straight from the model's row in LOGRADIO's radio
    // table (SMOC, MB, and the CW/LSB/USB/AM/FM/DIGL/DIGU columns), so a model
    // declares its row here and the base does the work.
    //
    // $FF means "this radio has no such mode" -- the existing convention in that
    // table -- and SetMode refuses rather than transmitting $FF, which is not a
    // defined mode byte on any of these radios.
    //
    // A model that leaves FSetModeOpcode at MODEOPCODE_UNSET either overrides
    // SetMode itself (the FT-817 group, FT-1000MP) or genuinely cannot set mode;
    // either way the base refuses loudly instead of sending a bogus frame.
    FSetModeOpcode: Byte;    // SMOC
    FModeByteIndex: Integer; // MB: which of the 4 payload slots holds the mode byte
    FModeCW:   Byte;
    // Reverse-sideband CW, if this model has its own byte for it. Left
    // MODEBYTE_NONE means "no separate byte", and reverse CW falls back to
    // FModeCW -- which is what every model in this family did until
    // 2026-08-28, including two that D7 sent a distinct byte for.
    FModeCWRev: Byte;
    FModeLSB:  Byte;
    FModeUSB:  Byte;
    FModeAM:   Byte;
    FModeFM:   Byte;
    FModeDIGL: Byte;
    FModeDIGU: Byte;

    // Send one 5-byte Yaesu command byte-exact (opcode last).
    procedure SendBytes(b0, b1, b2, b3, b4: Byte);

    // Sideband for a mode byte that says only "phone".
    //
    // TR4W keeps modes at two levels: a ROLL-UP (ModeType -- CW / Phone /
    // Digital / FM, what the main window shows) and the actual mode
    // (ExtendedModeType, which has eSSB for exactly this case and is what the
    // ContestExchange record carries).  The legacy pollers for several of these
    // old radios only ever set the roll-up: their mode byte reports "phone" and
    // nothing distinguishes LSB from USB.
    //
    // TRadioMode has no neutral phone member, so a driver must pick one.
    // Picking a fixed sideband would ASSERT something the radio never said and
    // put it in the log; deriving it from frequency uses the universal amateur
    // convention (LSB below 10 MHz, USB above) and gives the answer an operator
    // expects on every band.
    //
    // This is a CONVENTION, not a radio report.  A radio that actually tells us
    // the sideband must map it directly and never call this.
    function PhoneModeForFreq(hz: integer): TRadioMode;

  public
    constructor Create; reintroduce;

    // Trait-driven; see the fields above.  Models with a different frame shape
    // override it (FT-747GX, FT-767, FT-817 group, FT-1000MP).
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;

    function  Connect: integer; override;

    // ---- Not available over old Yaesu binary CAT (models that DO support one of
    // these override it).  Inert rather than abstract so a minimal model such as
    // the FT-817 does not have to restate a wall of empty stubs. ----
    procedure Transmit; override;
    procedure Receive; override;

    // The 5-byte CAT frame this radio keys with, or '' if it cannot key by
    // CAT.  A SUBCLASS DECLARES ITS FRAME; this base never asks which model
    // it is.  Default '' keeps the old, honest behaviour -- a warning and no
    // command -- for the radios D7 did not key either.
    function PTTFrameOn: string; virtual;
    function PTTFrameOff: string; virtual;
    procedure BufferCW(cwChars: string); override;   // CW keying stays on the legacy
    procedure SendCW; override;                      // path / future CW Keyer Factory
    procedure StopCW; override;
    procedure SetCWSpeed(speed: integer); override;
    function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
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

    // Not used by a binary protocol -- commands are 5-byte frames via SendBytes.
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
  end;

implementation

constructor TYaesuBinary.Create;
begin
   // The reading thread dispatches through the handler handed to the base ctor
   // (baseProcMsg), NOT through the virtual ProcessMsg.  Passing nil here would
   // leave rt.msgHandler unassigned, so every frame would be read, logged and then
   // silently DROPPED -- no freq/mode would ever reach the radio window and the
   // liveness watchdog (fed by UpdateLastValidResponse inside ProcessMsg) would keep
   // declaring the radio dead.  Wire the virtual ProcessMsg, as every radio does.
   inherited Create(ProcessMsg);

   SerialProtocolIsBinary := True;   // byte-exact 5-byte frames, no codepage decode
   bAddTermination        := False;  // NO CR/LF on binary CAT
   requiresPolling        := True;
   honorsFreqPollRate     := False;  // these answers are fixed-length; keep our cadence
   pollingInterval        := 150;    // conservative BR4800 default; models may lower it
   // SerialFixedFrameLength is intentionally NOT set here -- see the unit header.

   // Set-mode traits default to "this model has not declared its row", so a model
   // that forgets gets a logged refusal instead of a frame built from zeroes.
   FSetModeOpcode := MODEOPCODE_UNSET;
   FModeByteIndex := 3;      // MB=3 is the common case in the table
   FModeCW   := MODEBYTE_NONE;
   FModeCWRev := MODEBYTE_NONE;
   FModeLSB  := MODEBYTE_NONE;
   FModeUSB  := MODEBYTE_NONE;
   FModeAM   := MODEBYTE_NONE;
   FModeFM   := MODEBYTE_NONE;
   FModeDIGL := MODEBYTE_NONE;
   FModeDIGU := MODEBYTE_NONE;
end;

// Trait-driven SetMode shared by the rtYaesu1 family.  A base must never ask
// which model it is; it reads the traits the model declared and acts on them.
procedure TYaesuBinary.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeByte: Byte;
   b: array[0..3] of Byte;
   i: Integer;
begin
   if FSetModeOpcode = MODEOPCODE_UNSET then
      begin
      logger.Error('[SetMode] %s did not declare its set-mode traits and does not override SetMode',
                   [radioModel]);
      Exit;
      end;

   case mode of
      rmCW:    modeByte := FModeCW;
      rmCWRev:
         begin
         { A model that declares its own reverse byte gets it; the rest fall
           back to plain CW, which is what this line used to do for ALL of
           them. D7 sent /usr/bin/bash3 for the FT-100 and FT-920 when the operator had
           CW REVERSE set (LOGRADIO.PAS:3403), so for those two the fallback
           was a silent regression. }
         if FModeCWRev <> MODEBYTE_NONE then
            begin
            modeByte := FModeCWRev;
            end
         else
            begin
            modeByte := FModeCW;
            end;
         end;
      rmLSB:   modeByte := FModeLSB;
      rmUSB:   modeByte := FModeUSB;
      rmAM:    modeByte := FModeAM;
      rmFM:    modeByte := FModeFM;
      rmData:  modeByte := FModeDIGU;
      rmFSK:   modeByte := FModeDIGL;
   else
      begin
      logger.Error('[SetMode] %s: unsupported mode %d', [radioModel, Ord(mode)]);
      Exit;
      end;
   end;

   // $FF is the table's "this radio has no such mode".  Refuse rather than send
   // it -- $FF is not a defined mode byte and would leave the rig unpredictable.
   if modeByte = MODEBYTE_NONE then
      begin
      logger.Error('[SetMode] %s has no mode %d', [radioModel, Ord(mode)]);
      Exit;
      end;

   if (FModeByteIndex < 0) or (FModeByteIndex > 3) then
      begin
      logger.Error('[SetMode] %s declared an out-of-range mode byte index %d',
                   [radioModel, FModeByteIndex]);
      Exit;
      end;

   for i := 0 to 3 do
      begin
      b[i] := $00;
      end;
   b[FModeByteIndex] := modeByte;
   Self.SendBytes(b[0], b[1], b[2], b[3], FSetModeOpcode);
end;

function TYaesuBinary.Connect: integer;
begin
   Result := Inherited Connect;
   // No prime needed -- PollRadioState pulls status each cycle.
end;

function TYaesuBinary.PhoneModeForFreq(hz: integer): TRadioMode;
const
   SIDEBAND_CROSSOVER_HZ = 10000000;   // 10 MHz: below = LSB, above = USB
begin
   if hz < SIDEBAND_CROSSOVER_HZ then
      begin
      Result := rmLSB;
      end
   else
      begin
      Result := rmUSB;
      end;
end;

(* Char(), NEVER Chr(), FOR A PROTOCOL BYTE -- and the parameters are what make
  it matter.

  tr4w.inc sets {$MODESWITCH UnicodeStrings}, so `string` is UTF-16. FPC's Chr()
  returns an ANSI char, so putting one in a string runs DefaultSystemCodePage,
  which the LCL sets to UTF-8; a lone byte >= $80 is not valid UTF-8, decodes to
  U+FFFD, and the transport then puts $FD on the wire. Char(b) is a TYPECAST --
  it reinterprets the ordinal as a UTF-16 code unit, so codepoint == byte and no
  codepage is consulted. The full analysis is in uRadioIcomBase, above CivChr.

  CONSTANTS HIDE THIS. FPC folds Chr($FA) at compile time and gets it right, so
  every literal call works and only variable arguments break -- and b0..b4 are
  parameters, so a caller writing SendBytes($00,$00,$00,$01,$FA) with perfectly
  correct literals still had them corrupted here.

  WHAT IT COST (NY4I's FT-1000MP, 2026-08-31): the poll pair is $..$03 $10 for
  the 32-byte status block and $..$01 $FA for the 6-byte flags. $FA went out as
  $FD, so the radio saw an unknown opcode and answered nothing. The reader still
  expected 32+6 = 38 bytes, took the missing 6 from the next cycle, and every
  frame after that decoded 6 bytes further out of phase -- the Radio 1 panel
  rotating through invented frequencies while the rig sat on one. Every other
  byte in both commands is < $80, which is why only this one was wrong.

  PAREN-STAR DELIMITERS, because this comment quotes a compiler directive and
  braces do not nest -- the directive's own closing brace would end a brace
  comment early and compile the rest as code. That is exactly what happened on
  the first attempt at this comment, which is the third time in this tree. *)
procedure TYaesuBinary.SendBytes(b0, b1, b2, b3, b4: Byte);
begin
   Self.SendToRadio(Char(b0) + Char(b1) + Char(b2) + Char(b3) + Char(b4));
end;

// ---------------------------------------------------------------------------
// Neutral defaults.  Anything a specific radio supports is overridden there.
// ---------------------------------------------------------------------------

function TYaesuBinary.PTTFrameOn: string;
begin
   Result := '';      // this radio cannot key by CAT unless it says otherwise
end;

function TYaesuBinary.PTTFrameOff: string;
begin
   Result := '';
end;

procedure TYaesuBinary.Transmit;
begin
   if PTTFrameOn = '' then
      begin
      logger.Warn('[Transmit] PTT-via-CAT not supported by %s', [Self.radioModel]);
      Exit;
      end;
   Self.SendToRadio(PTTFrameOn);
end;

procedure TYaesuBinary.Receive;
begin
   if PTTFrameOff = '' then
      begin
      logger.Warn('[Receive] PTT-via-CAT not supported by %s', [Self.radioModel]);
      Exit;
      end;
   Self.SendToRadio(PTTFrameOff);
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

procedure TYaesuBinary.SetCWSpeed(speed: integer);
begin
   logger.Warn('[SetCWSpeed] not supported by %s (%d wpm ignored)', [Self.radioModel, speed]);
end;

function TYaesuBinary.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
begin
   Result := Self.vfo[vfo].mode;
end;

procedure TYaesuBinary.RITClear(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.XITClear(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.RITBumpDown;
begin
end;

procedure TYaesuBinary.RITBumpUp;
begin
end;

procedure TYaesuBinary.RITOn(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.RITOff(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.XITOn(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.XITOff(whichVFO: TVFO);
begin
end;

procedure TYaesuBinary.Split(splitOn: boolean);
begin
   logger.Warn('[Split] not supported by %s', [Self.radioModel]);
end;

procedure TYaesuBinary.SetRITFreq(whichVFO: TVFO; hz: integer);
begin
end;

procedure TYaesuBinary.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
end;

procedure TYaesuBinary.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
begin
   logger.Warn('[SetBand] rides the frequency set on old Yaesu binary CAT');
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

procedure TYaesuBinary.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   logger.Warn('[SendToRadio(vfo,cmd,data)] not used by Yaesu binary CAT');
end;

end.
