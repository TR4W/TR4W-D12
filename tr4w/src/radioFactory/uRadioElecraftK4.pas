{
 Copyright Thomas M. Schaefer, NY4I (c) 2024, 2025, 2026.
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
unit uRadioElecraftK4;

interface
uses
   uRadioElecraftBase, uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uRadioRegistry, uCWFraming,
     uElecraftIF;   // shared IF decode -- the K3 uses the same one


Type TK4Radio = class(TElecraftRadio)
   private
      firstProcessMessage: boolean;
   protected
      procedure SelectOperatingVFO(rxVFOIsB: boolean); override;
   private
      //procedure ProcessMessage(sMessage: string);
      procedure Initialize;
      function ModeTypeToInteger(mode: TRadioMode; var dataModeInt: integer): integer;
      //function IsDataMode(mode: TRadioMode): boolean;

   public
      Constructor Create;
      function Connect: integer; override;
      procedure Transmit; override;
      procedure Receive; override;
      procedure ProcessMsg(msg: string); override;
      procedure StopCW; override;
      function CWIsFactoryOwned: Boolean; override;   // The K4 keys CW itself: StopCW sends Chr(4)+";RX;".

      // Base class overrides with VFO parameters
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

      // K4-specific methods
      procedure PollRadioState; override;
      procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload;
      procedure ProcessMessage(sMessage: string);
      procedure SetAIMode(i: integer);
end;

implementation

// NO 'uses MainUnit' HERE.  Every logger.* call in this unit resolves to the
// `logger` FIELD on TFactoryRadioBase, set per radio in SetRadioModel so the
// category name carries the rig label -- it never referred to MainUnit's global
// at all, and the clause was vestigial.
//
// It was not harmless.  With this clause present, dcc32 died compiling this very
// line and no cold build of TR4W would complete:
//   uRadioElecraftK4.pas(78) F2084 Internal Error: AV62D16BA3(62CB0000)
// Incremental builds hid it because this unit's .dcu already existed.
//
// BE PRECISE ABOUT THE CAUSE.  Removing this one clause did fix the build --
// but re-adding it afterwards, once the other seven radioFactory units had also
// stopped naming MainUnit, compiles cleanly.  So the internal error is a
// compiler bug sensitive to the SHAPE OF THE WHOLE UNIT GRAPH, not to this line
// in isolation.  What makes it stay fixed is that the factory as a whole no
// longer drags the main window in.  That also costs ~60s less on a cold build.
//
// The practical rule stands: a radio has its own logger, so do not reach for
// MainUnit here.  If an internal error ever reappears, suspect the graph, and
// remember the IDE reports it in seconds where msbuild hangs silently.

Constructor TK4Radio.Create;
begin
   inherited Create(ProcessMessage);

   // Generic logger until rigLabel is set by LOGRADIO after creation

   firstProcessMessage := true;  // Call Initialize on first message received
   // K4 supports auto-info mode - no polling needed
   requiresPolling := False;
   autoUpdateCommand := 'AI5;';     // Enable auto-info mode level 5
   pollingInterval := 0;            // Not used for K4

   // INTENTIONALLY True (the base default, stated here so it is not mistaken for
   // an oversight).  On serial this radio polls 'IF;FB;' -- a direct frequency
   // read -- which is exactly the case FREQUENCY POLL RATE exists to control, so
   // uRadioPolling SHOULD overwrite pollingInterval with the user's setting.
   // Contrast the Icom, Flex and TS-890, which set it False because their poll
   // is a heavy state query or a keepalive rather than a frequency read.
   honorsFreqPollRate := True;
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
   // ---- CW-by-CAT framing --------------------------------------------------
   // Same 22-and-pad rule as the serial Elecrafts: a short KY is swallowed when
   // it follows the keyer abort TR4W sends before every message, and padding
   // gives it enough runway to survive that window (the radio trims the fill
   // rather than keying it).  Stated here rather than inherited because the K4
   // is deliberately NOT a TElecraftSerial -- it is a network+serial radio with
   // an AI push model (see this unit's header).
   FCapabilities.CWFrame := CWFrameRule(22, True);
end;

function TK4Radio.Connect: integer;
begin
   Self.readTerminator := ';';
   Result := Inherited Connect;
   if Self.IsConnected then
      begin
      if Self.serialPort <> NoPort then
         begin
         // Serial: disable AI to avoid flooding the serial port.
         // Use periodic polling instead (same approach as legacy K3 code).
         Self.SetAIMode(0);
         Self.requiresPolling := True;
         Self.pollingInterval  := 100; // Default; overridden by FREQUENCY POLL RATE in pFactoryRadio
         end
      else
         begin
         // Network: AI5 pushes state changes -- no polling needed for
         // state.  But the K4 server drops clients that send nothing
         // for 10 seconds (per K4 Programmer's Reference, PING/PONG
         // section -- Issue #897).  Enable a 1 Hz poll that sends
         // PING; as a keep-alive.  ProcessMessage handles the PONG;
         // response explicitly (case 17, 'PO') and at the top calls
         // UpdateLastValidResponse, refreshing the inbound watchdog.
         Self.SetAIMode(5);
         Self.requiresPolling := True;
         Self.pollingInterval := 1000; // 1 Hz keep-alive ping
         end;
      Self.SendToRadio('RT;XT;RO;FT;ID;MD;DT$;IF;');
      Self.SendToRadio('RT$;XT$;RO$;MD$;DT$;IF$;');
      end;
end;
procedure TK4Radio.Transmit;
begin
   Self.SendToRadio('TX;');
end;

procedure TK4Radio.Receive;
begin
   Self.SendToRadio('RX;');
end;

function TK4Radio.CWIsFactoryOwned: Boolean;
begin
   // The K4 keys CW itself: StopCW sends Chr(4)+";RX;".
   Result := True;
end;

procedure TK4Radio.StopCW;
begin
   // The 'KY ' PREFIX IS REQUIRED and was MISSING here: this sent a bare
   // Chr(4)+';RX;', which is not a command the radio recognises.  The abort is a
   // KY command carrying the abort character.  LOGRADIO's legacy arm -- the
   // authority -- sends the same bytes for K3, KX3 and K4 alike, and the wire
   // form is bench-confirmed on a K3 (tr4w.log 2026-07-31):
   //     KY <04> ; R X ;   ->  4B 59 20 04 3B 52 58 3B
   // Never noticed because Escape was only ever tested on the K3, which is not
   // CWIsFactoryOwned and therefore took the legacy path instead of this one.
   Self.SendToRadio('KY ' + Chr(4) + ';RX;');
end;



procedure TK4Radio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
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
      Self.SetMode(mode, vfo);
end;

procedure TK4Radio.SetMode(mode:TRadioMode; vfo: TVFO = nrVFOA);
var
  // sMode: string;
   modeInt: integer;
   dataModeInt: integer;
  // isData: boolean;

begin
   modeInt := Self.ModeTypeToInteger(mode,dataModeInt);
   if modeInt > 0 then
      begin
      Self.SendToRadio(vfo,'MD',IntToStr(modeInt));
      if dataModeInt >= 0 then
         begin
         Self.SendToRadio(vfo,'DT',IntToStr(dataModeInt));
         end;
      end
   else
      begin
      logger.error('[SetMode] Invalid mode passed Ordinal of mode = %d',[Ord(mode)]);
      Exit;
      end;
end;

function TK4Radio.ToggleMode(vfo: TVFO): TRadioMode;
begin
   // TODO: Implement mode toggling for K4
   Result := rmNone;
end;

procedure TK4Radio.SetCWSpeed(speed: integer);
begin
   if IntegerBetween(speed,8,100) then
      begin
      Self.localCWSpeed := speed;
      Self.SendToRadio(Format('KS%3d;',[speed]));
      end
   else
      begin
      logger.Error ('K4 supports a CW speed of 8 wpm to 100 wpm');
      end;
end;

procedure TK4Radio.RITClear(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'RC','');
end;

procedure TK4Radio.XITClear(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'RC','');
end;

procedure TK4Radio.RITBumpDown;
begin
   Self.SendToRadio('RD;');
end;

procedure TK4Radio.RITBumpUp;
begin
   Self.SendToRadio('RU;');
end;

procedure TK4Radio.RITOn (whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'RT','1');
end;

procedure TK4Radio.RITOff (whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'RT','0');
end;

procedure TK4Radio.XITOn(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'XT','1');
end;

procedure TK4Radio.XITOff(whichVFO: TVFO);
begin
   Self.SendToRadio(whichVFO,'XT','0');
end;

procedure TK4Radio.Split(splitOn: boolean);
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
procedure TK4Radio.SetRITFreq(whichVFO: TVFO; hz: integer);
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

procedure TK4Radio.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SetRITFreq(whichVFO, hz); // Same on K4
end;

procedure TK4Radio.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var s: string;
begin

   case band of
      rb160m: s := '00';
      rb80m: s := '01';
      rb60m: s := '02';
      rb40m: s := '03';
      rb30m: s := '04';
      rb20m: s := '05';
      rb17m: s := '06';
      rb15m: s := '07';
      rb12m: s := '08';
      rb10m: s := '09';
      rb6m:  s := '10';
   else
      begin
      logger.Error('Invalid band requested %d',[Ord(band)]);
      Exit;
      end;
   end;
   Self.SendToRadio(Format('BN%2d;',[Ord(band)]));
end;

procedure TK4Radio.VFOBumpDown(whichVFO: TVFO);
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
      logger.Warn('[TK4Radio.VFOBumpDown] Invalid vfo passed in whichVFO');
      end;
end;

procedure TK4Radio.VFOBumpUp(whichVFO: TVFO);
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
      logger.Warn('[TK4Radio.VFOBumpUp] Invalid vfo passed in whichVFO');
      end;
end;

function  TK4Radio.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
//var newBand: TRadioBand;
begin
   //newBand := Self.priorBand;
   //Self.priorBand := Self.band;
   //Self.SetBand(newBand, vfo);
   //Result := newBand;
   logger.Warn('ToggleBand not yet implemented');
   Result := rbNone;
end;

procedure TK4Radio.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
var filterInt: integer;
begin
   // Convert TRadioFilter enum to K4 filter number (1-5)
   case filter of
      rfNarrow: filterInt := 1;
      rfMid:    filterInt := 3;
      rfWide:   filterInt := 5;
   else
      filterInt := 3;  // Default to middle filter
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

function  TK4Radio.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   logger.Warn('SetFilterHz is not yet implemented on the K4');
   Result := 0;
end;

function TK4Radio.MemoryKeyer(mem: integer): boolean;
begin
   Result := true; // True is an error...default to that value to fail closed
   if mem = 0 then
      begin
      logger.debug('[K4-MemoryKeyer] Stopping DVK');
      Self.SendToRadio('DA0;');  // DA0; Stops all DVK activity
      Result := false;
      end
   else if IntegerBetween(mem,1,8) then
      begin
      logger.debug('[K4-MemoryKeyer] Playing memory %d',[mem]);
      Self.SendToRadio(Format('DAMP%d00000;',[mem]));  // DAMPmnnnnn; where m is mem number and nnnnn is repeat in ms (set to 00000)
      Result := false;
      end
   else
      begin
      logger.error('Memory value (%d) out of range for a K4 in MemoryKeyer',[mem]);
      Result := true;
      end;
end;

{
Type TRadioMode = (rmNone,rmCW, rmCWRev, rmLSB, rmUSB, rmFM, rmAM,
                   rmData, rmDataRev, rmFSK, rmFSKRev, rmPSK, rmPSKRev,
                   rmAFSK, rmAFSKRev);
                   }

// Helper functions
procedure TK4Radio.ProcessMsg(msg: string);
begin
   // Forward to ProcessMessage to maintain compatibility
   ProcessMessage(msg);
end;

procedure TK4Radio.ProcessMessage(sMessage: string);
var
   sCommand: string;
   sData: string;
  // sMode: string;
   hz: integer;
   i: integer;
   RITSign: integer;
   ritHz : integer;
   sDataMode: string;
   vfo: TRadioVFO;
   vfoBCommand: boolean;
begin
// This is called by the process that receives data on the socket - Event
// K4 messages are seperated by semi-colons (;) but each message should not have the ; as that is the ReadLn delimiter.
// This is a command that has been parsed into its parts. For example, if the radio
// sends RX;DT5;, this procedure is called once with RX; and once with DT5;
   logger.Trace('[ProcessMessage] Received from radio: (%s)',[sMessage]);
   UpdateLastValidResponse;  // Any message from the radio means it's connected
   sCommand := AnsiLeftStr(sMessage,2);
   if AnsiMidStr(sMessage,3,1) = '$' then
      begin
      logger.trace('[ProcessMessage] VFO B message received %s',[sMessage]);
      vfoBCommand := true;
      sData := AnsiMidStr(sMessage,4,length(sMessage));
      vfo := Self.vfo[nrVFOB];
      end
   else
      begin
      logger.trace('[ProcessMessage] VFO A message received %s',[sMessage]);
      vfoBCommand := false;
      sData := AnsiMidStr(sMessage,3,length(sMessage));
      vfo := Self.vfo[nrVFOA];
      end;
   if AnsiRightStr(sData,1) = ';' then      // Remove ; at end.
      begin
      SetLength(sData,length(sData)-1);
      end;

   Case AnsiIndexText(AnsiUppercase(sCommand), ['AI','BI','BN','DT','FA','FB','FT','IF','KS','MA','MD','RT','RX','TX','XT','RO','FP','PO']) of
      0: begin                                     // AI
         logger.debug('[ProcessMessage] AI command set to %s',[sData]);
         end;
      1: begin            // BI
         if sData = '1' then
            begin
            Self.bandIndependence := true;
            end;
         end;
      2: begin              // BN
         if Self.BandNumToBand(sData) <> vfo.band then
            begin    // band change so prime RIT, MD settings
            logger.debug('[TK4Radio.ProcessMessage] BN Received %s - Sending BN;BN$;MD;MD$;DT;DT$;FA;FB;IF;IF$;FP;FP$; to radio',[sData]);
            Self.SendToRadio('BN;BN$;MD;MD$;DT;DT$;FA;FB;IF;IF$;FP;FP$;');
            end;
         vfo.band := Self.BandNumToBand(sData);   // if I just set this, then CurrentStatus.band does not get set. It requires the next line to show up upon resetting the ports.
         Self.vfo[nrVFOA].band := Self.BandNumToBand(sData);     // These two things should be the same.
         logger.trace('[ProcessMessage] Received band number of %s',[sData]);
         end;
      3: begin             // DT
         // DT updates only the remembered data sub-mode.
         // The K4 sends DT responses even when in SSB/CW — the sub-mode register persists.
         // vfo.mode must NOT be set here; doing so would overwrite a valid SSB/CW mode.
         // The MD handler already applies vfo.datamode → vfo.mode when MD=6 arrives.
         sDataMode := AnsiLeftStr(sData,1);
         case StrToIntDef(sDataMode,-9) of
            0: vfo.datamode := rmData;
            1: vfo.datamode := rmAFSK;
            2: vfo.datamode := rmFSK;
            3: vfo.datamode := rmPSK;
            -9:logger.error('[ProcessMessage] Non-numeric passed with DT command (%s)',[sData]);
            end;
         // If currently in a data mode, sync vfo.mode with the new sub-mode.
         if vfo.mode in [rmData, rmDataRev, rmFSK, rmFSKRev, rmPSK, rmPSKRev, rmAFSK, rmAFSKRev] then
            vfo.mode := vfo.datamode;
         end;
      4: begin             // FA
         hz := StrToIntDef(AnsiLeftStr(sData,11),-9);
         if hz >= 0 then
            begin
            Self.vfo[nrVFOA].frequency := hz;
            Self.vfo[nrVFOA].band := FreqToRadioBand(hz);   // keep band in sync with frequency (see ParseIFCommand note)
            end
         else
            begin
            logger.error('[ProcessMessage] non-numeric passed in sData with FA command (%s)',[AnsiLeftStr(sData,11)]);
            end;
         end;
      5: begin             // FB
         hz := StrToIntDef(AnsiLeftStr(sData,11),-9);
         if hz >= 0 then
            begin
            Self.vfo[nrVFOB].frequency := hz;
            Self.vfo[nrVFOB].band := FreqToRadioBand(hz);   // keep band in sync with frequency (see ParseIFCommand note)
            end
         else
            begin
            logger.error('[ProcessMessage] non-numeric passed in sData with FB command (%s)',[AnsiLeftStr(sData,11)]);
            end;
         end;
      6: begin             // FT
         Self.localSplitEnabled := AnsiLeftStr(sData,1) = '1';
         logger.trace('[ProcessMessage] FT (Split) received - Split is %s - localSplitEnabled = %s',[AnsiLeftStr(sData,1),BoolToString(Self.localSplitEnabled)]);
         end;
      7: begin             // IF
         Self.ParseIFCommand(sData);
         end;
      8: begin             // KS
         logger.debug('Received %s in response to KS command',[sData]);
         i := StrToIntDef(AnsiLeftStr(sData,3),-1);
         if IntegerBetween(i,8,100) then
            begin
            Self.localCWSpeed := i;
            end
         else
            begin
            logger.Warn('[ProcessMessage] Invalid CW speed received in KS command (%s)',[AnsiLeftStr(sData,3)]);
            end;
         end;
      9: begin             // MA
         end;
      10:begin             // MD
         // For DATA mode (6), the sub-mode comes separately via DT response.
         // Use the already-known vfo.datamode to avoid a spurious ModeStrToMode error.
         if AnsiLeftStr(sData,1) = '6' then
            vfo.mode := vfo.datamode
         else
            vfo.mode := Self.ModeStrToMode(AnsiLeftStr(sData,1),' ');
         end;
      11:begin              // RT
         vfo.RITState := AnsiLeftStr(sData,1) = '1';
         //Self.RITState := AnsiLeftStr(sData,1) = '1';
         logger.debug('[ProcessMsg] RIT Enabled is %s',[AnsiLeftStr(sData,1)]);
         end;
      12:Self.radioState := rsReceive; // RX
      13:Self.radioState := rsTransmit; // TX
      14:begin              // XT
         vfo.XITState := AnsiLeftStr(sData,1) = '1';
         //Self.XITState := AnsiLeftStr(sData,1) = '1';
         logger.trace('[ProcessMessage] XIT Enabled is %s',[AnsiLeftStr(sData,1)]);
         end;
      15:begin    // RO
         RITSign := IfThen(AnsiLeftStr(sData,1) = '-',-1,1);
         {if AnsiLeftStr(sData,1) = '-' then
            begin
            RITSign := -1;
            end
         else
            begin
            RITSign := 1;
            end;}
         ritHz := StrToIntDef(AnsiMidStr(sData,2,4),99999);
         if ritHz = 99999 then
            begin
            ritHz := 0;
            logger.error('[ProcessMessage] Invalid value passed in RO command: %s',[sData]);
            end
         else
            begin
            ritHz := ritHz * ritSign;
            vfo.RITOffset := ritHz;
            vfo.XITOffset := ritHz;
            //Self.localRITOffset := ritHz;
            //Self.localXITOffset := ritHz; // Because on K4, this is the same value
            end;

         end;
      16:begin    // FP
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
      17:begin    // PO (response to PING -- the full token is PONG;)
         // The K4 server drops clients that send nothing for 10 s.
         // We send PING; at 1 Hz from PollRadioState in network mode
         // (see Connect's network branch and Issue #897).  PONG; is
         // the documented response.  Nothing to do here: the call to
         // UpdateLastValidResponse at the top of ProcessMessage has
         // already refreshed the inbound watchdog, which is the only
         // state PONG carries.  Explicit case branch (rather than a
         // fall-through) so future maintainers can see that PONG is
         // an expected message and is handled, not ignored by accident.
         logger.Trace('[ProcessMessage] PONG keep-alive response');
         end;
   end; // of case
   if firstProcessMessage then
      begin
      firstProcessMessage := false;
      Initialize;
      end;
end;

procedure TK4Radio.PollRadioState;
begin
   if Self.serialPort <> NoPort then
      begin
      // Serial: poll state (no AI on serial).
      // IF gives VFO A freq + mode + RIT/XIT/split/TX state in one response.
      // FB gives VFO B frequency.
      Self.SendToRadio('IF;FB;');
      end
   else
      begin
      // Network: AI5 already pushes state changes; just keep the
      // connection alive.  PING; is the documented keep-alive
      // command (Issue #897, K4 Programmer's Reference).  The K4
      // server drops clients that go silent for 10 s, so we send
      // PING; at 1 Hz from Connect's pollingInterval.
      Self.SendToRadio('PING;');
      end;
end;

procedure TK4Radio.SetAIMode(i: integer);
begin
   Self.SendToRadio(Format('AI%d;',[i]));
end;

procedure TK4Radio.Initialize;
begin
   // Now rigLabel is set by LOGRADIO — reinitialize logger with the radio's identity.
   // Inherits root appender and format; category name appears in every log line.
   if Self.rigLabel <> '' then
      logger := TLogLogger.GetLogger('TR4WDebugLog.K4-' + Self.rigLabel)
   else
      logger := TLogLogger.GetLogger('TR4WDebugLog.K4-Radio');

   if Self.serialPort <> NoPort then
      Self.SetAIMode(0)   // Serial: polling mode; AI5 would flood the serial port
   else
      Self.SetAIMode(5);
   logger.debug('[TK4Radio.Initialize] Sending KS;BN;RT;XT;RO;FT;ID;MD;DT$;IF;FP; to radio');
   Self.SendToRadio('KS;BN;RT;XT;RO;FT;ID;MD;DT;IF;FP;');
   Self.SendToRadio('BN$;RT$;XT$;RO$;MD$;DT$;IF$;FP$;');
end;

procedure TK4Radio.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
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

function TK4Radio.ModeTypeToInteger(mode: TRadioMode; var dataModeInt: integer): integer; // This converts the class mode to the K4 mode MD command
begin
   Result := -1;
   dataModeInt := -1; // So we do not mislead the caller since DATA A is 0.
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

{
// Not called for some reason - But reserve for future use
function TK4Radio.IsDataMode(mode: TRadioMode): boolean;
begin
   Result := mode in [rmData,rmDataRev];
end;
}


procedure TK4Radio.SelectOperatingVFO(rxVFOIsB: boolean);
begin
   // DELIBERATELY NOTHING.  The K4 uses the SWAP VFO model: A and B exchange
   // contents, so VFO A is always the operating VFO.  Telling it to switch --
   // which is right on a K3 -- would fight the radio.
   //
   // This one override is the entire difference between the K3's handling of an
   // IF response and the K4's; see TElecraftRadio.ParseIFCommand.
end;

initialization
  RegisterRadio(K4,
     function: TFactoryRadioBase begin Result := TK4Radio.Create end,
     'Elecraft K4', [rlSerial, rlNetwork], 9200, True,
     // 1 stop bit: Elecraft serial is 8N1 (NY4I 2026-07-30) -- see uRadioElecraftK2.
     SerialParams(38400, 8, PARITY_NONE, 1)
     ,
     2047
     );


end.
