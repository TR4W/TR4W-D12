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
unit uRadioFlexCAT;
{$I ..\tr4w.inc}

{
  FlexRadio Signature Series over SmartSDR CAT -- the ZZ command set.

  Source: SmartSDR CAT User Guide v4.1.5, sections 1.2, 2.2.2.1 and 3.3.
  That document is marked proprietary, so this unit cites sections and states
  behaviour rather than reproducing its tables.

  ONE DRIVER, BOTH TRANSPORTS.  SmartSDR CAT speaks the SAME protocol on a
  FlexVSP virtual COM port and on its TCP port (5002 by default): Kenwood-style
  2-character commands PLUS FlexRadio 4-character ZZxx commands (guide 2.2.2.1).
  So the transport is a port setting, not a different radio -- which is exactly
  how TR4W treats every other dual-link rig.

  DO NOT CONFUSE THIS WITH uRadioFlexAPI.  That unit drives the SmartSDR
  ETHERNET API on TCP 4992, a completely different protocol. Both are legitimate
  ways to reach the same radio:

      SmartSDR CAT, serial or TCP 5002  -> this unit (ZZ command set)
      SmartSDR Ethernet API, TCP 4992   -> uRadioFlexAPI

  WHY ZZ AND NOT THE KENWOOD SUBSET.  SmartSDR CAT also emulates a subset of the
  Kenwood TS-2000 set for programs that have no Flex option (guide 3.2). TR4W has
  a Flex option, so it should use the richer set. The emulation cannot express
  things this radio genuinely does:

    - INDEPENDENT RIT AND XIT OFFSETS.  The Kenwood subset has RT/XT (states) and
      RC/RD/RU, but NO command to read either offset -- the only offset it
      exposes is the single field in IF;. This driver reads ZZRG and ZZXG
      separately, so the radio window can show both.
    - ZZIF has the same limitation and it is worth knowing why: its P3 field
      "contains the XIT frequency when XIT is on; otherwise the RIT frequency"
      (guide 3.3.14). So a status poll alone can NEVER report both. That is the
      cause of the single-offset display NY4I observed on the bench, and it is a
      protocol property, not a race between writers.

  VFO B DOES NOT ALWAYS EXIST.  On these radios a VFO maps to a Slice, and the
  split Slice is CREATED by a CAT split command (ZZSW1;). Before that exists --
  or after it is closed -- VFO B queries are answered with "?;" (guide 1.2).
  That is normal, not an error, and ProcessMsg treats it as such rather than
  logging a fault every poll. It also explains a blank VFO B in the radio window
  when split has not been engaged through CAT: a split set up in the SmartSDR UI
  does not create the CAT-side Slice mapping.

  ****  NOT BENCH-VALIDATED AS A UNIT -- but NY4I has the hardware  ****
  BENCH ORDER (cheapest first):
    1. Frequency and mode on VFO A (ZZIF / ZZMD).
    2. Engage split from TR4W: VFO B should populate; drop split: it goes blank
       again and VFO B queries return "?;". Both are correct.
    3. Set RIT and XIT to DIFFERENT values -- both should now display, which the
       Kenwood path could not do.
}

interface

uses
   uRadioKenwoodBase, uFactoryRadioBase, uRadioBand, SysUtils, StrUtils, Math, Log4D, VC,
     uRadioRegistry, uCWFraming;

const
   // ---- ZZIF answer layout (guide 3.3.14).  1-based positions in the body AFTER
   // the reading thread has stripped the ';' terminator.
   //   ZZIF P1(11) P2(4) P3(6) P4 P5 P6 P7(2) P8 P9(2) P10 P11 P12 P13 P14(2) P15
   FLEXCAT_IF_LEN        = 40;
   FLEXCAT_IF_FREQ_POS   = 5;    // P1, 11 digits, Hz
   FLEXCAT_IF_OFFSET_POS = 20;   // P3, sign + 5 digits  (XIT when XIT on, else RIT)
   FLEXCAT_IF_RIT_POS    = 26;   // P4
   FLEXCAT_IF_XIT_POS    = 27;   // P5
   FLEXCAT_IF_MOX_POS    = 31;   // P8
   FLEXCAT_IF_MODE_POS   = 32;   // P9, 2 digits
   FLEXCAT_IF_SPLIT_POS  = 36;   // P12, "same as FT"

   FLEXCAT_FREQ_DIGITS   = 11;
   FLEXCAT_OFFSET_DIGITS = 5;

   // ---- ZZMD / ZZME mode values (guide 3.3.20) ----
   FLEXMODE_LSB  = '00';
   FLEXMODE_USB  = '01';
   FLEXMODE_CWL  = '03';
   FLEXMODE_CWU  = '04';
   FLEXMODE_FM   = '05';
   FLEXMODE_AM   = '06';
   FLEXMODE_DIGU = '07';
   FLEXMODE_DIGL = '09';
   FLEXMODE_SAM  = '10';
   FLEXMODE_NFM  = '11';
   FLEXMODE_DFM  = '12';
   FLEXMODE_FDV  = '20';
   FLEXMODE_RTTY = '30';
   FLEXMODE_DSTR = '40';

type
  TFlexCAT = class(TKenwoodProtocolRadio)
  protected
    function  ModeNumToMode(const s: string): TRadioMode;
    function  ModeToFlexNum(mode: TRadioMode): string;
    function  OffsetToFlex(hz: integer): string;
    function  FlexToOffset(const s: string): integer;
    procedure ParseZZIF(const msg: string);
  public
    constructor Create; reintroduce;

    procedure ProcessMsg(msg: string); override;
    procedure PollRadioState; override;

    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    procedure Transmit; override;
    procedure Receive; override;
    procedure Split(splitOn: boolean); override;

    procedure RITOn(whichVFO: TVFO); override;
    procedure RITOff(whichVFO: TVFO); override;
    procedure XITOn(whichVFO: TVFO); override;
    procedure XITOff(whichVFO: TVFO); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure XITClear(whichVFO: TVFO); override;
    procedure SetRITFreq(whichVFO: TVFO; hz: integer); override;
    procedure SetXITFreq(whichVFO: TVFO; hz: integer); override;

    // ---- remaining TFactoryRadioBase abstracts -----------------------------
    // These are ABSTRACT in the base, so leaving any of them out is not a
    // missing feature -- it is an EAbstractError the moment TR4W calls it.
    // That is exactly what happened the first time this class was instantiated:
    // LogCW.SetUpToSendOnActiveRadio -> FlushCWBufferAndClearPTT -> StopCW
    // killed the program at startup.  Every abstract is therefore implemented
    // here, even where the honest implementation is "this protocol has no such
    // command".
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
    procedure StopCW; override;
    function  CWIsFactoryOwned: Boolean; override;
    procedure SetCWSpeed(speed: integer); override;
    function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
    procedure RITBumpDown; override;
    procedure RITBumpUp; override;
    procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
    function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
    procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
    function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
    function  MemoryKeyer(mem: integer): boolean; override;
    procedure VFOBumpDown(whichVFO: TVFO); override;
    procedure VFOBumpUp(whichVFO: TVFO); override;
  end;

implementation

constructor TFlexCAT.Create;
begin
   // MUST pass ProcessMsg.  The base constructor is `overload`ed, so a bare
   // `inherited Create` compiles cleanly and silently resolves to TObject.Create,
   // skipping ALL base initialisation: baseProcMsg stays nil (so the reading
   // thread has nowhere to deliver a frame and nothing is ever parsed),
   // FLastValidResponse stays 0 (so GetIsConnected reports ~126 years of silence
   // and MaintainSerialLink reopens the port forever), and SocketLock/socket stay
   // nil.  That was the "COM16 will not connect" reopen loop.
   //
   // The reading thread dispatches through baseProcMsg, NOT through the virtual
   // ProcessMsg -- same note as TYaesuBinary's constructor.
   inherited Create(ProcessMsg);
   radioModel := 'FlexRadio (SmartSDR CAT)';
   // SEMICOLON-DELIMITED, on both transports.  This is NOT the factory default
   // and omitting it means the reading thread never frames a reply, so nothing
   // is ever parsed and the radio window stays empty -- which is exactly what
   // happened on NY4I's bench the first time this driver ran.
   Self.readTerminator := ';';

   // POLL CADENCE.  PollRadioState sends FOUR commands (ZZIF;ZZFB;ZZRG;ZZXG;),
   // so this is the Icom case, not the K4 case: it is a heavy state query, not a
   // single frequency read.
   //
   // honorsFreqPollRate MUST be False or uRadioPolling overwrites pollingInterval
   // with the user's FREQUENCY POLL RATE (default 10ms) the moment the radio
   // connects -- see uRadioPolling.pas, "Serial polling interval set to %dms".
   // With it left True the bench saw a poll every ~20ms: ~48 cycles/sec x 4
   // commands, which is the same flooding the legacy Kenwood poller did and the
   // thing this migration exists to stop.
   honorsFreqPollRate := False;
   pollingInterval := 200;

   // What this driver actually reads:
   //   rcReadVFOB     -- ZZFB (when a split Slice exists; see the header)
   //   rcReadSplit    -- ZZIF P12
   //   rcReadTXStatus -- ZZIF P8 (MOX)
   //   rcReadRIT      -- ZZRT/ZZXS states AND ZZRG/ZZXG offsets, separately
   //   rcCWByCAT      -- KY, the Kenwood-subset CW command, which SmartSDR CAT
   //                     accepts on this port.  LOGRADIO already keys this radio
   //                     that way (its KY branch covers FLEX, padding to 24 when
   //                     the port is not Network), so the capability must be
   //                     declared or the driver would contradict what TR4W does.
   // NOT rcSharedRITXITOffset: this radio has INDEPENDENT offset registers, which
   // is the whole reason for reading ZZRG and ZZXG rather than trusting ZZIF P3.
   FCapabilities.Flags := [rcReadVFOB, rcReadSplit, rcReadTXStatus, rcReadRIT,
                           rcCWByCAT];
   FCapabilities.CWSpeedMin := 5;
   FCapabilities.CWSpeedMax := 60;
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync];
   // ---- CW-by-CAT framing --------------------------------------------------
   // Over CAT the Flex keys with the Kenwood-subset KY, so it takes the Kenwood
   // rule: 24 bytes, last chunk filled.  This half of the old `FLEX:` arm was
   // selected by `pad := not network` -- a transport test that only existed
   // because ONE model enum covered two protocols.  TFlexCAT and TFlexAPI are
   // separate classes, so each simply states its own rule and the test is gone.
   FCapabilities.CWFrame := CWFrameRule(24, True);
end;

// ---------------------------------------------------------------------------
// Poll cycle
// ---------------------------------------------------------------------------
procedure TFlexCAT.PollRadioState;
begin
   // ZZIF carries frequency, mode, split, MOX and the RIT/XIT STATES in one
   // answer.  The two offsets must be asked for separately: ZZIF P3 holds only
   // ONE of them (XIT when XIT is on, else RIT -- guide 3.3.14), so a driver
   // that trusted it could never show both at once.
   //
   // ZZFB is asked ONLY while split is on.  VFO B maps to the split Slice, and
   // that Slice does not exist until a CAT split command creates it (guide 1.2),
   // so asking before then earns a "?;" every single cycle -- pure noise in the
   // CAT log and a wasted command on the wire.  ZZIF P12 already tells us whether
   // split is on, so use it.
   //
   // Cost: after split is engaged, VFO B first appears one cycle later (the ZZIF
   // that reports split arrives in the same batch that lacked ZZFB).  At 200 ms
   // that is not observable.
   if Self.localSplitEnabled then
      begin
      Self.SendToRadio('ZZIF;ZZFB;ZZRG;ZZXG;');
      end
   else
      begin
      Self.SendToRadio('ZZIF;ZZRG;ZZXG;');
      end;
end;

// ---------------------------------------------------------------------------
// Conversions
// ---------------------------------------------------------------------------
function TFlexCAT.ModeNumToMode(const s: string): TRadioMode;
begin
   // Guide 3.3.20.  Note BOTH CW variants: the Flex distinguishes CWL and CWU as
   // tuning styles, and TR4W's rmCW/rmCWRev is the closest pair.
   if s = FLEXMODE_LSB then       Result := rmLSB
   else if s = FLEXMODE_USB then  Result := rmUSB
   else if s = FLEXMODE_CWL then  Result := rmCW
   else if s = FLEXMODE_CWU then  Result := rmCWRev
   else if s = FLEXMODE_FM then   Result := rmFM
   else if s = FLEXMODE_AM then   Result := rmAM
   else if s = FLEXMODE_DIGU then Result := rmData
   else if s = FLEXMODE_DIGL then Result := rmDataRev
   else if s = FLEXMODE_SAM then  Result := rmAM     // synchronous AM
   else if s = FLEXMODE_NFM then  Result := rmFM     // narrow FM
   else if s = FLEXMODE_DFM then  Result := rmFM     // digital FM
   else if s = FLEXMODE_RTTY then Result := rmFSK
   else if s = FLEXMODE_FDV then  Result := rmDV
   else if s = FLEXMODE_DSTR then Result := rmDV
   else
      begin
      logger.Warn('[ModeNumToMode] unmapped Flex mode "%s"', [s]);
      Result := rmNone;
      end;
end;

function TFlexCAT.ModeToFlexNum(mode: TRadioMode): string;
begin
   case mode of
      rmLSB:     Result := FLEXMODE_LSB;
      rmUSB:     Result := FLEXMODE_USB;
      rmCW:      Result := FLEXMODE_CWL;
      rmCWRev:   Result := FLEXMODE_CWU;
      rmFM:      Result := FLEXMODE_FM;
      rmAM:      Result := FLEXMODE_AM;
      rmData:    Result := FLEXMODE_DIGU;
      rmDataRev: Result := FLEXMODE_DIGL;
      rmFSK:     Result := FLEXMODE_RTTY;
      rmDV:      Result := FLEXMODE_FDV;
   else
      Result := '';
   end;
end;

// ZZRG / ZZXG take a polarity character then five digits (guide 3.3.30, 3.3.40).
function TFlexCAT.OffsetToFlex(hz: integer): string;
var
   mag: integer;
   sign: Char;
begin
   if hz < 0 then
      begin
      sign := '-';
      end
   else
      begin
      sign := '+';
      end;
   mag := Abs(hz);
   if mag > 99999 then
      begin
      logger.Warn('[OffsetToFlex] %d Hz clamped to 99999', [hz]);
      mag := 99999;
      end;
   Result := sign + Format('%.*d', [FLEXCAT_OFFSET_DIGITS, mag]);
end;

function TFlexCAT.FlexToOffset(const s: string): integer;
begin
   // s is polarity + 5 digits.
   if Length(s) < FLEXCAT_OFFSET_DIGITS + 1 then
      begin
      Result := 0;
      Exit;
      end;
   Result := StrToIntDef(Copy(s, 2, FLEXCAT_OFFSET_DIGITS), 0);
   if s[1] = '-' then
      begin
      Result := -Result;
      end;
end;

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------
procedure TFlexCAT.ParseZZIF(const msg: string);
var
   hz: integer;
   splitNow: boolean;
begin
   if Length(msg) < FLEXCAT_IF_LEN then
      begin
      logger.Warn('[ParseZZIF] short answer (%d chars, expected %d): %s',
                  [Length(msg), FLEXCAT_IF_LEN, msg]);
      Exit;
      end;

   hz := StrToIntDef(Copy(msg, FLEXCAT_IF_FREQ_POS, FLEXCAT_FREQ_DIGITS), -1);
   if hz < 0 then
      begin
      logger.Warn('[ParseZZIF] unreadable frequency "%s"',
                  [Copy(msg, FLEXCAT_IF_FREQ_POS, FLEXCAT_FREQ_DIGITS)]);
      Exit;
      end;
   Self.vfo[nrVFOA].frequency := hz;
   Self.vfo[nrVFOA].band      := FreqToRadioBand(hz);
   Self.vfo[nrVFOA].mode      := ModeNumToMode(Copy(msg, FLEXCAT_IF_MODE_POS, 2));

   // P4 / P5 are the REAL states (guide 3.3.14) even though P3 carries only one
   // of the two offsets.  The offsets themselves come from ZZRG / ZZXG.
   Self.SetRITOn(msg[FLEXCAT_IF_RIT_POS] = '1');
   Self.SetXITOn(msg[FLEXCAT_IF_XIT_POS] = '1');

   // Split off means the split Slice is gone, so VFO B no longer refers to
   // anything.  Clear it on the transition -- PollRadioState stops asking for
   // ZZFB once split drops, so a stale VFO B would otherwise sit in the radio
   // window forever with no poll left to correct it.
   splitNow := msg[FLEXCAT_IF_SPLIT_POS] = '1';
   if Self.localSplitEnabled and (not splitNow) then
      begin
      Self.vfo[nrVFOB].frequency := 0;
      Self.vfo[nrVFOB].band      := rbNone;
      end;
   Self.SetSplitOn(splitNow);

   if msg[FLEXCAT_IF_MOX_POS] = '1' then
      begin
      Self.radioState := rsTransmit;
      end
   else
      begin
      Self.radioState := rsReceive;
      end;
end;

procedure TFlexCAT.ProcessMsg(msg: string);
var
   head: string;
   hz: integer;
begin
   msg := Trim(msg);
   if msg = '' then
      begin
      Exit;
      end;

   // "?;" is the documented answer to a VFO B query when no split Slice exists
   // (guide 1.2).  Expected, not an error -- do not log it every poll.
   if (msg = '?') or (msg = '?;') then
      begin
      Exit;
      end;

   UpdateLastValidResponse;
   head := UpperCase(Copy(msg, 1, 4));

   if head = 'ZZIF' then
      begin
      ParseZZIF(msg);
      end
   else if head = 'ZZFB' then
      begin
      hz := StrToIntDef(Copy(msg, 5, FLEXCAT_FREQ_DIGITS), -1);
      if hz >= 0 then
         begin
         Self.vfo[nrVFOB].frequency := hz;
         Self.vfo[nrVFOB].band      := FreqToRadioBand(hz);
         end;
      end
   else if head = 'ZZFA' then
      begin
      hz := StrToIntDef(Copy(msg, 5, FLEXCAT_FREQ_DIGITS), -1);
      if hz >= 0 then
         begin
         Self.vfo[nrVFOA].frequency := hz;
         Self.vfo[nrVFOA].band      := FreqToRadioBand(hz);
         end;
      end
   else if head = 'ZZRG' then
      begin
      // The point of this driver: RIT and XIT offsets are read INDEPENDENTLY.
      Self.SetRITOffset(FlexToOffset(Copy(msg, 5, MaxInt)));
      end
   else if head = 'ZZXG' then
      begin
      Self.SetXITOffset(FlexToOffset(Copy(msg, 5, MaxInt)));
      end
   else if head = 'ZZMD' then
      begin
      Self.vfo[nrVFOA].mode := ModeNumToMode(Copy(msg, 5, 2));
      end
   else if head = 'ZZME' then
      begin
      Self.vfo[nrVFOB].mode := ModeNumToMode(Copy(msg, 5, 2));
      end;
end;

// ---------------------------------------------------------------------------
// Write path
// ---------------------------------------------------------------------------
procedure TFlexCAT.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
   cmd: string;
begin
   if freq < 0 then
      begin
      logger.Error('[SetFrequency] negative frequency %d', [freq]);
      Exit;
      end;
   if vfo = nrVFOB then
      begin
      cmd := 'ZZFB';
      end
   else
      begin
      cmd := 'ZZFA';
      end;
   // 11 digits, zero-filled (guide 3.3.7 / 3.3.8).
   Self.SendToRadio(Format('%s%.*d;', [cmd, FLEXCAT_FREQ_DIGITS, freq]));
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

procedure TFlexCAT.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
   s: string;
begin
   s := ModeToFlexNum(mode);
   if s = '' then
      begin
      logger.Error('[SetMode] no Flex mode for %d', [Ord(mode)]);
      Exit;
      end;
   if vfo = nrVFOB then
      begin
      Self.SendToRadio('ZZME' + s + ';');
      end
   else
      begin
      Self.SendToRadio('ZZMD' + s + ';');
      end;
end;

procedure TFlexCAT.Transmit;
begin
   Self.SendToRadio('ZZTX1;');
end;

procedure TFlexCAT.Receive;
begin
   Self.SendToRadio('ZZTX0;');
end;

procedure TFlexCAT.Split(splitOn: boolean);
begin
   // ZZSW selects which VFO transmits.  ZZSW1; CREATES the split Slice if none
   // exists, and ZZSW0; removes it (guide 3.3.37) -- so this is also what makes
   // VFO B appear at all.  Split state is read back from ZZIF P12, so nothing is
   // tracked locally here.
   if splitOn then
      begin
      Self.SendToRadio('ZZSW1;');
      end
   else
      begin
      Self.SendToRadio('ZZSW0;');
      end;
end;

// ---------------------------------------------------------------------------
// RIT / XIT -- independent, which is the reason this driver exists
// ---------------------------------------------------------------------------
procedure TFlexCAT.RITOn(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZRT1;');
end;

procedure TFlexCAT.RITOff(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZRT0;');
end;

procedure TFlexCAT.XITOn(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZXS1;');
end;

procedure TFlexCAT.XITOff(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZXS0;');
end;

procedure TFlexCAT.RITClear(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZRC;');
end;

procedure TFlexCAT.XITClear(whichVFO: TVFO);
begin
   Self.SendToRadio('ZZXC;');
end;

procedure TFlexCAT.SetRITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SendToRadio('ZZRG' + OffsetToFlex(hz) + ';');
end;

procedure TFlexCAT.SetXITFreq(whichVFO: TVFO; hz: integer);
begin
   Self.SendToRadio('ZZXG' + OffsetToFlex(hz) + ';');
end;

// ---------------------------------------------------------------------------
// Remaining TFactoryRadioBase abstracts.
//
// GROUNDING.  Only commands the SmartSDR CAT User Guide actually NAMES are sent.
// Where the ZZ set has no such command, the method logs and does nothing rather
// than emit an invented one -- an undefined command is answered with "?;" at
// best, and at worst does something unintended to the radio.
// ---------------------------------------------------------------------------

procedure TFlexCAT.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   // Same shape as the Kenwood serial base: CAT commands are '<cmd><data>;'.
   Self.SendToRadio(Format('%s%s;', [sCmd, sData]));
end;

// ---- CW ---------------------------------------------------------------------
// THIS RADIO DOES SUPPORT CW BY CAT.  SmartSDR CAT accepts the Kenwood KY
// command on the CAT port, and TR4W already drives it: LOGRADIO puts FLEX in the
// Kenwood/Elecraft KY branch (maxLen 24, padded when the port is NOT Network)
// and writes the formatted 'KY...' string through tFactoryObject.SendToRadio.
// So on serial, CW keying flows through SendToRadio -- NOT through the three
// methods below.
//
// BufferCW/SendCW are the NETWORK path's shape (TFlexAPI uses the cwx API, which
// has no length limit and needs no padding -- LOGRADIO 2588-2594 delegates to
// them only when tCATPortType = Network).  On the CAT port they are placeholders,
// consistent with TKenwoodSerial, pending the CW Keyer Factory that will own CW
// keying as its own domain rather than folding it into radio control.
//
// StopCW is the one that must exist regardless: it is called during radio setup
// via LogCW.SetUpToSendOnActiveRadio -> FlushCWBufferAndClearPTT, before any CW
// is sent.  Leaving it abstract killed the program at startup.



function TFlexCAT.CWIsFactoryOwned: Boolean;
begin
   // StopCW below really aborts the keyer, so StopSendingCW may delegate here.
   Result := True;
end;

procedure TFlexCAT.StopCW;
begin
   // Moved from LOGRADIO.StopSendingCW's rtKenwood arm.  ZZSS is a PowerSDR/
   // SmartSDR extended command with no Kenwood-subset equivalent -- the plain
   // KY0;/RX; pair the other Kenwood-protocol radios use does not stop a Flex.
   CWBuffer := '';
   Self.SendToRadio('ZZSS;');
end;

procedure TFlexCAT.SetCWSpeed(speed: integer);
begin
   // KS is a Kenwood-subset command and FLEX is rt:rtKenwood in LOGRADIO's radio
   // table, so SetRadioCWSpeed already sends 'KS%003u;' to this radio today.
   // Same command, same 3-digit form.
   if (speed >= 4) and (speed <= 60) then
      begin
      Self.localCWSpeed := speed;
      Self.SendToRadio(Format('KS%.3d;', [speed]));
      end
   else
      begin
      logger.Debug('[FlexCAT.SetCWSpeed] %d WPM out of range 4-60; ignoring', [speed]);
      end;
end;

function TFlexCAT.MemoryKeyer(mem: integer): boolean;
begin
   // True = "error / unsupported", the convention used across the factory.
   Result := True;
end;

// ---- mode / band ------------------------------------------------------------


function TFlexCAT.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
begin
   // No toggle command; a caller that wants a specific mode uses SetMode.
   Result := Self.vfo[vfo].mode;
end;

procedure TFlexCAT.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var
   freq: LongInt;
begin
   // No band command in the ZZ set -- change band by tuning, as the Kenwood
   // serial base does.
   freq := BandToFreq(band);
   if freq > 0 then
      begin
      Self.SetFrequency(freq, vfo, Self.vfo[vfo].mode);
      end;
end;

function TFlexCAT.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
begin
   Result := Self.vfo[vfo].band;
end;

// ---- filter -----------------------------------------------------------------
// ZZFI (VFO A) and ZZFJ (VFO B) are named in the guide (3.3.9/3.3.10), but this
// copy carries no parameter detail and the filter codes are radio-dependent.
// Left as a no-op until the encoding can be grounded rather than guessed.

procedure TFlexCAT.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
begin
   logger.Debug('[FlexCAT.SetFilter] ZZFI/ZZFJ parameter encoding not yet grounded; ignoring');
end;

function TFlexCAT.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   Result := 0;   // 0 = not supported
end;

// ---- RIT / VFO nudges -------------------------------------------------------

procedure TFlexCAT.RITBumpDown;
begin
   // ZZRD -- "Decrement the RIT Frequency" (guide 3.3.29).  Sent without a
   // parameter, matching the Kenwood RD;/RU; usage this replaces.  UNVERIFIED:
   // the guide names the command but this copy does not give its parameter form.
   Self.SendToRadio('ZZRD;');
end;

procedure TFlexCAT.RITBumpUp;
begin
   // ZZRU -- "Increment VFO A RIT Frequency" (guide 3.3.32).  Same caveat.
   Self.SendToRadio('ZZRU;');
end;

procedure TFlexCAT.VFOBumpDown(whichVFO: TVFO);
begin
   // The ZZ set has no VFO up/down command.  The Kenwood subset's UP;/DN; might
   // work here, but nothing in the guide says so -- not guessed.
   logger.Debug('[FlexCAT.VFOBumpDown] No VFO step command in the ZZ set; ignoring');
end;

procedure TFlexCAT.VFOBumpUp(whichVFO: TVFO);
begin
   logger.Debug('[FlexCAT.VFOBumpUp] No VFO step command in the ZZ set; ignoring');
end;

// THIS UNIT REGISTERS NOTHING -- it is a protocol driver, not a model.
//
// The FLEX registration lives in uRadioFlex6000.pas, which names this class for
// the serial transport and TFlexAPI for the network transport:
//
//     RegisterRadio(FLEX, <TFlexAPI ctor>, <TFlexCAT ctor>,
//                   'FlexRadio 6000', [rlSerial, rlNetwork], 4992, True);
//
// ONE radio, ONE list entry, transport picked by the CAT Port setting.  NY4I:
//
//   "The radio type should be the standard Flex entry. There should not be a new
//    one... When selecting Flex as the radio, the simple question is if the
//    control port is TCP, then use the network code. If not, use the serial code
//    with the ZZ commands."
//
// An earlier version of this unit registered itself by string id as a separate
// "FlexRadio (SmartSDR CAT)" entry.  That was wrong -- it made the operator choose
// between two things that are the same radio.
//
// The TS-2000 emulation layer is not used at all: the ZZ set is strictly richer
// and is available on the serial CAT port (guide 2.2.2.1).



end.
