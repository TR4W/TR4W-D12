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
unit uRadioTCI;

{
  TCI (Transceiver Control Interface) -- ExpertSDR2 / Thetis / AetherSDR.

  See docs/TCI_Radio_Implementation_Plan.md for the protocol write-up this
  implements.  Short version:

    - The transport is WEBSOCKET, not raw TCP and not serial, so this driver
      owns its transport instead of using the base reading thread.  Precedent:
      THamLibDirect also bypasses the base socket.  uWebSocketClient does the
      RFC 6455 work and knows nothing about radios.
    - The protocol is PUSH.  After the server's init burst ends with `ready;`,
      every state change arrives unsolicited.  PollRadioState is a once-a-
      second REPAIR tick (liveness ping + rit/xit_offset GETs), not a state poll.
    - Commands and notifications share one grammar: `name:arg,arg,...;` with a
      few no-argument forms (`ready;`, `start;`, `stop;`).
    - There is NO per-model fan-out.  TCI *is* the model: the server abstracts
      whatever hardware is behind it, so one registration covers all of them.

  WHAT IS NOT DONE HERE, deliberately:
    - Spot push (`spot:` / `spot_delete:` / `spot_clear;`) and the
      `clicked_on_spot` pair.  That is bandmap integration, a later phase.
    - Audio.  We never subscribe; the WS layer discards binary frames.

  EVERYTHING MARKED [VERIFY] NEEDS A REAL SERVER.  This driver has never been
  run against ExpertSDR2, Thetis or AetherSDR -- it is written from the protocol
  contract only.
}

interface

uses
   Windows, SysUtils, Classes, StrUtils, Math, DateUtils,
   uFactoryRadioBase, uRadioBand, uRadioRegistry, uWebSocketClient, Log4D, VC,
   uCWFraming;

type
   TTCIRadio = class(TFactoryRadioBase)
   protected
      FWS:            TWebSocketClient;
      FRxBuffer:      string;      // partial command remainder between frames
      FReady:         boolean;     // server sent `ready;`
      FCWBuffer:      string;      // text accumulated by BufferCW
      FModulations:   TStringList; // what THIS server said it supports
      // Driver-local liveness clock.  The base's FLastValidResponse is
      // PRIVATE and it exposes UpdateLastValidResponse to WRITE it but no
      // way to READ it, so a driver that owns its transport (this one, and
      // THamLibDirect) cannot implement its own idle logic without this.
      FLastRx:        TDateTime;
      // SPLIT is expressed by TCI as a second RECEIVER carrying tx_enable:true --
      // NOT as split_enable on receiver 0.  From NY4I's 2026-08-02 capture, with
      // the AetherSDR UI in split the server sent:
      //     split_enable:0,false   (VFO A/B split within RX0 -- honestly off)
      //     tx_enable:0,false
      //     tx_enable:1,true       <-- receiver 1 is the transmitter
      //     vfo:1,0,7114000        <-- and it sits on the TX frequency
      // Note the ASYMMETRY: setting split still goes out as split_enable (the
      // server maps that to creating a slice).  Only the READ path needs this.
      FTxTrx:         integer;                  // receiver currently flagged tx_enable
      // Did WE turn split on?  AetherSDR will remove the slice IT created for a
      // client, but not one the operator created -- so ownership, not 'which
      // receiver transmits', decides whether we can turn split off.  Inferring
      // it from FTxTrx was wrong: a TR4W-created split ALSO moves the
      // transmitter to the new receiver, so the refusal fired on our own slice.
      FWeEnabledSplit: boolean;
      FRxVfoA:        array[0..7] of integer;   // VFO A per receiver, for the TX freq

      function  GetISConnected: boolean; override;
      function  GetIsOperational: boolean; override;

      // WebSocket callbacks (raised on the WS reader thread).
      procedure WSText(const Text: string);
      procedure WSDisconnected;

      procedure DispatchCommand(const Cmd: string);
      procedure RecomputeSplitFromTx;
      function  TCIModeToRadioMode(const s: string): TRadioMode;
      function  RadioModeToTCIMode(mode: TRadioMode): string;
      function  TrxIndexOf(const s: string): integer;
   public
      constructor Create; reintroduce;
      destructor  Destroy; override;

      function  Connect: integer; override;
      procedure Disconnect; override;
      procedure ProcessMsg(msg: string); override;
      procedure PollRadioState; override;
      procedure SendToRadio(s: string); overload; override;

      procedure Transmit; override;
      procedure Receive; override;

      procedure BufferCW(cwChars: string); override;
      procedure SendCW; override;
      procedure StopCW; override;
      function  CWIsFactoryOwned: Boolean; override;
      procedure SetCWSpeed(speed: integer); override;

      procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
      procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;

      procedure Split(splitOn: boolean); override;
      procedure RITOn(whichVFO: TVFO); override;
      procedure RITOff(whichVFO: TVFO); override;
      procedure XITOn(whichVFO: TVFO); override;
      procedure XITOff(whichVFO: TVFO); override;
      procedure RITClear(whichVFO: TVFO); override;
      procedure XITClear(whichVFO: TVFO); override;
      procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
      procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;

      function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;

      // THE REST OF THE ABSTRACT SURFACE.  These nine were left unimplemented
      // when TCI was added, and TFactoryRadioBase declares them Virtual;
      // Abstract -- so calling any of them on a TCI radio was an access
      // violation, not a polite refusal.  The compiler DOES say so, but only on
      // a full build: nine W1020 "Constructing instance of TTCIRadio containing
      // abstract method" warnings, which /t:Make skips over.
      //
      // Every one is now either implemented against the protocol or refuses in
      // writing.  Nothing here may fault.
      function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
      procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
      function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
      procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
      function  MemoryKeyer(mem: integer): boolean; override;
      procedure RITBumpUp; override;
      procedure RITBumpDown; override;
      procedure VFOBumpUp(whichVFO: TVFO); override;
      procedure VFOBumpDown(whichVFO: TVFO); override;
   end;

implementation

uses
   MainUnit, LogWind;   // logger; QuickDisplayError

const
   // TR4W drives receiver 0 only.  TCI supports several ("trx"), but a contest
   // logger has one operating receiver per radio slot; SO2R is two TR4W radios.
   TCI_TRX = '0';

   // How long the link may be silent before we probe with a WS ping.
   // EMPIRICAL -- no server has been observed yet.  [VERIFY on bench]
   TCI_IDLE_PING_MS = 15000;

{ ------------------------------------------------------------- lifecycle -- }

constructor TTCIRadio.Create;
begin
   inherited Create(ProcessMsg);

   radioModel := 'TCI';

   // Push, not poll -- the K4 AI5 precedent.  PollRadioState is empty; the
   // interval is only an idle tick for the factory poll loop.
   // TRUE, despite TCI being a push protocol.  PollRadioState is NOT a state
   // poll here -- it is a once-a-second repair tick (liveness ping, and the
   // rit/xit_offset GETs below).  The factory poll loop only calls
   // PollRadioState for radios with requiresPolling = True, so leaving this
   // False meant the tick never ran at all -- the idle ping added earlier
   // had never once fired.
   requiresPolling   := True;
   pollingInterval   := 1000;
   autoUpdateCommand := '';

   // TCI commands carry their own ';'.  A trailing CR/LF is exactly the
   // TS-890-LAN class of bug, so never append one.
   bAddTermination := False;

   FReady := False;
   FRxBuffer := '';
   FCWBuffer := '';
   FLastRx := Now;
   FTxTrx := 0;
   FWeEnabledSplit := False;
   FModulations := TStringList.Create;
   FModulations.CaseSensitive := False;

   // Capabilities are set HERE, in the constructor.  NOTE: DefineCapabilities
   // is an ICOM-FAMILY virtual (declared in uRadioIcomBase), NOT a factory-base
   // one -- 68 drivers use this constructor idiom, 5 Icom units use the virtual.
   FCapabilities.Flags := FCapabilities.Flags +
      [rcReadVFOB,       // vfo:<trx>,1,<hz> notifications
       rcReadRIT,        // rit_enable + rit_offset are both readable
       rcReadSplit,      // split_enable is broadcast
       rcReadTXStatus,   // trx:<trx>,<bool> is broadcast
       rcCWByCAT];       // cw_macros

   // ---- rcCWSpeedSync WITHDRAWN 2026-08-03 ---------------------------------
   // Not because TCI lacks the command -- because the server on the other end
   // will not honour it, and a capability is a promise about what actually
   // happens on the wire.  Claiming it made TR4W send a speed on every PgUp
   // that changed nothing, which is worse than not offering the feature: the
   // operator sees TR4W's speed move and the radio's stay put.
   //
   // EVIDENCE, not inference.  tr4w.log 2026-08-03 03:52:02-10: ten PgUp/PgDn
   // presses, ten `cw_macros_speed:NN;` sent (25,23,21,19,17,15,13,15,17,19),
   // and ten replies of `cw_macros_speed:30` -- the server's own unchanged
   // value, every time.  AetherSDR src/core/TciProtocol.cpp:454 says why:
   //
   //     bool isSet = (args.size() >= 2);
   //
   // Set-versus-get by ARGUMENT COUNT, which assumes every command is
   // receiver-addressed (`rit_offset:0,500;`).  cw_macros_speed is a GLOBAL
   // taking one argument, so our correctly-formed `cw_macros_speed:25;` is one
   // arg, reads as a GET, and cmdCwMacrosSpeed returns the current speed.  The
   // set path is unreachable for ANY client.  Our grammar is right -- it is the
   // string AetherSDR itself emits (same file, lines 974/985).
   //
   // This is an AETHERSDR limitation, not a TCI-protocol one.  We withdraw the
   // capability for every TCI server anyway: TR4W cannot tell which server it
   // is talking to, and NY4I chose the honest blanket answer over guessing.
   // AetherSDR issues #1677 (CW-over-TCI, closed with its "CW speed is
   // reflected on the radio" criterion never wire-tested) and #1764 (same root
   // cause for DRIVE/VOLUME; its own analysis prescribed the fix, which was
   // then applied only to `volume`).
   //
   // TO RESTORE: put rcCWSpeedSync back in the set above.  Nothing else needs
   // to change -- SetCWSpeed below is correct and stays, and the CWSpeedMin/Max
   // range is still used to clamp.  Retest by watching for a `cw_macros_speed`
   // reply that carries OUR number instead of the server's.
   //
   // AetherSDR accepts 5..100 wpm.  ExpertSDR2/Thetis ranges [VERIFY].
   FCapabilities.CWSpeedMin := 5;
   FCapabilities.CWSpeedMax := 100;
   // ---- CW-by-CAT framing --------------------------------------------------
   // cw_macros:<trx>,<text>; states no length limit, so no chunking and no
   // padding.  [VERIFY on hardware -- if a long message is truncated, give this
   // a real maxLen; the keyer will then split it with no other change.]
   FCapabilities.CWFrame := CWFrameRule(0, False);
   // pdNone -- pass prosign tokens through as literal text.  TCI is not a KY
   // radio, and nobody has established what its cw_macros does with a prosign,
   // so substituting a Kenwood '_' for AR would be inventing a fact.  Passing
   // the token through at least fails visibly.  [VERIFY]
   //
   // Until 2026-08-03 this radio got NO CW at all: the framing and the gate were
   // looked up by InterfacedRadioType, which a string-id radio does not have.
   // Deliberately absent: rcSharedRITXITOffset.  TCI carries rit_offset and
   // xit_offset separately, so they are independent. [VERIFY on hardware]

   FWS := TWebSocketClient.Create;
   FWS.OnTextMessage  := WSText;
   FWS.OnDisconnected := WSDisconnected;
end;

destructor TTCIRadio.Destroy;
begin
   if Assigned(FWS) then
      begin
      FWS.OnTextMessage  := nil;
      FWS.OnDisconnected := nil;
      FreeAndNil(FWS);
      end;
   FreeAndNil(FModulations);
   inherited Destroy;
end;

function TTCIRadio.Connect: integer;
begin
   Result := 0;
   FReady := False;
   FRxBuffer := '';

   if radioAddress = '' then
      begin
      logger.Error('[TCI] no address configured');
      Result := 1;
      Exit;
      end;

   logger.Info('[TCI] connecting to ws://%s:%d/', [radioAddress, radioPort]);
   if not FWS.Connect(radioAddress, radioPort, '/') then
      begin
      logger.Error('[TCI] WebSocket connect failed: %s', [FWS.LastError]);
      Result := 1;
      Exit;
      end;

   // Nothing to request: the server sends its whole init burst unprompted and
   // terminates it with `ready;`.  Until then IsOperational stays False.
end;

procedure TTCIRadio.Disconnect;
begin
   FReady := False;
   if Assigned(FWS) then
      begin
      FWS.Disconnect;
      end;
end;

function TTCIRadio.GetISConnected: boolean;
begin
   Result := Assigned(FWS) and FWS.Connected;
end;

function TTCIRadio.GetIsOperational: boolean;
begin
   // "Connected" is the socket; "operational" additionally means the server
   // finished its init burst.  Sending before `ready;` is the documented way
   // to have commands silently ignored.
   Result := GetISConnected and FReady;
end;

procedure TTCIRadio.SendToRadio(s: string);
begin
   if not GetISConnected then
      begin
      Exit;
      end;
   logger.Trace('[TCI TX] %s', [s]);
   FWS.SendText(s);
end;

procedure TTCIRadio.PollRadioState;
begin
   if not GetISConnected then
      begin
      Exit;
      end;

   // Liveness: the server is silent by design when nothing changes, so probe
   // rather than assume a quiet link is a live one.
   if MilliSecondsBetween(Now, FLastRx) > TCI_IDLE_PING_MS then
      begin
      FWS.Ping;
      end;

   if not FReady then
      begin
      Exit;
      end;

   // RIT/XIT OFFSET REPAIR.  AetherSDR broadcasts rit_enable on every change but
   // NEVER broadcasts rit_offset from its own UI -- verified in their source:
   // TciServer.cpp wires only the *_enable family to change signals and its
   // comment says 'sql_level/rit_offset/xit_offset are out of scope', while
   // TciProtocol.cpp cmdRitOffset emits a notification ONLY on a client SET.
   // So an operator turning the RIT knob leaves every client's offset stale.
   //
   // The same function answers a GET (args without a value returns
   // 'rit_offset:<trx>,<hz>;'), so ask once a second while the offset can
   // actually be showing.  Costs one short frame per second only while RIT/XIT
   // is engaged, and self-heals whether or not upstream ever changes.
   if Self.IsRITOn[nrVFOA] then
      begin
      SendToRadio(Format('rit_offset:%s;', [TCI_TRX]));
      end;
   if Self.IsXITOn[nrVFOA] then
      begin
      SendToRadio(Format('xit_offset:%s;', [TCI_TRX]));
      end;
end;

{ -------------------------------------------------------------- inbound -- }

procedure TTCIRadio.WSDisconnected;
begin
   FReady := False;
   FWeEnabledSplit := False;   // link gone -- any split we owned is not ours now
   logger.Info('[TCI] WebSocket link dropped');
end;

procedure TTCIRadio.WSText(const Text: string);
var
   i: integer;
   ch: Char;
begin
   // Frames do not align with commands: one frame may carry several `...;`
   // commands, or half of one.  Keep the remainder.
   FRxBuffer := FRxBuffer + Text;
   i := Pos(';', FRxBuffer);
   while i > 0 do
      begin
      DispatchCommand(Trim(Copy(FRxBuffer, 1, i - 1)));
      Delete(FRxBuffer, 1, i);
      i := Pos(';', FRxBuffer);
      end;

   // Guard against a peer that never sends ';' -- do not grow without bound.
   if Length(FRxBuffer) > 8192 then
      begin
      logger.Warn('[TCI] discarding %d unterminated characters', [Length(FRxBuffer)]);
      FRxBuffer := '';
      end;
end;

procedure TTCIRadio.ProcessMsg(msg: string);
begin
   DispatchCommand(msg);
end;

function TTCIRadio.TrxIndexOf(const s: string): integer;
begin
   Result := StrToIntDef(Trim(s), -1);
end;

// Split is DERIVED, not received: it is ON when the transmitting receiver is not
// the one we operate.  Recomputed whenever either input changes, because the init
// burst sends vfo:1,0 BEFORE tx_enable:1,true and neither order is promised.
procedure TTCIRadio.RecomputeSplitFromTx;
var
   opTrx: integer;
begin
   opTrx := StrToIntDef(TCI_TRX, 0);
   Self.SetSplitOn(FTxTrx <> opTrx);
   if (FTxTrx <> opTrx) and (FTxTrx >= Low(FRxVfoA)) and (FTxTrx <= High(FRxVfoA)) then
      begin
      // TR4W's model is VFO A = RX, VFO B = TX, so publish the transmitting
      // receiver's frequency as VFO B -- that is what the radio window shows.
      Self.vfo[nrVFOB].frequency := FRxVfoA[FTxTrx];
      Self.vfo[nrVFOB].band := FreqToRadioBand(FRxVfoA[FTxTrx]);
      end
   else
      begin
      // Split is OFF -- there is no transmit VFO, so VFO B must go BLANK rather
      // than keep the frequency of a slice that no longer exists.  Frequency 0
      // is this program's established 'blank' convention (see uRadioPolling's
      // disconnect path, which zeroes VFO A/B for exactly this reason: a stale
      // reading is more misleading than an empty field).
      Self.vfo[nrVFOB].frequency := 0;
      Self.vfo[nrVFOB].band := rbNone;
      // NOTE: ownership is deliberately NOT cleared here.  Turning split ON
      // produces a transient that lands in this branch: the server sends
      // tx_enable:0,false (TX leaving receiver 0) ~19 ms BEFORE
      // tx_enable:1,true (TX arriving at receiver 1), so for one dispatch the
      // transmitter is receiver 0 and split reads OFF.  Clearing here threw
      // away ownership of a split we had just created, and the next '-' was
      // refused.  Ownership is cleared on an explicit split_enable:<trx>,false
      // from the server, on Disconnect, and in the constructor -- never on a
      // tx_enable transient.
      end;
end;

procedure TTCIRadio.DispatchCommand(const Cmd: string);
var
   name: string;
   argsPart: string;
   args: TArray<string>;
   p: integer;
   hz: integer;
   b: boolean;
   vfoIdx: integer;
begin
   if Cmd = '' then
      begin
      Exit;
      end;

   // Liveness first: even telemetry we discard proves the server is alive.
   FLastRx := Now;
   UpdateLastValidResponse;

   p := Pos(':', Cmd);
   if p = 0 then
      begin
      name := LowerCase(Trim(Cmd));
      argsPart := '';
      end
   else
      begin
      name := LowerCase(Trim(Copy(Cmd, 1, p - 1)));
      argsPart := Copy(Cmd, p + 1, Length(Cmd));
      end;
   args := SplitString(argsPart, ',');

   // HIGH-RATE TELEMETRY WE NEVER USE.  Measured on NY4I's 2026-08-02 capture:
   // 68 of 129 commands (53%) were rx_smeter alone.  TCI has no client-side
   // subscription filter that we know of -- the server broadcasts to every
   // client -- so the most a client can do is drop it cheaply.  Bailing out
   // BEFORE the trace log is the point: otherwise half the log is S-meter
   // readings and a real protocol problem is invisible in it.
   if (name = 'rx_smeter') or (name = 'tx_swr') or (name = 'tx_power') or
      (name = 'tx_meter') or (name = 'rx_sensors') or (name = 'tx_sensors') then
      begin
      Exit;
      end;

   logger.Trace('[TCI RX] %s', [Cmd]);

   // ---- no-argument forms -------------------------------------------------
   if name = 'ready' then
      begin
      FReady := True;
      logger.Info('[TCI] server ready -- init burst complete');
      Exit;
      end;
   if (name = 'start') or (name = 'stop') then
      begin
      // Audio stream markers; we never subscribe.
      Exit;
      end;

   // ---- init burst --------------------------------------------------------
   if name = 'modulations_list' then
      begin
      FModulations.Clear;
      for p := 0 to High(args) do
         begin
         FModulations.Add(LowerCase(Trim(args[p])));
         end;
      logger.Debug('[TCI] server supports %d modulations', [FModulations.Count]);
      Exit;
      end;
   if (name = 'device') or (name = 'protocol') or (name = 'receive_only') or
      (name = 'trx_count') or (name = 'channels_count') or (name = 'vfo_limits') or
      (name = 'if_limits') or (name = 'rx_only') then
      begin
      logger.Debug('[TCI] init %s = %s', [name, argsPart]);
      Exit;
      end;

   // ---- CROSS-RECEIVER state, handled BEFORE the trx-0 gate below ---------
   // These two are the ONLY commands we care about from other receivers, and
   // they are exactly what carries split.  Discarding them (as this driver
   // originally did) is why a radio already in split read as not-split.
   if (name = 'tx_enable') and (Length(args) >= 2) then
      begin
      if SameText(Trim(args[1]), 'true') then
         begin
         FTxTrx := TrxIndexOf(args[0]);
         end
      else if TrxIndexOf(args[0]) = FTxTrx then
         begin
         // The receiver that WAS transmitting has given it up -- e.g. the
         // operator closed the split slice.  Fall back to the receiver we
         // operate.  Without this we would only ever notice a slice being
         // CREATED (tx_enable:n,true) and never one going away, leaving a stale
         // split indication and a stale VFO B on screen.
         FTxTrx := StrToIntDef(TCI_TRX, 0);
         end;
      RecomputeSplitFromTx;
      Exit;
      end;

   if (name = 'vfo') and (Length(args) >= 3) and
      (StrToIntDef(Trim(args[1]), -1) = 0) then
      begin
      vfoIdx := TrxIndexOf(args[0]);   // here: the RECEIVER index, not the VFO
      if (vfoIdx >= Low(FRxVfoA)) and (vfoIdx <= High(FRxVfoA)) then
         begin
         FRxVfoA[vfoIdx] := StrToIntDef(Trim(args[2]), FRxVfoA[vfoIdx]);
         if vfoIdx = FTxTrx then
            begin
            RecomputeSplitFromTx;
            end;
         end;
      // fall through: receiver 0 still needs its normal VFO A handling below
      end;

   // Everything below is addressed to a receiver; ignore other receivers.
   if (Length(args) > 0) and (TrxIndexOf(args[0]) <> StrToIntDef(TCI_TRX, 0)) then
      begin
      Exit;
      end;

   // ---- state notifications ----------------------------------------------
   if (name = 'vfo') and (Length(args) >= 3) then
      begin
      vfoIdx := StrToIntDef(Trim(args[1]), 0);
      hz := StrToIntDef(Trim(args[2]), -1);
      if hz >= 0 then
         begin
         if vfoIdx = 0 then
            begin
            Self.vfo[nrVFOA].frequency := hz;
            Self.vfo[nrVFOA].band := FreqToRadioBand(hz);
            end
         else
            begin
            Self.vfo[nrVFOB].frequency := hz;
            Self.vfo[nrVFOB].band := FreqToRadioBand(hz);
            end;
         end;
      Exit;
      end;

   if (name = 'modulation') and (Length(args) >= 2) then
      begin
      Self.vfo[nrVFOA].mode := TCIModeToRadioMode(Trim(args[1]));
      Exit;
      end;

   if (name = 'trx') and (Length(args) >= 2) then
      begin
      b := SameText(Trim(args[1]), 'true');
      Self.SetTransmitting(b);
      Exit;
      end;

   if (name = 'split_enable') and (Length(args) >= 2) then
      begin
      Self.SetSplitOn(SameText(Trim(args[1]), 'true'));
      if not SameText(Trim(args[1]), 'true') then
         begin
         // Server confirms split is off -- whoever owned it, nobody does now.
         FWeEnabledSplit := False;
         end;
      Exit;
      end;

   if (name = 'rit_enable') and (Length(args) >= 2) then
      begin
      Self.SetRITOn(SameText(Trim(args[1]), 'true'));
      Exit;
      end;

   if (name = 'xit_enable') and (Length(args) >= 2) then
      begin
      Self.SetXITOn(SameText(Trim(args[1]), 'true'));
      Exit;
      end;

   if (name = 'rit_offset') and (Length(args) >= 2) then
      begin
      Self.SetRITOffset(StrToIntDef(Trim(args[1]), 0));
      Exit;
      end;

   if (name = 'xit_offset') and (Length(args) >= 2) then
      begin
      Self.SetXITOffset(StrToIntDef(Trim(args[1]), 0));
      Exit;
      end;

   if (name = 'cw_macros_speed') and (Length(args) >= 1) then
      begin
      // Speed notifications are NOT receiver-addressed on every server, so this
      // arrives with the wpm in args[0]. [VERIFY]
      Self.localCWSpeed := StrToIntDef(Trim(args[0]), Self.localCWSpeed);
      Exit;
      end;

   // tx_enable: notification-only.  Never send it as a SET -- servers ignore it
   // from clients, which looks like a driver bug when it is protocol.
end;

{ ---------------------------------------------------------------- modes -- }

function TTCIRadio.TCIModeToRadioMode(const s: string): TRadioMode;
var
   m: string;
begin
   m := LowerCase(Trim(s));
   if m = 'cw' then Result := rmCW
   else if m = 'cwr' then Result := rmCWRev
   else if m = 'usb' then Result := rmUSB
   else if m = 'lsb' then Result := rmLSB
   else if (m = 'fm') or (m = 'nfm') or (m = 'wfm') then Result := rmFM
   else if (m = 'am') or (m = 'sam') then Result := rmAM
   else if m = 'digu' then Result := rmData
   else if m = 'digl' then Result := rmDataRev
   else if m = 'rtty' then Result := rmFSK
   else
      begin
      logger.Debug('[TCI] unmapped modulation "%s" -- treating as DATA', [m]);
      Result := rmData;
      end;
end;

function TTCIRadio.RadioModeToTCIMode(mode: TRadioMode): string;
begin
   case mode of
      rmCW:      Result := 'cw';
      rmCWRev:   Result := 'cwr';
      rmUSB:     Result := 'usb';
      rmLSB:     Result := 'lsb';
      rmFM:      Result := 'nfm';
      rmAM:      Result := 'am';
      rmFSK:     Result := 'rtty';
      rmData:    Result := 'digu';
      rmDataRev: Result := 'digl';
   else
      Result := 'digu';
   end;

   // Refuse to send a modulation this server never advertised: an unknown
   // string is silently ignored, which presents as "mode changes do nothing".
   if (FModulations.Count > 0) and (FModulations.IndexOf(Result) < 0) then
      begin
      logger.Warn('[TCI] server does not list modulation "%s" -- falling back to digu', [Result]);
      Result := 'digu';
      end;
end;

{ -------------------------------------------------------------- outbound -- }

procedure TTCIRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   idx: string;
begin
   if vfo = nrVFOB then
      begin
      idx := '1';
      end
   else
      begin
      idx := '0';
      end;
   SendToRadio(Format('vfo:%s,%s,%d;', [TCI_TRX, idx, freq]));
   if mode <> rmNone then
      begin
      SetMode(mode, vfo);
      end;
end;

procedure TTCIRadio.SetMode(mode: TRadioMode; vfo: TVFO);
begin
   // TCI modulation is per receiver, not per VFO -- there is no vfo argument.
   SendToRadio(Format('modulation:%s,%s;', [TCI_TRX, RadioModeToTCIMode(mode)]));
end;

procedure TTCIRadio.Transmit;
begin
   // Third argument is the TX AUDIO SOURCE.  TR4W does not send audio over TCI,
   // so it is omitted -- passing ',tci' would tell the server to expect an
   // audio stream that never arrives.
   SendToRadio(Format('trx:%s,true;', [TCI_TRX]));
end;

procedure TTCIRadio.Receive;
begin
   SendToRadio(Format('trx:%s,false;', [TCI_TRX]));
end;

procedure TTCIRadio.Split(splitOn: boolean);
var
   opTrx: integer;
begin
   opTrx := StrToIntDef(TCI_TRX, 0);

   // TURNING SPLIT OFF WHEN THE RADIO OWNS THE SLICE.
   // TCI expresses split two different ways, and only one of them is ours to
   // undo.  If the transmitting receiver is not the one we operate, the split
   // is a SECOND RECEIVER -- created on the radio, not by us -- and
   // split_enable cannot touch it.  Proven on the bench 2026-08-02: TR4W sent
   // split_enable:0,false, the server echoed it (already false) and left
   // tx_enable:1,true standing, so the rig kept transmitting on VFO B.
   //
   // Say so instead of pretending.  The RADIO is the source of truth: TR4W must
   // never show 'not split' while the rig is still in split.  See AetherSDR
   // issue #3715 -- per-slice ownership with unified teardown is PROPOSED, not
   // implemented, so today there is no client-side way to close it.
   if (not splitOn) and (FTxTrx <> opTrx) and (not FWeEnabledSplit) then
      begin
      logger.Warn('[TCI] cannot leave split: transmit receiver is trx %d, a slice created on the radio. ' +
                  'split_enable addresses only VFO A/B split within trx %d.', [FTxTrx, opTrx]);
      QuickDisplayError('Cannot disable split -- the transmit slice was created on the radio. Turn it off in the SDR.');
      Exit;   // do NOT send a command that would silently do nothing
      end;

   // Ordering matters for the ON case: enable split BEFORE programming VFO B.
   // The other order loses the VFO B write on real servers (JTDX-proven).
   if splitOn then
      begin
      SendToRadio(Format('split_enable:%s,true;', [TCI_TRX]));
      FWeEnabledSplit := True;
      end
   else
      begin
      SendToRadio(Format('split_enable:%s,false;', [TCI_TRX]));
      FWeEnabledSplit := False;
      end;
end;

procedure TTCIRadio.RITOn(whichVFO: TVFO);
begin
   SendToRadio(Format('rit_enable:%s,true;', [TCI_TRX]));
end;

procedure TTCIRadio.RITOff(whichVFO: TVFO);
begin
   SendToRadio(Format('rit_enable:%s,false;', [TCI_TRX]));
end;

procedure TTCIRadio.XITOn(whichVFO: TVFO);
begin
   SendToRadio(Format('xit_enable:%s,true;', [TCI_TRX]));
end;

procedure TTCIRadio.XITOff(whichVFO: TVFO);
begin
   SendToRadio(Format('xit_enable:%s,false;', [TCI_TRX]));
end;

procedure TTCIRadio.SetRITFreq(whichVFO: TVFO; hz: integer);
begin
   SendToRadio(Format('rit_offset:%s,%d;', [TCI_TRX, hz]));
end;

procedure TTCIRadio.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   SendToRadio(Format('xit_offset:%s,%d;', [TCI_TRX, hz]));
end;

procedure TTCIRadio.RITClear(whichVFO: TVFO);
begin
   SetRITFreq(whichVFO, 0);
end;

procedure TTCIRadio.XITClear(whichVFO: TVFO);
begin
   SetXITFreq(whichVFO, 0);
end;

function TTCIRadio.SetFilterHz(hz: integer; vfo: TVFO): integer;
var
   half: integer;
begin
   // TCI takes the two filter EDGES relative to the carrier, not a width.
   half := Max(1, hz div 2);
   SendToRadio(Format('rx_filter_band:%s,%d,%d;', [TCI_TRX, -half, half]));
   Result := hz;
end;

// The three named widths, in Hz, expressed through the one place that knows how
// to phrase a filter to TCI.  Values chosen to match the Icom family's intent
// (narrow = CW, mid = a tight SSB filter, wide = normal SSB) rather than picked
// fresh, so a contest operator switching radios gets the same three steps.
procedure TTCIRadio.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
var
   hz: integer;
begin
   case filter of
      rfNarrow: hz := 500;
      rfMid:    hz := 1800;
      rfWide:   hz := 2700;
   else
      // The enum has three members, so this is unreachable today -- and is here
      // because a fourth added later must not silently pick a width.
      logger.Warn('[TCI.SetFilter] Unknown filter ordinal %d -- ignored', [Ord(filter)]);
      Exit;
   end;

   SetFilterHz(hz, vfo);
end;

// The TR4W mode cycle, same order as the Icom family so the key does the same
// thing on every radio: LSB -> USB -> CW -> CWRev -> AM -> FM -> LSB.
function TTCIRadio.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
var
   nextMode: TRadioMode;
begin
   case Self.vfo[vfo].mode of
      rmNone, rmLSB: nextMode := rmUSB;
      rmUSB:         nextMode := rmCW;
      rmCW:          nextMode := rmCWRev;
      rmCWRev:       nextMode := rmAM;
      rmAM:          nextMode := rmFM;
      rmFM:          nextMode := rmLSB;
   else
      nextMode := rmUSB;
   end;

   SetMode(nextMode, vfo);
   Result := nextMode;
end;

// TCI has no band command -- it addresses frequency directly -- so a band change
// is a tune to that band's calling frequency.  BandToFreq is the base's own
// table, which is what keeps this radio from growing a second copy of it.
procedure TTCIRadio.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var
   freq: LongInt;
begin
   freq := BandToFreq(band);
   if freq <= 0 then
      begin
      logger.Warn('[TCI.SetBand] No frequency known for band ordinal %d -- ignored',
                  [Ord(band)]);
      Exit;
      end;

   SetFrequency(freq, vfo, Self.vfo[vfo].mode);
end;

// Up through the HF contest bands and round again.  Bands the operator does not
// have are still stepped through, exactly as on the other radios -- filtering
// that is a station-configuration question, not a driver one.
function TTCIRadio.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
var
   nextBand: TRadioBand;
begin
   case Self.vfo[vfo].band of
      rb160m: nextBand := rb80m;
      rb80m:  nextBand := rb40m;
      rb40m:  nextBand := rb20m;
      rb20m:  nextBand := rb15m;
      rb15m:  nextBand := rb10m;
      rb10m:  nextBand := rb160m;
   else
      // Includes rbNone and the WARC/VHF bands: a toggle from somewhere outside
      // the cycle enters it at the top rather than doing nothing.
      nextBand := rb160m;
   end;

   SetBand(nextBand, vfo);
   Result := nextBand;
end;

// TRUE MEANS ERROR/UNSUPPORTED here -- the house convention for this method,
// and it fails closed.  TCI can send CW text (see BufferCW/SendCW) but has no
// command to play a message memory held in the radio, because the "radio" is
// software that has no such memories.
function TTCIRadio.MemoryKeyer(mem: integer): boolean;
begin
   logger.Warn('[TCI.MemoryKeyer] TCI has no radio message memory -- memory %d ignored',
               [mem]);
   Result := True;
end;

{ ------------------------------------------------- the relative-tune group -- }

// THESE FOUR REFUSE IN WRITING, and the reason is worth stating once because it
// applies to all of them.
//
// TCI is an absolute protocol: vfo: and rit_offset: carry a frequency, and there
// is no "nudge" command. A serial radio's RU;/UP; moves by the STEP THE OPERATOR
// SET ON THE RADIO, which the radio knows and we do not. Implementing these as
// read-and-add would require inventing a step size, and would then move a TCI
// radio by a different amount than the K3 sitting next to it on the same key --
// silently, and only noticeably during a contest.
//
// A logged refusal is the better failure: nothing moves, and the log says why.
// Before this they were abstract, so the same key press access-violated.
//
// If TR4W later grows a configured tuning step, these become three lines each.
procedure TTCIRadio.RITBumpUp;
begin
   logger.Warn('[TCI.RITBumpUp] TCI has no relative RIT command and no step size is configured -- ignored');
end;

procedure TTCIRadio.RITBumpDown;
begin
   logger.Warn('[TCI.RITBumpDown] TCI has no relative RIT command and no step size is configured -- ignored');
end;

procedure TTCIRadio.VFOBumpUp(whichVFO: TVFO);
begin
   logger.Warn('[TCI.VFOBumpUp] TCI has no relative tune command and no step size is configured -- ignored');
end;

procedure TTCIRadio.VFOBumpDown(whichVFO: TVFO);
begin
   logger.Warn('[TCI.VFOBumpDown] TCI has no relative tune command and no step size is configured -- ignored');
end;

{ -------------------------------------------------------------------- CW -- }

function TTCIRadio.CWIsFactoryOwned: Boolean;
begin
   // MUST be True: otherwise StopSendingCW never delegates here and Escape
   // cannot abort a message.  That was the K3 bench lesson of 2026-07-31.
   Result := True;
end;

procedure TTCIRadio.BufferCW(cwChars: string);
begin
   FCWBuffer := FCWBuffer + cwChars;
end;

procedure TTCIRadio.SendCW;
begin
   if FCWBuffer = '' then
      begin
      Exit;
      end;
   // Grammar varies between servers -- AetherSDR takes the raw text.  Whether
   // ExpertSDR2/Thetis want a receiver index or an escaped payload is [VERIFY].
   SendToRadio(Format('cw_macros:%s;', [FCWBuffer]));
   FCWBuffer := '';
end;

procedure TTCIRadio.StopCW;
begin
   FCWBuffer := '';
   SendToRadio('cw_macros_stop;');
end;

procedure TTCIRadio.SetCWSpeed(speed: integer);
begin
   // UNREACHABLE while rcCWSpeedSync is withdrawn (see the constructor):
   // RadioObject.SetRadioCWSpeed checks the capability before delegating here.
   // Kept, and kept correct, because the command itself is right -- the server
   // is what cannot accept it.  Restoring the capability restores this path
   // with no edit here.
   speed := Max(FCapabilities.CWSpeedMin, Min(FCapabilities.CWSpeedMax, speed));
   SendToRadio(Format('cw_macros_speed:%d;', [speed]));
end;

initialization
   // String id, NOT the EXPERTTCI enum: that enum stays bound to the HamLib
   // bridge registration until this driver is bench-proven, so an operator can
   // fall back.  Two entries, two DISTINCT display names -- a duplicate display
   // name hides a model, which is a hard rule in this project.
   //
   // discoverable = False: per the TCI discovery contract, _tci._tcp mDNS
   // advertises PERIPHERALS, not radios.  Shipping a Discover button with
   // nothing behind it was the pre-implementation Flex mistake.
   RegisterRadioById('TCI',
      function: TFactoryRadioBase begin Result := TTCIRadio.Create end,
      'TCI (ExpertSDR / Thetis / AetherSDR)', [rlNetwork], 50001, False,
      SerialParams(0, 0, PARITY_NONE, 0)   // network-only; the serial row is unused
   );

end.
