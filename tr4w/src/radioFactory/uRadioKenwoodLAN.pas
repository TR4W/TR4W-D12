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
 unit uRadioKenwoodLAN;

{
  Kenwood LAN CAT -- the SHARED BASE for the TS-890S and TS-990S.

  Registers NOTHING.  The models live in uRadioKenwoodTS890.pas and
  uRadioKenwoodTS990.pas, each a thin subclass that states its own name and the
  identifier the radio answers to.

  WHY THIS WAS SPLIT OUT.  One class (TKenwoodLAN) previously served BOTH
  radios, with an ExpectedIdent property written by each registration.  NY4I: "One
  radio per class" -- when I look at the project I should see a class for every
  single radio.  A property existing only so one class can impersonate two models
  is the smell that made the case: a TS-990 owner's log said TS-890S, and any
  change to the class silently affected both radios with no signal at the edit
  site.  This is also live, bench-proven code and a plausible template for the
  next network Kenwood, so unlike the frozen historical Yaesus the copy hazard is
  real here.

  Everything in this unit is genuinely shared: the LAN authentication handshake and
  the Kenwood ASCII CAT implementation are identical between the two radios.  Only
  the identifier and the display name differ, and those now live with the models.

  Issue #436. Implements direct TCP/IP control of the TS-890S over its
  built-in LAN port. The wire protocol is the standard Kenwood ASCII CAT
  (semicolon-terminated commands such as FA;, FB;, OM0;, KS;, RC;) wrapped
  in a TCP stream, preceded by a three-step authentication handshake:

      Client                          Radio
      ------                          -----
      ##CN;                  -------->
                             <-------- ##CN1;
      ##ID0<idLen><pwLen><id><pw>; --->
                             <-------- ##ID1;   (auth success)

  After ##ID1; the connection becomes a plain Kenwood CAT byte stream.

  References:
    - Kenwood TS-890S PC Command Reference (Rev. 1)
      https://www.kenwood.com/i/products/info/amateur/pdf/ts890_pc_command_en_rev1.pdf
    - TR4QT TS890Radio C++ implementation
      https://github.com/ny4i/TR4QT/blob/master/docs/kenwood-direct-connection-flow.md

  Credentials (NetworkUsername / NetworkPassword) are set by
  RadioObject.SetUpRadioInterface in LOGRADIO.PAS after the factory
  constructs the instance. If NetworkUsername is empty, the auth
  handshake is skipped (useful for a future simulator path).
}

interface
uses
   uRadioKenwoodBase, uFactoryRadioBase, uRadioBand, StrUtils, SysUtils, Math, TF, Log4D, VC, uRadioRegistry,
     uCWFraming;

type
   TTS890AuthState = (
      ksNone,
      ksWaitingForCN,    // Sent ##CN;, awaiting ##CN1
      ksWaitingForID,    // Sent ##ID0...;, awaiting ##ID1
      ksWaitingForTI,    // legacy/unused: real TS-890 does NOT send ##UE/##TI; auth completes at ##ID1
      ksAuthenticated,   // Auth complete; normal Kenwood CAT
      ksAuthFailed       // Auth was rejected; connection unusable
   );

type TKenwoodLAN = class(TKenwoodProtocolRadio)
   private
      FAuthState: TTS890AuthState;
      FInitialized: Boolean;

      // TX VFO from the last FT reply.  Informational only: on this radio split
      // is its own flag (TB), NOT the FT/FR relationship -- see Split().
      FTxVFO: TVFO;

      procedure SendAuthCredentials;
      procedure SendPostLoginSetup;
      procedure HandleAuthMessage(const sMessage: string);
      procedure InitializeAfterAuth;
      function ModeCharToMode(ch: Char): TRadioMode;
      function ModeToModeChar(mode: TRadioMode): Char;
      procedure ParseFAOrFBResponse(const sMessage: string; whichVFO: TVFO);
      procedure ParseOMResponse(const sMessage: string);
      procedure ParseKSResponse(const sMessage: string);
      procedure ParseTBResponse(const sMessage: string);
      procedure ParseFTResponse(const sMessage: string);
      procedure ParseRTResponse(const sMessage: string);
      procedure ParseXTResponse(const sMessage: string);
      procedure ParseRFResponse(const sMessage: string);
      procedure ParseFRResponse(const sMessage: string);

   protected
      // The identifier this radio answers to on ID; -- ID024 for the TS-890S,
      // ID022 for the TS-990S.  PROTECTED, not private: Delphi's `private` is
      // unit-scoped, so the model subclasses in uRadioKenwoodTS890.pas and
      // uRadioKenwoodTS990.pas could not reach it (E2003).  Each model sets it in
      // its own constructor; this base never learns which radio it is serving.
      FExpectedIdent: string;

   public
      NetworkUsername: ShortString;   // Set by LOGRADIO before Connect; "Admin ID" on the radio
      NetworkPassword: ShortString;   // "Admin Password" on the radio
      // E-2: LOGRADIO used to type-test this class and poke the two fields above.
      procedure ApplyNetworkCredentials(const user, pass: string); override;

      Constructor Create;
      Destructor  Destroy; override;

      function  Connect: integer; override;
      procedure ProcessMessage(sMessage: string);
      procedure ProcessMsg(msg: string); override;

      // Auto-info / polling
      procedure PollRadioState; override;

      // Required abstract overrides
      procedure Transmit; override;
      procedure Receive; override;
      procedure SendCW; override;
      procedure StopCW; override;
      function CWIsFactoryOwned: Boolean; override;   // The LAN Kenwoods key CW themselves over the TCP link.

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
      procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
      procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;

      procedure Split(splitOn: boolean); override;
      procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
      function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
      procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
      function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
      function  MemoryKeyer(mem: integer): boolean; override;
      procedure VFOBumpDown(whichVFO: TVFO); override;
      procedure VFOBumpUp(whichVFO: TVFO); override;
end;

implementation

// No uses clause: the `logger` referred to here is the FIELD on
// TFactoryRadioBase, not MainUnit's global.  See uRadioElecraftK4.

const
   // TS-890 CW speed range per the PC Command Reference (KS command, P1 = 004..060)
   MIN_CW_SPEED = 4;
   MAX_CW_SPEED = 60;

// ============================================================================
// Constructor / Destructor
// ============================================================================

Constructor TKenwoodLAN.Create;
begin
   inherited Create(ProcessMessage);


   FAuthState   := ksNone;
   FInitialized := False;
   // Deliberately EMPTY.  Each MODEL sets the identifier it answers to in its own
   // constructor (TS-890S = ID024, TS-990S = ID022), so this base never has to
   // know which radio it is serving.
   FExpectedIdent := '';
   FTxVFO := nrVFOA;
   CWBuffer     := '';
   NetworkUsername := '';
   NetworkPassword := '';

   // The TS-890 LAN CAT parser rejects a trailing CR/LF (responds '?;') once
   // authenticated, so send bare ';'-terminated commands. (Proven via telnet:
   // the K4 ignores a trailing CR/LF; the TS-890 does not. The default is set
   // in uFactoryRadioBase.Create -- see SendToRadio / bAddTermination.)
   Self.bAddTermination := False;

   // TS-890 uses AI2 for state push, but the LAN protocol REQUIRES
   // periodic traffic from the client. Per the LAN HOWTO:
   //   "The TS-890 will close the TCP connection if it does not receive
   //    any data for 10 seconds. ... send the PS; command every 5 seconds"
   // (This is what Kenwood's own ARCP software does.)
   // So we poll PS; at 5-second intervals purely as a keepalive heartbeat;
   // the response is discarded. Without this, the radio drops us ~10s
   // after auth completes and any AI2 push state stops arriving.
   requiresPolling := True;
   autoUpdateCommand := 'AI2;';
   pollingInterval := 5000;

   // MUST be False, and specifically because pollingInterval above is a
   // KEEPALIVE, not a data poll -- AI2 pushes the actual state.
   //
   // uRadioPolling overwrites pollingInterval with the user's FREQUENCY POLL
   // RATE (default 10ms) for any SERIAL radio that leaves this True.  This radio
   // registers [rlSerial, rlNetwork], so on a COM port the 5-second heartbeat
   // silently became a 10ms one -- 500x the intended rate, sending PS; ~100
   // times a second for a reply that is discarded.  The network path was never
   // affected (the override only applies when serialPort <> NoPort), which is
   // why the LAN bench never showed it.
   honorsFreqPollRate := False;
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
   // ---- CW-by-CAT framing --------------------------------------------------
   // The family rule is the ordinary Kenwood one: KY takes 24 bytes and rejects
   // a short P2 under P1=space, so the last chunk is filled.  This is the
   // TS-990's rule; the TS-890 overrides `pad` -- see TKenwoodTS890Radio.
   FCapabilities.CWFrame := CWFrameRule(24, True);
end;

Destructor TKenwoodLAN.Destroy;
begin
   inherited;
end;

// ============================================================================
// Connect / Auth
// ============================================================================

function TKenwoodLAN.Connect: integer;
begin
   Self.readTerminator := ';';

   // Set initial auth state BEFORE connecting: once bytes start arriving we must
   // already know whether we are in the auth phase.
   //
   // The ##CN;/##ID0...; handshake is a LAN-ONLY login.  A TS-890/TS-990 reached
   // over its serial/USB CAT port has no login at all, so gate on the TRANSPORT
   // and not merely on whether credentials happen to be set -- otherwise an
   // operator who previously used the radio over the network, and still has the
   // Admin ID stored, would connect by serial and sit in ksWaitingForCN waiting
   // for a ##CN1; that a serial radio will never send.
   if (Self.serialPort = NoPort) and (Length(NetworkUsername) > 0) then
      begin
      FAuthState := ksWaitingForCN;
      end
   else
      begin
      FAuthState := ksAuthenticated;
      end;

   Result := Inherited Connect;

   if Self.IsConnected then
      begin
      if FAuthState = ksWaitingForCN then
         begin
         logger.Info('[%s.Connect] TCP connected; starting LAN auth (user=%s)',
                     [Self.rigLabel, NetworkUsername]);
         Self.SendToRadio('##CN;');
         end
      else
         begin
         if Self.serialPort <> NoPort then
            begin
            logger.Info('[%s.Connect] serial connected; no LAN auth on this transport',
                        [Self.rigLabel]);
            end
         else
            begin
            logger.Info('[%s.Connect] TCP connected; no credentials set, skipping auth',
                        [Self.rigLabel]);
            end;
         InitializeAfterAuth;
         end;
      end;
end;

procedure TKenwoodLAN.SendAuthCredentials;
var
   idLen, pwLen: Integer;
   cmd: string;
begin
   idLen := Length(NetworkUsername);
   pwLen := Length(NetworkPassword);

   // Format: ##ID0<idLen:2><pwLen:2><id><pw>;
   // idLen and pwLen are two-digit decimal counts.
   cmd := Format('##ID0%.2d%.2d%s%s;',
                 [idLen, pwLen, string(NetworkUsername), string(NetworkPassword)]);

   FAuthState := ksWaitingForID;
   Self.SendToRadio(cmd);

   // Log the framing without exposing the password.
   logger.Debug('[%s.SendAuthCredentials] Sent ##ID0%.2d%.2d%s******* (pw masked)',
                [Self.rigLabel, idLen, pwLen, string(NetworkUsername)]);
end;

procedure TKenwoodLAN.SendPostLoginSetup;
begin
   // Post-login LAN-session setup the ARCP-890 reference controller sends right
   // after ##ID1; (##VP = version/voice-protocol probe, ##KN = LAN notification
   // channels). Match the reference so the radio keeps the socket open and
   // pushes state over LAN. Responses (##VP0;/##KN21;/##KN02;) are ignored in
   // HandleAuthMessage once authenticated.
   Self.SendToRadio('##VP;');
   Self.SendToRadio('##KN2;');
   Self.SendToRadio('##KN0;');
   logger.Debug('[%s.SendPostLoginSetup] Sent ##VP; ##KN2; ##KN0;', [Self.rigLabel]);
end;

procedure TKenwoodLAN.HandleAuthMessage(const sMessage: string);
begin
   if FAuthState = ksWaitingForCN then
      begin
      if AnsiStartsStr('##CN1', sMessage) then
         begin
         logger.Debug('[%s.HandleAuthMessage] Received ##CN1; sending credentials',
                      [Self.rigLabel]);
         SendAuthCredentials;
         end
      else
         begin
         logger.Warn('[%s.HandleAuthMessage] Unexpected response while waiting for ##CN1: %s',
                     [Self.rigLabel, sMessage]);
         end;
      Exit;
      end;

   if FAuthState = ksWaitingForID then
      begin
      if AnsiStartsStr('##ID1', sMessage) then
         begin
         // ##ID1; = auth success. Real-hardware capture (Kenwood ARCP-890 vs a
         // TS-890S) shows the radio does NOT send ##UE/##TI here -- the
         // controller drives the rest (##VP; / ##KN2; / ##KN0;) and plain CAT
         // (ID;) already works immediately after ##ID1;. The previous
         // "wait for ##TI" left TR4W idle, so the radio closed the socket and
         // we reconnected in a loop. Go straight to CAT.
         FAuthState := ksAuthenticated;
         logger.Info('[%s.HandleAuthMessage] Credentials accepted; CAT-ready',
                     [Self.rigLabel]);
         SendPostLoginSetup;
         InitializeAfterAuth;
         end
      else
         begin
         FAuthState := ksAuthFailed;
         logger.Error('[%s.HandleAuthMessage] AUTH FAILED -- radio responded: %s',
                      [Self.rigLabel, sMessage]);
         end;
      Exit;
      end;

   if FAuthState = ksAuthenticated then
      begin
      // Post-auth ## frames are LAN-control responses/notifications:
      //   ##VP0;/##VP1; (replies to ##VP;), ##KN21;/##KN02;/##KN71; (##KN),
      //   and on some firmwares ##UE;/##TI;. None require action -- the CAT
      //   session is already running -- so just log and ignore them.
      logger.Debug('[%s.HandleAuthMessage] post-auth control frame (ignored): %s',
                   [Self.rigLabel, sMessage]);
      Exit;
      end;
end;

procedure TKenwoodLAN.InitializeAfterAuth;
begin
   if FInitialized then Exit;
   FInitialized := True;

   logger.Info('[%s.InitializeAfterAuth] Sending TS-890 init sequence', [Self.rigLabel]);

   // Enable Auto-Information mode 2 -- the radio will push frequency, mode,
   // split, and other state changes without further polling.
   Self.SendToRadio('AI2;');

   // Prime our cached state with explicit queries.
   Self.SendToRadio('FA;');     // VFO A frequency
   Self.SendToRadio('FB;');     // VFO B frequency
   Self.SendToRadio('FR;');     // operating (RX) VFO -- needed to map OM0/OM1 to physical VFOs
   Self.SendToRadio('OM0;');    // operating-VFO mode (OM is operating-relative)
   Self.SendToRadio('OM1;');    // other-VFO mode
   Self.SendToRadio('KS;');     // CW keyer speed
   Self.SendToRadio('TB;');     // Split (TX/RX VFO)
   Self.SendToRadio('FT;');     // TX VFO selection
   Self.SendToRadio('RT;');     // RIT state
   Self.SendToRadio('XT;');     // XIT state
   Self.SendToRadio('ID;');     // Radio identity (expect ID024;)

   Self.UpdateLastValidResponse;
end;

// ============================================================================
// Message Dispatch
// ============================================================================

procedure TKenwoodLAN.ProcessMessage(sMessage: string);
begin
   if sMessage = '' then Exit;

   // Refresh the disconnect watchdog -- any well-formed reply means the
   // radio is alive, even pre-auth handshake bytes.
   Self.UpdateLastValidResponse;

   // Auth-phase frames begin with "##".
   if AnsiStartsStr('##', sMessage) then
      begin
      HandleAuthMessage(sMessage);
      Exit;
      end;

   // Anything else received before auth completes is bytes from a previous
   // session or garbage -- ignore until ##ID1; has been received.
   if FAuthState <> ksAuthenticated then
      begin
      logger.Trace('[%s.ProcessMessage] Pre-auth byte stream ignored: %s',
                   [Self.rigLabel, sMessage]);
      Exit;
      end;

   // ----- Authenticated: normal Kenwood CAT replies follow -----
   // Replies are typically 2-character command + data + ';'. The semicolon
   // was already stripped by the reading thread (we set readTerminator).
   if AnsiStartsStr('FA', sMessage) then
      ParseFAOrFBResponse(sMessage, nrVFOA)
   else if AnsiStartsStr('FB', sMessage) then
      ParseFAOrFBResponse(sMessage, nrVFOB)
   else if AnsiStartsStr('OM', sMessage) then
      ParseOMResponse(sMessage)
   else if AnsiStartsStr('KS', sMessage) then
      ParseKSResponse(sMessage)
   else if AnsiStartsStr('TB', sMessage) then
      ParseTBResponse(sMessage)
   else if AnsiStartsStr('FT', sMessage) then
      ParseFTResponse(sMessage)
   else if AnsiStartsStr('FR', sMessage) then
      // Operating (RX) VFO -- pushed under AI2 on A/B. Tracked because the OM
      // mode reply is operating-VFO-relative (see ParseOMResponse).
      ParseFRResponse(sMessage)
   else if AnsiStartsStr('RT', sMessage) then
      ParseRTResponse(sMessage)
   else if AnsiStartsStr('XT', sMessage) then
      ParseXTResponse(sMessage)
   else if AnsiStartsStr('RF', sMessage) then
      // RIT/XIT frequency offset, pushed unsolicited under AI2 as the knob turns.
      ParseRFResponse(sMessage)
   else if AnsiStartsStr('TX', sMessage) then
      // Radio pushes TX0; when it goes to transmit (AI2). Surface it so the
      // main window's TX indicator updates.
      Self.SetTransmitting(True)
   else if AnsiStartsStr('RX', sMessage) then
      Self.SetTransmitting(False)
   else if AnsiStartsStr('PS', sMessage) then
      // Keepalive heartbeat response (PS1; = power on). No state to track;
      // the round-trip itself is what keeps the LAN connection from being
      // dropped by the radio's 10-second idle timeout.
      logger.Trace('[%s.ProcessMessage] Keepalive ack: %s', [Self.rigLabel, sMessage])
   else if AnsiStartsStr('ID', sMessage) then
      begin
      // This class serves BOTH radios, so it must accept both identifiers:
      // ID024 = TS-890S, ID022 = TS-990S.  Checking only for ID024 meant a
      // perfectly healthy TS-990 logged "Unexpected ID response" on every
      // connect -- a warning that would send someone looking for a cabling or
      // model-selection fault that does not exist.
      // FExpectedIdent is set by the MODEL's constructor, so a genuine
      // mismatch (a TS-890 selected in the dialog but a TS-990 on the wire) is
      // still reported, which is what the check is actually for.
      if AnsiStartsStr(FExpectedIdent, sMessage) then
         begin
         logger.Info('[%s.ProcessMessage] Confirmed %s (%s)',
                     [Self.rigLabel, Self.radioModel, FExpectedIdent]);
         end
      else
         begin
         logger.Warn('[%s.ProcessMessage] Unexpected ID response: %s (expected %s for %s)',
                     [Self.rigLabel, sMessage, FExpectedIdent, Self.radioModel]);
         end;
      end
   else
      begin
      logger.Trace('[%s.ProcessMessage] Unhandled reply: %s', [Self.rigLabel, sMessage]);
      end;
end;

procedure TKenwoodLAN.ProcessMsg(msg: string);
begin
   ProcessMessage(msg);
end;

// ============================================================================
// Reply Parsers
// ============================================================================

procedure TKenwoodLAN.ParseFAOrFBResponse(const sMessage: string; whichVFO: TVFO);
var
   freqStr: string;
   freqVal: Int64;
   convErr: Integer;
begin
   // Format: FA<11-digit Hz>;  or  FB<11-digit Hz>;  Semicolon already removed.
   if Length(sMessage) < 13 then
      begin
      logger.Warn('[%s.ParseFAOrFBResponse] Short freq reply: %s',
                  [Self.rigLabel, sMessage]);
      Exit;
      end;

   freqStr := Copy(sMessage, 3, 11);
   Val(freqStr, freqVal, convErr);
   if convErr <> 0 then
      begin
      logger.Warn('[%s.ParseFAOrFBResponse] Non-numeric freq: %s',
                  [Self.rigLabel, freqStr]);
      Exit;
      end;

   Self.vfo[whichVFO].frequency := freqVal;
   // Derive and store the band from the reported frequency. Without this,
   // vfo[].band stays NoBand -> GetBand returns NoBand -> FilteredStatus.Band
   // is NoBand -> ProcessFilteredStatus (uRadioPolling ~3161) skips the whole
   // ActiveBand/ActiveMode/DisplayBandMode update, so the main-window
   // band-above-freq, the band table, AND the mode never follow the radio
   // (only the frequency updates, via a separate path). The Kenwood reports a
   // frequency rather than a band number, so we derive it; the K4 sets
   // vfo[].band for exactly the same reason.
   if Self.vfo[whichVFO].frequency > 0 then
      begin
      Self.vfo[whichVFO].band := FreqToRadioBand(Self.vfo[whichVFO].frequency);
      end;
   logger.Trace('[%s.ParseFAOrFBResponse] %s = %d Hz (band %d)',
                [Self.rigLabel, VFOToString(whichVFO), freqVal,
                 Ord(Self.vfo[whichVFO].band)]);
end;

procedure TKenwoodLAN.ParseOMResponse(const sMessage: string);
var
   vfoChar, modeChar: Char;
   whichVFO: TVFO;
begin
   // Format: OM<vfoChar><modeChar>;  vfoChar = '0' (VFO A) or '1' (VFO B).
   if Length(sMessage) < 4 then
      begin
      logger.Warn('[%s.ParseOMResponse] Short OM reply: %s', [Self.rigLabel, sMessage]);
      Exit;
      end;

   vfoChar  := sMessage[3];
   modeChar := sMessage[4];

   // KENWOOD QUIRK: the OM P1 byte is OPERATING-VFO-relative, NOT a fixed VFO
   // A/B -- '0' = the operating (FR-selected) VFO, '1' = the other VFO. Map it
   // to the physical VFO via the base active VFO (GetActiveVFO, set from FR). Without this,
   // after an A/B swap to VFO B the radio's OM0 (= B's mode) is filed under
   // VFO A and the per-VFO modes display swapped (issue #1, confirmed in the
   // A/B capture: FR1 then OM with the modes transposed).
   case vfoChar of
      '0': whichVFO := Self.GetActiveVFO;
      '1': if Self.GetActiveVFO = nrVFOA then
              begin
              whichVFO := nrVFOB;
              end
           else
              begin
              whichVFO := nrVFOA;
              end;
   else
      logger.Warn('[%s.ParseOMResponse] Unexpected VFO char in: %s',
                  [Self.rigLabel, sMessage]);
      Exit;
   end;

   Self.vfo[whichVFO].mode := ModeCharToMode(modeChar);
   logger.Trace('[%s.ParseOMResponse] %s mode = %s (OM%s, operating=%s)',
                [Self.rigLabel, VFOToString(whichVFO),
                 Self.ModeToString(Self.vfo[whichVFO].mode), vfoChar,
                 VFOToString(Self.GetActiveVFO)]);
end;

procedure TKenwoodLAN.ParseKSResponse(const sMessage: string);
var
   wpmStr: string;
   wpmVal: Integer;
   convErr: Integer;
begin
   // Format: KS<3-digit WPM>;
   if Length(sMessage) < 5 then
      begin
      Exit;
      end;
   wpmStr := Copy(sMessage, 3, 3);
   Val(wpmStr, wpmVal, convErr);
   if convErr = 0 then
      begin
      Self.localCWSpeed := wpmVal;
      logger.Trace('[%s.ParseKSResponse] CW speed = %d wpm', [Self.rigLabel, wpmVal]);
      end;
end;

// Format: TB<0|1>;  -- 0 = split off, 1 = split on.
// TS-890 Split is a global on/off flag separate from FR/FT VFO selection.
procedure TKenwoodLAN.ParseTBResponse(const sMessage: string);
begin
   if Length(sMessage) < 3 then
      begin
      Exit;
      end;
   Self.SetSplitOn(sMessage[3] = '1');   // base setter -> localSplitEnabled the window reads
   logger.Trace('[%s.ParseTBResponse] Split = %s',
                [Self.rigLabel, BoolToStr(Self.localSplitEnabled, True)]);
end;

procedure TKenwoodLAN.ParseFTResponse(const sMessage: string);
begin
   if Length(sMessage) < 3 then
      begin
      Exit;
      end;

   // FT selects the transmit VFO; it is NOT split (that is TB).  Remembered for
   // the log and for future split-VFO work, deliberately without touching split
   // state -- deriving split from FT vs FR contradicts the command reference.
   if sMessage[3] = '1' then
      begin
      FTxVFO := nrVFOB;
      end
   else
      begin
      FTxVFO := nrVFOA;
      end;

   logger.Trace('[%s.ParseFTResponse] TX VFO = %s',
                [Self.rigLabel, IfThen(sMessage[3] = '1', 'B', 'A')]);
end;

// Format: FR<0|1>;  -- 0 = VFO A is the operating (RX) VFO, 1 = VFO B. The radio
// pushes this under AI2 when A/B is pressed. We must track it because the OM
// (mode) reply is operating-VFO-relative: OM0 = the operating VFO's mode, OM1 =
// the other VFO's. ParseOMResponse uses the base active VFO (GetActiveVFO) to file each OM reply
// under the correct physical VFO -- fixes the A/B mode-swap (issue #1).
procedure TKenwoodLAN.ParseFRResponse(const sMessage: string);
begin
   if Length(sMessage) < 3 then
      begin
      Exit;
      end;

   // TS-890 is a selectable-RX-VFO radio: FR moves the RX pointer (FR0=A, FR1=B)
   // without swapping VFO contents. Drive the base FActiveVFO so BOTH the main-
   // window display (via pFactoryRadio / GetActiveVFO) and the operating-relative
   // OM mode mapping follow the receiving VFO.
   if sMessage[3] = '1' then
      begin
      Self.SetActiveVFO(nrVFOB);
      end
   else
      begin
      Self.SetActiveVFO(nrVFOA);
      end;


   logger.Trace('[%s.ParseFRResponse] operating (RX) VFO = %s',
                [Self.rigLabel, VFOToString(Self.GetActiveVFO)]);
end;

// Format: RT<0|1>;  -- 0 = RIT off, 1 = RIT on.
procedure TKenwoodLAN.ParseRTResponse(const sMessage: string);
begin
   if Length(sMessage) < 3 then
      begin
      Exit;
      end;
   Self.SetRITOn(sMessage[3] = '1');   // base setter -> per-VFO RITState the window reads
   logger.Trace('[%s.ParseRTResponse] RIT = %s',
                [Self.rigLabel, BoolToStr(Self.RITState, True)]);
end;

// Format: XT<0|1>;  -- 0 = XIT off, 1 = XIT on.
procedure TKenwoodLAN.ParseXTResponse(const sMessage: string);
begin
   if Length(sMessage) < 3 then
      begin
      Exit;
      end;
   Self.SetXITOn(sMessage[3] = '1');   // base setter -> per-VFO XITState the window reads
   logger.Trace('[%s.ParseXTResponse] XIT = %s',
                [Self.rigLabel, BoolToStr(Self.XITState, True)]);
end;

// Format: RF<P1><P2P2P2P2>;  P1 = direction (0 = +, 1 = -), P2 = 4-digit RIT/XIT
// offset in Hz (0000-9999), e.g. RF10030 = -30 Hz, RF00000 = centered.  The
// TS-890 pushes this UNSOLICITED under AI2 as the RIT/XIT knob turns -- validated
// against N2SKH's capture: 276 RF frames from the radio, zero client RF; queries.
// So there is nothing to poll; we just stop discarding the frames we already
// receive.  Stored as the active VFO's RIT offset; the polling bridge copies
// vfo[].RITOffset -> CurrentStatus.RITFreq, which the main window displays.
// (RIT/XIT on/off arrive separately as RT;/XT; -- see ParseRT/XTResponse.)
procedure TKenwoodLAN.ParseRFResponse(const sMessage: string);
var
   magVal, convErr, offset: Integer;
begin
   // "RF" + direction(1) + 4 digits => 7 chars minimum (semicolon already stripped).
   if Length(sMessage) < 7 then
      begin
      logger.Warn('[%s.ParseRFResponse] Short RF reply: %s', [Self.rigLabel, sMessage]);
      Exit;
      end;

   Val(Copy(sMessage, 4, 4), magVal, convErr);   // P2: 4-digit magnitude in Hz
   if convErr <> 0 then
      begin
      logger.Warn('[%s.ParseRFResponse] Non-numeric RF offset: %s',
                  [Self.rigLabel, sMessage]);
      Exit;
      end;

   offset := magVal;
   if sMessage[3] = '1' then          // P1 = 1 => minus direction
      begin
      offset := -offset;
      end;

   Self.vfo[nrVFOA].RITOffset := offset;
   logger.Trace('[%s.ParseRFResponse] RIT/XIT offset = %d Hz', [Self.rigLabel, offset]);
end;

// ============================================================================
// Mode mapping (TS-890 PC Command Reference, OM command P2 values)
// ============================================================================

function TKenwoodLAN.ModeCharToMode(ch: Char): TRadioMode;
begin
   // 1=LSB 2=USB 3=CW 4=FM 5=AM 6=FSK 7=CW-R 9=FSK-R
   // A=PSK B=PSK-R C=LSB-DATA D=USB-DATA E=FM-DATA F=AM-DATA
   case ch of
      '1':      Result := rmLSB;
      '2':      Result := rmUSB;
      '3':      Result := rmCW;
      '4':      Result := rmFM;
      '5':      Result := rmAM;
      '6':      Result := rmFSK;
      '7':      Result := rmCWRev;
      '9':      Result := rmFSKRev;
      'A', 'a': Result := rmPSK;
      'B', 'b': Result := rmPSKRev;
      'C', 'c': Result := rmData;        // LSB-DATA
      'D', 'd': Result := rmData;        // USB-DATA
      'E', 'e': Result := rmData;        // FM-DATA
      'F', 'f': Result := rmData;        // AM-DATA
   else
      logger.Warn('[%s.ModeCharToMode] Unknown OM mode char "%s"', [Self.rigLabel, ch]);
      Result := rmNone;
   end;
end;

function TKenwoodLAN.ModeToModeChar(mode: TRadioMode): Char;
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
      rmPSK:    Result := 'A';
      rmPSKRev: Result := 'B';
      rmData:   Result := 'D';           // Default DATA to USB-DATA
      rmDataRev:Result := 'C';           // Reverse DATA = LSB-DATA
   else
      logger.Warn('[%s.ModeToModeChar] No TS-890 OM code for mode %d', [Self.rigLabel, Ord(mode)]);
      Result := #0;
   end;
end;

// ============================================================================
// Polling (only used if requiresPolling is True; we use AI2 instead)
// ============================================================================

procedure TKenwoodLAN.PollRadioState;
begin
   if FAuthState <> ksAuthenticated then Exit;
   // LAN-only requirement: the TS-890 closes the TCP connection if it
   // receives nothing from us for 10 seconds. ARCP and other Kenwood-
   // documented clients send PS; every 5 seconds as a heartbeat. The
   // response is just PS1; (power on) and is discarded. AI2 pushes
   // everything else, so this is keepalive only -- no real polling.
   Self.SendToRadio('PS;');
end;

// ============================================================================
// Transmit / Receive
// ============================================================================

procedure TKenwoodLAN.Transmit;
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('TX;');
end;

procedure TKenwoodLAN.Receive;
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RX;');
end;

// ============================================================================
// CW (KY buffer-based, identical idiom to K4 / TS-990)
// ============================================================================

procedure TKenwoodLAN.SendCW;
begin
   // The ONLY LAN-specific part: nothing may be sent before the session is
   // authenticated.  The KY command itself is inherited -- this driver used to
   // hand-roll the same string the other four KY radios built with a shared
   // formatter, which is exactly how two spellings of one command drift apart.
   if FAuthState <> ksAuthenticated then
      begin
      Exit;
      end;
   inherited SendCW;
end;

function TKenwoodLAN.CWIsFactoryOwned: Boolean;
begin
   // The LAN Kenwoods key CW themselves over the TCP link.
   Result := True;
end;

procedure TKenwoodLAN.StopCW;
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('KY0;RX;');
end;

// ============================================================================
// Frequency / Mode
// ============================================================================

procedure TKenwoodLAN.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var sCmd: string;
begin
   if FAuthState <> ksAuthenticated then Exit;

   case vfo of
      nrVFOA: sCmd := 'FA';
      nrVFOB: sCmd := 'FB';
   else
      logger.Error('[%s.SetFrequency] Invalid VFO', [Self.rigLabel]);
      Exit;
   end;
   Self.SendToRadio(Format('%s%.11d;', [sCmd, freq]));

   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

procedure TKenwoodLAN.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   modeChar: Char;
   vfoChar: Char;
begin
   if FAuthState <> ksAuthenticated then Exit;

   modeChar := ModeToModeChar(mode);
   if modeChar = #0 then Exit;

   // KENWOOD QUIRK: per the TS-890 PC Command Reference, the OM command's
   // P1 (VFO) byte is "ignored with the setting command" -- the radio always
   // applies the mode to the currently active VFO. We still emit a P1 byte
   // to match the documented command shape, but SetMode(mode, nrVFOB) when
   // VFO A is the active VFO will NOT change VFO B's mode; the radio will
   // change VFO A's mode instead. Setting the inactive VFO's mode would
   // require swap-VFO -> OM -> swap-VFO-back; not implemented (TR4W's
   // contest flow operates on the active VFO, so this is acceptable).
   case vfo of
      nrVFOA: vfoChar := '0';
      nrVFOB: vfoChar := '1';
   else
      Exit;
   end;
   Self.SendToRadio(Format('OM%s%s;', [vfoChar, modeChar]));
end;

function TKenwoodLAN.ToggleMode(vfo: TVFO): TRadioMode;
begin
   // Not implemented; TS-890 has no single-shot mode-toggle command.
   Result := rmNone;
end;

procedure TKenwoodLAN.SetCWSpeed(speed: integer);
begin
   if FAuthState <> ksAuthenticated then Exit;
   if not IntegerBetween(speed, MIN_CW_SPEED, MAX_CW_SPEED) then
      begin
      logger.Error('[%s.SetCWSpeed] TS-890 CW range is %d..%d wpm (got %d)',
                   [Self.rigLabel, MIN_CW_SPEED, MAX_CW_SPEED, speed]);
      Exit;
      end;
   Self.localCWSpeed := speed;
   Self.SendToRadio(Format('KS%.3d;', [speed]));
end;

// ============================================================================
// RIT / XIT
// ============================================================================

procedure TKenwoodLAN.RITClear(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RC;');
end;

procedure TKenwoodLAN.XITClear(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   // TS-890 shares the offset between RIT and XIT; clearing RC also clears XIT.
   Self.SendToRadio('RC;');
end;

procedure TKenwoodLAN.RITBumpDown;
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RD;');
end;

procedure TKenwoodLAN.RITBumpUp;
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RU;');
end;

procedure TKenwoodLAN.RITOn(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RT1;');
end;

procedure TKenwoodLAN.RITOff(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('RT0;');
end;

procedure TKenwoodLAN.XITOn(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('XT1;');
end;

procedure TKenwoodLAN.XITOff(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('XT0;');
end;

procedure TKenwoodLAN.SetRITFreq(whichVFO: TVFO; hz: integer);
var
   magnitude: Integer;
begin
   if FAuthState <> ksAuthenticated then Exit;

   // TS-890 sets a specific RIT/XIT offset in two steps:
   //   1. Clear the current offset:           RC;
   //   2. Apply magnitude with direction:
   //         RU<nnnnn>;   for a positive offset (RIT up)
   //         RD<nnnnn>;   for a negative offset (RIT down)
   //      where nnnnn is the 5-digit Hz value in the range 00000..09999.
   // The RIT and XIT offsets share one value on the TS-890; setting one
   // changes the other. XITClear / SetXITFreq route through here.
   //
   // When hz exceeds +-9999 we silently clamp to 9999. The TR4W RIT shift
   // keys are press-repeatedly UI affordances; once at the radio's limit,
   // further presses are no-ops, no warning needed.
   Self.SendToRadio('RC;');
   if hz = 0 then Exit;

   magnitude := Abs(hz);
   if magnitude > 9999 then
      begin
      magnitude := 9999;
      end;

   if hz > 0 then
      begin
      Self.SendToRadio(Format('RU%.5d;', [magnitude]));
      end
   else
      begin
      Self.SendToRadio(Format('RD%.5d;', [magnitude]));
      end;
end;

procedure TKenwoodLAN.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   // TS-890 has one shared RIT/XIT offset; setting XIT uses the same
   // RC + RU/RD command sequence as RIT.
   Self.SetRITFreq(whichVFO, hz);
end;

// ============================================================================
// Split / Band / Filter (stubs -- to be expanded in follow-up commits)
// ============================================================================

procedure TKenwoodLAN.Split(splitOn: boolean);
begin
   if FAuthState <> ksAuthenticated then Exit;
   // FT1 = TX on VFO B, FT0 = TX on VFO A.  UNCHANGED from the D7
   // implementation, which is reported working against a real radio.
   //
   // Note the command reference lists TB as the explicit split flag ("TB  Split.
   // P1: 0 = Split OFF, 1 = Split ON") and FT as "Transmitter Function (VFO A /
   // VFO B)", so on paper TB looks like the command to send.  It was changed to
   // TB here and changed BACK, because a manual reading is not a reason to alter
   // a path that works on hardware: a TX VFO differing from the RX VFO IS split,
   // and the radio then reports TB1 of its own accord, which is what
   // ParseTBResponse already consumes.
   //
   // OPEN QUESTION for the bench: does FT1; alone make a real TS-890 report TB1?
   // If it does, this is correct as-is.  If it does NOT, split has never worked
   // on this radio and the fix is to send TB1;/TB0; here.
   if splitOn then
      begin
      Self.SendToRadio('FT1;');   // TX = VFO B
      end
   else
      begin
      Self.SendToRadio('FT0;');  // TX = VFO A (split off)
      end;
end;

procedure TKenwoodLAN.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
begin
   if FAuthState <> ksAuthenticated then Exit;
   // The TS-890 changes band via a frequency set, so route through SetFrequency.
   Self.SetFrequency(Self.BandToFreq(band), vfo, rmNone);
end;

function TKenwoodLAN.ToggleBand(vfo: TVFO): TRadioBand;
begin
   Result := Self.band[vfo];
end;

procedure TKenwoodLAN.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
   if FAuthState <> ksAuthenticated then Exit;

   // TS-890 has 3 receive filter slots, A / B / C, selected via the FL0
   // command (P1 = 0/1/2). The bandwidth of each slot is user-configurable
   // in the radio's menu; by convention A is the narrowest and C the widest,
   // so we map rfNarrow/Mid/Wide -> A/B/C.
   //
   // Caveat: the radio rejects FL02; (filter C) when menu [6-10]
   // ("RX Filter Numbers") is set to "2", meaning the operator has restricted
   // their radio to two filter slots. We don't pre-query that menu setting
   // here; if the radio NAKs, the polling thread will log it at trace level.
   case filter of
      rfNarrow: Self.SendToRadio('FL00;');
      rfMid:    Self.SendToRadio('FL01;');
      rfWide:   Self.SendToRadio('FL02;');
   end;
end;

function TKenwoodLAN.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   Result := 0;
end;

function TKenwoodLAN.MemoryKeyer(mem: integer): boolean;
begin
   Result := False;
   if FAuthState <> ksAuthenticated then Exit;
   if not IntegerBetween(mem, 1, 6) then Exit;
   Self.SendToRadio(Format('PB%d;', [mem]));
   Result := True;
end;

procedure TKenwoodLAN.VFOBumpDown(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('DN;');
end;

procedure TKenwoodLAN.VFOBumpUp(whichVFO: TVFO);
begin
   if FAuthState <> ksAuthenticated then Exit;
   Self.SendToRadio('UP;');
end;

// This unit registers NOTHING -- it is the shared base.  See
// uRadioKenwoodTS890.pas and uRadioKenwoodTS990.pas.

procedure TKenwoodLAN.ApplyNetworkCredentials(const user, pass: string);
begin
   NetworkUsername := ShortString(user);
   NetworkPassword := ShortString(pass);
   logger.Info('[%s] LAN credentials set (user=%s, pass=*******)', [radioModel, user]);
end;



end.
