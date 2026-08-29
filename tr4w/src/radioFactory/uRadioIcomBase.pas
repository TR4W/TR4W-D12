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

 unit uRadioIcomBase;
{$I ..\tr4w.inc}

{
  Icom Radio Base Class with CI-V Protocol Support

  Implements the Icom CI-V (Computer Interface V) protocol for Icom transceivers.

  CI-V Frame Format:
    FE FE [To Address] [From Address] [Command] [Sub-command/Data] FD

  Where:
    FE FE = Preamble
    To Address = Radio address (e.g., 0x94 for IC-7300)
    From Address = Controller address (usually 0xE0)
    Command = Command byte
    Sub-command/Data = Optional data bytes
    FD = End of message

  Common Commands:
    0x03 = Read operating frequency
    0x04 = Read operating mode
    0x05 = Set operating frequency
    0x06 = Set operating mode
    0x07 = Read/Set VFO mode (Main/Sub)
    0x14 = Read/Set various levels
    0x15 = Read/Set meter
    0x1C = TX/RX control

  Usage:
    Create derived classes (e.g., TIcom7300Radio) that set the radioAddress
    and override any radio-specific behavior.
}

interface


uses
  Windows, uFactoryRadioBase, uRadioBand, uIcomNetworkTransport, uIcomNetworkTypes, SysUtils, StrUtils, VC, Log4D,
  uIcomCIV, Classes, SyncObjs, uCWFraming,
  uSpectrumTypes, uIcomScope;   // the panadapter seam and the $27 bandscope decoder

const
  // CI-V Sub-commands for TX/RX
  // PTT.  CI-V command $1C takes a SUBCOMMAND AND A DATA BYTE:
  //
  //     1C 00 01   set transmit
  //     1C 00 00   set receive
  //     1C 00      READ the transmit state -- no data byte
  //     1C 01      READ the ATU state
  //
  // These were $00 and $01 and were passed as the whole payload, so Transmit
  // asked the radio whether it was transmitting and Receive asked about the
  // antenna tuner.  Neither ever keyed anything, and tPTTVIACAT still
  // reported success because a frame HAD been sent.  Found on NY4I's IC-7100
  // over TCI: WSJT-X requested transmit, the log showed
  // FE FE 88 E0 1C 00 FD on the wire, and the radio stayed in receive.
  //
  // Named for what they ARE now -- a full payload, not a subcommand -- so the
  // next caller cannot make the same substitution.
  CIV_PAYLOAD_PTT_ON  = #$00#$01;
  CIV_PAYLOAD_PTT_OFF = #$00#$00;

type
  TIcomRadio = class; // forward — TCIVSendThread holds a back-reference

  TCIVPriority = (civpNormal, civpUrgent);

  { A RAW COPY OF EVERY $27 $00 PAYLOAD, for capturing a fixture.

    nil in normal operation and never assigned by the program.  It exists
    because the ONLY way to establish an Icom's scope geometry is to watch a
    rig send one: the IC-7760's point count is published nowhere, and even the
    IC-9700's is one person's capture rather than a guide.  Freezing real
    payloads is also how the K4 decoder got its regression fixture
    (test/unit/fixtures/k4pan-sample.bin), and the three claims that capture
    overturned are the argument for doing it again here.

    RAW, DELIBERATELY -- upstream of the decoder, so a fixture cannot inherit a
    decoder bug and then be used to prove that decoder right. }
  TIcomScopePayloadProc = procedure(const APayload: TBytes) of object;

  // Serializes all outbound CI-V commands through a single thread with a minimum
  // inter-command delay. Prevents any combination of callers (poll, user actions,
  // transceive follow-ups) from flooding the radio's CI-V input buffer.
  TCIVSendThread = class(TThread)
  private
    FOwner: TIcomRadio;
    FNormalQueue: TStringList;   // FIFO — index 0 is head
    FUrgentQueue: TStringList;   // Drained before normal queue
    FLock: TCriticalSection;
    FHasWork: TEvent;            // Auto-reset; signaled on each Enqueue call
    procedure DrainQueues;
  public
    constructor Create(AOwner: TIcomRadio);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Enqueue(const cmd: string; priority: TCIVPriority = civpNormal);
    procedure Stop;
  end;

  TIcomRadio = class(TFactoryRadioBase)
  private
    FRadioAddress: Byte;          // CI-V address of radio (e.g., 0x94 for IC-7300)
    FControllerAddress: Byte;     // CI-V address of controller (usually 0xE0)
    FCIVBuffer: string;           // Buffer for accumulating CI-V frames
    FCWBuffer: string;            // Buffer for CW text to send

    // Network transport (Icom UDP protocol)
    FNetworkTransport: TIcomNetworkTransport;
    FNetworkUsername: string;
    FNetworkPassword: string;

    // CI-V send queue — serializes outbound commands with inter-command spacing
    FCIVSendThread: TCIVSendThread;

    // Band memory: remembers last frequency per band (like TR4QT)
    FBandMemory: array[TRadioBand] of LongInt;
    FTransceiveChecked: Boolean;  // True after we've queried and logged the transceive state once
    FVFOQueryPending: Boolean;    // True while $25 $00/$01 query pair is in flight; prevents flooding
    FVFOQuerySentTick: DWORD;    // GetTickCount when query was sent; used to expire FVFOQueryPending
    FLastBaseMode: TRadioMode;    // Base mode before data mode overlay (restored when data mode goes off)
    FActiveVFO: TVFO;             // Which VFO is currently active (main); updated via $07 $D2 query/push
    FInitialQueryPending: Boolean; // True after $19 sent; triggers $03/$04 on $19 response
    FFirstMessage: Boolean;        // True until first valid frame received; triggers initial VFO/mode queries
    FTransceiverIDQueried: Boolean; // True once $19 $00 has been sent for this connection (see QueryTransceiverIDOnce)
    FBandEdgesQueried: Boolean;    // True once $02 has been sent for this connection (see QueryBandEdgesOnce)
    FLastRxByteTick: DWORD;        // GetTickCount when serial RX bytes last arrived (bus-quiet gating)
    FLastSentCommand: Byte;        // command byte of the last frame sent -- an NG names no command
    FLastSentSubCommand: Byte;     // its sub-command, or $FF when the frame carried none
    FTXBandsUnsupported: Boolean;  // True once this radio has NAKed $1E (see QueryBandEdgesOnce)
    FXITReadUnsupported: Boolean;  // True once this radio has NAKed $21 $02 (XIT on/off read)
    FLastBandEdgeProbeMHz: integer; // MHz the VFO was on when $02 was last read
    FPollPhase: Integer;            // Rotates through query groups to avoid flooding radio
    FLastSetCWSpeedTick: DWORD;   // GetTickCount at last SetCWSpeed call — suppresses stale echoes
    FDataModeID: Byte;            // Icom data sub-mode: $01=D1 (default), $02=D2, $03=D3 — configurable via RADIO x ICOM DATA MODE ID

    // ---- Bandscope ($27) ----------------------------------------------------
    FScopeGeometry: TIcomScopeGeometry;  // declared by the model -- DeclareScopeGeometry
    FScopeDecoder: TIcomScopeDecoder;    // nil until StartSpectrum; owns the assembly state
    FScopeSpanHz: Integer;               // TOTAL width the RIG reports ($27 $15 x 2); 0 = not yet said
    FScopeStreaming: Boolean;            // StartSpectrum sent the enables and has not stopped them
    FOnScopePayload: TIcomScopePayloadProc;   // capture hook -- see TIcomScopePayloadProc
    procedure ApplyScopeEnables;   // $27 $10 + $27 $11; see OnNetworkStateChange
    procedure ProcessScopeWaveData(const data: string);
    procedure ProcessScopeSpanReply(const data: string);
    function ScopeSelector: string;      // the selector byte $27 $15 and friends carry

    // Actual UDP send — only called by TCIVSendThread.DrainQueues
    procedure DoSendDirect(const s: string);

    // One-shot $19 $00 transceiver-ID query, triggered by the FIRST mode
    // response of the connection rather than the connect burst itself.
    procedure QueryTransceiverIDOnce;

    // One-shot $02 band-edge query.  PROBE, NY4I 2026-08-05 -- see the
    // implementation for what it is for and what it is not yet wired to.
    procedure QueryBandEdgesOnce;
    procedure MaybeReprobeBandEdges(hz: LongInt);
    procedure RearmStartupCommand; override;
    procedure LogBandEdgePayload(const tag: string; const data: string);

    // A CI-V radio can say whether a startup command is even addressable to it.
    function StartupCommandIsSendable(const cmd: string;
                                      out reason: string): boolean; override;

    // Serial bus discipline -- called only by TCIVSendThread.DrainQueues.
    procedure WaitForBusQuiet;
    function SerialInterCommandDelayMs: integer;


    procedure ProcessCIVMessage(msg: string);
    procedure ProcessNetworkCivData(msg: string);
    procedure OnNetworkStateChange(Sender: TObject);

  protected
    FTransceiveMenuBytes: string;  // 2-byte menu item for CI-V transceive query (radio-specific)
    FSupportsExtendedVFOBCommands: Boolean;  // True if radio supports $25/$26 direct VFO B set (almost all modern Icoms)
    FSupportsActiveVFOQuery: Boolean;        // True if radio supports $07 $D2 to read which VFO is active (e.g. IC-7760)
    FDirectFreqRoute: Boolean;               // True → $00 transceive routed directly to FActiveVFO (no round-trip $25 query)
                                             //   Use for radios where $07 $D2 is unreliable but $00 always reflects active VFO
                                             //   (e.g. IC-9700). Overrides FSupportsExtendedVFOBCommands path in $00 handler.
    FMainBandProcessingOnly: Boolean;        // True → radio only supports $25/$26 for MAIN band (IC-9700, IC-9100).
                                             //   In satellite mode these radios return FA (NG) for $25; demotes that
                                             //   NAK log from Warn to Debug so it does not spam the log.
    FActiveVFOInverted: Boolean;             // True → $07 $D2 response byte semantics are inverted:
                                             //   $00 = VFO B active, $01 = VFO A active (IC-9700).
                                             //   IC-7610/IC-7760 use $00 = VFO A active (default False).
    FModeSetIncludesFilter: Boolean;         // True → $06 set-mode carries a trailing filter byte ($06 <mode> <filter>).
                                             //   False → mode byte only ($06 <mode>); old Icoms (IC-718) NAK the filter byte.
    FCWSpeedMin: Integer;                    // CW keyer speed range (wpm) for the $14 0C 000-255 level encode.
    FCWSpeedMax: Integer;                    //   Default 6..48 (modern Icoms); IC-718 is 6..60.
    FSplitStateReadable: Boolean;            // True → radio reports split back ($0F read or $0F transceive push),
                                             //   so leave localSplitEnabled to the radio (source of truth).
                                             //   False → set-only split (IC-718: $0F read NAKs, no push); Split()
                                             //   must track the commanded state locally or the split warning
                                             //   would never appear. Default True; IC-718 overrides to False.
    // Frequency BCD helpers — delegate to standalone functions in uIcomCIV
    function BuildCIVCommand(command: Byte; data: string): string;
    function FreqToBCD(freq: LongInt): string;
    function BCDToFreq(bcd: string): LongInt;
    procedure ProcessCIVFrame(frame: string); virtual;
    function GetIsConnected: boolean; override;
    function GetIsOperational: boolean; override;             // Strict: true only when handshake fully complete
    function GetCanRecycleOnStuckHandshake: boolean; override; // True for network -- fresh AYH is the recovery
    function GetAuthFailed: boolean; override;
    function IsNetworkConnection: boolean;
    function SupportsDataMode: Boolean; virtual;  // now = rcDataMode in FCapabilities.Flags
    // Declare this radio's capability set. Base = modern-Icom default; older/minimal
    // radios override to declare fewer. Called from TIcomRadio.Create (virtual dispatch).
    procedure DefineCapabilities; virtual;

    { ---- Bandscope -----------------------------------------------------------

      DECLARED BY THE MODEL, GUARDED BY THE BASE.  Scope geometry is a per-model
      hardware fact that cannot be inferred from anything else the radio says:
      the IC-7610 differs from the IC-7300 in BOTH point count (689 vs 475) and
      level range (0..200 vs 0..160), and a wrong point count truncates every
      sweep so the right-hand third of the display goes flat.

      DELIBERATELY NOT IN TRadioCapabilities.  Every Icom subclass replaces that
      record's Flags wholesale in DefineCapabilities, and the family has already
      been bitten twice by a value written there being silently wiped -- all
      fourteen keying Icoms came out with CW frame maxLen 0, a legal and silent
      "no limit".  A field here cannot be wiped by an override that does not
      mention it.

      A radio that declares rcSpectrum and never calls this has a geometry of
      zeroes, which IS a legal-looking answer -- so uTestIcomScopeSeam asserts
      exhaustively that the two agree, per CLAUDE.md's rule on
      silently-defaulted fields. }
    procedure DeclareScopeGeometry(APoints, AMaxLevel: Integer);


  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure ProcessMsg(msg: string); override;
    function Connect: integer; override;
    procedure Disconnect; override;
    procedure SendToRadio(s: string); overload; override;
    procedure SendToRadioUrgent(const s: string);  // Bypasses normal queue order (PTT, CW stop)

    // Polling interface implementation
    procedure QueryVFOAFrequency; override;
    procedure QueryVFOBFrequency; override;
    procedure QueryVFOAMode;              // $26 $00 — VFO A mode (when VFO B is active)
    procedure QueryVFOBMode; override;    // $26 $01 — VFO B mode
    procedure QueryActiveVFO; override;   // $07 $D2 — which VFO is active (if FSupportsActiveVFOQuery)
    procedure QueryMode; override;
    procedure QueryTXStatus; override;
    procedure QueryRITState; override;
    procedure QueryXITState; override;
    procedure QueryBand; override;
    procedure QuerySplitState; override;
    procedure PollRadioState; override;

    // Radio control methods
    procedure Transmit; override;
    procedure Receive; override;
    procedure BufferCW(cwChars: string); override;
    procedure SendCW; override;
    procedure StopCW; override;
  procedure DeclareCWProsigns; override;
      function CWIsFactoryOwned: Boolean; override;   // The CI-V drivers key CW themselves ($17 / buffered send).
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
    procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
    function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
    procedure SetCWSpeed(speed: integer); override;
    procedure RITClear(whichVFO: TVFO); override;
    procedure XITClear(whichVFO: TVFO); override;
    procedure RITBumpDown; override;
    procedure RITBumpUp; override;
    procedure RITOn(vfo: TVFO); override;
    procedure RITOff(vfo: TVFO); override;
    procedure XITOn(vfo: TVFO); override;
    procedure XITOff(vfo: TVFO); override;
    procedure Split(splitOn: boolean); override;
    procedure SetRITFreq(vfo: TVFO; hz: integer); override;
    procedure SetXITFreq(vfo: TVFO; hz: integer); override;
    procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
    function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
    procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
    procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
    function  MemoryKeyer(mem: integer): boolean; override;
    function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
    procedure VFOBumpDown(whichVFO: TVFO); override;
    procedure VFOBumpUp(whichVFO: TVFO); override;

    property RadioAddress: Byte read FRadioAddress write FRadioAddress;
    property ControllerAddress: Byte read FControllerAddress write FControllerAddress;
    property NetworkUsername: string read FNetworkUsername write FNetworkUsername;
    property NetworkPassword: string read FNetworkPassword write FNetworkPassword;
    property DataModeID: Byte read FDataModeID write FDataModeID;
    // ---- Bandscope: the panadapter seam ------------------------------------
    // The second implementer of TFactoryRadioBase's spectrum seam, after the
    // K4.  Nothing above the radio layer learns that this one is an Icom --
    // see uIcomScope for how the wire format is turned into TSpectrumFrame.
    function SpectrumAvailable: Boolean; override;
    procedure StartSpectrum; override;
    procedure StopSpectrum; override;
    procedure SetSpectrumSpan(const aSpanHz: Integer); override;
    function SpectrumSpanHz: Integer; override;
    procedure StepSpectrumSpan(const aDirection: Integer); override;
    function PrimarySpectrumSourceId: string; override;
    function SpectrumStreaming: Boolean; override;
    function SpectrumLinkUp: Boolean; override;

    { WHAT THIS RADIO SAYS ITS SCOPE IS, and WHAT IT ACTUALLY SENT.

      READ-ONLY AND PUBLIC, while DeclareScopeGeometry stays protected: only a
      subclass may STATE a geometry, but anyone may ask what was stated -- and
      the bench harness has to, because comparing the two is the only way to
      find a wrong declaration.  That is not hypothetical: the IC-7760's point
      count is published nowhere and its driver carries a provisional guess.

      ScopeMeasuredPoints is the level-byte count of the last completed sweep,
      taken BEFORE truncation to the declared geometry -- so it disagrees with
      ScopeGeometryPoints exactly when the declaration is wrong.  0 before any
      sweep has completed.

      ScopeMeasuredMaxLevel is a LOWER BOUND on the level range, reached only
      if something strong was in the passband.  It can disprove a declared
      maximum; it cannot confirm one. }
    { Which scope this radio's panadapter follows.  Main on every model today;
      a subclass whose Sub scope is the interesting one overrides it.  Used
      both as the SourceId filter and as the selector byte on $27 $15.

      PUBLIC because it is read-only information a caller legitimately wants --
      the seam test asserts that PrimarySpectrumSourceId is exactly what the
      decoder stamps for this id, and nothing else can check that. }
    function ScopeIdToFollow: Byte; virtual;
    function ScopeGeometry: TIcomScopeGeometry;
    function ScopeGeometryPoints: Integer;
    function ScopeGeometryMaxLevel: Integer;
    function ScopeMeasuredPoints: Integer;
    function ScopeMeasuredMaxLevel: Integer;

    // E-2: LOGRADIO used to type-test this class and poke the properties above.
    procedure ApplyNetworkCredentials(const user, pass: string); override;
    procedure ApplyDataModeID(id: integer); override;
    property NetworkTransport: TIcomNetworkTransport read FNetworkTransport;

    // Capture hook for tr4w/test/bench/bench_icomscope.lpr.  See
    // TIcomScopePayloadProc; nothing in the program assigns it.
    property OnScopePayload: TIcomScopePayloadProc
             read FOnScopePayload write FOnScopePayload;
  end;

implementation

var
  logger: TLogLogger;

(* ONE CI-V BYTE AS ONE Char, WITHOUT THE CODEPAGE.

  USE THIS AND NEVER Chr() FOR A CI-V BYTE.  Chr() is WRONG here, and wrong in
  a way that no compiler diagnostic and no reading of the source can show:

    * tr4w.inc sets {$MODESWITCH UnicodeStrings}, so `string` is UTF-16;
    * FPC's Chr() returns an ANSI char, so putting one in a `string` runs
      DefaultSystemCodePage -- which the LCL sets to 65001 (UTF-8);
    * a lone byte >= $80 is not valid UTF-8, so it decodes to U+FFFD, and the
      transport's Byte(Ord(...)) then puts $FD on the wire.

  THIS COMMENT USES PAREN-STAR DELIMITERS ON PURPOSE.  A brace comment cannot
  quote a compiler directive: braces do not nest, so the closing brace of the
  MODESWITCH directive above would end the comment early and everything after
  it would be compiled as code.  NY4I, 2026-08-26: "this has bitten us before".
  (Paren-star does not nest either -- so do not write its delimiters inside
  one, which is exactly the mistake this line replaces.)

  AND CONSTANTS HIDE IT.  FPC folds Chr($A2) at compile time into a UTF-16
  literal, which is correct -- so every Chr() with a literal argument works and
  only the ones with a VARIABLE argument are broken.  Measured, both forms in
  one program:

      Chr($A2)  literal        ->  U+00A2   correct
      Chr(b)    b: Byte = $A2  ->  U+FFFD   corrupt

  WHAT IT COST: every CI-V frame TR4W built carried $FD in BOTH address bytes,
  because a radio address ($A2 on an IC-9700, $94 on an IC-7300, $98 on an
  IC-7610, $A4 on an IC-705) and the controller address ($E0) are variables and
  are all >= $80.  $FD is also the CI-V terminator, so the radio saw
  `FE FE FD` -- a frame that ends before it begins -- and answered nothing.
  Found 2026-08-26 on NY4I's IC-9700 while bringing up the bandscope; the scope
  was the first thing that NEEDED a reply rather than merely sending.

  THE RECEIVE SIDE HAD THE MIRROR IMAGE OF THIS -- see CIV_PREAMBLE1, where it
  is the CONSTANTS that break and runtime casts that work.  Same root cause,
  opposite symptom, which is why fixing one did not reveal the other.

  A TYPECAST, NOT A CONVERSION.  Char(b) reinterprets the ordinal as a UTF-16
  code unit, so codepoint == byte by construction and no codepage is consulted.
  It is the same thing CivRawToStr already does per character, and that
  routine's comment already warned about this hazard for BCD payloads -- the
  address bytes simply never got the same treatment. *)
function CivChr(b: Byte): Char; inline;
begin
   Result := Char(b);
end;


// CI-V send queue tuning
const
  CIV_INTER_COMMAND_DELAY_MS = 25;  // Minimum gap between outbound CI-V commands (network; serial adds a baud-scaled term).

  // Serial CI-V is a shared HALF-DUPLEX bus: transmitting while the radio is
  // answering an earlier command destroys BOTH frames (the rigs jam the bus
  // with FC bytes).  Bench-proven on the IC-718 at 4800 baud: a fixed 25ms gap
  // put the $04 mode query inside the radio's $03 response window on every
  // connect, so the mode display stayed NON.  Two defences, both serial-only:
  //   1. a baud-scaled inter-command gap -- see SerialInterCommandDelayMs;
  //   2. WaitForBusQuiet -- do not start a TX until the RX line has been
  //      silent for CIV_BUS_QUIET_MS (a frame gap), so a response already in
  //      flight is never trampled.  Capped so heavy transceive traffic can
  //      only delay a command, never starve it.
  CIV_BUS_QUIET_MS     = 20;
  CIV_BUS_QUIET_CAP_MS = 250;
                                    // Icom CI-V over network needs ~20-30ms between
                                    // commands to avoid overflowing the radio's input buffer.
  CIV_QUEUE_MAX_NORMAL       = 50;  // Safety cap: drop normal items beyond this depth.
                                    // In normal operation the queue depth is 4 (one poll burst).

// ---- TCIVSendThread --------------------------------------------------------

constructor TCIVSendThread.Create(AOwner: TIcomRadio);
begin
  inherited Create(True);  // Suspended — caller calls Resume
  FOwner := AOwner;
  FNormalQueue := TStringList.Create;
  FUrgentQueue := TStringList.Create;
  FLock := TCriticalSection.Create;
  FHasWork := TEvent.Create(nil, False, False, '');  // Auto-reset, initially non-signaled
  FreeOnTerminate := False;
end;

destructor TCIVSendThread.Destroy;
begin
  FHasWork.Free;
  FLock.Free;
  FUrgentQueue.Free;
  FNormalQueue.Free;
  inherited Destroy;
end;

procedure TCIVSendThread.Execute;
begin
  while not Terminated do
     begin
     FHasWork.WaitFor(50);  // 50ms timeout so we wake even if a signal is missed
     DrainQueues;
     end;
end;

procedure TCIVSendThread.DrainQueues;
var
  cmd: string;
  hasItem: Boolean;
begin
  repeat
     cmd := '';
     hasItem := False;
     FLock.Acquire;
     try
        if FUrgentQueue.Count > 0 then
           begin
           cmd := FUrgentQueue[0];
           FUrgentQueue.Delete(0);
           hasItem := True;
           end
        else if FNormalQueue.Count > 0 then
           begin
           cmd := FNormalQueue[0];
           FNormalQueue.Delete(0);
           hasItem := True;
           end;
     finally
        FLock.Release;
     end;

     if hasItem then
        begin
        FOwner.WaitForBusQuiet;   // serial only: never start a TX over an RX in flight
        FOwner.DoSendDirect(cmd);
        if not Terminated then
           begin
           Sleep(FOwner.SerialInterCommandDelayMs);
           end;
        end;
  until (not hasItem) or Terminated;
end;

procedure TCIVSendThread.Enqueue(const cmd: string; priority: TCIVPriority = civpNormal);
begin
  FLock.Acquire;
  try
     if priority = civpUrgent then
        begin
        FUrgentQueue.Add(cmd)
        end
     else
        begin
        if FNormalQueue.Count >= CIV_QUEUE_MAX_NORMAL then
           begin
           logger.Warn('[TCIVSendThread.Enqueue] Normal queue full (%d items) — dropping command',
                       [FNormalQueue.Count]);
           Exit;
           end;
        FNormalQueue.Add(cmd);
        end;
  finally
     FLock.Release;
  end;
  FHasWork.SetEvent;
end;

procedure TCIVSendThread.Stop;
begin
  Terminate;         // Sets Terminated := True
  FHasWork.SetEvent; // Wake up immediately if waiting
end;

// ---- CI-V Protocol Constants -----------------------------------------------
const
  (* TYPED Char CONSTANTS, AND THE TYPE IS THE WHOLE POINT.

     These were untyped character constants -- `CIV_PREAMBLE1 = #$FE;` -- and
     that spelling made every CI-V frame TR4W received UNPARSEABLE.  Measured
     on a buffer holding FE FE A2 E0 27 11 01 FD, built the same way
     ExtractCivFrames builds one:

         Pos(CIV_PREAMBLE1 + CIV_PREAMBLE2, buf)  =  0     <-- untyped
         Pos(CIV_EOM, buf)                        =  0     <-- untyped
         Pos(Char($FE) + Char($FE), buf)          =  1

     WHY.  tr4w.inc turns on the UnicodeStrings modeswitch, so `string` is
     UTF-16.  An UNTYPED character constant is still 8-bit, so passing one as a
     string PARAMETER converts it through DefaultSystemCodePage -- which the
     LCL sets to 65001 (UTF-8) -- and a lone byte >= $80 is not valid UTF-8, so
     the needle became U+FFFD and matched nothing.  Declaring the type makes
     them UTF-16 by construction and no overload can pick an 8-bit one.

     COMPARISONS WERE NEVER AFFECTED, WHICH IS WHY THIS SURVIVED REVIEW.
     `frame[1] <> CIV_PREAMBLE1` and `frame[Length(frame)] <> CIV_EOM` work
     with either spelling -- the compiler widens the constant in a comparison.
     Only PARAMETER PASSING breaks, so the three Pos() calls in
     ProcessCIVMessage failed while every hand-written check around them
     succeeded.  ProcessCIVMessage therefore reported "N byte(s) in the buffer
     with no preamble" for buffers that visibly began FE FE.

     `readTerminator := CIV_EOM` (the SERIAL frame terminator) was corrupted by
     the same conversion, so this is not a network-only fault.

     Found 2026-08-26 on NY4I's IC-9700 while bringing up the bandscope.  It is
     a migration defect, not a new one: docs record Icom as verified UNDER
     DELPHI and never re-confirmed under FPC, and this is what that gap was
     hiding. *)
  CIV_PREAMBLE1: Char = #$FE;
  CIV_PREAMBLE2: Char = #$FE;
  CIV_EOM: Char = #$FD;

  // CI-V Commands
  CIV_CMD_BAND_EDGES = #$02;   // read band edge frequencies -- see QueryBandEdgesOnce
  CIV_CMD_TX_BANDS   = #$1E;   // $1E 00 = number of TX bands, $1E 01 = their edges
  TX_BANDS_TAG = 'TX bands ($1E)';   // log tag, and the enumeration trigger
  CIV_CMD_READ_FREQ = #$03;
  CIV_CMD_READ_MODE = #$04;
  CIV_CMD_SET_FREQ = #$05;
  CIV_CMD_SET_MODE = #$06;
  CIV_CMD_VFO_MODE = #$07;
  CIV_CMD_SPLIT = #$0F;
  CIV_CMD_LEVELS = #$14;
  CIV_CMD_CW_SEND = #$17;
  CIV_CMD_FILTER = #$1A;
  CIV_CMD_TX_RX = #$1C;
  CIV_CMD_RIT_XIT = #$21;
  CIV_CMD_VFO_SELECT = #$25;
  CIV_CMD_TRANSCEIVER_ID = #$19;


  // CI-V Sub-commands for RIT/XIT ($21)
  // Modern Icom layout (IC-7610, IC-7760, confirmed via pcap):
  //   $21 $00 = shared RIT/XIT offset (read/write, BCD + sign)
  //   $21 $01 = RIT on/off (read: no data, write: $00/$01)
  //   $21 $02 = XIT on/off (read: no data, write: $00/$01)
  CIV_SUBCMD_RIT_OFFSET_READ = #$00;  // Read:  $21 $00 = read shared RIT/XIT offset
  CIV_SUBCMD_RIT_ONOFF_READ  = #$01;  // Read:  $21 $01 = read RIT on/off
  CIV_SUBCMD_XIT_ONOFF_READ  = #$02;  // Read:  $21 $02 = read XIT on/off
  CIV_SUBCMD_RIT_OFF = #$01;          // Write: $21 $01 $00 = RIT off
  CIV_SUBCMD_RIT_ON  = #$01;          // Write: $21 $01 $01 = RIT on
  CIV_SUBCMD_XIT_OFF = #$02;          // Write: $21 $02 $00 = XIT off
  CIV_SUBCMD_XIT_ON  = #$02;          // Write: $21 $02 $01 = XIT on
  CIV_SUBCMD_RIT_FREQ = #$00;         // Write: $21 $00 <BCD> <sign> = set offset

  // CI-V Sub-commands for Split ($0F)
  CIV_SUBCMD_SPLIT_OFF = #$00;
  CIV_SUBCMD_SPLIT_ON = #$01;

  // CI-V Sub-commands for VFO Select ($25)
  CIV_SUBCMD_VFO_A = #$00;
  CIV_SUBCMD_VFO_B = #$01;

  // $17 has NO sub-command.  A CIV_SUBCMD_CW_SEND = #$00 used to be prefixed to
  // the message here; see TIcomRadio.SendCW for why it is gone.

  // CI-V Sub-commands for Filter ($1A)
  CIV_SUBCMD_FILTER_WIDTH = #$03;

  // CI-V Sub-commands for Levels ($14)
  CIV_SUBCMD_CW_SPEED = #$0C;

  // Read: $19 $00 = read the transceiver ID (the model's factory-default CI-V address)
  CIV_SUBCMD_TRANSCEIVER_ID_READ = #$00;

constructor TIcomRadio.Create;
begin
  inherited Create(ProcessMsg);

  // Icom radios require polling
  requiresPolling := True;
  autoUpdateCommand := '';
  pollingInterval := 1000;  // Poll every 1s — transceive pushes handle real-time freq/mode updates;
                             // polling only covers RIT/split/TX/ActiveVFO which change slowly.

  // Default addresses (derived classes override)
  FControllerAddress := $E0;  // Standard controller address
  FRadioAddress := $00;       // Set by derived class

  FCIVBuffer := '';
  FCWBuffer := '';
  readTerminator := CIV_EOM;  // CI-V frames end with FD
  SerialProtocolIsBinary := True;  // CI-V is binary: serial TX/RX must be byte-exact (bytes >= $80 like FE/88/FD), not ASCII/codepage-encoded
  honorsFreqPollRate := False;  // keep pollingInterval at 1s: PollRadioState is a heavy multi-command CI-V state query and freq arrives via transceive -- a 10ms FREQUENCY POLL RATE would flood the CI-V send queue

  // Initialize band memory with typical calling frequencies
  FillChar(FBandMemory, SizeOf(FBandMemory), 0);

  FNetworkTransport := nil;
  FNetworkUsername := '';
  FNetworkPassword := '';
  FLastBaseMode := rmNone;
  FDataModeID := $01;  // Default to D1; override via RADIO x ICOM DATA MODE ID config command
  FInitialQueryPending := False;
  FFirstMessage        := True;
  FTransceiverIDQueried := False;
  FLastRxByteTick      := 0;   // "long ago" -- the first send is never gated
  FDirectFreqRoute          := False;  // Override True in subclass for radios where $07 $D2 is unreliable
  FMainBandProcessingOnly   := False;  // Override True for IC-9700, IC-9100 (satellite-mode $25 returns FA)
  FActiveVFOInverted        := False;  // Override True for IC-9700 ($00=$B active, $01=$A active)
  FPollPhase := 0;

  // ---- Bandscope ----------------------------------------------------------
  // ZEROES ARE THE HONEST DEFAULT.  A model that has a scope declares its
  // geometry in its own constructor (DeclareScopeGeometry); one that does not
  // is left with a geometry SpectrumAvailable refuses, so a radio cannot half
  // advertise a panadapter.  The decoder is not built until StartSpectrum --
  // most stations never open the window, and an idle decoder is 475 or 689
  // bytes per scope of nothing.
  FScopeGeometry := IcomScopeGeometry(0, 0);
  FScopeDecoder := nil;
  FScopeSpanHz := 0;
  FScopeStreaming := False;
  FOnScopePayload := nil;
  FTransceiveMenuBytes := #$01 + #$50;  // Default: IC-7610/IC-7760 menu item; IC-9700 overrides to $01 $28
  FSupportsActiveVFOQuery := False;       // Overridden True by radios that support $07 $D2 (e.g. IC-7760)
  FActiveVFO := nrVFOA;                  // Safe default; updated by $07 $D2 response on connect
  FModeSetIncludesFilter := True;        // Modern Icoms take $06 <mode> <filter>; IC-718 overrides to False

  // Capabilities: each radio declares its own set in DefineCapabilities (virtual,
  // so it dispatches to the actual subclass even from this base ctor).  The
  // hot-path CI-V fields below are a CACHE derived from it -- FCapabilities is the
  // single source of truth (the factory replacement for LOGRADIO's global
  // IcomRadiosThatSupport* typesets).
  DefineCapabilities;

  // ---- CW-by-CAT framing, FAMILY-WIDE (was uCWFraming's `IC78..IC9700:` arm) --
  // 28 bytes per $17 send.  The legacy code TRUNCATED at 28 and dropped the rest
  // -- it never looped -- so a longer message lost its tail silently; stating it
  // as a frame rule means the keyer SPLITS instead, which is what the old comment
  // there asked for ("TODO Optimally, this should be sent in multiple batches").
  //
  // busyFactor 1.25: the CI-V send queue is rate limited (~25 ms a command), so a
  // purely element-based estimate of the message duration runs short on this
  // family, and the poll thread can step on CW still being keyed.
  //
  // Icom spells prosigns as NAMED tokens ('^AR') and has an SN where Elecraft
  // does not -- a third dialect, not a variant of the Kenwood one.
  //
  // SAME "MUST RUN AFTER DefineCapabilities" HAZARD as the flag above, and it bit
  // in exactly the same way: written inside the base DefineCapabilities, every
  // subclass override replaced the record wholesale and all 14 keying Icoms came
  // out with maxLen 0 -- "no limit", a legal and silent answer that would have
  // sent a 40-character message as one 40-byte $17.  Caught by the CW_PINS test,
  // not by the compiler.  A per-model deviation goes in that model's OWN ctor,
  // which runs after this one.
  FCapabilities.CWFrame := CWFrameRule(28, False, 1.25);

  FSupportsExtendedVFOBCommands := rcReadVFOB in FCapabilities.Flags;
  FSplitStateReadable          := rcReadSplit in FCapabilities.Flags;
  FCWSpeedMin                  := FCapabilities.CWSpeedMin;
  FCWSpeedMax                  := FCapabilities.CWSpeedMax;

  radioModel := 'Icom';  // Will be overridden by derived classes
end;

// RESTRICTIVE default: the base promises NOTHING.  Every read capability must be
// declared by the radio's own class (or its family base: TIcomModernRadio,
// TIcomReadLimitedRadio, TIcomLegacyRadio).  This is deliberate fail-safe design:
// a new Icom subclass whose author forgets DefineCapabilities gets a radio with a
// visibly missing feature, NOT one that silently sends $25/$21/$0F/$1C/$1A06
// queries the rig NAKs -- bus collisions that look like a bad cable on the bench.
// (The modern full profile used to live HERE as the default; it moved to
// TIcomModernRadio in uRadioIcomModern.pas.)
procedure TIcomRadio.DefineCapabilities;
begin
  FCapabilities.Flags := [];
  // The CW speed range is an ENCODING PARAMETER for $14 $0C, not a capability
  // claim -- and SetCWSpeed divides by (max - min), so an empty 0..0 range here
  // would trade a mild clamp error for a division by zero.  6..48 is the family
  // norm; the IC-718 (6..60) overrides it.
  FCapabilities.CWSpeedMin := 6;
  FCapabilities.CWSpeedMax := 48;
  // The CW FRAME RULE and prosign dialect are deliberately NOT set here.  This
  // method is replaced wholesale by every subclass override, so a family-wide
  // value must be assigned in the CONSTRUCTOR, after DefineCapabilities returns
  // -- the same hazard that made the retired rcCWFlushDisruptsTiming Include
  // silently do nothing when it sat earlier in this constructor.
end;

destructor TIcomRadio.Destroy;
begin
  // BEFORE the transport goes.  StopSpectrum sends $27 $11 $00 to turn the
  // radio's data output back off, and a send after the transport is freed is a
  // call through a nil pointer.  (StopSpectrum is safe to call when nothing was
  // started -- see its own guard.)
  StopSpectrum;
  FreeAndNil(FScopeDecoder);

  if FNetworkTransport <> nil then
     begin
     FNetworkTransport.Disconnect;
     FreeAndNil(FNetworkTransport);
     end;
  inherited Destroy;
end;

// Returns a human-readable hex string for a raw CI-V frame, e.g. "FE FE A2 E0 1A FD"
// Used for trace-level logging of all sent and received CI-V bytes.
function CIVDataToHex(const s: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(s) do
     begin
     if i > 1 then
        begin
        Result := Result + ' ';
        end;
     Result := Result + IntToHex(Ord(s[i]), 2);
     end;
end;

// Read the transceiver ID ($19 $00) ONCE per connection.  The reply carries one
// byte: the radio's DEFAULT CI-V address (bench-proven on the IC-718: reply
// FE FE E0 5E 19 00 5E FD) -- a fixed per-model code, so the INFO log shows
// what model is REALLY on the wire even when the operator has reconfigured the
// rig's bus address or selected the wrong radio TYPE.
//
// Triggered by the FIRST MODE RESPONSE, deliberately NOT queued into the
// connect burst: CI-V is half-duplex, and appending $19 to the burst put its
// TX on the wire while the radio was still transmitting its $04 mode response
// -- the bench log showed the corrupted echo (7E FE ...), the FC FC FC FC FC
// collision jam, and a dead mode display (NON) as the mode response was
// destroyed.  By the first mode response the burst is finished and the bus has
// a quiet second before the next poll.
procedure TIcomRadio.QueryTransceiverIDOnce;
begin
  if FTransceiverIDQueried then
     begin
     Exit;
     end;
  FTransceiverIDQueried := True;
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_TRANSCEIVER_ID),
                              CIV_SUBCMD_TRANSCEIVER_ID_READ));
end;

// Ask the radio for its BAND EDGE FREQUENCIES ($02), once per connection.
//
// WHY.  TR4W's band-up/down walks one fixed list for every radio (LOGSTUFF's
// BandChangeArray: ... 6m, 2m, 222, 432, 902 ...) and nothing knows which of
// those a given radio actually has.  On an IC-7100 -- HF, 6 m, 2 m, 70 cm --
// band-up from 2 m therefore sends 222.100 MHz, the radio ignores a frequency
// it cannot tune, and TR4W's own band display advances anyway.  Bench, NY4I
// 2026-08-04: the wire showed FE FE 88 E0 05 00 00 10 22 02 FD twice.
//
// WHY ASK THE RADIO rather than tabulate it.  Coverage is per radio AND per
// region: an E-model may have 4 m where a US model does not, and options like
// the IC-9100's 23 cm module change it again.  HamLib's rig_caps carries a
// curated table per model (rigctl -u), but the radio in front of the operator
// is the authority.  This command is in the IC-718 manual and others.
//
// THIS IS A PROBE.  Nothing consumes the answer yet: it is logged so we can see
// what a real 7100 returns -- one pair for the current band, or a list -- before
// designing the coverage capability around it.  An Icom that does not implement
// $02 answers NG, which is harmless and equally informative.
//
// Timing copies QueryTransceiverIDOnce deliberately: fired from the first mode
// response, when the connect burst is over and the bus is quiet.  A CI-V bus
// collision here would corrupt the very response we are trying to read.
// Every byte TR4W sends a CI-V radio belongs to a frame: FE FE <to> <from>
// <cmd> ... FD.  A startup command that is not one cannot mean anything to the
// radio, and worse, it is not inert -- the rig echoes it back on a half-duplex
// bus, so the reader has to resynchronise past bytes that can never begin a
// frame.  Bench, NY4I 2026-08-05: an IC-7100 configured with a leftover K3
// startup command put 4B 59 20 3C 3B ('KY <;') on the bus at every connect, and
// the driver logged "No preamble found in buffer" while it recovered.
//
// So the Icoms refuse it and say why, rather than transmitting it in silence.
// The check is FRAMING ONLY: addresses and command bytes are the operator's
// business -- the point of a raw startup command is to send something TR4W does
// not know about.
function TIcomRadio.StartupCommandIsSendable(const cmd: string;
                                             out reason: string): boolean;
begin
   reason := '';
   Result := True;

   // 6 bytes is the shortest legal frame: FE FE <to> <from> <cmd> FD.
   if Length(cmd) < 6 then
      begin
      reason := 'shorter than the smallest CI-V frame (FE FE <to> <from> <cmd> FD)';
      Result := False;
      Exit;
      end;

   if (cmd[1] <> #$FE) or (cmd[2] <> #$FE) then
      begin
      reason := 'not a CI-V frame -- must begin FE FE';
      Result := False;
      Exit;
      end;

   if cmd[Length(cmd)] <> #$FD then
      begin
      reason := 'not a CI-V frame -- must end FD';
      Result := False;
      Exit;
      end;
end;

// Log a band-edge payload without assuming its shape.  PROBE support: the
// layouts of $02 and $1E 01 are being established on the bench, so this reports
// what arrived and decodes only what it can justify.
//
// A pair is 5 bytes lower edge | $2D | 5 bytes higher edge = 11 bytes, in the
// same little-endian BCD as $03/$05.  A payload may or may not carry a leading
// index/sub-command byte, so both alignments are tried and the one that divides
// evenly is reported.
procedure TIcomRadio.LogBandEdgePayload(const tag: string; const data: string);
var
   offset, ix, pairNo, count: integer;
   lowHz, highHz: LongInt;
begin
   logger.Info('[%s] %s raw (%d bytes): %s',
               [radioModel, tag, Length(data), CIVDataToHex(data)]);

   // A single trailing byte after the sub-command echo is a COUNT, not edges.
   //
   // AND IT IS BCD, like every other number CI-V carries.  The IC-7100 answers
   // $13, which read as hex would be 19 and read as BCD is 13 -- and 13 is
   // exactly its US band list: 160 80 60 40 30 20 17 15 12 10, 6 m, 2 m, 70 cm.
   // Reading it as hex was my bug on the first pass (NY4I bench, 2026-08-05).
   if Length(data) = 2 then
      begin
      count := ((Ord(data[2]) shr 4) * 10) + (Ord(data[2]) and $0F);
      logger.Info('[%s] %s -> count = %d (BCD $%.2x)',
                  [radioModel, tag, count, Ord(data[2])]);

      // $1E 01 with no band number is answered NG (bench-proven), so the count
      // is not decoration: it is how many times to ask.  Enumerate them now --
      // the send queue serialises these behind whatever else is pending.
      // A new enumeration is starting: forget the previous answer rather than
      // appending to it, or a reconnect would double every range.
      ClearCoverage;

      if (tag = TX_BANDS_TAG) and (not FTXBandsUnsupported) and
         (count > 0) and (count <= 30) then
         begin
         for ix := 1 to count do
            begin
            SendToRadio(BuildCIVCommand(Ord(CIV_CMD_TX_BANDS),
                                        #$01 + CivChr(((ix div 10) shl 4) or (ix mod 10))));
            end;
         logger.Info('[%s] %s -> requested edges for bands 1..%d',
                     [radioModel, tag, count]);
         end;
      Exit;
      end;

   offset := -1;
   if (Length(data) mod 11) = 0 then
      begin
      offset := 1;                       // pairs start immediately
      end
   else if ((Length(data) - 1) mod 11) = 0 then
      begin
      offset := 2;                       // one leading index/sub-command byte
      logger.Info('[%s] %s -> leading byte $%.2x (index?)',
                  [radioModel, tag, Ord(data[1])]);
      end
   else if ((Length(data) - 2) mod 11) = 0 then
      begin
      offset := 3;                       // sub-command echo + index
      logger.Info('[%s] %s -> leading bytes $%.2x $%.2x',
                  [radioModel, tag, Ord(data[1]), Ord(data[2])]);
      end;

   if offset < 0 then
      begin
      logger.Info('[%s] %s -> %d bytes is not a whole number of 11-byte pairs; ' +
                  'the layout differs from the manual we have',
                  [radioModel, tag, Length(data)]);
      Exit;
      end;

   ix := offset;
   pairNo := 0;
   while ix + 10 <= Length(data) do
      begin
      Inc(pairNo);
      lowHz  := BCDToFreq(Copy(data, ix, 5));
      highHz := BCDToFreq(Copy(data, ix + 6, 5));
      if (lowHz = FREQ_INVALID) or (highHz = FREQ_INVALID) then
         begin
         // A corrupt edge would define a band that swallows or excludes real
         // frequencies for the rest of the session -- worse than not probing.
         logger.Warn('[%s] band-edge reply has a corrupt BCD frequency -- ignored', [radioModel]);
         Exit;
         end;
      logger.Info('[%s] %s edge %d: %d Hz .. %d Hz  (separator $%.2x)',
                  [radioModel, tag, pairNo, lowHz, highHz, Ord(data[ix + 5])]);

      // $1E IS THE COVERAGE SOURCE; $02 IS NOT.  $1E reports the TRANSMIT
      // segments, which is the question a logger needs -- a band you cannot
      // transmit on is not a band you can work.  $02 reports the tuning span of
      // whichever receiver SECTION the VFO is in (bench-proven: 30 kHz ..
      // 199.999999 MHz on 20 m, 400..470 MHz on 70 cm), so recording it would
      // claim the radio can transmit right across 222 MHz, which is the very
      // bug this exists to fix.
      if tag = TX_BANDS_TAG then
         begin
         AddCoverageRange(lowHz, highHz);
         end;

      Inc(ix, 11);
      end;
end;

// Re-read $02 when the radio moves to a different RECEIVER SECTION.
//
// THE HYPOTHESIS this tests.  On the IC-7100 a bare $02 returned 30 kHz ..
// 199.999999 MHz while the VFO sat on 14.1 MHz -- which is not a band plan and
// not the whole radio, but is EXACTLY the main section's span.  The 7100 also
// has a separate 400-470 MHz section.  If $02 reports the section you are
// currently in, then reading it from 70 cm should return 400-470 rather than
// the same answer, and the command earns its place after all (NY4I: "I cannot
// imagine why they would have that command if we cannot get all the band
// edges").
//
// Sections are coarse on purpose -- below 200 MHz, or at/above 400 MHz -- so
// this fires at most a couple of times a session, not on every tune.
procedure TIcomRadio.RearmStartupCommand;
begin
   inherited RearmStartupCommand;

   // Everything below was LEARNED from the radio that was on this port.  A link
   // drop can mean it was power-cycled -- or that a different rig is there now,
   // which is exactly when a remembered "this radio does not support $1E" would
   // be wrong.  Ask again.
   FBandEdgesQueried    := False;
   FTXBandsUnsupported  := False;
   FXITReadUnsupported  := False;
   FLastBandEdgeProbeMHz := -1;

   // Coverage was read from the radio that WAS on this port.  Keeping it across
   // a swap would let one radio's band plan filter another radio's band changes.
   ClearCoverage;
end;

procedure TIcomRadio.MaybeReprobeBandEdges(hz: LongInt);
var
   section: integer;
begin
   if not FBandEdgesQueried then
      begin
      Exit;   // the connect probe has not run yet; it will read $02 itself
      end;

   if hz >= 400000000 then
      begin
      section := 2;
      end
   else if hz >= 200000000 then
      begin
      section := 1;
      end
   else
      begin
      section := 0;
      end;

   if section = FLastBandEdgeProbeMHz then
      begin
      Exit;
      end;

   FLastBandEdgeProbeMHz := section;
   logger.Info('[%s] Now in receiver section %d (%d Hz) -- re-reading $02 to see ' +
               'whether it is section-relative', [radioModel, section, hz]);
   SendToRadio(BuildCIVCommand(Ord(CIV_CMD_BAND_EDGES), ''));
end;

procedure TIcomRadio.QueryBandEdgesOnce;
begin
  if FBandEdgesQueried then
     begin
     Exit;
     end;
  FBandEdgesQueried := True;
  logger.Info('[%s] Probing band edges ($02) and TX bands ($1E 00 / $1E 01)', [radioModel]);

  // $02 -- the overall tuning range of the main band.  Bench-answered on an
  // IC-7100 (NY4I, 2026-08-05): ONE pair, 30 kHz .. 199.999999 MHz.  That is
  // the whole main receiver, not a band plan, and it OMITS the radio's
  // 400-470 MHz range entirely -- so on its own it would correctly exclude
  // 222 MHz and wrongly exclude 70 cm.  Kept because it is one frame and it
  // bounds the main receiver, but it cannot answer the coverage question.
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_BAND_EDGES), ''));

  // $02 PERMUTATIONS.  NY4I: "I cannot imagine why they would have that command
  // if we cannot get all the band edges."  Agreed -- so try the arguments it
  // might take.  These are cheap (6-7 bytes each), they are sent once per
  // connection, and an NG is now attributed by name, so the log says exactly
  // which of them the radio refused.
  //
  // Each response is logged with its raw payload immediately after the CIV TX
  // line that requested it, so a reply can be matched to its request by reading
  // down the log even though a $02 response does not echo its argument.
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_BAND_EDGES), #$00));
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_BAND_EDGES), #$01));
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_BAND_EDGES), #$02));

  // $1E -- what we actually want, and it is about TRANSMIT, which is the right
  // question for a logger: a band you cannot transmit on is not a band you can
  // work.  $1E 00 = how many TX bands, $1E 01 = their edges.
  //
  // THE FORMAT, from the manual NY4I supplied ("Band edge frequency setting,
  // Command: 02*, 1E 01, 1E 03"):
  //
  //     [edge no. 01-30] [5 bytes lower] [2D] [5 bytes higher]
  //
  // with the footnote that settles the shape: "Edge number is NOT sent with
  // command 02".  So $02 returns 11 bytes and $1E 01 returns 12 -- which
  // matches the IC-7100 exactly (its bare $02 gave 11).  An indexed $02 is
  // therefore not a thing; if segments are selectable it is $1E 01 that takes
  // the number.  $1E 00 tells us how many there are to ask for.
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_TX_BANDS), #$00));
  SendToRadio(BuildCIVCommand(Ord(CIV_CMD_TX_BANDS), #$01));

end;

function TIcomRadio.SupportsDataMode: Boolean;
begin
  // Now derived from the capability set (declared per radio in DefineCapabilities);
  // no subclass override needed -- a radio without $1A06 simply omits rcDataMode.
  Result := rcDataMode in FCapabilities.Flags;
end;

function TIcomRadio.IsNetworkConnection: boolean;
begin
  // Network connection when serial port is not set and IP address is provided
  // Use TFactoryRadioBase() cast to access base class radioAddress (string),
  // not TIcomRadio.RadioAddress which is the CI-V address (Byte)
  Result := (serialPort = NoPort) and
            (Length(TFactoryRadioBase(Self).radioAddress) > 0) and
            (radioPort > 0);
end;

function TIcomRadio.Connect: integer;
begin
  // Start the CI-V send queue for BOTH serial and network connections.
  // Serial: the polling thread and the reading thread both call SendToRadio
  //   concurrently; without a queue they race each other on the serial port,
  //   flooding the radio's CI-V buffer and causing dropped responses.
  // Network: prevents flooding the radio's UDP CI-V input buffer.
  if FCIVSendThread = nil then
     begin
     FCIVSendThread := TCIVSendThread.Create(Self);
     FCIVSendThread.Resume;
     logger.Info('[TIcomRadio.Connect] CI-V send queue thread started');
     end;

  if IsNetworkConnection then
     begin
     logger.Info('[TIcomRadio.Connect] Connecting via Icom network protocol to %s:%d',
                 [TFactoryRadioBase(Self).radioAddress, radioPort]);

     // Create transport if needed
     if FNetworkTransport = nil then
        begin
        FNetworkTransport := TIcomNetworkTransport.Create;
        FNetworkTransport.OnCivData := ProcessNetworkCivData;
        FNetworkTransport.OnStateChange := OnNetworkStateChange;
        if rigLabel <> '' then
           begin
           FNetworkTransport.RadioName := rigLabel + ' ' + radioModel
           end
        else
           begin
           FNetworkTransport.RadioName := radioModel;
           end;
        end;

     // Network mode: frequency and mode arrive via CI-V transceive pushes.
     // RIT, XIT, and split do NOT push — poll those only.
     requiresPolling := True;
     pollingInterval := 1000;  // Poll every 1s; PollRadioState queries RIT/XIT/split/TX only
     FTransceiveChecked := False;

     Result := FNetworkTransport.Connect(TFactoryRadioBase(Self).radioAddress,
                                          radioPort,
                                          FNetworkUsername, FNetworkPassword);
     if Result = 0 then
        begin
        logger.Info('[TIcomRadio.Connect] Network connection initiated to %s:%d',
                    [TFactoryRadioBase(Self).radioAddress, radioPort])
        end
     else
        begin
        logger.Error('[TIcomRadio.Connect] Network connection failed: %d', [Result]);
        end;
     end
  else
     begin
     // Serial connection - use base class
     Result := inherited Connect;
     end;
end;

procedure TIcomRadio.Disconnect;
begin
  // Stop the send queue first — prevents the queue thread from writing to a
  // port/socket that is about to be closed by inherited Disconnect below.
  if FCIVSendThread <> nil then
     begin
     logger.Debug('[TIcomRadio.Disconnect] Stopping CI-V send queue thread');
     FCIVSendThread.Stop;
     FCIVSendThread.WaitFor;
     FreeAndNil(FCIVSendThread);
     logger.Debug('[TIcomRadio.Disconnect] CI-V send queue thread stopped');
     end;

  if IsNetworkConnection and (FNetworkTransport <> nil) then
     begin
     logger.Debug('[TIcomRadio.Disconnect] Calling FNetworkTransport.Disconnect (state=%s)',
                 [IcomStateToString(FNetworkTransport.State)]);
     FNetworkTransport.Disconnect;
     logger.Debug('[TIcomRadio.Disconnect] FNetworkTransport.Disconnect returned, calling FreeAndNil');
     FreeAndNil(FNetworkTransport);
     logger.Debug('[TIcomRadio.Disconnect] FreeAndNil complete');
     end
  else
     begin
     inherited Disconnect;
     end;
end;

// DoSendDirect — the only place that calls FNetworkTransport.SendCivData.
// Must only be called from TCIVSendThread.DrainQueues to preserve inter-command spacing.
procedure TIcomRadio.DoSendDirect(const s: string);
begin
  if logger.IsTraceEnabled then
     begin
     logger.Trace('[%s] CIV TX: %s', [radioModel, CIVDataToHex(s)]);
     end;

  // Remember the command (and sub-command) going out, because a CI-V NG does
  // NOT say what it is refusing -- the whole frame is FE FE <to> <from> FA FD.
  // The send queue serialises and the radio answers before the next frame, so
  // the last command sent is the one being refused.
  //
  // Frame layout: FE FE <to> <from> <cmd> [<sub>] ... FD, so the command is at
  // index 5 and the sub-command, when there is one, at 6.
  if Length(s) >= 5 then
     begin
     FLastSentCommand := Ord(s[5]);
     if Length(s) >= 7 then       // 7 = cmd + at least one data byte + FD
        begin
        FLastSentSubCommand := Ord(s[6]);
        end
     else
        begin
        FLastSentSubCommand := $FF;   // no sub-command in this frame
        end;
     end;

  if IsNetworkConnection and (FNetworkTransport <> nil) then
     begin
     FNetworkTransport.SendCivData(s)
     end
  else
     begin
     inherited SendToRadio(s);
     end;
end;

// SendToRadio — enqueues at normal priority.
// All existing callers (poll, set freq/mode, RIT/XIT, etc.) use this path.
// Queue is active for BOTH serial and network; see Connect for rationale.
procedure TIcomRadio.SendToRadio(s: string);
begin
  if FCIVSendThread <> nil then
     begin
     FCIVSendThread.Enqueue(s, civpNormal)
     end
  else
     begin
     DoSendDirect(s);  // Fallback: queue not yet started (should not happen after Connect)
     end;
end;

// SendToRadioUrgent — enqueues at urgent priority, ahead of any normal items.
// Use for time-critical commands: PTT on/off, CW stop.
procedure TIcomRadio.SendToRadioUrgent(const s: string);
begin
  if FCIVSendThread <> nil then
     begin
     FCIVSendThread.Enqueue(s, civpUrgent)
     end
  else
     begin
     DoSendDirect(s);
     end;
end;

function TIcomRadio.GetIsConnected: boolean;
begin
  if IsNetworkConnection then
     begin
     if FNetworkTransport <> nil then
       // Return True for any active state (connecting OR connected).
       // The polling thread checks IsConnected to decide whether to reconnect.
       // If we return False while in WaitingForLogin the polling thread will
       // call Connect() every ~1 second, aborting the auth handshake before
       // the radio has time to respond.  Only return False when truly disconnected.
        begin
        Result := (FNetworkTransport.State <> icsDisconnected)
        end
     else
        begin
        Result := False;
        end;
     end
  else
     begin
     Result := inherited GetIsConnected;
     end;
end;

// "Operational" is the strict counterpart to IsConnected: True only once the
// transport has finished its full handshake and reached icsConnected.
// Distinct from IsConnected (which stays True during the WaitingForHere /
// WaitingForReady / WaitingForLogin / Authenticated / StreamRequested
// reconnect dance so the polling thread does not interrupt the handshake).
//
// The UI alert color (uRadioPolling.SetRadioAlertState) keys off
// IsOperational so the operator sees "radio lost" magenta the entire time
// the radio is unreachable, instead of clearing back to normal the moment
// a reconnect attempt fires (which is what happened before this override --
// the base class's GetIsOperational returned True unconditionally).
function TIcomRadio.GetIsOperational: boolean;
begin
  if IsNetworkConnection then
    // Operational requires BOTH a completed handshake (state = icsConnected)
    // AND fresh inbound CI-V data.  Icom's UDP transport is connectionless and
    // has no socket-close signal, so a powered-off radio leaves the session in
    // icsConnected indefinitely (unlike the K4's TCP socket, which simply
    // breaks).  The CI-V-freshness gate is what surfaces "radio lost" -- it
    // drives the red freq display and the UDP RadioInfo IsConnected=False via
    // the polling thread's SetRadioAlertState.  Issue #1062.
     begin
     Result := (FNetworkTransport <> nil) and
               (FNetworkTransport.State = icsConnected) and
               FNetworkTransport.CivDataFresh
     end
  else
     begin
     Result := inherited GetIsOperational;
     end;
end;

// Tell the polling thread it's safe to force a Disconnect+Connect cycle
// when we sit in IsConnected=True / IsOperational=False for too long.
// For network Icom this means "the multi-step handshake stalled" and a
// fresh AYH packet is the only recovery (the transport doesn't auto-retry
// the initial $0003).  For serial Icom this state can't really happen, so
// return True only for the network path.
function TIcomRadio.GetCanRecycleOnStuckHandshake: boolean;
begin
  Result := IsNetworkConnection;
end;

function TIcomRadio.GetAuthFailed: boolean;
begin
   if IsNetworkConnection and (FNetworkTransport <> nil) then
      begin
      Result := FNetworkTransport.AuthFailed;
      end
   else
      begin
      Result := False;
      end;
end;

procedure TIcomRadio.ProcessNetworkCivData(msg: string);
begin
  // Called from transport thread when CI-V data arrives via UDP
  // Forward to CI-V message parser
  logger.Trace('[TIcomRadio.ProcessNetworkCivData] Received CI-V data, length: %d', [Length(msg)]);
  ProcessCIVMessage(msg);
end;

procedure TIcomRadio.OnNetworkStateChange(Sender: TObject);
begin
  if FNetworkTransport = nil then Exit;

  logger.Debug('[TIcomRadio.OnNetworkStateChange] Transport state: %s',
              [IcomStateToString(FNetworkTransport.State)]);

  { At StreamRequested the capabilities packet has been received and the transport
    has populated CivAddress with the radio's actual CI-V address. Update
    FRadioAddress now — before the CI-V socket is opened — so all subsequent
    CI-V frames use the correct address. This handles user-customised addresses
    and model variants (e.g. IC-7300MK2 factory default $B6 vs user-set $94).
    NOTE: do NOT check at icsAuthenticated — CivAddress is 0 at that point
    because the capabilities packet arrives after the state transition fires. }
  if FNetworkTransport.State = icsStreamRequested then
     begin
     if FNetworkTransport.CivAddress <> 0 then
        begin
        if FNetworkTransport.CivAddress <> FRadioAddress then
           begin
           logger.Info('[TIcomRadio.OnNetworkStateChange] CI-V address override: ' +
                       'class default $%.2x replaced by radio-reported $%.2x. ' +
                       'All CI-V commands will use $%.2x.',
                       [FRadioAddress, FNetworkTransport.CivAddress,
                        FNetworkTransport.CivAddress]);
           end;
        FRadioAddress := FNetworkTransport.CivAddress;
        end;
     end;

  if FNetworkTransport.State = icsConnected then
     begin
     // CI-V stream is now open. Send Icom-specific one-shot queries.
     // Freq/mode/RIT/XIT/split/TX are handled by the polling thread's connected
     // block (pFactoryRadio), which owns the display-update path.
     // Queries here are for state that the polling thread doesn't know about.
     SendToRadio(BuildCIVCommand($1A, #$05 + FTransceiveMenuBytes));  // Transceive state
     if SupportsDataMode then
        begin
        SendToRadio(BuildCIVCommand($1A, #$06));                       // Data mode on/off
        end;
     SendToRadio(BuildCIVCommand($14, CIV_SUBCMD_CW_SPEED));          // CW speed ($14 $0C)

     (* THE BANDSCOPE ENABLES BELONG HERE, NOT IN StartSpectrum.

        A command sent before the CI-V stream is open is DROPPED -- the
        transport logs "SendCivData called while CI-V stream not open" and
        returns -- and StartSpectrum can easily run first: the window opens
        whenever the operator presses the button, and uPanadapterRestore fires
        it at start-up while the radio is still handshaking.

        THIS COST A WHOLE BENCH SESSION.  On NY4I's IC-9700 the first enable
        ($27 $10, the scope FUNCTION) was dropped this way while the second
        ($27 $11, the CI-V wave output) went out 32 ms later and succeeded.  The
        result is the worst possible symptom: the radio streams perfectly
        well-formed 490-byte sweeps at 30 frames a second, every field correct,
        and every level ZERO.  Nothing errors, nothing is missing, and the
        display is simply flat -- which reads as "the band is dead" rather than
        as a command that never arrived.

        Re-sending unconditionally on every connect is deliberate: these are
        idempotent set commands, a reconnect loses them anyway, and the cost is
        two frames. *)
     ApplyScopeEnables;
     end;
end;


function TIcomRadio.BuildCIVCommand(command: Byte; data: string): string;
begin
  Result := CIV_PREAMBLE1 + CIV_PREAMBLE2 +
            CivChr(FRadioAddress) + CivChr(FControllerAddress) +
            CivChr(command) + data + CIV_EOM;
end;

// Byte-faithful conversions between a CI-V byte carried in a `string` (each Char's
// codepoint is 0..255 == one CI-V byte, exactly as BuildCIVCommand's Chr() produces)
// and the AnsiString byte buffers the uIcomCIV BCD helpers use. These copy bytes
// verbatim; unlike `s := AnsiStr` / `AnsiStr := s`, they do NOT run the ANSI codepage
// (which turns BCD byte $99 into U+2122 and back into '?').
function CivRawToStr(const a: AnsiString): string;
var
  i: Integer;
begin
   SetLength(Result, Length(a));
   for i := 1 to Length(a) do
      begin
      Result[i] := Char(Ord(a[i]));
      end;
end;

function CivStrToRaw(const s: string): AnsiString;
var
  i: Integer;
begin
   SetLength(Result, Length(s));
   for i := 1 to Length(s) do
      begin
      Result[i] := AnsiChar(Ord(s[i]));
      end;
end;

function TIcomRadio.FreqToBCD(freq: LongInt): string;
begin
   Result := CivRawToStr(IcomFreqToBCD(freq));
end;

function TIcomRadio.BCDToFreq(bcd: string): LongInt;
begin
   Result := IcomBCDToFreq(CivStrToRaw(bcd));
end;

// FreqToRadioBand is defined in uRadioBand (implementation uses above).
// All call sites below remain unchanged.


procedure TIcomRadio.ProcessMsg(msg: string);
begin
  // Stamp the RX clock FIRST -- WaitForBusQuiet in the send thread reads this
  // to avoid transmitting over a response that is still arriving.
  FLastRxByteTick := GetTickCount;
  logger.trace('[%s.ProcessMsg] CALLED with length: %d', [radioModel, Length(msg)]);
  // Forward to ProcessCIVMessage to maintain compatibility
  ProcessCIVMessage(msg);
end;

// Serial CI-V bus discipline (see the constants block for the bench story).
procedure TIcomRadio.WaitForBusQuiet;
var
   waited: integer;
begin
   if IsNetworkConnection then
      begin
      Exit;
      end;
   waited := 0;
   while (DWORD(GetTickCount - FLastRxByteTick) < CIV_BUS_QUIET_MS) and
         (waited < CIV_BUS_QUIET_CAP_MS) do
      begin
      Sleep(5);
      Inc(waited, 5);
      end;
end;

// Gap between outbound commands.  Network: the fixed 25ms.  Serial: add the
// time the bus is occupied by the command's own echo plus a typical response
// (~25 bytes of frames at 10 bits/byte) -- at 4800 baud that is ~52ms extra,
// at 19200 ~13ms, vanishing at USB-CAT rates.  Together with WaitForBusQuiet
// this keeps the next command out of the current command's response window.
function TIcomRadio.SerialInterCommandDelayMs: integer;
begin
   Result := CIV_INTER_COMMAND_DELAY_MS;
   if (not IsNetworkConnection) and (serialBaudRate > 0) then
      begin
      Result := Result + (250000 div integer(serialBaudRate));
      end;
end;

procedure TIcomRadio.ProcessCIVMessage(msg: string);
var
  frameStart, frameEnd, nextPreamble: Integer;
  frame: string;
begin
  logger.trace('[%s.ProcessCIVMessage] CALLED with msg length: %d', [radioModel, Length(msg)]);  // Removed String2Hex to avoid circular dependency

  // TReadingThread strips the terminator, so add it back
  if (Length(msg) > 0) and (msg[Length(msg)] <> CIV_EOM) then
     begin
     msg := msg + CIV_EOM;
     end;

  // Add received data to buffer
  FCIVBuffer := FCIVBuffer + msg;
  logger.trace('[%s.ProcessCIVMessage] Buffer length: %d', [radioModel, Length(FCIVBuffer)]);

  // Process complete CI-V frames (FE FE ... FD)
  while True do
     begin
     frameStart := Pos(CIV_PREAMBLE1 + CIV_PREAMBLE2, FCIVBuffer);
     if frameStart = 0 then
        begin
        // THREE DIFFERENT SITUATIONS, and they used to share one message that
        // read like an error in all three (NY4I, 2026-08-05: "the no preamble
        // message is disconcerting").  Nearly every occurrence is the FIRST one:
        // the loop drained the buffer and is simply done.
        if FCIVBuffer = '' then
           begin
           logger.trace('[%s.ProcessCIVMessage] Buffer empty -- all frames processed',
                        [radioModel]);
           end
        else if FCIVBuffer = CIV_PREAMBLE1 then
           begin
           // One FE: the second half of the preamble has not arrived yet.  Normal
           // on a byte-at-a-time serial read; the next chunk completes it.
           logger.trace('[%s.ProcessCIVMessage] Partial preamble (one FE) held for the next read',
                        [radioModel]);
           end
        else
           begin
           // Bytes that cannot begin a frame.  THIS is the one worth seeing, so it
           // says how many and shows them -- an echoed non-CI-V startup command
           // looked exactly like this.  They are KEPT, not discarded: the preamble
           // may still be arriving behind them, and the 1024-byte cap below is the
           // backstop if it never does.
           logger.Warn('[%s.ProcessCIVMessage] %d byte(s) in the buffer with no preamble: %s',
                       [radioModel, Length(FCIVBuffer), CIVDataToHex(FCIVBuffer)]);
           end;
        Break;
        end;

     frameEnd := Pos(CIV_EOM, FCIVBuffer);
     if frameEnd = 0 then
        begin
        // A frame is arriving and its FD has not landed yet -- normal.  Shown with
        // the bytes so a frame that never completes can be told from one that is
        // merely in flight.
        logger.trace('[%s.ProcessCIVMessage] Preamble but no EOM yet, holding %d byte(s): %s',
                     [radioModel, Length(FCIVBuffer), CIVDataToHex(FCIVBuffer)]);
        Break;
        end;

     if frameEnd < frameStart then
        begin
        // EOM before preamble - remove garbage
        Delete(FCIVBuffer, 1, frameEnd);
        Continue;
        end;

     // A half-duplex CI-V bus collision can eat a frame's EOM (FD). The reading
     // thread splits only on FD, so it then hands us two frames merged into one
     // blob with a single trailing FD -- and the extract below would swallow the
     // collision filler and the next frame as one garbage frame (e.g. a $03 reply
     // mis-decoded to a 747-MHz "frequency"). Guard: if another preamble appears
     // before this frame's EOM, the frame at frameStart lost its terminator.
     // Discard it and resync on the later, intact preamble. On a clean stream no
     // second preamble precedes the FD, so this never fires (modern Icoms unaffected).
     nextPreamble := Pos(CIV_PREAMBLE1 + CIV_PREAMBLE2,
                         Copy(FCIVBuffer, frameStart + 2, Length(FCIVBuffer)));
     if nextPreamble > 0 then
        begin
        nextPreamble := nextPreamble + frameStart + 1;  // -> absolute buffer index
        if nextPreamble < frameEnd then
           begin
           logger.trace('[%s.ProcessCIVMessage] Truncated frame at %d (lost EOM), resyncing on preamble at %d',
             [radioModel, frameStart, nextPreamble]);
           Delete(FCIVBuffer, 1, nextPreamble - 1);
           Continue;
           end;
        end;

     // Extract complete frame including preamble and EOM
     frame := Copy(FCIVBuffer, frameStart, frameEnd - frameStart + 1);
     Delete(FCIVBuffer, 1, frameEnd);

     logger.trace('[%s.ProcessCIVMessage] Extracted frame, length: %d', [radioModel, Length(frame)]);

     // Process the frame
     ProcessCIVFrame(frame);
     end;

  // Backstop: a buffer this size means we are holding bytes that will never
  // form a frame.  Say so with the contents rather than dropping them quietly.
  if Length(FCIVBuffer) > 1024 then
     begin
     logger.Warn('[%s.ProcessCIVMessage] Discarding %d unparseable byte(s): %s',
                 [radioModel, Length(FCIVBuffer), CIVDataToHex(Copy(FCIVBuffer, 1, 64))]);
     FCIVBuffer := '';
     end;
end;

procedure TIcomRadio.ProcessCIVFrame(frame: string);
var
  command: Byte;
  data: string;
  edgeIx: integer;   // $02 band-edge probe: walk position
  pairNo: integer;   // $02 band-edge probe: pairs decoded
  freq: LongInt;
  modeNum: Byte;
  radioMode: TRadioMode;
  subCmd: Byte;
  vfoSlot: TVFO;
  offset: LongInt;
begin
  // Minimum frame: FE FE [To] [From] [Cmd] FD = 6 bytes
  if Length(frame) < 6 then
     begin
     Exit;
     end;

  // Verify preamble
  if (frame[1] <> CIV_PREAMBLE1) or (frame[2] <> CIV_PREAMBLE2) then
     begin
     Exit;
     end;

  // Verify EOM
  if frame[Length(frame)] <> CIV_EOM then
     begin
     Exit;
     end;

  // CI-V frame layout: FE FE [dest] [src] [cmd] [data...] FD
  // frame[3] = destination, frame[4] = source.
  // Discard frames addressed TO the radio (echoes of our own outgoing commands).
  // Only process frames FROM the radio: dest = FControllerAddress or $00 (broadcast).
  if (Ord(frame[3]) = FRadioAddress) then
     begin
     if logger.IsTraceEnabled then
        begin
        logger.Trace('[%s] CIV echo (discarded): %s', [radioModel, CIVDataToHex(frame)]);
        end;
     Exit;
     end;

  // Valid frame received - update timestamp for disconnect detection
  UpdateLastValidResponse;

  // On first valid frame from the radio, query current VFO/mode state.
  // This covers the case where CI-V transceive is enabled but no $00/$01 push
  // has arrived yet — the display would otherwise be blank until the operator
  // tunes the VFO.
  if FFirstMessage then
     begin
     FFirstMessage := False;
     logger.trace('[%s] First valid CI-V frame — querying initial VFO frequency and mode', [radioModel]);
     // IC-9700 (FMainBandProcessingOnly): $04 returns only the Main Band mode and cannot
     // distinguish VFO A from VFO B. Use $26 $00/$01 for literal-addressed mode queries.
     // Query freq+mode together per VFO so both arrive as a pair.
     if FMainBandProcessingOnly then
        begin
        QueryVFOAFrequency;   // $25 $00 → nrVFOA
        QueryVFOAMode;        // $26 $00 → nrVFOA
        QueryVFOBFrequency;   // $25 $01 → nrVFOB
        QueryVFOBMode;        // $26 $01 → nrVFOB
        end
     else
        begin
        QueryVFOAFrequency;
        QueryVFOBFrequency;
        QueryMode;            // $04 → active VFO mode (other radios)
        end;
     QueryActiveVFO;  // No-op unless FSupportsActiveVFOQuery = True
     // The $19 $00 transceiver-ID read is deliberately NOT part of this burst
     // -- see QueryTransceiverIDOnce, which fires on the first mode response.
     end;

  if logger.IsTraceEnabled then
     begin
     logger.Trace('[%s] CIV RX: %s', [radioModel, CIVDataToHex(frame)]);
     end;

  // Extract command and data
  command := Ord(frame[5]);
  data := Copy(frame, 6, Length(frame) - 6);  // Everything between command and EOM

  case command of
    $00:  // Unsolicited frequency push — active VFO changed frequency
      begin
        if Length(data) >= 5 then
           begin
           freq := BCDToFreq(Copy(data, 1, 5));
           if freq = FREQ_INVALID then
              begin
              // A collision on the one-wire CI-V bus, not a dial movement. Dropped
              // rather than pushed: see IcomBCDToFreq.
              logger.Warn('[%s] $00 push has a corrupt BCD frequency -- frame ignored', [radioModel]);
              Exit;
              end;
           // A $00 transceive push is how this radio reports the operator turning
           // the dial -- and on the IC-7100 it is the ONLY report of a band change
           // made at the rig, so the section watcher has to see it here as well as
           // on the $25 poll reply.  Bench, 2026-08-05: a move to 432.1 MHz arrived
           // as "$00 freq push" and the re-probe hooked only to $25 never fired.
           MaybeReprobeBandEdges(freq);
           if (FSupportsActiveVFOQuery or FDirectFreqRoute) and not FActiveVFOInverted then
              begin
              // Route directly to FActiveVFO — only for radios where FActiveVFO is
              // reliably current and $00 is the best frequency source.
              // FActiveVFOInverted radios (IC-9700) fall through to the $25 pair path
              // below — $25/$00 and $25/$01 give unambiguous VFO A/B data and avoid
              // the FActiveVFO staleness window that occurs on VFO switch.
              logger.Debug('[%s] $00 freq push: %d Hz → VFO %s (direct)',
                 [radioModel, freq, IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
              Self.vfo[FActiveVFO].Frequency := freq;
              Self.vfo[FActiveVFO].Band := FreqToRadioBand(freq);
              if Self.vfo[FActiveVFO].Band <> rbNone then
                 begin
                 FBandMemory[Self.vfo[FActiveVFO].Band] := freq;
                 end;
              end
           else if FSupportsExtendedVFOBCommands then
              begin
              // Active VFO unknown — must query both slots.
              // Guard and timeout prevent flooding under heavy receive traffic.
              if FVFOQueryPending and (GetTickCount - FVFOQuerySentTick > 2000) then
                 begin
                 logger.Warn('[%s] $25 query timed out — clearing pending flag', [radioModel]);
                 FVFOQueryPending := False;
                 end;
              if not FVFOQueryPending then
                 begin
                 logger.Debug('[%s] $00 freq push (%d Hz) → querying $25/$26 for both VFOs', [radioModel, freq]);
                 FVFOQueryPending := True;
                 FVFOQuerySentTick := GetTickCount;
                 // Query freq+mode together per VFO.
                 // IC-9700 (FMainBandProcessingOnly): also refresh mode — $04 push may arrive
                 // separately but $00 push alone doesn't carry mode data for both VFOs.
                 QueryVFOAFrequency;   // $25 $00 → nrVFOA
                 if FMainBandProcessingOnly then
                    begin
                    QueryVFOAMode;    // $26 $00 → nrVFOA
                    end;
                 QueryVFOBFrequency;   // $25 $01 → nrVFOB
                 if FMainBandProcessingOnly then
                    begin
                    QueryVFOBMode;    // $26 $01 → nrVFOB
                    end;
                 end
              else
                 begin
                 logger.Debug('[%s] $00 freq push (%d Hz) skipped — query already in flight', [radioModel, freq]);
                 end;
              end
           else
              begin
              // Older radios: $00 always refers to VFO A
              logger.Debug('[%s] $00 freq push: %d Hz → VFO A', [radioModel, freq]);
              Self.vfo[nrVFOA].Frequency := freq;
              Self.vfo[nrVFOA].Band := FreqToRadioBand(freq);
              if Self.vfo[nrVFOA].Band <> rbNone then
                 begin
                 FBandMemory[Self.vfo[nrVFOA].Band] := freq;
                 end;
              end;
           end;
      end;

    $01:  // Unsolicited mode (CI-V transceive push)
      begin
        if Length(data) >= 1 then
           begin
           // IC-9700 (FActiveVFOInverted): FActiveVFO is unreliable during and after a
           // VFO swap — routing the $01 push directly to FActiveVFO would write the wrong
           // slot. Use the push as a trigger to refresh all four VFO slots via unambiguous
           // literal-addressed $25 and $26 queries. Both freq and mode are refreshed because
           // a mode change on IC-9700 (e.g. Main/Sub swap) may affect both VFOs.
           if FActiveVFOInverted then
              begin
              logger.Debug('[%s] $01 mode push → triggering $25/$26 full refresh', [radioModel]);
              QueryVFOAFrequency;  // $25 $00 → nrVFOA
              QueryVFOAMode;       // $26 $00 → nrVFOA
              QueryVFOBFrequency;  // $25 $01 → nrVFOB
              QueryVFOBMode;       // $26 $01 → nrVFOB
              end
           else
              begin
              modeNum := Ord(data[1]);
              case modeNum of
                $00: radioMode := rmLSB;
                $01: radioMode := rmUSB;
                $02: radioMode := rmAM;
                $03: radioMode := rmCW;
                $04: radioMode := rmFSK;
                $05: radioMode := rmFM;
                $07: radioMode := rmCWRev;
                $08: radioMode := rmFSKRev;
                $06: radioMode := rmFM;   // WFM — treat as FM
                $12: radioMode := rmPSK;
                $13: radioMode := rmPSKRev;
                $17: radioMode := rmDV;   // D-STAR digital voice
                else radioMode := rmNone;
              end;
              logger.debug('[%s] Transceive mode push: $%.2x → TRadioMode=%d → VFO %s',
                 [radioModel, modeNum, Ord(radioMode), IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
              FLastBaseMode := radioMode;
              Self.vfo[FActiveVFO].Mode := radioMode;
              Self.vfo[FActiveVFO].dataMode := rmNone;  // Mode update clears data overlay
              localDataMode := rmNone;

              // Radio doesn't push $1A $06 on data mode change — query it after voice modes
              if SupportsDataMode and (radioMode in [rmUSB, rmLSB, rmFM, rmAM]) then
                 begin
                 SendToRadio(BuildCIVCommand($1A, #$06));
                 end;

              // $01 = active VFO mode changed. Radio doesn't push $26 unsolicited,
              // so query the INACTIVE VFO mode to keep its display in sync.
              // If VFO A is active → VFO B is inactive ($26 $01).
              // If VFO B is active → VFO A is inactive ($26 $00).
              if FSupportsExtendedVFOBCommands then
                 begin
                 if FActiveVFO = nrVFOA then
                    begin
                    QueryVFOBMode   // $26 $01 → nrVFOB (inactive)
                    end
                 else
                    begin
                    QueryVFOAMode;  // $26 $00 → nrVFOA (inactive)
                    end;
                 end;
              end;
           end;
      end;

    $27:  // Bandscope.  Wave data is PUSHED unsolicited once enabled; the rest
          // are replies to what StartSpectrum asked for.
      begin
        // Length 1 is the sub-command alone.  A $27 with no sub-command at all
        // is not something a radio sends, so it is dropped rather than guessed.
        if Length(data) >= 1 then
           begin
           case Ord(data[1]) of
             ICOM_SCOPE_SUB_WAVEDATA:
               begin
                 ProcessScopeWaveData(data);
               end;

             ICOM_SCOPE_SUB_SPAN:
               begin
                 ProcessScopeSpanReply(data);
               end;
             else
               begin
                 // Every other scope setting -- reference level, waterfall
                 // colour, sweep speed, attenuator.  DELIBERATELY NOT PARSED:
                 // the sweep carries its own edges and TR4W scales from the
                 // sweep's own levels, so nothing here is blocked by ignoring
                 // them.  The K4 work reached the same conclusion about its 25
                 // '#' commands and revisited it later with evidence rather
                 // than guessing up front (docs/PANADAPTER_LCL_DESIGN.md 10).
               end;
           end;
           end;
      end;

    $07:  // VFO selection response or transceive push
      begin
        // $07 $D2 <value> — active VFO query response or push when VFO changes.
        // Standard (IC-7610, IC-7760): $00 = VFO A active, $01 = VFO B active.
        // Inverted  (IC-9700):         $00 = VFO B active, $01 = VFO A active.
        if (Length(data) >= 2) and (Ord(data[1]) = $D2) then
           begin
           logger.Trace('[%s] $07 $D2 raw value = $%.2x (FActiveVFOInverted=%s)',
              [radioModel, Ord(data[2]), BoolToStr(FActiveVFOInverted, True)]);
           if FActiveVFOInverted then
              begin
              if Ord(data[2]) = $00 then
                 begin
                 vfoSlot := nrVFOB
                 end
              else
                 begin
                 vfoSlot := nrVFOA;
                 end;
              end
           else
              begin
              if Ord(data[2]) = $00 then
                 begin
                 vfoSlot := nrVFOA
                 end
              else
                 begin
                 vfoSlot := nrVFOB;
                 end;
              end;
           if vfoSlot <> FActiveVFO then
              begin
              // VFO selection changed — refresh both frequencies and modes
              FActiveVFO := vfoSlot;
              logger.Debug('[%s] $07 $D2: active VFO changed to VFO %s — refreshing',
                 [radioModel, IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
              QueryVFOAFrequency;
              QueryVFOAMode;
              QueryVFOBFrequency;
              QueryVFOBMode;
              end
           else
              begin
              logger.Trace('[%s] $07 $D2: VFO %s active (unchanged)',
                 [radioModel, IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
              end;
           end
        else if Length(data) >= 1 then
           begin
           logger.Debug('[%s] $07 response: byte[1]=$%.2x (unhandled sub-cmd)', [radioModel, Ord(data[1])]);
           end;
      end;

    $03:  // Read operating frequency response — returns the active VFO's frequency
      begin
        logger.Debug('[%s] $03 response received, data len=%d', [radioModel, Length(data)]);
        if Length(data) >= 5 then
           begin
           freq := BCDToFreq(Copy(data, 1, 5));
           if freq = FREQ_INVALID then
              begin
              logger.Warn('[%s] $03 reply has a corrupt BCD frequency -- frame ignored', [radioModel]);
              Exit;
              end;
           // $03 returns the currently selected VFO. We only call $03 from the
           // initial connect block (before $25/$00 is available) so treat it as VFO A.
           logger.Debug('[%s] $03 freq: %d Hz -> VFO A', [radioModel, freq]);
           Self.vfo[nrVFOA].Frequency := freq;
           Self.vfo[nrVFOA].Band := FreqToRadioBand(freq);
           if Self.vfo[nrVFOA].Band <> rbNone then
              begin
              FBandMemory[Self.vfo[nrVFOA].Band] := freq;
              end;
           end
        else
           begin
           logger.Warn('[%s] $03 response too short (len=%d), expected >=5', [radioModel, Length(data)]);
           end;
      end;

    $25:  // VFO A/B frequency response (explicit read via $25 $00 / $25 $01)
      begin
        if Length(data) >= 6 then  // IC-7760 format: subcmd(1) + freq(5)
           begin
           subCmd := Ord(data[1]);
           freq := BCDToFreq(Copy(data, 2, 5));
           if freq = FREQ_INVALID then
              begin
              logger.Warn('[%s] $25 reply has a corrupt BCD frequency -- frame ignored', [radioModel]);
              Exit;
              end;
           // $25 $00 = selected (active) VFO → nrVFOA (top display slot)
           // $25 $01 = unselected VFO       → nrVFOB (bottom display slot)
           // Applies to all Icoms including IC-9700 where $00=selected may be
           // physically VFO B — the selected VFO always displays on top.
           if subCmd = $00 then vfoSlot := nrVFOA else vfoSlot := nrVFOB;
           vfo[vfoSlot].Frequency := freq;
           vfo[vfoSlot].Band := FreqToRadioBand(freq);
           if vfo[vfoSlot].Band <> rbNone then
              begin
              FBandMemory[vfo[vfoSlot].Band] := freq;
              end;
           if subCmd = $00 then
              begin
              FVFOQueryPending := False;  // Query pair complete — allow next $00 to trigger
              MaybeReprobeBandEdges(freq);
              end;
           logger.Debug('[%s] $25/$%.2x → radio object vfo[%s] freq = %d Hz',
              [radioModel, subCmd, IfThen(vfoSlot = nrVFOA, 'nrVFOA', 'nrVFOB'), freq]);
           end
        else if Length(data) = 5 then  // IC-7610/standard format: freq(5) only, no subcmd
           begin
           freq := BCDToFreq(data);
           vfo[nrVFOB].Frequency := freq;
           vfo[nrVFOB].Band := FreqToRadioBand(freq);
           if vfo[nrVFOB].Band <> rbNone then
              begin
              FBandMemory[vfo[nrVFOB].Band] := freq;
              end;
           logger.debug('[%s] VFO B freq ($25): %d Hz', [radioModel, freq]);
           end;
      end;

    $04:  // Read mode response
      begin
        QueryTransceiverIDOnce;   // first mode response = connect burst done, bus quiet
        QueryBandEdgesOnce;       // PROBE -- see the implementation
        // IC-9700 (FMainBandProcessingOnly): the radio pushes mode changes as $04 transceive.
        // The $04 data covers only the active VFO and cannot distinguish A from B.
        // Use its arrival as a trigger to refresh both VFOs via explicit $25/$26 queries.
        if FMainBandProcessingOnly then
           begin
           logger.Debug('[%s] $04 mode push → triggering $25/$26 full refresh', [radioModel]);
           QueryVFOAFrequency;   // $25 $00 → nrVFOA
           QueryVFOAMode;        // $26 $00 → nrVFOA
           QueryVFOBFrequency;   // $25 $01 → nrVFOB
           QueryVFOBMode;        // $26 $01 → nrVFOB
           end
        else
           begin
           logger.Debug('[%s] $04 response received, data len=%d', [radioModel, Length(data)]);
           if Length(data) >= 1 then
              begin
              modeNum := Ord(data[1]);
              case modeNum of
                $00: radioMode := rmLSB;
                $01: radioMode := rmUSB;
                $02: radioMode := rmAM;
                $03: radioMode := rmCW;
                $04: radioMode := rmFSK;
                $05: radioMode := rmFM;
                $07: radioMode := rmCWRev;
                $08: radioMode := rmFSKRev;
                $06: radioMode := rmFM;   // WFM — treat as FM
                $12: radioMode := rmPSK;
                $13: radioMode := rmPSKRev;
                $17: radioMode := rmDV;   // D-STAR digital voice
                else radioMode := rmNone;
              end;
              vfoSlot := FActiveVFO;
              logger.Debug('[%s] $04 mode: byte=$%.2x → TRadioMode=%d → VFO %s',
                 [radioModel, modeNum, Ord(radioMode), IfThen(vfoSlot = nrVFOA, 'A', 'B')]);
              FLastBaseMode := radioMode;
              Self.vfo[vfoSlot].Mode := radioMode;
              Self.vfo[vfoSlot].dataMode := rmNone;
              localDataMode := rmNone;

              // $04 doesn't include data mode state — query it for voice modes.
              // Also query the inactive VFO mode, same logic as $01 handler.
              if SupportsDataMode and (radioMode in [rmUSB, rmLSB, rmFM, rmAM]) then
                 begin
                 SendToRadio(BuildCIVCommand($1A, #$06));
                 end;
              if FSupportsExtendedVFOBCommands then
                 begin
                 if vfoSlot = nrVFOA then
                    begin
                    QueryVFOBMode
                    end
                 else
                    begin
                    QueryVFOAMode;
                    end;
                 end;
              end
           else
              begin
              logger.Warn('[%s] $04 response empty (len=%d)', [radioModel, Length(data)]);
              end;
           end;
      end;

    $1A:  // Settings responses — transceive check and data mode
      begin
        if Length(data) >= 1 then
           begin
           // 1A 05 [menu byte 1] [menu byte 2] [value] — CI-V transceive setting query response
           // Menu bytes are radio-specific: IC-7610/IC-7760 = $01 $50; IC-9700 = $01 $28
           if (Ord(data[1]) = $05) and (Length(data) >= 4) and
              (data[2] = FTransceiveMenuBytes[1]) and (data[3] = FTransceiveMenuBytes[2]) then
              begin
              if not FTransceiveChecked then
                 begin
                 FTransceiveChecked := True;
                 if Ord(data[4]) = $01 then
                    begin
                    logger.Info('[%s] CI-V Transceive confirmed ON', [radioModel])
                    end
                 else
                    begin
                    logger.Warn('[%s] CI-V Transceive is OFF — frequency/mode will not update automatically', [radioModel]);
                    MessageBoxW(0,
                      PChar(radioModel + ': CI-V Transceive is disabled on this radio.' + #13#10 +
                      'Frequency and mode will not update automatically in network mode.' + #13#10 + #13#10 +
                      'To fix: Set > Connectors > CI-V Transceive = ON'),
                      'TR4W - Radio Configuration Warning',
                      MB_OK or MB_ICONWARNING or MB_TASKMODAL);
                    end;
                 end;
              end
           // 1A 06 [dm] [filter] — data mode on/off (decorator on top of voice mode)
           // dm=00 → data off; dm=01/02/03 → D1/D2/D3 (all mean "data" to a logger)
           else if SupportsDataMode and (Ord(data[1]) = $06) and (Length(data) >= 2) then
              begin
              if Ord(data[2]) = $00 then
                 begin
                 // Data mode OFF — restore the base voice/CW mode
                 vfo[FActiveVFO].Mode := FLastBaseMode;
                 vfo[FActiveVFO].dataMode := rmNone;
                 localDataMode := rmNone;
                 logger.debug('[%s] Data mode OFF, restored base mode on VFO %s',
                    [radioModel, IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
                 end
              else
                 begin
                 // Data mode ON (D1/D2/D3) — only apply if current mode is a voice mode
                 // Ignore stale responses that arrive after switching to CW/FSK/PSK
                 if vfo[FActiveVFO].Mode in [rmUSB, rmLSB, rmFM, rmAM] then
                    begin
                    FLastBaseMode := vfo[FActiveVFO].Mode;  // Save base mode for restore
                    vfo[FActiveVFO].Mode := rmData;
                    vfo[FActiveVFO].dataMode := rmData;
                    localDataMode := rmData;
                    logger.debug('[%s] Data mode ON (D%d) on VFO %s',
                       [radioModel, Ord(data[2]), IfThen(FActiveVFO = nrVFOA, 'A', 'B')]);
                    end
                 else
                    begin
                    logger.debug('[%s] Data mode ON ignored — current mode is not voice', [radioModel]);
                    end;
                 end;
              end;
           end;
      end;

    $26:  // VFO B frequency/mode (query response or transceive push)
      // IC-7760 format (FSupportsExtendedVFOBCommands): $01 <freq5> <mode> <filter>
      // Standard format: <freq5> <mode> <filter>
      begin
        QueryTransceiverIDOnce;   // first mode response = connect burst done, bus quiet
        QueryBandEdgesOnce;       // PROBE -- see the implementation
        logger.Debug('[%s] $26 response received, data len=%d, extended=%s',
           [radioModel, Length(data), BoolToStr(FSupportsExtendedVFOBCommands, True)]);
        if FSupportsExtendedVFOBCommands then
           begin
           if Length(data) = 1 then
              begin
              // Sub-command echo/ACK from radio — not a data frame, ignore
              logger.debug('[%s] $26 sub-command ACK, ignoring', [radioModel]);
              end
           else if Length(data) >= 7 then
              begin
              // Transceive push (full frame): $01 <freq5> <mode> <filter>
              freq := BCDToFreq(Copy(data, 2, 5));
              vfo[nrVFOB].Frequency := freq;
              vfo[nrVFOB].Band := FreqToRadioBand(freq);
              if vfo[nrVFOB].Band <> rbNone then
                 begin
                 FBandMemory[vfo[nrVFOB].Band] := freq;
                 end;
              modeNum := Ord(data[7]);
              case modeNum of
                $00: radioMode := rmLSB;
                $01: radioMode := rmUSB;
                $02: radioMode := rmAM;
                $03: radioMode := rmCW;
                $04: radioMode := rmFSK;
                $05: radioMode := rmFM;
                $07: radioMode := rmCWRev;
                $08: radioMode := rmFSKRev;
                $06: radioMode := rmFM;
                $12: radioMode := rmPSK;
                $13: radioMode := rmPSKRev;
                $17: radioMode := rmDV;
                else radioMode := rmNone;
              end;
              vfo[nrVFOB].Mode := radioMode;
              logger.Debug('[%s] VFO B freq+mode ($26 push): %d Hz, mode=$%.2x → TRadioMode=%d',
                 [radioModel, freq, modeNum, Ord(radioMode)]);
              end
           else if Length(data) >= 3 then
              begin
              // Mode-only query response: <subCmd> <mode> <filter> [<datamode>]
              // $26 $00 = selected (active) VFO mode → nrVFOA (top display slot)
              // $26 $01 = unselected VFO mode       → nrVFOB (bottom display slot)
              // Consistent with $25 mapping — selected VFO always on top.
              subCmd := Ord(data[1]);
              if subCmd = $00 then vfoSlot := nrVFOA else vfoSlot := nrVFOB;
              modeNum := Ord(data[2]);
              case modeNum of
                $00: radioMode := rmLSB;
                $01: radioMode := rmUSB;
                $02: radioMode := rmAM;
                $03: radioMode := rmCW;
                $04: radioMode := rmFSK;
                $05: radioMode := rmFM;
                $07: radioMode := rmCWRev;
                $08: radioMode := rmFSKRev;
                $06: radioMode := rmFM;
                $12: radioMode := rmPSK;
                $13: radioMode := rmPSKRev;
                $17: radioMode := rmDV;
                else radioMode := rmNone;
              end;
              // IC-7760 $26 mode-only response format: subCmd + mode + dataMode + filter
              // data[2]=mode, data[3]=dataMode ($00=off, $01-$03=D1-D3), data[4]=filter
              // NOTE: dataMode comes BEFORE filter — do not confuse with filter byte.
              if SupportsDataMode and (radioMode in [rmUSB, rmLSB, rmFM, rmAM]) and
                 (Length(data) >= 3) and (Ord(data[3]) <> $00) then
                 begin
                 vfo[vfoSlot].Mode := rmData;
                 vfo[vfoSlot].dataMode := rmData;
                 logger.Debug('[%s] $26/$%.2x → radio object vfo[%s] mode=$%.2x + data mode D%d → rmData',
                    [radioModel, subCmd, IfThen(vfoSlot = nrVFOA, 'nrVFOA', 'nrVFOB'), modeNum, Ord(data[3])]);
                 end
              else
                 begin
                 vfo[vfoSlot].Mode := radioMode;
                 vfo[vfoSlot].dataMode := rmNone;
                 logger.Debug('[%s] $26/$%.2x → radio object vfo[%s] mode=$%.2x → TRadioMode=%d',
                    [radioModel, subCmd, IfThen(vfoSlot = nrVFOA, 'nrVFOA', 'nrVFOB'), modeNum, Ord(radioMode)]);
                 end;
              end
           else
              begin
              logger.Warn('[%s] $26 response unexpected length %d, ignoring',
                 [radioModel, Length(data)]);
              end;
           end
        else
           begin
           // Standard format: <freq5> <mode> <filter>
           if Length(data) >= 5 then
              begin
              freq := BCDToFreq(Copy(data, 1, 5));
              vfo[nrVFOB].Frequency := freq;
              vfo[nrVFOB].Band := FreqToRadioBand(freq);
              if vfo[nrVFOB].Band <> rbNone then
                 begin
                 FBandMemory[vfo[nrVFOB].Band] := freq;
                 end;
              logger.Debug('[%s] VFO B freq ($26): %d Hz', [radioModel, freq]);
              end;
           if Length(data) >= 6 then
              begin
              modeNum := Ord(data[6]);
              case modeNum of
                $00: radioMode := rmLSB;
                $01: radioMode := rmUSB;
                $02: radioMode := rmAM;
                $03: radioMode := rmCW;
                $04: radioMode := rmFSK;
                $05: radioMode := rmFM;
                $07: radioMode := rmCWRev;
                $08: radioMode := rmFSKRev;
                $06: radioMode := rmFM;   // WFM — treat as FM
                $12: radioMode := rmPSK;
                $13: radioMode := rmPSKRev;
                $17: radioMode := rmDV;   // D-STAR digital voice
                else radioMode := rmNone;
              end;
              vfo[nrVFOB].Mode := radioMode;
              logger.Debug('[%s] VFO B mode ($26): byte=$%.2x → TRadioMode=%d',
                 [radioModel, modeNum, Ord(radioMode)]);
              end;
           end;
      end;

    $0F:  // Split on/off (transceive push or poll response)
      begin
        if Length(data) >= 1 then
           begin
           localSplitEnabled := (Ord(data[1]) = $01);
           logger.trace('[%s] Split: %s', [radioModel, BoolToStr(localSplitEnabled, True)]);
           end;
      end;

    $1C:  // TX/RX state (transceive push — radio went to TX or RX)
      begin
        // Sub-command $00 = TX/RX, value $00 = RX, $01 = TX
        if (Length(data) >= 2) and (Ord(data[1]) = $00) then
           begin
           if Ord(data[2]) = $01 then
              begin
              radioState := rsTransmit
              end
           else
              begin
              radioState := rsReceive;
              end;
           logger.trace('[%s] TX state: %s', [radioModel, IfThen(radioState = rsTransmit, 'TX', 'RX')]);
           end;
      end;

    $21:  // RIT/XIT state or offset (poll response or transceive push)
      // Modern Icom layout (IC-7610, IC-7760, confirmed via pcap):
      //   $21 $00 [BCD lo] [BCD hi] [sign] = shared RIT/XIT offset
      //   $21 $01 [on/off]                 = RIT on/off
      //   $21 $02 [on/off]                 = XIT on/off
      begin
        if Length(data) >= 1 then
           begin
           subCmd := Ord(data[1]);
           case subCmd of
             $00:  // Shared RIT/XIT offset
               begin
                 if Length(data) >= 4 then
                    begin
                    offset := BCDToFreq(Copy(data, 2, 2));
                    if Ord(data[4]) <> $00 then
                       begin
                       offset := -offset;
                       end;
                    localRITOffset := offset;
                    localXITOffset := offset;  // Shared
                    vfo[nrVFOA].RITOffset := offset;
                    vfo[nrVFOA].XITOffset := offset;
                    logger.trace('[%s] RIT/XIT offset: %d Hz', [radioModel, offset]);
                    end;
               end;
             $01:  // RIT on/off
               begin
                 if Length(data) >= 2 then
                    begin
                    RITState := (Ord(data[2]) = $01);
                    vfo[nrVFOA].RITState := RITState;
                    logger.trace('[%s] RIT %s', [radioModel, IfThen(RITState, 'ON', 'OFF')]);
                    end;
               end;
             $02:  // XIT on/off
               begin
                 if Length(data) >= 2 then
                    begin
                    XITState := (Ord(data[2]) = $01);
                    vfo[nrVFOA].XITState := XITState;
                    logger.trace('[%s] XIT %s', [radioModel, IfThen(XITState, 'ON', 'OFF')]);
                    end;
               end;
           end;
           end;
      end;

    $14:  // Levels response (CW speed, etc.)
      begin
        if (Length(data) >= 3) and (Ord(data[1]) = $0C) then
           begin
           // CW speed: 2 BCD bytes encoding 0-255, maps to 6-48 WPM
           // Format: $0C <bcd-high> <bcd-low> (e.g., $01 $08 = value 108)
           offset := ((Ord(data[2]) shr 4) * 10) + (Ord(data[2]) and $0F);  // high decimal
           freq := ((Ord(data[3]) shr 4) * 10) + (Ord(data[3]) and $0F);    // low decimal
           offset := offset * 100 + freq;  // combine: 0-255 value
           // Formula (spec): WPM = 6 + value * 42 / 255, round to nearest
           // Integer round-to-nearest: add half the divisor (127) before div
           freq := 6 + (offset * 42 + 127) div 255;
           // Debounce: ignore radio echo for 500ms after a program-initiated SetCWSpeed.
           // Without this, the radio echoes the old speed back and the polling sync loop
           // overwrites CodeSpeed with the stale value, causing the bouncing.
           if GetTickCount - FLastSetCWSpeedTick >= 500 then
              begin
              localCWSpeed := freq;
              logger.debug('[%s] CW speed from radio: %d WPM (BCD $%.2x $%.2x = value %d)',
                           [radioModel, localCWSpeed, Ord(data[2]), Ord(data[3]), offset]);
              end
           else
              begin
              logger.debug('[%s] CW speed echo suppressed (debounce): %d WPM (sent %d ms ago)',
                           [radioModel, freq, GetTickCount - FLastSetCWSpeedTick]);
              end;
           end;
      end;

    Ord(CIV_CMD_BAND_EDGES),   // $02 -- band edges (PROBE, see QueryBandEdgesOnce)
    Ord(CIV_CMD_TX_BANDS):     // $1E -- TX band count / TX band edges
      begin
        if command = Ord(CIV_CMD_BAND_EDGES) then
           begin
           LogBandEdgePayload('Band edges ($02)', data);
           end
        else
           begin
           LogBandEdgePayload(TX_BANDS_TAG, data);
           end;
      end;

    Ord(CIV_CMD_TRANSCEIVER_ID):  // $19 -- ID response ($19 $00 sent once on first valid frame)
      begin
        // Radio replies: FE FE [ctrl] [radio] 19 00 [id] FD.
        // data[1] = $00 (sub-command echo), data[2] = the radio's DEFAULT CI-V
        // address -- a fixed per-model code (IC-718 = $5E, bench-proven), NOT
        // the address the operator may have reconfigured on the rig.  Logged at
        // INFO so a log shows when the configured radio TYPE and the physical
        // radio disagree.
        if Length(data) >= 2 then
           begin
           if Ord(data[2]) = FRadioAddress then
              begin
              logger.Info('[%s] Transceiver ID ($19 $00): $%.2x — matches the configured CI-V address',
                          [radioModel, Ord(data[2])]);
              end
           else
              begin
              logger.Info('[%s] Transceiver ID ($19 $00): $%.2x — configured CI-V address is $%.2x. ' +
                          'A mismatch means the radio TYPE selected in TR4W is not the radio on the port.',
                          [radioModel, Ord(data[2]), FRadioAddress]);
              end;
           end
        else
           begin
           logger.Info('[%s] Transceiver ID response received (no ID byte)', [radioModel]);
           end;
      end;

    $FB:  // Command OK (ACK)
      logger.debug('[%s] Command acknowledged', [radioModel]);

    $FA:  // Command NG (NAK)
      begin
        // The frame is just FE FE <to> <from> FA FD -- it does NOT say what was
        // refused.  DoSendDirect records the last command put on the wire, and
        // the send queue serialises, so that is the one being refused.  Naming
        // it turns "something was rejected" into "this radio does not support
        // $1E", which is the difference between noise and a capability.
        if FLastSentSubCommand = $FF then
           begin
           logger.Debug('[%s] Command $%.2x rejected (NG)',
                        [radioModel, FLastSentCommand])
           end
        else
           begin
           logger.Debug('[%s] Command $%.2x $%.2x rejected (NG)',
                        [radioModel, FLastSentCommand, FLastSentSubCommand]);
           end;

        // A radio that refuses $1E has no band-segment interrogation.  Say so
        // ONCE, at INFO, and stop asking -- both the count and any segments
        // still queued.  This is the capability test: it needs no per-model
        // table, because the radio answers for itself.  (Whether an IC-718
        // supports $1E is therefore something the log will state rather than
        // something we have to know in advance.)
        // A polled command that is refused will be refused every time.  Record
        // it and stop polling, so the log shows the fact once instead of once a
        // second, and the bus carries traffic that can be answered.
        if (FLastSentCommand = $21) and (FLastSentSubCommand = $02) and
           (not FXITReadUnsupported) then
           begin
           FXITReadUnsupported := True;
           logger.Info('[%s] No XIT on/off readback: this radio rejects $21 $02. ' +
                       'Not polling it again on this link.', [radioModel]);
           end;

        if (FLastSentCommand = Ord(CIV_CMD_TX_BANDS)) and
           (not FTXBandsUnsupported) then
           begin
           FTXBandsUnsupported := True;
           logger.Info('[%s] No band-segment interrogation: this radio rejects $1E. ' +
                       'TX coverage cannot be read from it.', [radioModel]);
           end;
      end;
  end;
end;

// Polling interface
procedure TIcomRadio.QueryVFOAFrequency;
begin
  // Prefer $25 $00 (VFO-addressed read) over $03 (active-VFO read).
  // $03 is relative to whichever VFO is selected: when VFO B is active
  // it returns VFO B's frequency and would overwrite the nrVFOA slot.
  // $25 $00 always returns VFO A regardless of selection state.
  // Fall back to $03 only for older radios that do not support $25.
  if FSupportsExtendedVFOBCommands then
     begin
     SendToRadio(BuildCIVCommand($25, CIV_SUBCMD_VFO_A))
     end
  else
     begin
     SendToRadio(BuildCIVCommand($03, ''));
     end;
end;

procedure TIcomRadio.QueryVFOBFrequency;
begin
  // $25 $01 returns VFO B frequency directly in its response
  SendToRadio(BuildCIVCommand($25, CIV_SUBCMD_VFO_B));
end;

procedure TIcomRadio.QueryVFOAMode;
begin
  // $26 $00 — reads VFO A mode when VFO B is active (symmetric to $26 $01 for VFO B).
  // Only meaningful on extended-command radios; response handled in $26 handler by subCmd $00.
  if FSupportsExtendedVFOBCommands then
     begin
     SendToRadio(BuildCIVCommand($26, CIV_SUBCMD_VFO_A));
     end;
end;

procedure TIcomRadio.QueryVFOBMode;
begin
  // $26 $01 returns VFO B mode. Extended radios use sub-command $01, standard Icoms use plain $26.
  if FSupportsExtendedVFOBCommands then
     begin
     SendToRadio(BuildCIVCommand($26, CIV_SUBCMD_VFO_B))
     end
  else
     begin
     SendToRadio(BuildCIVCommand($26, ''));
     end;
end;

procedure TIcomRadio.QueryActiveVFO;
begin
  // $07 $D2 read — returns $00 (main/VFO A active) or $01 (sub/VFO B active).
  // Only supported on radios with FSupportsActiveVFOQuery = True (e.g. IC-7760).
  if FSupportsActiveVFOQuery then
     begin
     SendToRadio(BuildCIVCommand($07, #$D2));
     end;
end;

procedure TIcomRadio.QueryMode;
begin
  SendToRadio(BuildCIVCommand($04, ''));  // Read operating mode
end;

procedure TIcomRadio.QueryTXStatus;
begin
  // Query TX/RX status using command $1C $00
  SendToRadio(BuildCIVCommand($1C, #$00));
end;

procedure TIcomRadio.QueryRITState;
begin
  // $21 $01 = RIT on/off, $21 $00 = shared RIT/XIT offset
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_ONOFF_READ));
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_OFFSET_READ));
end;

procedure TIcomRadio.QueryXITState;
begin
  // This radio has no XIT -- see TRadioCapabilities.HasXIT.  Guarded at every
  // XIT entry point, not just the poll: where RIT and XIT SHARE one offset
  // register ($21 $00), an XIT write would move the RIT instead.
  if not FCapabilities.HasXIT then
     begin
     Exit;
     end;

  // $21 $02 = XIT on/off (the offset is shared with RIT and already queried).
  //
  // NOT EVERY ICOM HAS IT.  The IC-7100's $21 set is $00 (RIT frequency) and
  // $01 (RIT on/off) -- there is no $02 (NY4I, from the manual, 2026-08-05) --
  // so it NAKed this once a second for the life of every session: thousands of
  // frames asking a question already answered no.
  //
  // The radio's refusal IS the answer, so stop asking.  Learned at runtime
  // rather than declared per model, for the same reason the $1E probe is: the
  // radio is the authority on itself, and a table of 28 Icoms would be a guess
  // maintained by hand.  RearmUnsupportedQueries clears this on link-up, since
  // the rig on the port may not be the one that refused.
  if FXITReadUnsupported then
     begin
     Exit;
     end;
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_XIT_ONOFF_READ));
end;

procedure TIcomRadio.QueryBand;
begin
  // Band is derived from frequency
end;

procedure TIcomRadio.QuerySplitState;
begin
  // Query split status using command $0F
  SendToRadio(BuildCIVCommand($0F, ''));
end;

procedure TIcomRadio.PollRadioState;
begin
  // Only poll states that CI-V transceive does NOT push automatically.
  // VFO A freq/mode arrive via $00/$01 transceive pushes — polling $25 $00 every
  // second would overwrite VFO A with physical VFO A when VFO B is active, fighting
  // the transceive push. Leave VFO A entirely to the transceive mechanism.
  // VFO B freq/mode are polled via $26 since transceive only pushes the active VFO.
  // Ask only for what this radio can actually answer.  A radio that NAKs a
  // query gains nothing from being asked once a second, and the NAK is noise
  // in the log when someone is trying to read a real fault.
  //
  // NOTE this is DEFENCE, not a fix for a live bug: every radio that reaches
  // this base inherits rcReadSplit/rcReadTXStatus from TIcomModern or
  // TIcomReadLimited, and the one radio that denies them (the IC-718, which
  // NAKs $21/$0F/$1C/$07) already overrides PollRadioState entirely.  The
  // gates exist so the NEXT radio to declare a capability off is respected
  // without also having to override the poll.
  //
  // rcReadRIT deliberately gates only the RIT/XIT queries: per
  // docs/ADDING_A_RADIO.md a missing flag can mean 'TR4W does not read it'
  // rather than 'the radio cannot report it', so absence is NOT proof of
  // inability -- but asking a radio we would not parse the answer from is
  // pointless either way.
  logger.trace('[%s.PollRadioState] Polling RIT/XIT/Split/TX/ActiveVFO', [radioModel]);
  if Supports(rcReadRIT) then
     begin
     QueryRITState;          // $21 $01
     QueryXITState;          // $21 $02
     end;
  if Supports(rcReadSplit) then
     begin
     QuerySplitState;        // $0F
     end;
  if Supports(rcReadTXStatus) then
     begin
     QueryTXStatus;          // $1C $00
     end;
  QueryActiveVFO;         // $07 $D2 -- no capability covers this; every radio
                          // reaching this base answers it (the IC-718 does not,
                          // and does not use this poll).
end;

// Radio control methods - basic implementations
procedure TIcomRadio.Transmit;
begin
  SendToRadioUrgent(BuildCIVCommand($1C, CIV_PAYLOAD_PTT_ON));   // PTT on — urgent
end;

procedure TIcomRadio.Receive;
begin
  SendToRadioUrgent(BuildCIVCommand($1C, CIV_PAYLOAD_PTT_OFF));  // PTT off — urgent
end;

procedure TIcomRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var
  bcdFreq: string;
begin
  logger.Debug('[%s.SetFrequency] freq=%d VFO=%s TRadioMode=%d', [radioModel, freq, IfThen(vfo = nrVFOA, 'A', 'B'), Ord(mode)]);
  bcdFreq := FreqToBCD(freq);
  if (vfo = nrVFOB) and FSupportsExtendedVFOBCommands then
     begin
     // $25 $01 <freq> sets VFO B frequency directly without disturbing the active VFO.
     // Supported by all modern Icom radios. FSupportsExtendedVFOBCommands defaults to
     // True; set to False in a subclass constructor for older radios that lack it.
     SendToRadio(BuildCIVCommand($25, CIV_SUBCMD_VFO_B + bcdFreq));
     end
  else if vfo = nrVFOB then
     begin
     // No $25 extended VFO-B support (e.g. IC-718): $05 only sets the ACTIVE VFO,
     // so select VFO B ($07 $01), set its frequency, then restore VFO A ($07 $00).
     // Without the swap the split TX frequency lands on VFO A -- the radio changes
     // frequency but never goes into a meaningful split.
     SendToRadio(BuildCIVCommand($07, #$01));   // select VFO B
     SendToRadio(BuildCIVCommand($05, bcdFreq));
     SendToRadio(BuildCIVCommand($07, #$00));   // restore VFO A
     end
  else
     begin
     // VFO A: $05 sets the active VFO directly.
     SendToRadio(BuildCIVCommand($05, bcdFreq));
     end;
  logger.debug('[%s.SetFrequency] Set VFO %s to %d Hz', [radioModel, IfThen(vfo = nrVFOA, 'A', 'B'), freq]);
  // Optimistic update: Icom radios do not transceive-push $00 in response to a
  // CI-V $05 they received — only front-panel VFO changes trigger transceive.
  // Update vfo state immediately so the display reflects the new frequency
  // without waiting for the operator to touch the VFO knob.
  Self.vfo[vfo].Frequency := freq;
  Self.vfo[vfo].Band := FreqToRadioBand(freq);
  if Self.vfo[vfo].Band <> rbNone then
     begin
     FBandMemory[Self.vfo[vfo].Band] := freq;
     end;
  // Set mode if provided. Done after the frequency command so the radio sees
  // freq+mode arrive together. rmNone means "frequency only, leave mode alone".
  if mode <> rmNone then
     begin
     SetMode(mode, vfo);
     end;
  // Also queue a $03 query so the radio confirms the frequency it actually
  // landed on. If the frequency was rejected (out of band, etc.) this
  // corrects the optimistic update with the real value.
  if vfo = nrVFOA then
     begin
     QueryVFOAFrequency
     end
  else
     begin
     QueryVFOBFrequency;
     end;
end;

procedure TIcomRadio.SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA);
var
  modeCmd: Byte;
  filterCmd: Byte;
  dataMode: Byte;
begin
  logger.Debug('[%s.SetMode] Setting VFO %s to TRadioMode=%d', [radioModel, IfThen(vfo = nrVFOA, 'A', 'B'), Ord(mode)]);

  // Map TRadioMode to Icom mode numbers
  filterCmd := $01;  // Default filter
  case mode of
    rmLSB:    modeCmd := $00;
    rmUSB:    modeCmd := $01;
    rmAM:     modeCmd := $02;
    rmCW:     modeCmd := $03;
    rmFSK:    modeCmd := $04;
    rmFM:     modeCmd := $05;
    rmCWRev:  modeCmd := $07;
    rmFSKRev: modeCmd := $08;
    rmAFSK,
    rmData:     modeCmd := $01;  // USB base mode + data sub-mode
    rmDataRev:  modeCmd := $00;  // LSB base mode + data sub-mode
    rmPSK:    modeCmd := $12;
    rmPSKRev: modeCmd := $13;
    rmDV:     modeCmd := $17;  // D-STAR digital voice
  else
    modeCmd := $01;  // Default to USB
  end;

  if (vfo = nrVFOB) and FSupportsExtendedVFOBCommands then
     begin
     // Use $26 $01 <mode> <dataMode> <filter> to set VFO B mode directly,
     // without any VFO-swap sequence. The $07 $01 / $06 / $07 $00 approach
     // races with CI-V transceive pushes over network connections — the $06
     // command lands on whichever VFO is active when the radio processes it,
     // which may still be VFO A. $26 $01 targets VFO B unconditionally.
     // This matches the serial path (LOGRADIO.PAS IcomRadiosThatSupportVFOB).
     if mode in [rmAFSK, rmData, rmDataRev] then
        begin
        dataMode := FDataModeID
        end
     else
        begin
        dataMode := 0;
        end;
     logger.Debug('[%s.SetMode] Sending $26 $01 modeCmd=$%.2x dataMode=$%.2x filterCmd=$%.2x',
        [radioModel, modeCmd, dataMode, filterCmd]);
     SendToRadio(BuildCIVCommand($26, #$01 + CivChr(modeCmd) + CivChr(dataMode) + CivChr(filterCmd)));
     end
  else
     begin
     // VFO A, or radios without $25/$26 support: use $06 targeting the active VFO.
     // For VFO B on older radios, swap to VFO B first, then restore VFO A after.
     if vfo = nrVFOB then
        begin
        SendToRadio(BuildCIVCommand($07, #$01));
        end;

     if FModeSetIncludesFilter then
        begin
        logger.Debug('[%s.SetMode] Sending $06 modeCmd=$%.2x filterCmd=$%.2x', [radioModel, modeCmd, filterCmd]);
        SendToRadio(BuildCIVCommand($06, CivChr(modeCmd) + CivChr(filterCmd)));
        end
     else
        begin
        // Old Icoms (IC-718) take the mode byte only; a trailing filter byte makes them NAK the frame.
        logger.Debug('[%s.SetMode] Sending $06 modeCmd=$%.2x (no filter byte)', [radioModel, modeCmd]);
        SendToRadio(BuildCIVCommand($06, CivChr(modeCmd)));
        end;

     // Set or clear the Icom data sub-mode flag ($1A $06):
     //   Entering data mode  → turn flag ON  ($1A $06 D1/D2/D3) via FDataModeID
     //   Leaving data mode for a voice mode → turn flag OFF ($1A $06 $00)
     //   Only send the clear command when the previous mode was actually a data
     //   mode; sending $1A $06 $00 unnecessarily (e.g. USB→USB on a retune) is
     //   known to kill the IC-7760 CI-V transceive stream.
     //   CW/CW-R: the radio auto-clears data mode on $06 $03 — no $1A $06 needed.
     //   FSK/PSK: use native Icom mode numbers and need no $1A $06 command.
     if SupportsDataMode then
        begin
        if mode in [rmAFSK, rmData, rmDataRev] then
           begin
           logger.Debug('[%s.SetMode] Sending $1A $06 $%.2x (data mode ON, D%d)', [radioModel, FDataModeID, FDataModeID]);
           SendToRadio(BuildCIVCommand($1A, #$06 + CivChr(FDataModeID)));
           end
        else if (mode in [rmUSB, rmLSB, rmAM, rmFM]) and
                (Self.vfo[vfo].Mode in [rmData, rmDataRev, rmAFSK]) then
           begin
           logger.Debug('[%s.SetMode] Sending $1A $06 $00 (leaving data mode, prev TRadioMode=%d)', [radioModel, Ord(Self.vfo[vfo].Mode)]);
           SendToRadio(BuildCIVCommand($1A, #$06 + #$00));
           end;
        end;

     if vfo = nrVFOB then
        begin
        SendToRadio(BuildCIVCommand($07, #$00));
        end;
     end;

  // Optimistic update: reflect the new mode in our cached VFO state immediately.
  // The polling thread reads vfo.Mode on every cycle; without this update, the
  // stale mode triggers ProcessFilteredStatus to override the display back to
  // the old mode before the transceive-push confirmation from the radio arrives.
  // rmAFSK maps to rmData because that is what the radio confirms: a $01 $01
  // (USB) transceive push combined with the $1A $06 $01 (data ON) response.
  if mode = rmAFSK then
     begin
     Self.vfo[vfo].Mode := rmData
     end
  else
     begin
     Self.vfo[vfo].Mode := mode;
     end;

  logger.Debug('[%s.SetMode] Done — VFO %s TRadioMode=%d modeCmd=$%.2x', [radioModel, IfThen(vfo = nrVFOA, 'A', 'B'), Ord(mode), modeCmd]);
end;

procedure TIcomRadio.BufferCW(cwChars: string);
begin
  FCWBuffer := FCWBuffer + cwChars;
  logger.debug('[%s.BufferCW] Buffered: "%s", Total buffer: "%s"', [radioModel, cwChars, FCWBuffer]);
end;

procedure TIcomRadio.SendCW;
begin
  if FCWBuffer = '' then
     begin
     logger.warn('[%s.SendCW] CW buffer is empty - nothing to send', [radioModel]);
     Exit;
     end;

  // Send CW message using CI-V command $17.  The message text follows the
  // command DIRECTLY -- $17 takes no sub-command.
  //
  // A #$00 was prefixed here until 2026-08-04.  Two independent references send
  // the text with nothing between: the D7 legacy path (LOGRADIO.PAS:2667 writes
  // ICOM_SEND_CW then the characters) and HamLib (icom_send_morse passes
  // C_SND_CW with subcmd -1, meaning "no sub-command byte").  $00 is also not in
  // the character table the radio documents for this command -- the codes there
  // are 20, 27-3F and 41-7A -- so it was a byte outside the alphabet the command
  // accepts.  An IC-7100 tolerated it, which is why this went unnoticed; a radio
  // that does not would have refused every CW message.
  SendToRadio(BuildCIVCommand($17, FCWBuffer));
  logger.info('[%s.SendCW] Sending CW: "%s"', [radioModel, FCWBuffer]);

  // Clear buffer after sending
  FCWBuffer := '';
end;

function TIcomRadio.CWIsFactoryOwned: Boolean;
begin
   // The CI-V drivers key CW themselves ($17 / buffered send).
   Result := True;
end;

procedure TIcomRadio.StopCW;
begin
  // CI-V command $17 $FF stops CW sending — sent urgent to jump the queue
  SendToRadioUrgent(BuildCIVCommand($17, #$FF));
  logger.debug('[%s.StopCW] CW transmission stopped', [radioModel]);
end;

function TIcomRadio.MemoryKeyer(mem: integer): boolean;
begin
   Result := True; // default: error
   if mem = 0 then
      begin
      SendToRadio(BuildCIVCommand($28, #$00#$00));
      logger.debug('[%s.MemoryKeyer] Stopping DVK', [radioModel]);
      Result := False;
      end
   else if (mem >= 1) and (mem <= 8) then
      begin
      SendToRadio(BuildCIVCommand($28, #$00 + CivChr(mem)));
      logger.debug('[%s.MemoryKeyer] Playing DVK memory %d', [radioModel, mem]);
      Result := False;
      end
   else
      begin
      logger.error('[%s.MemoryKeyer] Memory %d out of range (0-8)', [radioModel, mem]);
      end;
end;

function TIcomRadio.SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer;
begin
   // TODO: implement filter bandwidth control via CI-V $1A $03
   logger.debug('[%s.SetFilterHz] Not yet implemented (hz=%d)', [radioModel, hz]);
   Result := 0;
end;

procedure TIcomRadio.VFOBumpDown(whichVFO: TVFO);
begin
   // TODO: implement VFO bump via CI-V frequency step commands
   logger.debug('[%s.VFOBumpDown] Not yet implemented', [radioModel]);
end;

procedure TIcomRadio.VFOBumpUp(whichVFO: TVFO);
begin
   // TODO: implement VFO bump via CI-V frequency step commands
   logger.debug('[%s.VFOBumpUp] Not yet implemented', [radioModel]);
end;

function TIcomRadio.ToggleMode(vfo: TVFO = nrVFOA): TRadioMode;
var
  currentMode: TRadioMode;
  nextMode: TRadioMode;
begin
  // Get current mode from VFO
  currentMode := Self.vfo[vfo].Mode;

  // Toggle to next mode in sequence
  case currentMode of
    rmNone, rmLSB: nextMode := rmUSB;
    rmUSB:   nextMode := rmCW;
    rmCW:    nextMode := rmCWRev;
    rmCWRev: nextMode := rmAM;
    rmAM:    nextMode := rmFM;
    rmFM:    nextMode := rmLSB;  // Wrap around
  else
    nextMode := rmUSB;  // Default
  end;

  SetMode(nextMode, vfo);
  Result := nextMode;
end;

procedure TIcomRadio.SetCWSpeed(speed: integer);
var
  icomValue: Integer;
  bcdHigh, bcdLow: Byte;
begin
  // Icom CW keyer speed: FCWSpeedMin..FCWSpeedMax WPM maps linearly to CI-V value
  // 0-255 (default 6..48 for modern Icoms; the IC-718 is 6..60). We use ceiling,
  // NOT round-to-nearest, because the radio decodes with truncation
  // (WPM = min + floor(value * span / 255)); round-nearest can land one WPM low,
  // ceiling encodes exactly. For 6..48 this is identical to the old ((s-6)*255+41) div 42.
  if speed < FCWSpeedMin then
     begin
     speed := FCWSpeedMin;
     end;
  if speed > FCWSpeedMax then
     begin
     speed := FCWSpeedMax;
     end;
  icomValue := ((speed - FCWSpeedMin) * 255 + (FCWSpeedMax - FCWSpeedMin - 1)) div (FCWSpeedMax - FCWSpeedMin);
  if icomValue > 255 then
     begin
     icomValue := 255;
     end;

  // Encode 0-255 value as 2 BCD bytes: hundreds|tens, ones
  bcdHigh := IcomByteToBCD(icomValue div 100);    // 0-2
  bcdLow  := IcomByteToBCD(icomValue mod 100);    // 0-99
  FLastSetCWSpeedTick := GetTickCount;  // Start debounce window before sending
  SendToRadio(BuildCIVCommand($14, CIV_SUBCMD_CW_SPEED + CivChr(bcdHigh) + CivChr(bcdLow)));
  localCWSpeed := speed;
  logger.debug('[%s.SetCWSpeed] %d WPM -> icomValue=%d -> BCD $%s $%s',
               [radioModel, speed, icomValue,
                IntToHex(bcdHigh, 2), IntToHex(bcdLow, 2)]);
end;

procedure TIcomRadio.RITClear(whichVFO: TVFO);
begin
  // Clear RIT by setting offset to 0
  SetRITFreq(whichVFO, 0);
  logger.debug('[%s.RITClear] Cleared RIT offset', [radioModel]);
end;

procedure TIcomRadio.XITClear(whichVFO: TVFO);
begin
  // This radio has no XIT -- see TRadioCapabilities.HasXIT.  Guarded at every
  // XIT entry point, not just the poll: where RIT and XIT SHARE one offset
  // register ($21 $00), an XIT write would move the RIT instead.
  if not FCapabilities.HasXIT then
     begin
     Exit;
     end;

  // Clear XIT by setting offset to 0
  SetXITFreq(whichVFO, 0);
  logger.debug('[%s.XITClear] Cleared XIT offset', [radioModel]);
end;

procedure TIcomRadio.RITBumpDown;
begin
  // Bump RIT down by 10 Hz
  // Note: Would need to track current RIT offset to implement properly
  logger.debug('[%s.RITBumpDown] RIT bump down not fully implemented', [radioModel]);
end;

procedure TIcomRadio.RITBumpUp;
begin
  // Bump RIT up by 10 Hz
  // Note: Would need to track current RIT offset to implement properly
  logger.debug('[%s.RITBumpUp] RIT bump up not fully implemented', [radioModel]);
end;

procedure TIcomRadio.RITOn(vfo: TVFO);
begin
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_ON + #$01));  // $21 $01 $01
  logger.debug('[%s.RITOn] RIT enabled', [radioModel]);
end;

procedure TIcomRadio.RITOff(vfo: TVFO);
begin
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_OFF + #$00));  // $21 $01 $00
  logger.debug('[%s.RITOff] RIT disabled', [radioModel]);
end;

procedure TIcomRadio.XITOn(vfo: TVFO);
begin
  // This radio has no XIT -- see TRadioCapabilities.HasXIT.  Guarded at every
  // XIT entry point, not just the poll: where RIT and XIT SHARE one offset
  // register ($21 $00), an XIT write would move the RIT instead.
  if not FCapabilities.HasXIT then
     begin
     logger.Debug('[%s.XITOn] This radio has no XIT', [radioModel]);
     Exit;
     end;

  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_XIT_ON + #$01));  // $21 $02 $01
  logger.debug('[%s.XITOn] XIT enabled', [radioModel]);
end;

procedure TIcomRadio.XITOff(vfo: TVFO);
begin
  // This radio has no XIT -- see TRadioCapabilities.HasXIT.  Guarded at every
  // XIT entry point, not just the poll: where RIT and XIT SHARE one offset
  // register ($21 $00), an XIT write would move the RIT instead.
  if not FCapabilities.HasXIT then
     begin
     logger.Debug('[%s.XITOff] This radio has no XIT', [radioModel]);
     Exit;
     end;

  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_XIT_OFF + #$00));  // $21 $02 $00
  logger.debug('[%s.XITOff] XIT disabled', [radioModel]);
end;

procedure TIcomRadio.Split(splitOn: boolean);
begin
  if splitOn then
     begin
     SendToRadio(BuildCIVCommand($0F, CIV_SUBCMD_SPLIT_ON))
     end
  else
     begin
     SendToRadio(BuildCIVCommand($0F, CIV_SUBCMD_SPLIT_OFF));
     end;
  // A set-only-split radio (IC-718) never reports split back -- $0F read NAKs and
  // it emits no $0F transceive push -- so localSplitEnabled (which drives the
  // "You are in SPLIT MODE" warning via CurrentStatus.Split) would never reflect
  // the command. When the radio can't be read back, track the commanded state
  // locally. Readable radios leave localSplitEnabled to the $0F poll/push so the
  // radio stays the source of truth (front-panel split changes still win there).
  if not FSplitStateReadable then
     begin
     SetSplitOn(splitOn);
     end;
  logger.debug('[%s.Split] Split %s', [radioModel, IfThen(splitOn, 'enabled', 'disabled')]);
end;

procedure TIcomRadio.SetRITFreq(vfo: TVFO; hz: integer);
var
  bcdOffset: string;
begin
  bcdOffset := CivRawToStr(IcomOffsetToBCD(hz));
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_FREQ + bcdOffset));
  logger.debug('[%s.SetRITFreq] Set RIT offset to %d Hz', [radioModel, hz]);
end;

procedure TIcomRadio.SetXITFreq(vfo: TVFO; hz: integer);
var
  bcdOffset: string;
begin
  // This radio has no XIT -- see TRadioCapabilities.HasXIT.  Guarded at every
  // XIT entry point, not just the poll: where RIT and XIT SHARE one offset
  // register ($21 $00), an XIT write would move the RIT instead.
  if not FCapabilities.HasXIT then
     begin
     logger.Debug('[%s.SetXITFreq] This radio has no XIT', [radioModel]);
     Exit;
     end;

  // RIT/XIT share the same offset register on modern Icom radios ($21 $00)
  bcdOffset := CivRawToStr(IcomOffsetToBCD(hz));
  SendToRadio(BuildCIVCommand($21, CIV_SUBCMD_RIT_FREQ + bcdOffset));
  logger.debug('[%s.SetXITFreq] Set XIT offset to %d Hz', [radioModel, hz]);
end;

procedure TIcomRadio.SetBand(band: TRadioBand; vfo: TVFO = nrVFOA);
var
  freq: LongInt;
begin
  // Use remembered frequency for this band; fall back to typical frequency
  freq := FBandMemory[band];
  if freq = 0 then
     begin
     freq := BandToFreq(band);
     end;
  SetFrequency(freq, vfo, rmNone);
  logger.debug('[%s.SetBand] Set band to %d, freq=%d', [radioModel, Ord(band), freq]);
end;

function TIcomRadio.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
var
  currentBand: TRadioBand;
  nextBand: TRadioBand;
begin
  // Get current band from VFO
  currentBand := Self.vfo[vfo].Band;

  // Toggle to next band in sequence
  case currentBand of
    rbNone, rb160m: nextBand := rb80m;
    rb80m:  nextBand := rb60m;
    rb60m:  nextBand := rb40m;
    rb40m:  nextBand := rb30m;
    rb30m:  nextBand := rb20m;
    rb20m:  nextBand := rb17m;
    rb17m:  nextBand := rb15m;
    rb15m:  nextBand := rb12m;
    rb12m:  nextBand := rb10m;
    rb10m:  nextBand := rb6m;
    rb6m:   nextBand := rb4m;
    rb4m:   nextBand := rb2m;
    rb2m:   nextBand := rb70cm;
    rb70cm: nextBand := rb160m;  // Wrap around
  else
    nextBand := rb20m;  // Default
  end;

  SetBand(nextBand, vfo);
  Result := nextBand;
end;

procedure TIcomRadio.SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA);
var
  filterNum: Byte;
begin
  // Map TRadioFilter to Icom filter numbers
  // Note: Filter numbering varies by radio, this is a general mapping
  case filter of
    rfNarrow:  filterNum := $02;  // Narrow filter
    rfMid:     filterNum := $01;  // Medium/default filter
    rfWide:    filterNum := $03;  // Wide filter
  else
    filterNum := $01;  // Default filter
  end;

  SendToRadio(BuildCIVCommand($1A, CIV_SUBCMD_FILTER_WIDTH + CivChr(filterNum)));
  logger.debug('[%s.SetFilter] Set filter to %d', [radioModel, filterNum]);
end;

procedure TIcomRadio.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
  // For Icom, commands are built differently - this is mainly for compatibility
  SendToRadio(sCmd + sData);
end;

procedure TIcomRadio.ApplyNetworkCredentials(const user, pass: string);
begin
   FNetworkUsername := user;
   FNetworkPassword := pass;
   logger.Info('[%s] network credentials set (user=%s, pass=*******)', [radioModel, user]);
end;

procedure TIcomRadio.ApplyDataModeID(id: integer);
begin
   // Only D1..D3 are meaningful; anything else leaves the constructor default.
   if (id >= 1) and (id <= 3) then
      begin
      FDataModeID := Byte(id);
      logger.Info('[%s] Icom data mode ID set to D%d', [radioModel, id]);
      end;
end;



procedure TIcomRadio.DeclareCWProsigns;
begin
  // Icom has NO prosign alphabet.  '^' (0x5E) is a MODIFIER meaning "send the
  // following characters with no inter-character space", so '^SK' is the letters
  // S and K keyed run together -- which IS SK.  Same for ^AR, ^BT, ^SN.
  //
  // This is why an Icom cannot borrow either KY grammar: every character those
  // substitute (% _ * > [) is outside the set command $17 documents
  // (20, 27-3F, 41-7A).  The half space is a whole space -- passing '^' through
  // would run the next two characters together, which is not what TR4W means
  // by it.
  FCapabilities.CWProsigns := CWProsigns(' ', '^SN', '^AR', '^SK', '^BT');
end;

// ===========================================================================
// Bandscope ($27) -- the panadapter seam
//
// The SECOND implementer of TFactoryRadioBase's spectrum seam.  Read
// uIcomScope's header for the wire format and for where the three references
// disagree; what follows is only the wiring.
//
// THE DIFFERENCE FROM THE K4 THAT SHAPES ALL OF IT: there is no side channel.
// The K4 opens a second TCP socket on CAT port + 1 and owns a dedicated
// reading thread; an Icom pushes $27 $00 down the SAME CI-V link that carries
// frequency and mode, so this code runs on whatever thread already delivers
// CI-V and adds no thread of its own.  Two consequences worth stating:
//
//   * PublishSpectrumFrame is raised on the CI-V receive thread, which is
//     exactly the contract TSpectrumFrameProc already declares.  The
//     panadapter window parks the frame under a lock and repaints on a timer,
//     so it needs no change for this.
//   * the scope competes with tuning commands for the link.  That is a real
//     cost and it is why StopSpectrum turns the radio's data output back OFF
//     rather than leaving it running for a window nobody has open.
//
// FRAMING IS SAFE, and not by luck: a scope frame can contain neither $FD nor
// $FE.  Levels top out at 200, BCD digits at $99, the sign nibble makes at most
// $F9, and the mode, division and flag bytes are all small.  So the CI-V framer
// -- which splits on $FD and resyncs on $FE $FE -- cannot be desynchronised by
// a 490-byte payload, and neither the serial reading thread's terminator split
// nor ProcessCIVMessage needed changing.
// ===========================================================================

procedure TIcomRadio.DeclareScopeGeometry(APoints, AMaxLevel: Integer);
begin
   FScopeGeometry := IcomScopeGeometry(APoints, AMaxLevel);

   // A geometry that arrives after the decoder exists must reach it, or the
   // decoder would keep sizing sweeps to the old point count.  In practice this
   // is called from a model constructor long before StartSpectrum; the branch
   // is here so that ordering is not load-bearing.
   if Assigned(FScopeDecoder) then
      begin
      FScopeDecoder.Geometry := FScopeGeometry;
      end;
end;

function TIcomRadio.ScopeGeometry: TIcomScopeGeometry;
begin
   Result := FScopeGeometry;
end;

function TIcomRadio.ScopeGeometryPoints: Integer;
begin
   Result := FScopeGeometry.Points;
end;

function TIcomRadio.ScopeGeometryMaxLevel: Integer;
begin
   Result := FScopeGeometry.MaxLevel;
end;

function TIcomRadio.ScopeMeasuredPoints: Integer;
begin
   // 0 when nothing has decoded yet, which the caller must distinguish from a
   // disagreement -- "no sweep arrived" and "the declaration is wrong" have
   // very different fixes.
   if not Assigned(FScopeDecoder) then
      begin
      Result := 0;
      Exit;
      end;

   Result := FScopeDecoder.LastSweepLevelBytes;
end;

function TIcomRadio.ScopeMeasuredMaxLevel: Integer;
begin
   if not Assigned(FScopeDecoder) then
      begin
      Result := 0;
      Exit;
      end;

   Result := FScopeDecoder.MaxLevelSeen;
end;

function TIcomRadio.ScopeIdToFollow: Byte;
begin
   // Main.  HamLib documents 0 = Main, 1 = Sub, and that is the only claim
   // anyone makes about which is which -- it has NOT been confirmed on a rig
   // here.  Nothing breaks if it is backwards on some model: the window would
   // follow the other scope, which a bench session sees immediately.
   Result := 0;
end;

function TIcomRadio.ScopeSelector: string;
begin
   Result := CivChr(ScopeIdToFollow);
end;

function TIcomRadio.PrimarySpectrumSourceId: string;
begin
   { A RADIO WITH NO SCOPE NAMES NO SOURCE, and the guard is not decoration --
     uTestIcomScopeSeam caught this override answering '0' for an IC-7600, a
     radio that streams nothing at all.  A plausible id on a radio with no
     spectrum is worse than an empty one: it makes a caller's "did this radio
     give me a source" test pass, so the failure moves from the place that can
     report it to a window that simply never draws.

     GATED ON THE CAPABILITY, NOT ON SpectrumAvailable.  Which scope the
     panadapter follows is a fact about the MODEL and does not stop being true
     because this particular rig is on a serial cable today. }
   if not Supports(rcSpectrum) then
      begin
      Result := '';
      Exit;
      end;

   // The SAME spelling the decoder stamps on every frame.  One function owns
   // it (uIcomScope.IcomScopeSourceId) precisely because the window filters by
   // string equality and a mismatch produces a window that draws nothing with
   // nothing logged anywhere.
   Result := IcomScopeSourceId(ScopeIdToFollow);
end;

function TIcomRadio.SpectrumAvailable: Boolean;
begin
   { THREE THINGS, AND THE ORDER MATTERS.

     rcSpectrum first, so deleting the capability from a model's constructor
     disables the feature in ONE edit rather than leaving this contradicting it
     -- the same reasoning TK4Radio.SpectrumAvailable gives.

     NETWORK ONLY, for now.  Icom pushes $27 down plain CI-V, so unlike the K4
     this is not a transport the protocol forces -- a serial Icom really can
     stream spectrum, in 11 or 15 divisions, and uIcomScope decodes that path
     and has tests for it.  What has NOT happened is anyone watching it work on
     a wire, and 30 sweeps a second on a shared serial bus alongside tuning
     commands is exactly the kind of thing that behaves differently in a
     contest than on a bench.  So the decoder is ready and the gate is shut;
     opening it is a one-line change behind a bench session.

     GEOMETRY LAST, and it is not a formality.  A model that declares
     rcSpectrum and forgets DeclareScopeGeometry has points = 0, which decodes
     every sweep into nothing at all and produces no diagnostic -- CLAUDE.md's
     "a silently-defaulted field reads as a legal zero".  Refusing here turns
     that into an absent button instead of an empty window, and
     uTestIcomScopeSeam asserts the two can never disagree. }
   Result := Supports(rcSpectrum) and
             IsNetworkConnection and
             IcomScopeGeometryIsValid(FScopeGeometry);
end;

procedure TIcomRadio.ProcessScopeWaveData(const data: string);
var
   payload: TBytes;
   i: Integer;
   status: TIcomScopeStatus;
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   if not Assigned(FScopeDecoder) then
      begin
      // Frames arriving with no window open.  Normal: the radio keeps pushing
      // for a moment after StopSpectrum, and an operator can have the scope's
      // data output on from a previous session.  Dropped in silence because
      // logging it would write a line 30 times a second.
      Exit;
      end;

   // `data` is the CI-V payload INCLUDING the sub-command at [1]; the decoder
   // takes what follows it.  Copied byte-faithfully -- each Char's codepoint IS
   // the CI-V byte, which is the convention BuildCIVCommand's Chr() sets and
   // the one an AnsiString assignment would silently break by running the ANSI
   // codepage over it.
   SetLength(payload, Length(data) - 1);

   for i := 0 to Length(payload) - 1 do
      begin
      payload[i] := Byte(Ord(data[i + 2]));
      end;

   // UPSTREAM OF THE DECODER, so a captured fixture is evidence about the RADIO
   // rather than a record of what this decoder made of it.
   if Assigned(FOnScopePayload) then
      begin
      FOnScopePayload(payload);
      end;

   status := FScopeDecoder.Feed(payload, Length(payload), sweep);

   if status <> issComplete then
      begin
      // NOT AN ERROR IN THE COMMON CASES: issAssembling is every division but
      // the last over a serial link, and a continuation with no header is
      // normal when joining a stream mid-sweep.  The decoder counts the ones
      // that are real (Rejected, Abandoned) so the bench can read one number
      // instead of a flood of lines.
      Exit;
      end;

   frame := IcomSweepToSpectrumFrame(sweep, FScopeGeometry,
                                     IcomScopeSourceId(sweep.ScopeId));

   // EVERY scope is published, not just the one the window follows.  Filtering
   // here would make adding a Sub-scope window a rework rather than a setting
   // -- the same mistake TR4QT makes by discarding two of the K4's three pans
   // at the parser (docs/PANADAPTER_LCL_DESIGN.md section 7).  The window
   // filters on SourceId and the cost of a frame nobody wants is one compare.
   PublishSpectrumFrame(frame);
end;

procedure TIcomRadio.ProcessScopeSpanReply(const data: string);
var
   raw: AnsiString;
   halfHz: LongInt;
   i: Integer;
begin
   { The reply to $27 $15 <selector>: the selector echoed, then the span as a
     5-byte little-endian BCD frequency.  So the payload here is
     [1]=$15 [2]=selector [3..7]=span.

     A HALF-WIDTH ON THE WIRE.  The rig carries what the front panel shows --
     "+/-100k" -- while SpectrumSpanHz is a TOTAL, so it is doubled exactly
     once, here.  HamLib does the same in one place for the same reason
     (spectrum_span_freq = from_bcd(...) * 2). }
   if Length(data) < (2 + 5) then
      begin
      Exit;
      end;

   // Only the scope this radio follows.  A dual-scope rig answers for whichever
   // selector was asked, and taking the Sub scope's span as the Main scope's is
   // how the span buttons start stepping from a number that has nothing to do
   // with what is on screen.
   if Ord(data[2]) <> ScopeIdToFollow then
      begin
      Exit;
      end;

   SetLength(raw, 5);

   for i := 1 to 5 do
      begin
      raw[i] := AnsiChar(Ord(data[2 + i]));
      end;

   // The STRICT decoder, on purpose: a span is never negative, so this is an
   // ordinary frequency field and gets the ordinary refusal on corruption.
   // (uIcomScope's signed variant exists only for a scope EDGE.)
   halfHz := IcomBCDToFreq(raw);

   if halfHz = FREQ_INVALID then
      begin
      logger.Warn('[%s] scope span reply was not valid BCD: %s',
                  [radioModel, CIVDataToHex(data)]);
      Exit;
      end;

   FScopeSpanHz := IcomScopeHalfToTotalHz(halfHz);
   logger.Trace('[%s] radio reports scope span %d Hz total (+/-%d)',
                [radioModel, FScopeSpanHz, halfHz]);
end;

procedure TIcomRadio.ApplyScopeEnables;
begin
   if not FScopeStreaming then
      begin
      Exit;
      end;

   (* BOTH SWITCHES, AND IN THIS ORDER.

      $27 $10 turns the scope FUNCTION on; $27 $11 turns the CI-V wave OUTPUT
      on.  They fail in opposite and equally silent ways, and this driver has
      now seen both:

        only $10  -- the scope lights up on the RADIO'S screen and not one byte
                     reaches us.  AetherSDR names this the number-one "my
                     panadapter is black" cause.
        only $11  -- the radio streams structurally perfect sweeps whose levels
                     are all ZERO.  Measured on NY4I's IC-9700, 2026-08-26:
                     588 sweeps, 475 bins each, every bin at the floor.

      Neither produces an error, a NAK, or a missing frame. *)
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_ONOFF) + #$01));
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_DATAOUTPUT) + #$01));
end;

procedure TIcomRadio.StartSpectrum;
begin
   if FScopeStreaming then
      begin
      Exit;                       // idempotent by contract
      end;

   if not SpectrumAvailable then
      begin
      // Said out loud.  A window that opens and never draws is the failure this
      // seam is most able to produce, and the reason is always one of the three
      // gates in SpectrumAvailable -- none of which the operator can see.
      logger.Info('[%s] spectrum not available (capability=%s network=%s geometry=%s); not starting',
                  [radioModel,
                   BoolToStr(Supports(rcSpectrum), True),
                   BoolToStr(IsNetworkConnection, True),
                   BoolToStr(IcomScopeGeometryIsValid(FScopeGeometry), True)]);
      Exit;
      end;

   if not Assigned(FScopeDecoder) then
      begin
      FScopeDecoder := TIcomScopeDecoder.Create(FScopeGeometry);
      end
   else
      begin
      // A restart must not resume a sweep half-assembled before the last stop.
      FScopeDecoder.Reset;
      end;

   FScopeStreaming := True;

   (* SENT NOW *AND* ON EVERY CONNECT.  If the CI-V stream is not open yet the
      transport drops these silently, so OnNetworkStateChange re-sends them the
      moment it is -- see the note there for what that cost on the bench. *)
   ApplyScopeEnables;

   { ASK WHAT THE SPAN IS.  The rig pushes $27 $15 when the operator changes it
     but not on connect, so without this ask nothing knows the span until they
     happen to touch the radio -- and the span buttons report "radio has not
     reported one" in the meantime.  The K4 needs the identical ask for the
     identical reason (#SPN at connect).

     WITH THE SELECTOR.  A read of a scope sub-command carries the scope byte
     just as a set does; omitting it is a frame the rig ignores in silence. }
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_SPAN) + ScopeSelector));

   logger.Info('[%s] bandscope started: %d points, levels 0..%d, scope %d',
               [radioModel, FScopeGeometry.Points, FScopeGeometry.MaxLevel,
                ScopeIdToFollow]);
end;

procedure TIcomRadio.StopSpectrum;
begin
   if not FScopeStreaming then
      begin
      Exit;                       // idempotent, and safe from the destructor
      end;

   FScopeStreaming := False;

   { THE DATA OUTPUT GOES OFF; THE SCOPE ITSELF STAYS ON.

     $11 is TR4W's own switch -- nobody else wants CI-V wave data -- so leaving
     it on would keep a 30-frame-a-second stream competing with tuning commands
     for a window that is closed.  $10 is the operator's: it is what puts the
     scope on the RADIO'S screen, and turning that off because a TR4W window
     closed would reach out and change the rig in a way nobody asked for. }
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_DATAOUTPUT) + #$00));

   // The decoder is kept, not freed: a stop/start pair is cheap and the buffers
   // are a few hundred bytes.  Reset, so a restart cannot splice onto a sweep
   // that was in flight when the window closed.
   if Assigned(FScopeDecoder) then
      begin
      FScopeDecoder.Reset;
      end;

   logger.Info('[%s] bandscope stopped', [radioModel]);
end;

function TIcomRadio.SpectrumSpanHz: Integer;
begin
   Result := FScopeSpanHz;
end;

procedure TIcomRadio.SetSpectrumSpan(const aSpanHz: Integer);
var
   want: Integer;
   halfHz: Integer;
begin
   if not SpectrumAvailable then
      begin
      Exit;
      end;

   { SNAPPED HERE, BECAUSE THE RIG SNAPS ANYWAY AND WILL NOT SAY SO.  A request
     off the ladder is not rejected -- it is quietly rounded, so the caller
     cannot tell an accepted request from an adjusted one by watching for an NG.
     Snapping first means the value sent is the value expected, and the reply
     confirms it. }
   want := IcomScopeNearestSpanHz(aSpanHz);
   halfHz := IcomScopeTotalToHalfHz(want);

   { SIX DATA BYTES: the selector, then the HALF-width as a 5-byte BCD
     frequency.  AetherSDR reports that without the leading selector the radio
     ignores the frame outright -- no NG, no error, the span simply does not
     change, which reads as "zoom does nothing" and sends you hunting through
     the UI.  HamLib builds it the same way. }
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_SPAN) + ScopeSelector +
                               CivRawToStr(IcomFreqToBCD(halfHz))));

   { AND THEN ASK.  The value is NOT recorded locally: the rig is the authority
     on what it settled on, and a driver that believed its own request would
     step from a number the radio never had.  This is the same lesson the K4's
     span buttons taught (docs/PANADAPTER_LCL_DESIGN.md section 10.2). }
   SendToRadio(BuildCIVCommand(ICOM_SCOPE_CMD,
                               CivChr(ICOM_SCOPE_SUB_SPAN) + ScopeSelector));
end;

procedure TIcomRadio.StepSpectrumSpan(const aDirection: Integer);
begin
   if (aDirection = 0) or (FScopeSpanHz <= 0) then
      begin
      // Nothing to step FROM; the caller tells the operator.
      Exit;
      end;

   { ONE RUNG OF THE LADDER, NOT A NUMBER OF Hz -- which is the whole reason
     this virtual exists.  An Icom offers eight spans and snaps to the nearest,
     and the rungs are spaced by ratios of 2 and 2.5, so any fine trim lands
     back on the rung it started from and the button is inert.  AetherSDR
     measured that as zoom-out dead at all eight spans.

     ANCHORED ON WHAT THE RIG REPORTS, not on what is being drawn: the ladder
     walk needs a rung to start from, and the sweep's width and the rig's
     setting are different quantities. }
   SetSpectrumSpan(IcomScopeAdjacentSpanHz(FScopeSpanHz, aDirection));
end;

function TIcomRadio.SpectrumStreaming: Boolean;
begin
   Result := FScopeStreaming;
end;

function TIcomRadio.SpectrumLinkUp: Boolean;
begin
   { DISTINCT FROM Streaming, and here the distinction is nearly free: the
     scope rides the CI-V link, so "is the stream's link up" is "is the radio
     answering CI-V at all", which the transport already tracks for the
     frequency display's alert colour.

     On the K4 these two are genuinely separate objects -- a second socket with
     its own reconnect backoff.  Here they are the same link, and saying so is
     more honest than inventing a second liveness signal that could disagree
     with the one the rest of the program uses. }
   Result := FScopeStreaming and GetIsOperational;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcomBase');


end.
