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
unit uRadioKenwoodSerial;
{$I ..\tr4w.inc}

{
  Kenwood serial CAT -- concrete, configurable family base for Kenwood radios
  that speak standard Kenwood ASCII CAT over a serial port (TS-570 and the many
  near-identical TS-x40..TS-2000 siblings).

  This is the Kenwood family's own base -- it deliberately does NOT share
  inheritance with the Elecraft (TK4Radio) or Flex families even though their
  command sets rhyme; each family is its own item.  A per-model subclass (e.g.
  TKenwoodTS570Radio) sets radioModel + serial defaults + capability flags and
  overrides only genuine per-model deviations, exactly as TIcom718Radio
  subclasses TIcomRadio.

  Protocol (standard Kenwood, semicolon-terminated ASCII):
    - IF;                full transceiver status (the poll response): freq, mode,
                         RIT/XIT on+offset, TX/RX, active (RX) VFO, split.
    - FA<11>; / FB<11>;  VFO A / VFO B frequency (set and query).
    - MD<n>;             mode  (1 LSB 2 USB 3 CW 4 FM 5 AM 6 FSK 7 CW-R 9 FSK-R).
    - FR<n>; / FT<n>;    RX / TX VFO select (0=A 1=B) -- split = FT1; (TX on B).
    - RT1;/RT0; XT1;/XT0;  RIT / XIT on/off.   RC;  clear RIT/XIT.   RU;/RD; bump.
    - KS<3>;             keyer speed.          UP;/DN;  VFO step up/down.

  The IF response is parsed by counting back from the terminator (the reading
  thread strips the ';', so we index from the end of the delivered string).
  These offsets match TR4W's proven legacy Kenwood parser (uRadioPolling
  pKenwood2): mode i-8, active-VFO i-7, TX i-9, XIT i-13, RIT i-14, split i-5,
  RIT sign i-19 with a 4-digit magnitude at i-18..i-15, where i is the ';'.

  requiresPolling is True: PollRadioState sends IF;FA;FB; each cycle.  This is
  also what drives serial liveness recovery -- the factory poll loop only
  re-polls (and thus recovers from a radio power-cycle) radios with
  requiresPolling = True.
}

interface

uses
   uRadioKenwoodBase,
  uFactoryRadioBase, uRadioBand, VC, SysUtils, StrUtils, Log4D, uCWFraming;

type
  TKenwoodSerial = class(TKenwoodProtocolRadio)
  protected
    FSeedOtherVFOMode: boolean;   // one-shot: probe the non-operating VFO's mode at connect
    function  ModeNumToMode(ch: Char): TRadioMode;
    function  ModeToKenwoodByte(mode: TRadioMode): string;
    procedure ParseIF(const msg: string);
    procedure ParseFreqResponse(const msg: string; whichVFO: TVFO);
  public
    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;

    procedure Transmit; override;
    procedure Receive; override;
    procedure StopCW; override;
    function  CWIsFactoryOwned: Boolean; override;

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
  end;

implementation

constructor TKenwoodSerial.Create;
begin
  inherited Create(ProcessMsg);
  CWBuffer := '';
  // Standard Kenwood serial radios have no reliable auto-info push we can lean
  // on across the whole family, so poll IF;FA;FB; and rely on the poll (not AI).
  requiresPolling   := True;
  autoUpdateCommand := '';
  pollingInterval   := 500;
  // Use the FIXED 500 ms pollingInterval, NOT the user's FREQUENCY POLL RATE.
  // honorsFreqPollRate=True would set the interval to FreqPollRate (default
  // 10 ms) on connect -- at 100 IF;FA;FB; polls/sec that floods a 4800-baud
  // Kenwood link and its rate-limited send queue (same reason the Icom keeps
  // honorsFreqPollRate=False).  A faster-baud Kenwood model may override True.
  honorsFreqPollRate := False;

   // ---- CW-by-CAT framing (was uCWFraming's `TS480, TS570, ...:` arm) ------
   // The Kenwood KY takes 24 bytes and REJECTS a short P2 under P1=space, so
   // the last chunk is filled to 24.  (The TS-890 is the exception and is a
   // TKenwoodLAN, which states its own rule.)
   //
   // NOTE, a deliberate change of behaviour: the model list this replaces named
   // TS480/570/590/950/990/2000 and omitted the TS-850, which DOES declare
   // rcCWByCAT.  The TS-850 therefore fell to "no limit, no padding".  In D7 it
   // was worse than that -- LOGRADIO.SendCW's `maxLen` was an uninitialised
   // local with no arm for the TS-850, and its chunk loop is
   // `sLen := min(tempLen, maxLen)`, which cannot drain when maxLen <= 0.  A
   // TS-850 keying CW by CAT was undefined in D7 and unchunked in D12; as a
   // TKenwoodSerial it now gets the family rule, which is what its KY wants.
  FCapabilities.CWFrame := CWFrameRule(24, True);
end;

function TKenwoodSerial.Connect: integer;
begin
  Self.readTerminator := ';';
  Result := inherited Connect;
  if Self.IsConnected then
     begin
     // Seed the non-operating VFO's mode once, on the first IF (see ParseIF): the
     // TS-570 reports only the operating VFO's mode, so we briefly flip RX to the
     // other VFO to read it and then restore the operator's VFO.
     FSeedOtherVFOMode := True;
     // Prime the display: full status + both VFO frequencies.
     Self.SendToRadio('IF;FA;FB;');
     end;
end;

// ---------------------------------------------------------------------------
// Incoming message dispatch.  The reading thread hands us one ';'-stripped
// CAT response at a time.
procedure TKenwoodSerial.ProcessMsg(msg: string);
var
  prefix: string;
begin
  if Length(msg) < 2 then
     begin
     Exit;
     end;
  // Any valid frame proves the radio is answering -> refresh serial liveness.
  Self.UpdateLastValidResponse;

  prefix := AnsiUpperCase(Copy(msg, 1, 2));
  if prefix = 'IF' then
     begin
     ParseIF(msg);
     end
  else if prefix = 'FA' then
     begin
     ParseFreqResponse(msg, nrVFOA);
     end
  else if prefix = 'FB' then
     begin
     ParseFreqResponse(msg, nrVFOB);
     end;
  // IF carries only the operating VFO's mode; the other VFO's mode is seeded once
  // at connect by the brief FR flip in ParseIF (the TS-570 has no OM command --
  // it answers "?" to OM0;/OM1;).
end;

// ---------------------------------------------------------------------------
// FA<11 digits> / FB<11 digits> -> that VFO's frequency.
procedure TKenwoodSerial.ParseFreqResponse(const msg: string; whichVFO: TVFO);
var
  hz: integer;
begin
  if Length(msg) < 13 then
     begin
     Exit;
     end;
  hz := StrToIntDef(Copy(msg, 3, 11), -1);
  if hz <= 0 then
     begin
     Exit;
     end;
  Self.vfo[whichVFO].frequency := hz;
  Self.vfo[whichVFO].band := FreqToRadioBand(hz);
end;

// ---------------------------------------------------------------------------
// IF status response.  Parsed end-relative (see unit header) so it is robust to
// the exact overall length across Kenwood models.
procedure TKenwoodSerial.ParseIF(const msg: string);
var
  L: integer;
  hz: integer;
  ritMag: integer;
  activeVFO: TVFO;
begin
  L := Length(msg);
  // Need room for the RIT-sign field at L-18.
  if L < 25 then
     begin
     logger.Error('[%s.ParseIF] IF response too short (%d): %s', [Self.rigLabel, L, msg]);
     Exit;
     end;

  // Frequency of the RX (active) VFO: 11 digits right after "IF".
  hz := StrToIntDef(Copy(msg, 3, 11), -1);

  // Active (RX) VFO from the FR field.
  if msg[L - 6] = '1' then
     begin
     activeVFO := nrVFOB;
     end
  else
     begin
     activeVFO := nrVFOA;
     end;
  Self.SetActiveVFO(activeVFO);

  if hz > 0 then
     begin
     Self.vfo[activeVFO].frequency := hz;
     Self.vfo[activeVFO].band := FreqToRadioBand(hz);
     end;

  // Mode of the active (RX) VFO. IF carries only one mode; the OTHER VFO's mode
  // is read separately via OM0;/OM1; (see ParseOM), because the VFOs can differ.
  Self.vfo[activeVFO].mode := ModeNumToMode(msg[L - 7]);
  Self.localMode := Self.vfo[activeVFO].mode;

  // TX / RX.
  if msg[L - 8] = '1' then
     begin
     Self.radioState := rsTransmit;
     end
  else
     begin
     Self.radioState := rsReceive;
     end;

  // Split (drives the "You are in SPLIT MODE" warning via CurrentStatus.Split).
  Self.SetSplitOn(msg[L - 4] <> '0');

  // RIT / XIT on-off.
  Self.SetRITOn(msg[L - 13] = '1');
  Self.SetXITOn(msg[L - 12] = '1');

  // RIT/XIT offset: sign at L-18, 4-digit magnitude at L-17..L-14.
  ritMag := StrToIntDef(Copy(msg, L - 17, 4), 0);
  if msg[L - 18] = '-' then
     begin
     ritMag := -ritMag;
     end;
  Self.localRITOffset := ritMag;
  Self.localXITOffset := ritMag;   // shared register on Kenwood
  Self.vfo[activeVFO].RITOffset := ritMag;
  Self.vfo[activeVFO].XITOffset := ritMag;

  // One-shot at connect: the TS-570 reports only the operating VFO's mode, so to
  // learn the OTHER VFO's mode we briefly flip RX to it (its IF then carries its
  // mode, filed by ParseIF's own FR field) and immediately restore the operator's
  // VFO.  Runs once per connect; the flipped-to IF does not re-arm this.
  //
  // NEVER WHILE SPLIT IS ON.  On this radio a bare FR CANCELS SPLIT.  Observed on
  // NY4I's TS-570 (tr4w.log 2026-07-29 12:35:13): the radio was in split, TR4W
  // connected, sent FR1;IF;FR0;IF; and the very next IF came back with the split
  // field (L-4) flipped from '1' to '0'.  The operator watched split drop off the
  // rig seconds after starting the program.
  //
  // That is a migration regression, not inherited behaviour: LOGRADIO NEVER sends
  // a bare FR.  Every occurrence there pairs it with an FT in the same write --
  // 'FR0;FT1;', 'FR0;FT0;', 'FR0;FT3;', 'FR0;FT2;' (LOGRADIO 2069/2101/2139/2165)
  // -- so the split state is always re-asserted by the same command.  This
  // standalone flip had no such precedent.
  //
  // Destroying an operator's split to populate a display field is not a trade
  // worth making, so the seeding is simply skipped while split is on.  The cost
  // is VFO B's mode label, which the legacy path never had either.
  if FSeedOtherVFOMode then
     begin
     if Self.localSplitEnabled then
        begin
        // Do not re-arm: retrying on a later poll would just wait for the operator
        // to drop split and then yank it again at a random moment.
        FSeedOtherVFOMode := False;
        logger.Debug('[%s.ParseIF] Split is on -- skipping the VFO-mode seed, ' +
                     'because a bare FR cancels split on this radio', [Self.rigLabel]);
        end
     else
        begin
        FSeedOtherVFOMode := False;
        if activeVFO = nrVFOA then
           begin
           Self.SendToRadio('FR1;IF;FR0;IF;');   // read VFO B, restore VFO A
           end
        else
           begin
           Self.SendToRadio('FR0;IF;FR1;IF;');   // read VFO A, restore VFO B
           end;
        end;
     end;
end;

// ---------------------------------------------------------------------------
// Mode maps (standard Kenwood MD byte).
function TKenwoodSerial.ModeNumToMode(ch: Char): TRadioMode;
begin
  case ch of
    '1': Result := rmLSB;
    '2': Result := rmUSB;
    '3': Result := rmCW;
    '4': Result := rmFM;
    '5': Result := rmAM;
    '6': Result := rmFSK;
    '7': Result := rmCWRev;
    '9': Result := rmFSKRev;
  else
    Result := rmNone;
  end;
end;

function TKenwoodSerial.ModeToKenwoodByte(mode: TRadioMode): string;
begin
  case mode of
    rmLSB:    Result := '1';
    rmUSB:    Result := '2';
    rmCW:     Result := '3';
    rmFM:     Result := '4';
    rmAM:     Result := '5';
    rmFSK:    Result := '6';
    rmCWRev:  Result := '7';
    rmFSKRev: Result := '9';
  else
    Result := '';
  end;
end;

// ---------------------------------------------------------------------------
procedure TKenwoodSerial.PollRadioState;
begin
  // One light query per cycle: full status + both VFO frequencies.  Also the
  // keep-alive that lets the factory serial path recover after a power-cycle.
  Self.SendToRadio('IF;FA;FB;');
end;

// VFO-addressed command: FA<data> for VFO A, FB<data> for VFO B (Kenwood has no
// "$" second-VFO suffix like the K4).  sCmd is the base command letter pair
// with the trailing A/B chosen here.
procedure TKenwoodSerial.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
  Self.SendToRadio(Format('%s%s;', [sCmd, sData]));
end;

procedure TKenwoodSerial.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
begin
  case vfo of
    nrVFOA: Self.SendToRadio(Format('FA%.11d;', [freq]));
    nrVFOB: Self.SendToRadio(Format('FB%.11d;', [freq]));
  else
    begin
    logger.Error('[%s.SetFrequency] invalid VFO', [Self.rigLabel]);
    Exit;
    end;
  end;
  if mode <> rmNone then
     begin
     Self.SetMode(mode, vfo);
     end;
end;

procedure TKenwoodSerial.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
  b: string;
begin
  b := ModeToKenwoodByte(mode);
  if b = '' then
     begin
     logger.Error('[%s.SetMode] unsupported mode %d', [Self.rigLabel, Ord(mode)]);
     Exit;
     end;
  // Standard Kenwood MD sets the mode of the current RX VFO; there is no
  // per-VFO mode set on the TS-570, so vfo is advisory here.
  Self.SendToRadio(Format('MD%s;', [b]));
end;

function TKenwoodSerial.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
begin
  // Not implemented for the base family; a model may override.
  Result := Self.vfo[vfo].mode;
end;

procedure TKenwoodSerial.SetCWSpeed(speed: integer);
begin
  if (speed >= 4) and (speed <= 60) then
     begin
     Self.localCWSpeed := speed;
     Self.SendToRadio(Format('KS%.3d;', [speed]));
     end
  else
     begin
     logger.Error('[%s.SetCWSpeed] speed out of range (%d)', [Self.rigLabel, speed]);
     end;
end;

// ---------------------------------------------------------------------------
// RIT / XIT.
procedure TKenwoodSerial.RITClear(whichVFO: TVFO);
begin
  Self.SendToRadio('RC;');
end;

procedure TKenwoodSerial.XITClear(whichVFO: TVFO);
begin
  Self.SendToRadio('RC;');   // RC; clears the shared RIT/XIT offset
end;

procedure TKenwoodSerial.RITBumpDown;
begin
  Self.SendToRadio('RD;');
end;

procedure TKenwoodSerial.RITBumpUp;
begin
  Self.SendToRadio('RU;');
end;

procedure TKenwoodSerial.RITOn(whichVFO: TVFO);
begin
  Self.SendToRadio('RT1;');
end;

procedure TKenwoodSerial.RITOff(whichVFO: TVFO);
begin
  Self.SendToRadio('RT0;');
end;

procedure TKenwoodSerial.XITOn(whichVFO: TVFO);
begin
  Self.SendToRadio('XT1;');
end;

procedure TKenwoodSerial.XITOff(whichVFO: TVFO);
begin
  Self.SendToRadio('XT0;');
end;

procedure TKenwoodSerial.Split(splitOn: boolean);
begin
  // FR0; FIRST, then FT.  FT alone selects the TX VFO, but the legacy path has
  // always sent BOTH (LOGRADIO.PAS:2066 / :2135, 'FR0;FT1;' and 'FR0;FT0;') and
  // carries a maintainer's warning about exactly this:
  //
  //   {KK1L: 6.71 For some reason needed this to get the FT1; command to take.
  //               Started when I added setting mode of B VFO to set freq. }
  //
  // So FT alone was known NOT to take on at least some radios in this family,
  // and the factory migration dropped the fix.  Sending FR0; also puts RX on
  // VFO A, which makes this a complete "RX on A, TX on B" split rather than a
  // TX-side-only change -- and that is what every Kenwood here has received from
  // TR4W for years.
  //
  // Restored deliberately: of the twelve Kenwoods now on this base, only the
  // TS-570 has been benched through the factory, so matching the shipping
  // behaviour is the safe default rather than an improvement on it.
  if splitOn then
     begin
     Self.SendToRadio('FR0;FT1;');
     end
  else
     begin
     Self.SendToRadio('FR0;FT0;');
     end;
  // FR0; moved the RX pointer to VFO A; keep the driver's own idea of the
  // active VFO in step or the next IF parse will disagree with the radio.
  Self.SetActiveVFO(nrVFOA);
end;

procedure TKenwoodSerial.SetRITFreq(whichVFO: TVFO; hz: integer);
begin
  // The TS-570 has no "set RIT to N Hz" CAT command (offset is adjusted only by
  // RU;/RD; steps).  Clear it so at least the state is known; exact offset set
  // is a hard radio limit.  (Bench assumption -- flag if a model supports it.)
  Self.SendToRadio('RC;');
  logger.Debug('[%s.SetRITFreq] TS-570 cannot set an exact RIT offset; cleared', [Self.rigLabel]);
end;

procedure TKenwoodSerial.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
  Self.SetRITFreq(whichVFO, hz);
end;

// ---------------------------------------------------------------------------
// Band: standard Kenwood has no direct band-select command on the TS-570 --
// changing the VFO frequency changes band.  Retune VFO A to the band's typical
// frequency.
procedure TKenwoodSerial.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var
  freq: LongInt;
begin
  freq := BandToFreq(band);
  if freq > 0 then
     begin
     Self.SetFrequency(freq, vfo, rmNone);
     end;
end;

function TKenwoodSerial.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
  Result := Self.vfo[vfo].band;
end;

procedure TKenwoodSerial.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
  // Filter selection differs across Kenwood models (FL/IS/SL/SH); left as a
  // no-op in the base until per-model support is added.  (Bench assumption.)
  logger.Debug('[%s.SetFilter] not implemented for the Kenwood serial base', [Self.rigLabel]);
end;

function TKenwoodSerial.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
  Result := 0;   // not supported in the base
end;

function TKenwoodSerial.MemoryKeyer(mem: integer): boolean;
begin
  // The TS-570 has no CW message memory over CAT.  True = "error / unsupported".
  Result := True;
end;

procedure TKenwoodSerial.VFOBumpDown(whichVFO: TVFO);
begin
  Self.SendToRadio('DN;');
end;

procedure TKenwoodSerial.VFOBumpUp(whichVFO: TVFO);
begin
  Self.SendToRadio('UP;');
end;

// ---------------------------------------------------------------------------
// PTT / CW.
procedure TKenwoodSerial.Transmit;
begin
  Self.SendToRadio('TX;');
end;

procedure TKenwoodSerial.Receive;
begin
  Self.SendToRadio('RX;');
end;



function TKenwoodSerial.CWIsFactoryOwned: Boolean;
begin
   // StopCW below really aborts the keyer, so StopSendingCW may delegate here.
   Result := True;
end;

procedure TKenwoodSerial.StopCW;
begin
   // Moved from LOGRADIO.StopSendingCW's rtKenwood arm, which sent these two
   // commands for TS480/570/590/850/890/950/990/2000.  KY0 empties the keyer
   // buffer; RX then drops the radio out of transmit -- the buffer alone would
   // leave it keyed down with nothing to send.  Two separate writes, as the
   // legacy code sent them.
   Self.CWBuffer := '';
   Self.SendToRadio('KY0;');
   Self.SendToRadio('RX;');
end;



end.
