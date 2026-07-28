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

  In particular SerialFixedFrameLength is deliberately NOT set here -- the answer
  length is per-model, and a wrong value silently mis-delimits every frame.
}

interface

uses uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC;

type
  TYaesuBinary = class(TFactoryRadioBase)
  protected
    logger: TLogLogger;
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

    function  Connect: integer; override;

    // ---- Not available over old Yaesu binary CAT (models that DO support one of
    // these override it).  Inert rather than abstract so a minimal model such as
    // the FT-817 does not have to restate a wall of empty stubs. ----
    procedure Transmit; override;
    procedure Receive; override;
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
   logger := TLogLogger.GetLogger('TR4WDebugLog.YaesuBinary');

   SerialProtocolIsBinary := True;   // byte-exact 5-byte frames, no codepage decode
   bAddTermination        := False;  // NO CR/LF on binary CAT
   requiresPolling        := True;
   honorsFreqPollRate     := False;  // these answers are fixed-length; keep our cadence
   pollingInterval        := 150;    // conservative BR4800 default; models may lower it
   // SerialFixedFrameLength is intentionally NOT set here -- see the unit header.
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

procedure TYaesuBinary.SendBytes(b0, b1, b2, b3, b4: Byte);
begin
   Self.SendToRadio(Chr(b0) + Chr(b1) + Chr(b2) + Chr(b3) + Chr(b4));
end;

// ---------------------------------------------------------------------------
// Neutral defaults.  Anything a specific radio supports is overridden there.
// ---------------------------------------------------------------------------

procedure TYaesuBinary.Transmit;
begin
   logger.Warn('[Transmit] PTT-via-CAT not supported by %s', [Self.radioModel]);
end;

procedure TYaesuBinary.Receive;
begin
   logger.Warn('[Receive] PTT-via-CAT not supported by %s', [Self.radioModel]);
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
