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
unit uRadioElecraftSerial;

{
  Elecraft serial CAT -- concrete, configurable family base for the serial
  Elecraft radios (K3, KX3 and the K2 to the extent it speaks the same CAT).

  This is the ELECRAFT family's own base.  It deliberately does NOT share
  inheritance with the Kenwood (TKenwoodSerial) or Flex families even though
  their command sets rhyme; each family is its own item (the K4 keeps its own
  uRadioElecraftK4 unit -- it is a network+serial radio with an AI push model,
  a different animal from the serial-only, poll-driven K3).  A per-model subclass
  (e.g. TK3Radio) sets radioModel + capability flags and overrides only genuine
  per-model deviations, exactly as TKenwoodTS570Radio subclasses TKenwoodSerial.

  The CAT logic here is PORTED from the bench-proven TK4Radio: the Elecraft IF /
  MD / DT / FA / FB / FT / RT / XT / RO / KS / BN command set is identical.  The
  differences from the K4 that this base bakes in are all serial-K3 specifics:

    - Extended command mode.  The K3/KX3 default to "K30" (basic), where the "$"
      second-VFO suffix (MD$, DT$) and the extended IF response are unavailable.
      Connect sends K31; to switch on extended mode -- exactly what the legacy
      serial path did in uRadioPolling.pKenwood2 (SetK3ExtendedCommandMode).  The
      K4 needs no such command (always extended), which is one reason it is not
      this family's base.

    - Poll, don't push.  Serial Elecraft is polled (AI disabled): Connect sends
      AI0; and PollRadioState queries IF;FB;MD$;DT$; each cycle -- IF gives VFO A
      freq+mode+RIT/XIT/split/TX and the operating VFO; FB/MD$/DT$ give VFO B's
      freq/mode/sub-mode via the "$" suffix (no VFO flip, no RX blip).  This poll
      is also what drives serial liveness recovery: the factory poll loop only
      re-polls (and thus recovers a power-cycled radio) radios with
      requiresPolling = True.

    - DVK memory keyer uses the K3 SWT button emulation (SWT21/31/35/39, SWT37 to
      cancel), not the K4 DAMP command.

  CW keying is intentionally NOT implemented here.  CW-by-CAT for these radios is
  keyed through the legacy path (RadioObject.SendCW builds the KY bytes ->
  AddToOutputBuffer -> tFactoryObject.SendToRadio), and a future CW Keyer Factory
  will own keying-strategy selection.  SendCW/BufferCW/StopCW are inert stubs so
  the factory contract is satisfied without duplicating (and racing) that path.
}

interface

uses Windows, uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uCWFraming,
     uElecraftIF;   // shared IF decode -- the K4 uses the same one

type
  TElecraftSerial = class(TFactoryRadioBase)
  protected
    CWBuffer: string;       // text accumulated by BufferCW, emitted by SendCW
    firstProcessMessage: boolean;
    FCWSpeedMin: integer;   // KS range; K3/KX3 keyer is 8..50 wpm (per-model overridable)
    FCWSpeedMax: integer;
    function  ParseIFCommand(cmd: string): boolean;
    function  ModeStrToMode(sMode: string; sDataMode: string): TRadioMode;
    function  BandNumToBand(sBand: string): TRadioBand;
    function  ModeTypeToInteger(mode: TRadioMode; var dataModeInt: integer): integer;
    procedure Initialize;
    procedure SetAIMode(i: integer);
  public
    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    procedure ProcessMessage(sMessage: string);
    procedure PollRadioState; override;

    procedure Transmit; override;
    procedure Receive; override;
    procedure BufferCW(cwChars: string); override;
    procedure SendCW; override;
    procedure StopCW; override;
    function  CWIsFactoryOwned: Boolean; override;
    // The character that aborts the keyer inside a KY command: #4 on the
    // K3/KX3/K4, '@' on the K2.  A VIRTUAL, not a model test -- this base must
    // never ask which radio it is (see the K2 override).
    function  CWAbortChar: Char; virtual;

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

    // VFO-addressed send: sCmd + optional "$" (VFO B) + data + ";"
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
  end;

implementation

const
   // (The IF length guard moved to uElecraftIF.IF_PARSED_LENGTH, where it is
   // stated in terms of what the parse consumes rather than the wire length.)

   // How long to let the rig finish the RX transition after a keyer abort
   // before the next KY is sent.  EMPIRICAL -- start here and tune on the
   // bench; the failing case is a ONE-character message ('?') following an
   // abort, which was silent at a 1-2 ms gap while a 12-character message
   // survived.  Paid only when a message is actually interrupted.
   CW_ABORT_SETTLE_MS = 75;

constructor TElecraftSerial.Create;
begin
   inherited Create(ProcessMessage);

   // Generic logger until rigLabel is set by LOGRADIO after creation.

   firstProcessMessage := True;   // call Initialize on first message received

   // Serial Elecraft is polled (AI off).  See unit header.
   requiresPolling    := True;
   autoUpdateCommand  := '';
   pollingInterval    := 100;
   // Use the FIXED pollingInterval, NOT the user's FREQUENCY POLL RATE.  The
   // factory poll loop sends PollRadioState then sleeps pollingInterval without
   // waiting for the answer, so a 10 ms FreqPollRate would fire IF;FB;MD$;DT$;
   // ~100x/sec and flood even a 38400-baud link.  100 ms (10 Hz) tracks the
   // radio's VFO comfortably for contest logging.  A faster-baud model may
   // override this to True.
   honorsFreqPollRate := False;

   // K3/KX3 keyer speed range.  Overridable per model.
   FCWSpeedMin := 8;
   FCWSpeedMax := 50;
end;

function TElecraftSerial.Connect: integer;
begin
   Self.readTerminator := ';';
   Result := Inherited Connect;
   if Self.IsConnected then
      begin
      // Switch the K3/KX3 into extended command mode so the "$" second-VFO
      // suffix and the extended IF response are available (basic "K30" mode has
      // neither).  Then disable AI -- we poll on serial.
      Self.SendToRadio('K31;');
      Self.SetAIMode(0);
      Self.requiresPolling := True;
      // Prime the display: extended-mode probe already sent; now pull full state
      // for both VFOs.  MD$/DT$ read VFO B's mode/sub-mode via the "$" suffix.
      Self.SendToRadio('RT;XT;RO;FT;MD;DT;IF;FA;FB;MD$;DT$;');
      end;
end;

procedure TElecraftSerial.Transmit;
begin
   Self.SendToRadio('TX;');
end;

procedure TElecraftSerial.Receive;
begin
   Self.SendToRadio('RX;');
end;

// ---------------------------------------------------------------------------
// CW keying is owned by the legacy path (and, later, the CW Keyer Factory).  See
// unit header.  These stubs satisfy the abstract contract without duplicating it.
procedure TElecraftSerial.BufferCW(cwChars: string);
begin
   Self.CWBuffer := Self.CWBuffer + cwChars;
end;

procedure TElecraftSerial.SendCW;
begin
   // No longer inert.  LOGRADIO used to format the KY command itself and push it
   // through SendToRadio; it now hands the driver a chunk and this emits it, so
   // the command form belongs to the radio that speaks it.  The chunking and the
   // 22-character limit stay in uCWFraming -- they are per-model DATA, shared
   // with the legacy path while the migration finishes.
   if Self.CWBuffer = '' then
      begin
      Exit;
      end;
   Self.SendToRadio(uCWFraming.CWKYCommand(Self.CWBuffer, Self.CWSendImmediate));
   Self.CWBuffer := '';
   Self.CWSendImmediate := False;
end;

function TElecraftSerial.CWAbortChar: Char;
begin
   Result := Chr(4);
end;

function TElecraftSerial.CWIsFactoryOwned: Boolean;
begin
   // StopCW below really aborts the keyer, so StopSendingCW may delegate here.
   // (It checks this flag precisely because most drivers' StopCW is inert; a
   // blanket delegation once swallowed Escape entirely -- NY4I, K3, 2026-07-31.)
   Result := True;
end;

procedure TElecraftSerial.StopCW;
begin
   // The 'KY ' PREFIX IS REQUIRED -- the abort is a KY command carrying the
   // abort character, not a bare control byte.
   //
   // THE 'RX;' IS WHAT ACTUALLY STOPS THE TRANSMISSION.  Briefly removed on
   // 2026-08-01 because the K3 command reference calls ^D (EOT, ASCII 04) a
   // command that "quickly terminates transmission" -- but the same line ends
   // "use with CW-to-DATA", and that qualifier is load-bearing.  In plain CW
   // ^D does not stop the keyer: with the RX gone, NY4I's next function key no
   // longer interrupted at all -- the new message simply queued behind the
   // running one and played after it finished.  Restored.
   //
   // So both halves are now known from the bench, and they conflict:
   //   - RX stops the transmission (required), AND
   //   - RX opens a window in which a SHORT following message never keys.
   // '?' was silent every time behind an abort; a 12-character message survived
   // the same 1-2 ms gap.  Padding cannot rescue it, because under P1=blank the
   // K3 TRIMS the trailing fill instead of keying it -- the very property that
   // makes the pad inaudible -- so a padded '?' is still one character when the
   // radio decides what to key.
   //
   // Hence the settle delay: let the RX transition complete before the caller
   // sends the next KY.  It costs latency ONLY on the interrupt path (a flush
   // with CW actually in progress), which is already the slow path -- the guard
   // in TCWKeyerCAT.Flush means an idle radio never gets here at all.
   Self.SendToRadio('KY ' + Self.CWAbortChar + ';RX;');
   Sleep(CW_ABORT_SETTLE_MS);
end;

procedure TElecraftSerial.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
   Self.SendToRadio(Format('%2s%.11d;',[sCmd,freq]));
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

procedure TElecraftSerial.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeInt: integer;
   dataModeInt: integer;
begin
   modeInt := Self.ModeTypeToInteger(mode, dataModeInt);
   if modeInt > 0 then
      begin
      Self.SendToRadio(vfo, 'MD', IntToStr(modeInt));
      if dataModeInt >= 0 then
         begin
         Self.SendToRadio(vfo, 'DT', IntToStr(dataModeInt));
         end;
      end
   else
      begin
      logger.error('[SetMode] Invalid mode passed Ordinal of mode = %d',[Ord(mode)]);
      Exit;
      end;
end;

function TElecraftSerial.ToggleMode(vfo: TVFO): TRadioMode;
begin
   // Not implemented for the Elecraft serial base; a model may override.
   Result := Self.vfo[vfo].mode;
end;

procedure TElecraftSerial.SetCWSpeed(speed: integer);
begin
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

procedure TElecraftSerial.RITClear(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'RC', '');
end;

procedure TElecraftSerial.XITClear(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'RC', '');
end;

procedure TElecraftSerial.RITBumpDown;
begin
   Self.SendToRadio('RD;');
end;

procedure TElecraftSerial.RITBumpUp;
begin
   Self.SendToRadio('RU;');
end;

procedure TElecraftSerial.RITOn(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'RT', '1');
end;

procedure TElecraftSerial.RITOff(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'RT', '0');
end;

procedure TElecraftSerial.XITOn(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'XT', '1');
end;

procedure TElecraftSerial.XITOff(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO, 'XT', '0');
end;

procedure TElecraftSerial.Split(splitOn: boolean);
begin
   if splitOn then
      begin
      Self.SendToRadio('FT1;');
      end
   else
      begin
      Self.SendToRadio('FT0;');
      end;
end;

procedure TElecraftSerial.SetRITFreq(whichVFO: TVFO; hz: integer);
var s: string;
begin
   if (hz > -10000) and (hz < 10000) then
      begin
      if hz >= 0 then
         begin
         s := '+';
         end
      else
         begin
         s := '-';
         end;
      s := s + Format('%4d',[Abs(hz)]);
      Self.SendToRadio('RO' + s + ';');
      end
   else
      begin
      logger.Error('[SetRITFreq] RIT frequency must be between -9999 and 9999 (%d)',[hz]);
      end;
end;

procedure TElecraftSerial.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SetRITFreq(whichVFO, hz);   // shared RIT/XIT offset register on Elecraft
end;

procedure TElecraftSerial.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var s: string;
begin
   case band of
      rb160m: s := '00';
      rb80m:  s := '01';
      rb60m:  s := '02';
      rb40m:  s := '03';
      rb30m:  s := '04';
      rb20m:  s := '05';
      rb17m:  s := '06';
      rb15m:  s := '07';
      rb12m:  s := '08';
      rb10m:  s := '09';
      rb6m:   s := '10';
   else
      begin
      logger.Error('Invalid band requested %d',[Ord(band)]);
      Exit;
      end;
   end;
   Self.SendToRadio(Format('BN%s;',[s]));
end;

procedure TElecraftSerial.VFOBumpDown(whichVFO: TVFO);
begin
   if whichVFO = nrVFOA then
      begin
      Self.SendToRadio('DN;');
      end
   else if whichVFO = nrVFOB then
      begin
      Self.SendToRadio('DNB;');
      end
   else
      begin
      logger.Warn('[VFOBumpDown] Invalid vfo passed in whichVFO');
      end;
end;

procedure TElecraftSerial.VFOBumpUp(whichVFO: TVFO);
begin
   if whichVFO = nrVFOA then
      begin
      Self.SendToRadio('UP;');
      end
   else if whichVFO = nrVFOB then
      begin
      Self.SendToRadio('UPB;');
      end
   else
      begin
      logger.Warn('[VFOBumpUp] Invalid vfo passed in whichVFO');
      end;
end;

function TElecraftSerial.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
   logger.Warn('ToggleBand not yet implemented');
   Result := rbNone;
end;

procedure TElecraftSerial.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
var filterInt: integer;
begin
   // Convert TRadioFilter enum to Elecraft filter preset (1..5).
   case filter of
      rfNarrow: filterInt := 1;
      rfMid:    filterInt := 3;
      rfWide:   filterInt := 5;
   else
      filterInt := 3;
   end;

   if IntegerBetween(filterInt, 1, 5) then
      begin
      logger.Info('[SetFilter] Setting filter on VFO %s to %d',[VFOToString(vfo),filterInt]);
      if vfo = nrVFOA then
         begin
         Self.SendToRadio(Format('FP%d;',[filterInt]));
         end
      else if vfo = nrVFOB then
         begin
         Self.SendToRadio(Format('FP$%d;',[filterInt]));
         end;
      end
   else
      begin
      logger.error('[SetFilter] filter out of range 1..5 - %d',[filterInt]);
      end;
end;

function TElecraftSerial.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   logger.Warn('SetFilterHz is not yet implemented on the Elecraft serial base');
   Result := 0;
end;

function TElecraftSerial.MemoryKeyer(mem: integer): boolean;
begin
   // K3/KX3 DVK is driven by emulating the front-panel MSG/REC buttons over CAT
   // (SWT<nn>;), matching the legacy K3 path in LOGRADIO.MemoryKeyer.  This is a
   // per-family deviation from the K4's DAMP command.
   // Result True = "error / unsupported" (fail closed).
   Result := True;
   if IntegerBetween(mem, 0, 4) then
      begin
      case mem of
         0: Self.SendToRadio('SWT37;');   // REC/D cancels playback
         1: Self.SendToRadio('SWT21;');
         2: Self.SendToRadio('SWT31;');
         3: Self.SendToRadio('SWT35;');
         4: Self.SendToRadio('SWT39;');
      end;
      Result := False;
      end
   else
      begin
      logger.error('Memory value (%d) out of range for a K3 in MemoryKeyer',[mem]);
      end;
end;

// ---------------------------------------------------------------------------
// IF (Transceiver Information; GET only).  Format (identical to the K3/K4):
// IF[f=11]*****+yyyyrx*00tmvspbd1*;  -- parsed by deleting fixed-width fields
// from the front.  (Ported verbatim from TK4Radio, including its lenient length
// guard, to preserve bench-proven behavior.)
function TElecraftSerial.ParseIFCommand(cmd: string): boolean;
var
   info: TElecraftIF;
   err: TElecraftIFError;
   vfo: TRadioVFO;
begin
   Result := false;

   // Decoding lives in uElecraftIF so the K3 and K4 cannot drift apart again;
   // APPLYING the decoded state stays here, because that is where they legitimately
   // differ (this radio selects between VFOs, the K4 swaps them).
   err := ParseElecraftIF(cmd, info);
   if err <> ifeNone then
      begin
      logger.Error('[ParseIFCommand] %s', [ElecraftIFErrorText(err, cmd)]);
      Exit;
      end;

   // Base setters, not the raw scalars: they also write the per-VFO values the
   // radio window reads.  On a serial Elecraft (AI0 + poll) this IF poll is the
   // ONLY ongoing RIT/XIT source -- writing just the scalar left the window
   // indicator stuck off.
   Self.SetRITOffset(info.RITXITOffsetHz);
   Self.SetXITOffset(Self.localRITOffset);   // shared register on Elecraft
   logger.trace('[ParseIFCommand] RITOffset = %d', [Self.localRITOffset]);

   Self.SetRITOn(info.RITOn);
   Self.SetXITOn(info.XITOn);

   if info.Transmitting then
      begin
      Self.RadioState := rsTransmit;
      end
   else
      begin
      Self.RadioState := rsReceive;
      end;

   Self.SetSplitOn(info.SplitOn);

   // Route to the RX (operating) VFO reported by the IF 'v' field.
   if not info.RXVFOIsB then
      begin
      vfo := Self.vfo[nrVFOA];
      Self.SetActiveVFO(nrVFOA);
      end
   else
      begin
      vfo := Self.vfo[nrVFOB];
      Self.SetActiveVFO(nrVFOB);
      end;

   vfo.frequency := info.FrequencyHz;
   // Serial polling does not deliver BN on a band change, so derive band from
   // frequency here (as every other modern radio class does).
   vfo.band := FreqToRadioBand(info.FrequencyHz);
   vfo.mode := ModeStrToMode(info.ModeChar, info.DataModeChar);
   Result := true;
end;

// Helper: Elecraft MD byte (+ DT sub-mode) -> TRadioMode.
function TElecraftSerial.ModeStrToMode(sMode: string; sDataMode: string): TRadioMode;
var
   problem: string;
begin
   // Mapping lives in uElecraftIF alongside the IF decode -- the K4 had a
   // character-for-character copy of this same case statement.  Logging stays
   // here so each radio still reports in its own category.
   Result := ElecraftModeToRadioMode(sMode, sDataMode, problem);
   if problem <> '' then
      begin
      logger.Error('[ModeStrToMode] %s', [problem]);
      end;
end;

procedure TElecraftSerial.ProcessMsg(msg: string);
begin
   ProcessMessage(msg);   // forward to keep the internal handler name
end;

procedure TElecraftSerial.ProcessMessage(sMessage: string);
var
   sCommand: string;
   sData: string;
   hz: integer;
   i: integer;
   RITSign: integer;
   ritHz: integer;
   sDataMode: string;
   vfo: TRadioVFO;
begin
   // The reading thread hands us one ';'-terminated CAT response at a time, with
   // the ';' stripped.  A "$" in column 3 addresses VFO B.
   logger.Trace('[ProcessMessage] Received from radio: (%s)',[sMessage]);
   UpdateLastValidResponse;  // any message proves the radio is answering
   sCommand := AnsiLeftStr(sMessage,2);
   if AnsiMidStr(sMessage,3,1) = '$' then
      begin
      sData := AnsiMidStr(sMessage,4,length(sMessage));
      vfo := Self.vfo[nrVFOB];
      end
   else
      begin
      sData := AnsiMidStr(sMessage,3,length(sMessage));
      vfo := Self.vfo[nrVFOA];
      end;
   if AnsiRightStr(sData,1) = ';' then      // defensive: strip a stray ';'
      begin
      SetLength(sData,length(sData)-1);
      end;

   Case AnsiIndexText(AnsiUppercase(sCommand), ['AI','BI','BN','DT','FA','FB','FT','IF','KS','MA','MD','RT','RX','TX','XT','RO','FP']) of
      0: begin                                     // AI
         logger.debug('[ProcessMessage] AI command set to %s',[sData]);
         end;
      1: begin                                     // BI
         if sData = '1' then
            begin
            Self.bandIndependence := true;
            end;
         end;
      2: begin                                     // BN
         if Self.BandNumToBand(sData) <> vfo.band then
            begin    // band change -- prime RIT/MD settings for both VFOs
            logger.debug('[ProcessMessage] BN Received %s - re-querying state',[sData]);
            Self.SendToRadio('BN;BN$;MD;MD$;DT;DT$;FA;FB;IF;FP;FP$;');
            end;
         vfo.band := Self.BandNumToBand(sData);
         Self.vfo[nrVFOA].band := Self.BandNumToBand(sData);
         end;
      3: begin                                     // DT
         // DT updates only the remembered data sub-mode; do NOT overwrite mode.
         sDataMode := AnsiLeftStr(sData,1);
         case StrToIntDef(sDataMode,-9) of
            0: vfo.datamode := rmData;
            1: vfo.datamode := rmAFSK;
            2: vfo.datamode := rmFSK;
            3: vfo.datamode := rmPSK;
            -9:logger.error('[ProcessMessage] Non-numeric passed with DT command (%s)',[sData]);
            end;
         if vfo.mode in [rmData, rmDataRev, rmFSK, rmFSKRev, rmPSK, rmPSKRev, rmAFSK, rmAFSKRev] then
            begin
            vfo.mode := vfo.datamode;
            end;
         end;
      4: begin                                     // FA
         hz := StrToIntDef(AnsiLeftStr(sData,11),-9);
         if hz >= 0 then
            begin
            Self.vfo[nrVFOA].frequency := hz;
            Self.vfo[nrVFOA].band := FreqToRadioBand(hz);
            end
         else
            begin
            logger.error('[ProcessMessage] non-numeric passed in sData with FA command (%s)',[AnsiLeftStr(sData,11)]);
            end;
         end;
      5: begin                                     // FB
         hz := StrToIntDef(AnsiLeftStr(sData,11),-9);
         if hz >= 0 then
            begin
            Self.vfo[nrVFOB].frequency := hz;
            Self.vfo[nrVFOB].band := FreqToRadioBand(hz);
            end
         else
            begin
            logger.error('[ProcessMessage] non-numeric passed in sData with FB command (%s)',[AnsiLeftStr(sData,11)]);
            end;
         end;
      6: begin                                     // FT
         Self.SetSplitOn(AnsiLeftStr(sData,1) = '1');
         logger.trace('[ProcessMessage] FT (Split) = %s',[AnsiLeftStr(sData,1)]);
         end;
      7: begin                                     // IF
         Self.ParseIFCommand(sData);
         end;
      8: begin                                     // KS
         i := StrToIntDef(AnsiLeftStr(sData,3),-1);
         if IntegerBetween(i, FCWSpeedMin, FCWSpeedMax) then
            begin
            Self.localCWSpeed := i;
            end
         else
            begin
            logger.Warn('[ProcessMessage] CW speed out of range in KS command (%s)',[AnsiLeftStr(sData,3)]);
            end;
         end;
      9: begin                                     // MA
         end;
      10:begin                                     // MD
         // DATA (6) sub-mode arrives separately via DT; use the known datamode.
         if AnsiLeftStr(sData,1) = '6' then
            begin
            vfo.mode := vfo.datamode;
            end
         else
            begin
            vfo.mode := Self.ModeStrToMode(AnsiLeftStr(sData,1),' ');
            end;
         end;
      11:begin                                     // RT
         Self.SetRITOn(AnsiLeftStr(sData,1) = '1');   // per-radio; write every VFO copy the window reads
         end;
      12:Self.radioState := rsReceive;             // RX
      13:Self.radioState := rsTransmit;            // TX
      14:begin                                     // XT
         Self.SetXITOn(AnsiLeftStr(sData,1) = '1');   // per-radio; write every VFO copy the window reads
         end;
      15:begin                                     // RO
         RITSign := IfThen(AnsiLeftStr(sData,1) = '-',-1,1);
         ritHz := StrToIntDef(AnsiMidStr(sData,2,4),99999);
         if ritHz = 99999 then
            begin
            ritHz := 0;
            logger.error('[ProcessMessage] Invalid value passed in RO command: %s',[sData]);
            end
         else
            begin
            ritHz := ritHz * ritSign;
            Self.SetRITOffset(ritHz);   // per-radio; write every VFO copy the window reads
            Self.SetXITOffset(ritHz);
            end;
         end;
      16:begin                                     // FP
         i := StrToIntDef(AnsiLeftStr(sData,1),-1);
         if i <> -1 then
            begin
            vfo.filter := i;
            end
         else
            begin
            logger.error('[ProcessMessage] For FP command, invalid value in sData (%s)',[sData]);
            end;
         end;
   end; // of case
   if firstProcessMessage then
      begin
      firstProcessMessage := false;
      Initialize;
      end;
end;

function TElecraftSerial.BandNumToBand(sBand: string): TRadioBand;
var iBand: integer;
begin
   iBand := StrToIntDef(sBand,-9);
   case iBand of
      0: Result := rb160m;
      1: Result := rb80m;
      2: Result := rb60m;
      3: Result := rb40m;
      4: Result := rb30m;
      5: Result := rb20m;
      6: Result := rb17m;
      7: Result := rb15m;
      8: Result := rb12m;
      9: Result := rb10m;
      10:Result := rb6m;
      -9:begin
         logger.Error('[BandNumToBand] Invalid band requested (non-numeric): %s',[sBand]);
         Result := rbNone;
         end;
   else
      begin
      logger.Error('[BandNumToBand] Unhandled band value: %d (from string: %s)',[iBand, sBand]);
      Result := rbNone;
      end;
   end;
end;

procedure TElecraftSerial.PollRadioState;
begin
   // Serial poll: IF gives VFO A freq+mode+RIT/XIT/split/TX and the operating
   // VFO; FB/MD$/DT$ give VFO B's freq/mode/sub-mode via the "$" suffix.  This is
   // also the keep-alive that lets the factory serial path recover a power-cycle.
   Self.SendToRadio('IF;FB;MD$;DT$;');
end;

procedure TElecraftSerial.SetAIMode(i: integer);
begin
   Self.SendToRadio(Format('AI%d;',[i]));
end;

procedure TElecraftSerial.Initialize;
begin
   // rigLabel is set by LOGRADIO after creation -- re-key the logger so every
   // line is radio-identified.
   if Self.rigLabel <> '' then
      begin
      logger := TLogLogger.GetLogger('TR4WDebugLog.Elecraft-' + Self.rigLabel);
      end
   else
      begin
      logger := TLogLogger.GetLogger('TR4WDebugLog.ElecraftSerial');
      end;

   Self.SetAIMode(0);   // serial: poll, do not push
   logger.debug('[Initialize] Querying full state (KS;BN;RT;XT;RO;FT;MD;DT;IF;FP; + $ VFO B)');
   Self.SendToRadio('KS;BN;RT;XT;RO;FT;MD;DT;IF;FP;');
   Self.SendToRadio('BN$;RT$;XT$;RO$;MD$;DT$;IF$;FP$;');
end;

// VFO-addressed send: "$" selects VFO B.
procedure TElecraftSerial.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   if whichVFO = nrVFOB then
      begin
      Inherited SendToRadio(Format('%s$%s;',[sCmd,sData]));
      end
   else if whichVFO = nrVFOA then
      begin
      Inherited SendToRadio(Format('%s%s;',[sCmd,sData]));
      end
   else
      begin
      logger.error('[SendToRadio] Invalid VFO passed for command %s - data = %s',[sCmd, sData]);
      end;
end;

function TElecraftSerial.ModeTypeToInteger(mode: TRadioMode; var dataModeInt: integer): integer;
begin
   Result := -1;
   dataModeInt := -1;   // -1 so we do not mislead the caller (DATA A is 0)
   case mode of
      rmNone: Result := 0;
      rmCW: Result := 3;
      rmCWRev: Result := 7;
      rmLSB: Result := 1;
      rmUSB: Result := 2;
      rmFM: Result := 4;
      rmAM: Result := 5;
      rmData:
         begin
         Result := 6;
         dataModeInt := 0;
         end;
      rmDataRev:
         begin
         Result := 9;
         dataModeInt := 0;
         end;
      rmFSK:
         begin
         Result := 6;
         dataModeInt := 2;
         end;
      rmFSKRev:
         begin
         Result := 6;
         dataModeInt := 2;
         end;
      rmPSK:
         begin
         Result := 6;
         dataModeInt := 3;
         end;
      rmPSKRev:
         begin
         Result := 9;
         dataModeInt := 3;
         end;
      rmAFSK:
         begin
         Result := 6;
         dataModeInt := 1;
         end;
      rmAFSKRev:
         begin
         Result := 9;
         dataModeInt := 1;
         end;
      end;
end;

end.
