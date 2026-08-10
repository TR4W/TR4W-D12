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

uses Windows, uFactoryRadioBase, uRadioKYBase, uRadioElecraftBase,
     uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uCWFraming,
     uElecraftIF;   // shared IF decode -- the K4 uses the same one

type
  TElecraftSerial = class(TElecraftRadio)
  protected
    firstProcessMessage: boolean;
    FCWSpeedMin: integer;   // KS range; K3/KX3 keyer is 8..50 wpm (per-model overridable)
    FCWSpeedMax: integer;
    function  ModeTypeToInteger(mode: TRadioMode; var dataModeInt: integer): integer;
    procedure Initialize;
    procedure SetAIMode(i: integer);
    // Set by LOGRADIO from the radio library at setup.  0 = off, which is
    // the historic behaviour: poll for everything.
    procedure ApplyAutoInfoLevel(level: integer); override;
    // Puts auto-info back to 0 on the way out -- see the implementation.
    procedure Disconnect; override;
  private
    FAutoInfoLevel: integer;
  public
    // READ-ONLY, so the resolved level can be asserted without a radio.  The
    // default is decided in ApplyAutoInfoLevel rather than in a table, which
    // makes it exactly the kind of silently-defaulted value that reads as a
    // legal zero if it ever regresses.  Write access stays with the applier.
    property AutoInfoLevel: integer read FAutoInfoLevel;

    constructor Create; reintroduce;

    function  Connect: integer; override;
    procedure ProcessMsg(msg: string); override;
    procedure ProcessMessage(sMessage: string);
    procedure PollRadioState; override;

    procedure Transmit; override;
    procedure Receive; override;
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

   // ---- CW-by-CAT framing (was uCWFraming's `K3, KX3, K4:` arm) ------------
   // A short KY fails on the K3/KX3 ONLY when it follows the keyer abort TR4W
   // sends before every message ('KY <04>;RX;', from StopCW): the abort/RX
   // transition swallows a short following message, while >= 8 chars survives
   // it.  (tr4w.log 2026-06-18: 'KY AGN4567;' silent, 'KY AGN45678;' keys; a
   // standalone 'KY ?;' from the K3 utility keys fine -- so this is the ABORT
   // WINDOW, not a radio length floor.)  Padding to maxLen gives every message
   // enough runway to survive the abort; under P1=space the radio trims the
   // trailing fill instead of keying it.  The K2 overrides pad -- see TK2Radio.
   FCapabilities.CWFrame := CWFrameRule(22, True);

   // DELIBERATE DIVERGENCE FROM LEGACY, carried over from uCWFraming: LOGRADIO
   // tested `RadioModel in [K2, K3, K4]`, omitting the KX3, so a KX3 was given
   // the KENWOOD spellings and keyed the wrong characters for AR, SK, BT and
   // SN.  The KX3 shares the K3's CAT command set and is a TElecraftSerial, so
   // it now inherits the Elecraft dialect here -- the omission was a gap, not a
   // decision.  Still unverified on hardware; NY4I has no KX3.
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
      Self.SetAIMode(FAutoInfoLevel);
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
   // K3 DVK is driven by emulating the front-panel MSG/REC buttons over CAT
   // (SWT<nn>;), matching the legacy K3 path in LOGRADIO.MemoryKeyer.  This is a
   // per-family deviation from the K4's DAMP command.
   // NOT the KX3: it has no DVK and none of these front-panel buttons, so it
   // does not declare rcPlayDVK and never reaches here.
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
// Helper: Elecraft MD byte (+ DT sub-mode) -> TRadioMode.
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

   Case AnsiIndexText(AnsiUppercase(sCommand), ['AI','BI','BN','DT','FA','FB','FT','IF','KS','MA','MD','RT','RX','TX','XT','RO','FP','FR']) of
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

procedure TElecraftSerial.PollRadioState;
begin
   // Serial poll: IF gives VFO A freq+mode+RIT/XIT/split/TX and the operating
   // VFO; FB/MD$/DT$ give VFO B's freq/mode/sub-mode via the "$" suffix.  This is
   // also the keep-alive that lets the factory serial path recover a power-cycle.
   //
   // A REDUCED POLL DURING TRANSMIT WAS TRIED AND REVERTED (NY4I, 2026-08-09).
   // Sending only 'IF;' while transmitting cut the traffic that delays the
   // RX; ending the transmission, and it was wrong: the premise was that
   // nothing observable can change mid-transmission, and the operator can
   // change VFO B on the radio while it is transmitting.  A poll that cannot
   // see that is a display showing a frequency the radio is not on.
   //
   // The latency it bought is not worth buying this way.  The backlog it was
   // treating is addressed properly by flow control in the poll loop -- see
   // TFactoryRadioBase.PollOutstanding -- which slows the poll only when the
   // radio has not answered, rather than deciding in advance what the
   // operator is allowed to change.
   //
   // If this is revisited, 'IF;FB;' is the shape to consider: MD$/DT$ are the
   // two that plausibly cannot change mid-transmission.  That is a question
   // for someone who programs rigs, not an assumption to make here.
   //
   // WITH AUTO-INFO ON, ASK FOR ONE THING.  AI2 pushes FA/FB/FR/FT/IF/MD/DT
   // whenever the operator changes them -- every piece of state this poll
   // existed to fetch -- but it NEVER reports a T/R transition (confirmed on
   // NY4I's K3S: keying and unkeying from the front panel produced no
   // message at all, while the VFO, mode and filter changes all did).  So
   // transmit state is the one thing that still has to be asked for.
   //
   // IF rather than TQ, although TQ is four bytes against thirty-seven.
   // Bytes are not the constraint -- command COUNT is, and both are one
   // command -- and IF doubles as a re-sync, so a push lost to a buffer
   // overrun or a reconnect cannot leave the display stale indefinitely.
   // TQ also reports pseudo-transmit (TX TEST, CW pre-arm) as transmitting,
   // which would misreport CW keying.
   //
   // Coupled deliberately: the poll may only be cut BECAUSE auto-info is
   // supplying the rest.  Turning AI off must restore the full poll, or the
   // display silently stops tracking VFO B.
   if FAutoInfoLevel > 0 then
      begin
      Self.SendToRadio('IF;');
      end
   else
      begin
      Self.SendToRadio('IF;FB;MD$;DT$;');
      end;
end;

procedure TElecraftSerial.Disconnect;
begin
   // LEAVE THE RADIO AS WE FOUND IT.
   //
   // Auto-info is a setting we make ON THE RADIO, and it outlives us: the rig
   // keeps pushing after TR4W closes the port.  Whatever opens it next -- the
   // next TR4W run, WSJT-X in CAT mode, a terminal -- then meets a radio
   // talking unprompted, and a program that cannot tell an unsolicited push
   // from its own reply will mis-pace itself badly.  That is not theoretical:
   // it wrecked a bench measurement here, where a paced IF; poll collapsed
   // from ~100 ms to 2953 ms purely because the K3 was still in AI2 from a
   // previous TR4W session (NY4I, 2026-08-09).
   //
   // Best effort, and quiet about failing: by the time this runs the radio may
   // already be gone, which is not worth an error on the way out.
   if FAutoInfoLevel > 0 then
      begin
      try
         logger.Debug('[Disconnect] restoring auto-info to 0');
         Self.SetAIMode(0);
      except
         // The port may already be closed.  Nothing to do and nothing to say.
      end;
      end;
   inherited Disconnect;
end;

procedure TElecraftSerial.ApplyAutoInfoLevel(level: integer);
begin
   // A NEGATIVE LEVEL MEANS "YOU DECIDE", AND THIS FAMILY SAYS 2.
   //
   // AI2 is the right default for every Elecraft in this family -- K2, K3,
   // KX3, and a KX2 when it is added, which shares the KX3 command set
   // (NY4I).  Measured on a K3S: the radio pushes FA/FB/FR/FT/IF/MD/DT on
   // every change, including VFO B DURING A TRANSMISSION, so the poll drops
   // to one command and an unkey falls from ~500-1100 ms to 221 ms.
   //
   // Deciding it HERE rather than in a table is what makes that true for a
   // model nobody has written yet: a new thin subclass inherits the default
   // with no list to remember to update.  Zero remains the operator saying
   // OFF, which is a different answer from not having chosen.
   if level < 0 then
      begin
      FAutoInfoLevel := 2;
      end
   else
      begin
      FAutoInfoLevel := level;
      end;

   // Stored, not sent: Initialize and the extended-mode setup both send it,
   // and they run at the right point in the connect sequence.  Sending here
   // would race a port that may not be open yet.
   logger.Debug('[ApplyAutoInfoLevel] requested %d -> auto-info %d%s',
      [level, FAutoInfoLevel,
       IfThen(FAutoInfoLevel > 0, ' -- polling reduced to IF;', ' -- full poll')]);
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

   // 0 keeps the historic poll-for-everything behaviour.  At 2 the radio
   // pushes state and PollRadioState drops to a single command, which is
   // what makes an unkey fast -- see ApplyAutoInfoLevel.
   Self.SetAIMode(FAutoInfoLevel);
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
