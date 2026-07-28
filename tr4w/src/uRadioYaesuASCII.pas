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

unit uRadioYaesuASCII;

{
  Yaesu serial CAT -- ASCII/text family BASE (legacy rtYaesu3 + rtYaesu4).  The
  ";"-terminated text dialect spoken by the newer Yaesu radios: FTDX-10, FT-991,
  and later FTDX-101 / FT-710 / FTX-1F.

  This unit holds the SHARED PROTOCOL ONLY.  It knows nothing about any particular
  model and must stay that way -- see THE CONTRACT below.  Per-model units are the
  siblings named after their lead model: uRadioYaesuFTDX10, uRadioYaesuFT991.
  (Mirrors uRadioYaesuBinary, the base for the old 5-byte binary CAT radios in
  uRadioYaesuFT817 / uRadioYaesuFT1000MP.)

  ---------------------------------------------------------------------------
  THE CONTRACT -- read this before adding anything to this unit
  ---------------------------------------------------------------------------
  NOTHING IN THIS UNIT MAY ASK WHICH RADIO IT IS.  No "if radioModel = ...", no
  "RadioModel in [FTDX10, ...]", not in any form.  That test is what the factory
  exists to eliminate: it was scattered through LOGRADIO and uRadioPolling, and it
  is why adding one radio there meant editing a dozen unrelated case statements.

  When a model needs to behave differently, it says so in one of two ways:

    1. OVERRIDE A VIRTUAL.  Preferred when the difference is behaviour.  Every
       command method is virtual, plus the four protocol seams below.
    2. DECLARE A CAPABILITY.  Preferred when the difference is a fact ABOUT the
       radio that other code must branch on -- FCapabilities.Flags, set in the
       model constructor.  The base may test a flag; it may never test a model.

  The seams a new model is most likely to need:

    ProcessMessage    dispatch of a received command.  A radio that answers with
                      something new overrides this, handles its own command, and
                      calls inherited for the rest.
    ParseIFResponse   the IF;/OI; field layout.  The FTX-1F is documented as a
                      30-byte response (VC.pas, Issue #817) rather than 28, so it
                      will need this one.
    ModeCharToMode    read side of the mode map.  The rtYaesu3 radios differ from
                      the rtYaesu4 ones on exactly one character -- see
                      uRadioYaesuFT991.
    ModeToYaesuDigit  write side of the same map.

  Worked example -- Yaesu ships a new radio, near-identical to the FTDX-10, except
  it finally supports KY; for CW text the way Kenwood and Elecraft do:

      unit uRadioYaesuFTDX1234;
      TYaesuFTDX1234Radio = class(TYaesuSerial)
        procedure BufferCW(cwChars: string); override;
        procedure SendCW; override;          // KY; -- the one real difference
      end;

  Nothing in THIS unit changes and no other Yaesu is affected.  If instead you find
  yourself wanting to add "if radioModel = FTDX1234" here, that is the signal that
  a seam is missing: add the virtual or the capability flag, not the test.
  ---------------------------------------------------------------------------

  PROTOCOL, ported from the bench-proven legacy path (uRadioPolling
  pFTDX10_FTDX101 / pFT891_FT991 plus the LOGRADIO rtYaesu3/rtYaesu4 send arms).
  Differences from the Kenwood/Elecraft ASCII dialect that this base bakes in:
    - VFO B is read with a SEPARATE command OI; (opposite-VFO info), not a "$"
      suffix -- these radios cannot return both VFOs from one IF;.
    - Split is read with FT; and set with FT3;/FT2; (not FR;/FT1;/FT0;).
    - Mode is set with the 5-char MD0n; (extra VFO/"0" byte) vs Kenwood's MDn;.
    - The IF;/OI; response is 28 bytes, parsed by FIXED offsets from the START
      (freq pos 6-14, clarifier pos 15-19, RIT-on pos 20, XIT-on pos 21, mode
      pos 22) -- NOT end-relative like the Kenwood base.

  Poll, do not push: PollRadioState queries IF;OI;FT;TX; each cycle at a fixed
  100 ms interval (honorsFreqPollRate = False) so a fast FreqPollRate cannot
  flood the BR4800 link.  requiresPolling = True drives serial power-cycle
  recovery.

  Per-VFO writes: freq/mode go to vfo[nrVFOA/nrVFOB], and RIT/XIT go through the
  base SetRITOn/SetXITOn/SetRITOffset/SetXITOffset setters (NOT the Self.* legacy
  scalars) so the radio window -- fed from the per-VFO fields on the serial poll
  -- actually updates.  (This is the same fix the K3 needed.)

  CW keying is NOT implemented here (inert stubs).  CW-by-CAT keys through the
  legacy path / future CW Keyer Factory, same as the Elecraft/Kenwood serial bases.
}

interface

uses uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uRadioRegistry;

type
  TYaesuSerial = class(TFactoryRadioBase)
  protected
    logger: TLogLogger;
    firstProcessMessage: boolean;
    FCWSpeedMin: integer;
    FCWSpeedMax: integer;
    // The four protocol seams a per-model subclass may need.  Virtual so a
    // deviating model overrides one instead of this unit growing a model test.
    procedure ParseIFResponse(const msg: string; whichVFO: TVFO); virtual;
    // virtual: the rtYaesu3 radios (FT-991) override the one character that
    // differs between the Type3 and Type5 legacy maps.
    function  ModeCharToMode(c: Char): TRadioMode; virtual;
    function  ModeToYaesuDigit(mode: TRadioMode): integer; virtual;
    procedure Initialize;
  public
    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    // Virtual AND the constructor callback: TFactoryRadioBase.Create captures
    // this as a method pointer, and Delphi fixes the VMT before any constructor
    // body runs, so the pointer resolves to a subclass override.  If it were
    // static, a model that answers with a new command could not hook in at all
    // -- overriding ProcessMsg would not help either, since the reading thread
    // is handed baseProcMsg (this) and never calls ProcessMsg.
    procedure ProcessMessage(sMessage: string); virtual;
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

implementation

constructor TYaesuSerial.Create;
begin
   inherited Create(ProcessMessage);
   logger := TLogLogger.GetLogger('TR4WDebugLog.YaesuSerial');
   firstProcessMessage := True;

   requiresPolling    := True;
   autoUpdateCommand  := '';
   pollingInterval    := 100;
   honorsFreqPollRate := False;   // fixed 100ms; a 10ms FreqPollRate would flood BR4800

   FCWSpeedMin := 4;              // Yaesu keyer range (per-model overridable)
   FCWSpeedMax := 60;
end;

function TYaesuSerial.Connect: integer;
begin
   Self.readTerminator := ';';
   Result := Inherited Connect;
   if Self.IsConnected then
      begin
      // Prime the display: full state for both VFOs + split + TX.
      Self.SendToRadio('IF;OI;FT;TX;');
      end;
end;

procedure TYaesuSerial.Transmit;
begin
   Self.SendToRadio('TX1;');
end;

procedure TYaesuSerial.Receive;
begin
   Self.SendToRadio('TX0;');
end;

// CW keying owned by the legacy path / future CW Keyer Factory -- inert stubs.
procedure TYaesuSerial.BufferCW(cwChars: string);
begin
end;

procedure TYaesuSerial.SendCW;
begin
end;

procedure TYaesuSerial.StopCW;
begin
end;

procedure TYaesuSerial.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var sCmd: string;
begin
   case vfo of
      nrVFOA: sCmd := 'FA';
      nrVFOB: sCmd := 'FB';
      else
         begin
         logger.error('[SetFrequency] Invalid VFO passed');
         Exit;
         end;
      end;
   // rtYaesu4 uses the 9-digit freq form (LOGRADIO Issue 218).
   Self.SendToRadio(Format('%s%.9d;',[sCmd,freq]));
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

procedure TYaesuSerial.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var d: integer;
begin
   d := Self.ModeToYaesuDigit(mode);
   if d > 0 then
      begin
      // 5-char MD0n; (the '0' is the VFO/fixed byte per legacy rtYaesu4).
      Self.SendToRadio(Format('MD0%d;',[d]));
      end
   else
      begin
      logger.error('[SetMode] Invalid mode passed Ordinal = %d',[Ord(mode)]);
      end;
end;

function TYaesuSerial.ToggleMode(vfo: TVFO): TRadioMode;
begin
   Result := Self.vfo[vfo].mode;
end;

procedure TYaesuSerial.SetCWSpeed(speed: integer);
begin
   // Yaesu KS keyer-speed command (KS + 3 digits).  Verify range/format on bench.
   if IntegerBetween(speed, FCWSpeedMin, FCWSpeedMax) then
      begin
      Self.localCWSpeed := speed;
      Self.SendToRadio(Format('KS%.3d;',[speed]));
      end
   else
      begin
      logger.Error('[SetCWSpeed] speed out of range %d..%d (%d)',[FCWSpeedMin, FCWSpeedMax, speed]);
      end;
end;

procedure TYaesuSerial.RITClear(whichVFO: TVFO);
begin
   Self.SendToRadio('RC;');   // clarifier clear
end;

procedure TYaesuSerial.XITClear(whichVFO: TVFO);
begin
   Self.SendToRadio('RC;');
end;

procedure TYaesuSerial.RITBumpDown;
begin
   Self.SendToRadio('RD;');
end;

procedure TYaesuSerial.RITBumpUp;
begin
   Self.SendToRadio('RU;');
end;

procedure TYaesuSerial.RITOn(whichVFO: TVFO);
begin
   Self.SendToRadio('RT1;');
end;

procedure TYaesuSerial.RITOff(whichVFO: TVFO);
begin
   Self.SendToRadio('RT0;');
end;

procedure TYaesuSerial.XITOn(whichVFO: TVFO);
begin
   Self.SendToRadio('XT1;');
end;

procedure TYaesuSerial.XITOff(whichVFO: TVFO);
begin
   Self.SendToRadio('XT0;');
end;

procedure TYaesuSerial.Split(splitOn: boolean);
begin
   // rtYaesu4 split: FT3; on / FT2; off (LOGRADIO PutRadioIntoSplit/OutOfSplit).
   if splitOn then
      begin
      Self.SendToRadio('FT3;');
      end
   else
      begin
      Self.SendToRadio('FT2;');
      end;
end;

procedure TYaesuSerial.SetRITFreq(whichVFO: TVFO; hz: integer);
var s: string;
begin
   if (hz > -10000) and (hz < 10000) then
      begin
      if hz >= 0 then s := '+' else s := '-';
      s := s + Format('%.4d',[Abs(hz)]);
      // Yaesu clarifier-offset set command (RU/RD steps or a direct set); the
      // direct form varies by model -- confirm on bench.  Using the clarifier
      // offset command form here.
      Self.SendToRadio('RO' + s + ';');
      end
   else
      begin
      logger.Error('[SetRITFreq] RIT frequency must be between -9999 and 9999 (%d)',[hz]);
      end;
end;

procedure TYaesuSerial.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SetRITFreq(whichVFO, hz);
end;

procedure TYaesuSerial.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
begin
   // Yaesu has no simple "band N" command like the Elecraft BN; band changes ride
   // the freq set.  No-op (a model may override with BS if needed).
   logger.Warn('[SetBand] direct band-set not implemented for Yaesu serial (rides freq set)');
end;

function TYaesuSerial.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
   logger.Warn('ToggleBand not implemented');
   Result := rbNone;
end;

procedure TYaesuSerial.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
   logger.Warn('SetFilter not yet implemented for Yaesu serial');
end;

function TYaesuSerial.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   logger.Warn('SetFilterHz not yet implemented for Yaesu serial');
   Result := 0;
end;

function TYaesuSerial.MemoryKeyer(mem: integer): boolean;
begin
   // DVK/memory-keyer over CAT not implemented for Yaesu serial yet.
   Result := True;   // True = unsupported (fail closed)
end;

procedure TYaesuSerial.VFOBumpDown(whichVFO: TVFO);
begin
   Self.SendToRadio('DN;');
end;

procedure TYaesuSerial.VFOBumpUp(whichVFO: TVFO);
begin
   Self.SendToRadio('UP;');
end;

// -----------------------------------------------------------------------------
// IF; / OI; response parse (28-byte, fixed offsets from the start).  whichVFO says
// which VFO this response describes (IF; -> A, OI; -> B).
//   pos 1-2  "IF"/"OI"
//   pos 6-14 frequency (9 ASCII digits, Hz)
//   pos 15   clarifier sign (+/-)
//   pos 16-19 clarifier offset (4 digits)
//   pos 20   RIT (clarifier RX) on/off
//   pos 21   XIT (clarifier TX) on/off
//   pos 22   mode char
procedure TYaesuSerial.ParseIFResponse(const msg: string; whichVFO: TVFO);
var
   hz: integer;
   ritHz: integer;
   ritSign: integer;
begin
   if Length(msg) < 22 then
      begin
      logger.Error('[ParseIFResponse] short response (%d chars): %s',[Length(msg), msg]);
      Exit;
      end;

   hz := StrToIntDef(Copy(msg, 6, 9), -1);
   if hz < 0 then
      begin
      logger.Error('[ParseIFResponse] non-numeric frequency: %s',[Copy(msg, 6, 9)]);
      Exit;
      end;
   Self.vfo[whichVFO].frequency := hz;
   Self.vfo[whichVFO].band := FreqToRadioBand(hz);
   Self.vfo[whichVFO].mode := Self.ModeCharToMode(msg[22]);

   // RIT/XIT are per-radio; write every VFO copy the window reads (base setters).
   ritSign := IfThen(msg[15] = '-', -1, 1);
   ritHz := StrToIntDef(Copy(msg, 16, 4), 0) * ritSign;
   Self.SetRITOffset(ritHz);
   Self.SetXITOffset(ritHz);
   Self.SetRITOn(msg[20] = '1');
   Self.SetXITOn(msg[21] = '1');
end;

function TYaesuSerial.ModeCharToMode(c: Char): TRadioMode;
begin
   // Common Yaesu (Type5) mode chars.  Less-common DATA/PSK variants: confirm on bench.
   case c of
      '1': Result := rmLSB;
      '2': Result := rmUSB;
      '3': Result := rmCW;
      '4': Result := rmFM;
      '5': Result := rmAM;
      '6': Result := rmFSK;      // RTTY-LSB
      '7': Result := rmCWRev;    // CW-R
      '8': Result := rmData;     // DATA-LSB
      '9': Result := rmFSKRev;   // RTTY-USB
      'A': Result := rmData;     // DATA-FM
      'B': Result := rmFM;       // FM-N
      'C': Result := rmData;     // DATA-USB
      'D': Result := rmAM;       // AM-N
      'E': Result := rmPSK;      // PSK31 (Type5)
      'F': Result := rmData;     // DATA-FM
      // 'B' and 'F' were missing from the original port of this map and would
      // have logged "unmapped mode char" on a real FM-N or DATA-FM QSO; both are
      // present in the legacy GetVFOInfoForYaesuType5 this was ported from.
      //
      // NOTE for subclasses: 'E' is the ONLY entry the rtYaesu3 radios disagree
      // with (C4FM there, not PSK31) -- see uRadioYaesuFT991, which overrides
      // exactly that one character and defers the rest here.
   else
      begin
      logger.Warn('[ModeCharToMode] unmapped mode char "%s"',[c]);
      Result := rmNone;
      end;
   end;
end;

function TYaesuSerial.ModeToYaesuDigit(mode: TRadioMode): integer;
begin
   // Set-mode digit for MD0n; (per LOGRADIO rtYaesu4 send arm).
   case mode of
      rmLSB:    Result := 1;
      rmUSB:    Result := 2;
      rmCW:     Result := 3;
      rmCWRev:  Result := 7;
      rmFM:     Result := 4;
      rmAM:     Result := 5;
      rmFSK:    Result := 6;   // RTTY-L
      rmFSKRev: Result := 9;   // RTTY-U
      rmData:   Result := 8;   // DATA-L
      rmPSK:    Result := 8;
   else
      Result := -1;
   end;
end;

procedure TYaesuSerial.ProcessMsg(msg: string);
begin
   ProcessMessage(msg);
end;

procedure TYaesuSerial.ProcessMessage(sMessage: string);
var
   sCommand: string;
begin
   logger.Trace('[ProcessMessage] Received from radio: (%s)',[sMessage]);
   UpdateLastValidResponse;   // any message proves the radio is answering
   if Length(sMessage) < 2 then
      begin
      Exit;
      end;
   sCommand := AnsiUppercase(AnsiLeftStr(sMessage, 2));

   if sCommand = 'IF' then
      begin
      Self.ParseIFResponse(sMessage, nrVFOA);
      Self.SetActiveVFO(nrVFOA);
      end
   else if sCommand = 'OI' then
      begin
      Self.ParseIFResponse(sMessage, nrVFOB);
      end
   else if sCommand = 'FT' then
      begin
      // FT; reports which VFO is TX: '1'..'3' non-zero -> split.  (pos 3.)
      if Length(sMessage) >= 3 then
         begin
         Self.SetSplitOn(sMessage[3] <> '0');
         end;
      end
   else if sCommand = 'TX' then
      begin
      if Length(sMessage) >= 3 then
         begin
         if sMessage[3] in ['1','2'] then
            begin
            Self.radioState := rsTransmit;
            end
         else
            begin
            Self.radioState := rsReceive;
            end;
         end;
      end
   else if sCommand = 'FA' then
      begin
      Self.vfo[nrVFOA].frequency := StrToIntDef(Copy(sMessage, 3, 9), Self.vfo[nrVFOA].frequency);
      Self.vfo[nrVFOA].band := FreqToRadioBand(Self.vfo[nrVFOA].frequency);
      end
   else if sCommand = 'FB' then
      begin
      Self.vfo[nrVFOB].frequency := StrToIntDef(Copy(sMessage, 3, 9), Self.vfo[nrVFOB].frequency);
      Self.vfo[nrVFOB].band := FreqToRadioBand(Self.vfo[nrVFOB].frequency);
      end;

   if firstProcessMessage then
      begin
      firstProcessMessage := false;
      Initialize;
      end;
end;

procedure TYaesuSerial.PollRadioState;
begin
   // IF; = VFO A (28-byte), OI; = VFO B (28-byte), FT; = split, TX; = TX state.
   // Also the keep-alive that drives serial power-cycle recovery.
   Self.SendToRadio('IF;OI;FT;TX;');
end;

procedure TYaesuSerial.Initialize;
begin
   if Self.rigLabel <> '' then
      begin
      logger := TLogLogger.GetLogger('TR4WDebugLog.Yaesu-' + Self.rigLabel);
      end;
   logger.debug('[Initialize] Yaesu serial ready');
end;

// Yaesu serial has no "$" VFO addressing (VFO B is read via OI;, set via FB).
// This overload just appends ';' and ignores whichVFO for the plain send form.
procedure TYaesuSerial.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   Inherited SendToRadio(Format('%s%s;',[sCmd,sData]));
end;

end.
