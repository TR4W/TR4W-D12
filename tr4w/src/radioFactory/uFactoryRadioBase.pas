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
unit uFactoryRadioBase;
{$I ..\tr4w.inc}

interface

uses
   Windows, IdTCPClient, IdComponent, IdTCPConnection,IdThreadComponent, IdExceptionCore, SysUtils,
   Classes, StrUtils, Log4D, uLogConfig, VC, Tree, IdException, IdStack, SyncObjs, uSerialPort, uRadioBand,
   uCWFraming,   // TCWFrameRule / TCWProsign -- the CW traits a radio declares
   uSpectrumTypes,  // TSpectrumFrame / TSpectrumFrameProc -- the panadapter seam
  uTR4WStrings;

Type TProcessMsgRef = procedure (sMessage: string) of Object;
// Optional per-radio frame check for FIXED-LENGTH framing.  Returns True if the
// candidate bytes look like a genuine frame at this alignment.  See
// TFactoryRadioBase.ValidateFrame for why this exists.
Type TFrameValidator = function (const frame: string): Boolean of Object;
Type TBinary = (bOn, bOff);
Type TVFO = (nrVFOA, nrVFOB);  // Keep in sync with vfoNames in var section below

(* A question yet to resolve in this generalization is how to handle multiple
   slices in Flex radios. Should there be a nrVFOA and VFOB for each slice? Or should
   there be a radio object for each (but with a common connection). Once the K4
   is completed, I can experiment with the FLex 6600 and see what makes sense.
   NY4I 26-Nov-2021
*)

Type TRadioMode = (rmNone, rmCW, rmCWRev, rmLSB, rmUSB, rmFM, rmAM,
                   rmData, rmDataRev, rmFSK, rmFSKRev, rmPSK, rmPSKRev,
                   rmAFSK, rmAFSKRev, rmDV);
// TRadioBand is defined in uRadioBand (canonical location) and re-exported
// here via the interface uses clause so all existing consumers are unaffected.

Type TRadioFilter = (rfNarrow, rfMid, rfWide);
Type TRadioState = (rsOff, rsReceive, rsTransmit);
Type TRadioVFO = class(TObject)
   public
      ID: TVFO;
      frequency: integer;
      active: boolean;
      mode: TRadioMode;
      dataMode: TRadioMode;
      band: TRadioBand;
      priorBand: TRadioBand;
      filterWidth: TRadioFilter;
      filterHz: integer;
      RITState: boolean;
      XITState: boolean;
      RITOffset: integer;
      XITOffset: integer;
      IFShift: integer;
      filterWidthHz: integer;
      filter: integer;
     // NR: boolean;
     // NRLevel: integer;   // Are things like notch and NR set per VFO or radio wide?
     // Notch: integer;
end;

// Radio capabilities -- what a rig can do, OWNED BY THE RADIO OBJECT.  This is the
// factory replacement for the global IcomRadiosThatSupport* enum-keyed sets in
// LOGRADIO: each radio class declares its own set in its constructor, and callers
// ask the object (radio.Supports(rcReadVFOB), radio.SupportsCWByCAT) rather than a
// global table -- which is also what makes it work for non-enum string-id radios.
// Boolean traits live in a set (compact, enumerable -> a HamLib `rigctl -u`-style
// capability dump falls right out, see CapabilitiesAsText); ranged traits (CW speed)
// are discrete fields.  Extend TRadioCapability as new traits are modelled.
Type
   TRadioCapability = (
      rcReadVFOB,      // can read the UNSELECTED VFO's freq+mode (Icom $25/$26, Kenwood FR-flip)
      rcReadRIT,       // can read RIT/XIT state+offset back (else set-only / not reported)
      rcReadSplit,     // reports split back ($0F read/push) vs set-only
      rcReadTXStatus,  // can read TX/RX (PTT) state back over CAT
      rcDataMode,      // has a data sub-mode (Icom $1A06 USB-D); NOT plain RTTY, which is a mode byte
      rcCWByCAT,       // can key CW over CAT.  Replaces LOGRADIO's
                       //   RadioSupportsCWByCAT.  DISTINCT FROM THE OPERATOR'S
                       //   CONFIG SETTING: `CW BY CAT = TRUE` says what the user
                       //   WANTS, this says what the radio CAN do, and
                       //   IsCWByCATActive requires BOTH -- a user can switch the
                       //   option on for a radio that cannot do it, and the
                       //   capability is what stops that.  Keying itself still
                       //   runs on the legacy path / the future CW Keyer Factory
                       //   (see [[cw-keyer-factory-direction]]).
      rcPlayDVK,       // can play a recorded voice message (DVK) over CAT.
                       //   Replaces LOGRADIO's RadioSupportsPlayDVK.  Same
                       //   config-versus-capability split as rcCWByCAT.
      rcCWSpeedSync,   // CW keyer speed can be pushed to the radio so its own
                       //   keyer follows TR4W's speed.  Replaces LOGRADIO's
                       //   RadioSupportsCWSpeedSync -- a WIDER set than
                       //   rcCWByCAT: a radio can accept a speed without being
                       //   able to key text (the older Icoms and the FTDX
                       //   family), so the two are independent flags.
      rcSharedRITXITOffset,
                       // ONE offset register shared by RIT and XIT (Yaesu FT-1000MP
                       // "RIT offset"): the two on/off states are still independent,
                       // but there is a single offset value -- setting RIT's offset
                       // moves XIT's too.
                       //
                       // ABSENCE MEANS "NOBODY HAS CHECKED", NOT "INDEPENDENT".
                       // An earlier comment here claimed absent = independent = the
                       // safe default.  That is backwards, and NY4I set the rule:
                       // "let's assume they are a single offset unless we either
                       // know for sure they are not or I confirm."  Only the
                       // FT-1000MP declares this today, so 90 radios read as
                       // independent on no evidence -- treat them as shared.
                       //
                       // Evidence so far: the Flex 6000 IS genuinely independent
                       // (bench-proven, ZZRG and ZZXG returning different values at
                       // once), and HamLib models every rig it implements as shared
                       // (65 of 65 classified -- its Kenwood set_xit literally just
                       // calls set_rit).  Nothing consumes this flag yet.

      rcSpectrum       // can produce a panadapter / waterfall data stream.
                       //
                       // WHAT THE RADIO CAN DO, not what TR4W will do with it --
                       // the same split as rcCWByCAT.  Whether a spectrum window
                       // actually opens is the PROGRAM's decision (NY4I,
                       // 2026-08-25), and three things have to agree: this flag,
                       // SpectrumAvailable for the connection in hand, and the
                       // operator's setting.  The radio declares the first and
                       // knows the second; only TR4W knows the third.
                       //
                       // SAYS NOTHING ABOUT THE TRANSPORT, deliberately.  The K4
                       // serves its stream on a second TCP port and so offers it
                       // over Ethernet only, while Icom pushes $27 bandscope
                       // frames down plain CI-V, which is a serial link
                       // (uRadioIcomBase.pas:1635 already receives and discards
                       // them).  Which links a radio offers it on is a fact about
                       // THAT radio, so it belongs in its SpectrumAvailable
                       // override -- never in this flag, and never in a base
                       // class asking which model it is.
      ,
      rcSplitClearedByModeChange
                       // Setting a VFO's MODE clears SPLIT on this radio, and does
                       // so LATE -- as a side effect the rig finishes after it has
                       // already accepted the split command.  Wire order therefore
                       // does not save you: TR4W sends the mode and then the split,
                       // the rig acknowledges the split, and ~145 ms later reports
                       // split off again with nothing further sent.
                       //
                       // Bench-proven on the Elecraft K4 (NY4I, 2026-08-25, two
                       // sessions, log at 11:17 and 14:01).  HamLib carries the same
                       // workaround for the K3/KX2/KX3 as well (rigs/kenwood/k3.c:
                       // "split can get turned off when modes are changing"), so
                       // those very likely share it -- but only the K4 has been
                       // watched, so only the K4 declares it.
   );
   TRadioCapabilitySet = set of TRadioCapability;

   // One span this radio can transmit on, in Hz.
   TRadioFreqRange = record
      lowHz:  LongInt;
      highHz: LongInt;
   end;

   // What a radio keys for one of TR4W's prosign tokens.
   TCWProsign = record
      handled: boolean;   // True: this token IS a prosign; do not treat it as text
      text: string;       // what to append ('' = token consumed, key nothing)
   end;

   // How ONE radio spells the five prosign tokens TR4W understands
   // (^ half space, ! SN, + AR, < SK, = BT -- see TC_CWMENU).
   //
   // DATA, declared by the radio in its constructor exactly as CWFrame is.  It
   // was three functions in uCWFraming with each driver delegating to one, and
   // that failed the test this factory is built around: adding a radio must
   // touch only that radio's units.  A Yaesu that gained CW-by-CAT would have
   // needed a YaesuProsign function added to a SHARED unit -- radio-specific
   // code outside the factory, which is the thing being eliminated everywhere
   // else.  Stating five strings here keeps every fact about a radio in that
   // radio's own file.
   //
   // Declared = False means this radio's CW grammar has not been established.
   // Every token then passes through as literal text, which is the only honest
   // default: sending an untested radio another vendor's substitute characters
   // would be a guess presented as a fact.  Note the difference from a DECLARED
   // but empty spelling -- Elecraft has no SN, so its '!' is consumed and keys
   // nothing, which is not the same as passing '!' through to be keyed.
   TCWProsignSet = record
      Declared: boolean;
      HalfSpace: string;   // '^'
      SN: string;          // '!'
      AR: string;          // '+'
      SK: string;          // '<'
      BT: string;          // '='
   end;

   TRadioCapabilities = record
      Flags: TRadioCapabilitySet;  // boolean traits
      CWSpeedMin: integer;         // CW keyer wpm range (ranged traits a set can't hold; default 6..48)
      CWSpeedMax: integer;
      // ---- CW-by-CAT framing, for the radios that declare rcCWByCAT ---------
      // How this rig's CW command must be cut up.  This was a `case model of`
      // table in uCWFraming until 2026-08-03; it is a fact about ONE radio, so
      // it belongs here beside CWSpeedMin/Max rather than in a table the radio
      // cannot participate in (a string-id radio has no InterfacedRadioType to
      // be a case label).
      //
      // Declared by the family base and overridden per model -- the K2 and the
      // TS-890 differ from their families only in `pad`.  A base must never
      // test model identity to decide these; the model unit overrides the field.
      //
      // The prosign spellings are the same kind of fact and are declared the
      // same way -- see TCWProsignSet.
      CWFrame: TCWFrameRule;
      CWProsigns: TCWProsignSet;

      // Does this radio have XIT over CAT at all?
      //
      // A FIELD rather than a member of Flags, deliberately: this has to default
      // TRUE, and a set member cannot -- absent means false.  Worse, every
      // DefineCapabilities assigns `Flags := [...]` wholesale, so a default
      // added in the base constructor would be silently wiped by any family that
      // overrides it.  That exact hazard is documented on TIcomRadio.Create and
      // it has bitten before; CWSpeedMin/Max and CWFrame are separate fields for
      // the same reason.
      //
      // TRUE for every radio unless it says otherwise.  The IC-7100 says
      // otherwise: its $21 set is $00 and $01 with no $02, so it NAKs every XIT
      // command -- and HamLib agrees independently (rigctl -m 3070 -u reports
      // "Can get XIT: N", where an IC-7850 reports Y).
      HasXIT: boolean;
   end;

// Declare a radio's prosign spellings, for use in its constructor.  Reads as
// CWProsigns(' ', '%', '_', '>', '[') at each declaration -- half space, SN,
// AR, SK, BT, in the order they appear in TR4W's own notation.
function CWProsigns(const halfSpace, sn, ar, sk, bt: string): TCWProsignSet;

Type TSimpleEventProc = procedure(const aStrParam:string) of object;
Type PBoolean = ^Boolean;  // Pointer to Boolean type
Type TReadingThread = class(TThread)
  protected
    readTerminator: string;
    FConn: TIdTCPConnection;
    FSerialPort: TSerialPort;
    FSerialBuffer: string;  // Buffer for accumulating serial data
    msgHandler: TProcessMsgRef;
    FSocketLock: TCriticalSection;
    FDisconnecting: PBoolean;  // Pointer to parent's Disconnecting flag
    procedure Execute; override;
    procedure DoTerminate; override;
  public
    radioWasDisconnected: boolean;
    radioName: string;  // Set after creation for radio-identified trace messages
    binaryProtocol: Boolean;  // Set from the radio's SerialProtocolIsBinary after creation; True = read raw bytes (Icom CI-V), not a codepage-decoded string
    fixedFrameLength: integer;  // >0: responses are FIXED-LENGTH with no terminator (Yaesu FT1000MP binary) -> hand over N-byte frames. 0 (default) = terminator-delimited (unchanged).
    frameValidator: TFrameValidator;  // Optional, fixed-frame mode only. nil (default) = accept every frame at face value, exactly as before. When supplied, a candidate frame that fails validation causes ONE byte to be dropped and alignment retried -- a self-syncing recovery for a protocol with no terminator. See TFactoryRadioBase.ValidateFrame.
    pendingResyncDrops: integer;      // Bytes discarded since the last good frame; reported once on recovery instead of per byte.
    constructor Create(AConn: TIdTCPConnection; proc: TProcessMsgRef; ASocketLock: TCriticalSection; ADisconnecting: PBoolean); reintroduce; overload;
    constructor Create(ASerialPort: TSerialPort; proc: TProcessMsgRef; ASocketLock: TCriticalSection; ADisconnecting: PBoolean); reintroduce; overload;
    procedure ClearSerialBuffer;  // Clear accumulated serial buffer data
  end;

//tr4w_ClassName                        : array[0..4] of Char = ('T', 'R', '4', 'W', #0);
const
   vfoNames: array[Low(TVFO)..High(TVFO)] of string = ('VFOA','VFOB');

   // Reconnection configuration
   RECONNECT_INITIAL_DELAY = 1000;    // 1 second initial delay
   // 5 seconds, not 30.  NY4I timed a power cycle at 13.55 s from switch-on to
   // the frequency reappearing -- and almost all of that was WAITING FOR THE
   // NEXT ATTEMPT, not the radio: he switched on part way through an 8 or 16
   // second backoff.
   //
   // The 30 s cap was set to avoid "a tight loop", but the log says what a
   // reopen actually costs: 17:34:59.391 -> .503, ONE HUNDRED AND TWELVE
   // MILLISECONDS.  Rationing a 112 ms operation to once every 30 s buys
   // nothing measurable and costs up to 30 s of an operator staring at a
   // magenta callsign.  At 5 s a rig left off overnight costs 112 ms every 5 s
   // -- about 2% of one thread, doing nothing but a close and an open on a port
   // with no one on the other end.
   //
   // Worst-case recovery is now roughly the backoff plus one poll round trip,
   // so about 5 s rather than about 30 s.  The doubling is kept: the first
   // retry is still immediate-ish for the common case of a rig switched off and
   // straight back on.
   RECONNECT_MAX_DELAY = 5000;        // 5 seconds max delay between reopen attempts
   RECONNECT_BACKOFF_MULTIPLIER = 2;  // Double delay each retry

   // How long the link must stay good before the startup command goes out.
   // A radio that has just been powered on answers CAT well before the rest
   // of it is ready: an Elecraft K3 replies to IF; within a few hundred ms of
   // its first byte, and a startup command sent in that window is accepted by
   // the serial port and then quietly dropped by the radio.  Bench-proven on
   // 2026-08-01 -- the identical command took effect on a Reset Radio Ports a
   // moment later.  This is a settle, NOT a retry: the command still goes out
   // exactly once per link-up.
   STARTUP_COMMAND_SETTLE_MS = 2000;

   // Serial disconnect detection
   SERIAL_RESPONSE_TIMEOUT = 5.0;     // 5 seconds - consider disconnected if no valid response
{var
   logger: TLogLogger;
   appender: TLogFileAppender;
}

function BoolToString(b: boolean): string;

// Add telnet client to this base class
// Add property for IP address, port, type (tcp or udp but just implement tcp right now).
// Add a connect and disconnect method

Type TFactoryRadioBase = class(TObject)
   private
      //socket: TIdTCPClient;
      //idThreadComponent   : TIdThreadComponent;
      localAddress: string;
      localPort: integer;
      localSerialPort: portType;
      rt: TReadingThread;
      baseProcMsg: TProcessMsgRef;
      SocketLock: TCriticalSection;
      FLastValidResponse: TDateTime;  // Track last valid response for timeout detection

      // ONE OUTSTANDING POLL AT A TIME -- see PollOutstanding.
      FPollAwaitingReply: boolean;
      FPollSentTick: cardinal;
      // Has the radio said ANYTHING since the poll went out, and when.
      // Both are needed: "quiet" only means the poll is answered if the
      // radio started talking in the first place.
      FPollHeardReply: boolean;
      FPollLastFrameTick: cardinal;
      FLastSerialReopenTick: LongWord;  // MaintainSerialLink throttle
      FSerialReopenDelay: Integer;      // grows to RECONNECT_MAX_DELAY while silent
      FFrequencyOffset: integer;   // transverter offset in Hz; 0 = none
      FActiveVFO: TVFO;  // RX/operating VFO; nrVFOA = swap model (K4: A/B swaps contents so A is always active), selectable-model radios (Kenwood FR, Flex slice) drive it via SetActiveVFO

      function GetRadioPort: integer;
      procedure SetRadioPort(Value: Integer);
      function GetRadioAddress: string;
      procedure SetRadioAddress(Value: string);
      function GetSerialPort: portType;
      procedure SetSerialPort (Value: portType);
      function GetCWSpeed: integer;
      function GetIsTransmitting: boolean;
      function GetIsReceiving: boolean;
      function GetBand(whichVFO: TVFO): TRadioBand;
      function GetFrequency(whichVFO: TVFO): integer;
      function GetIsRITOn(whichVFO: TVFO): boolean;
      function GetRITOffset(whichVFO: TVFO): integer;
      function GetIsXITOn(whichVFO: TVFO): boolean;
      function GetXITOffset(whichVFO: TVFO): integer;
      function GetMode(whichVFO: TVFO): TRadioMode;
      function GetDataMode(whichVFO: TVFO): TRadioMode;
      function GetIFShift(whichVFO: TVFO): integer;
      function GetFilter(whichVFO: TVFO): integer;
      function GetSplitEnabled: boolean;
      function GetVFO(whichVFO: TVFO): TRadioVFO;

      procedure SetPTTviaCAT(Value: boolean);
      function  GetPTTviaCAT: boolean;
      procedure OnRadioConnected(Sender:TObject);
      procedure OnRadioDisconnected(Sender: TObject);
      procedure OnRadioStatus(Sender: TObject; const Status: TIdStatus; const AStatusText: TIdText);
      //procedure IdThreadComponentRun(Sender: TIdThreadComponent);

   protected
      Disconnecting: Boolean;
      readTerminator: string;
      socket: TIdTCPClient;
      serialPortObj: TSerialPort;
      localCWSpeed: integer;
      FRadioModel: string;   // backing field for the radioModel property

      // ONE logger for every factory radio, owned by the base and derived from the
      // model name (see SetRadioModel).
      //
      // Before this, 17 model classes assigned their own category and 74 inherited
      // their family's, so most radios logged as TR4WDebugLog.IcomBase /
      // .YaesuSerial / .KenwoodSerial while a handful logged as .K4-Radio.  Two
      // costs: a reader could not tell a deliberate omission from an oversight, and
      // per-model log filtering was impossible for the 74 -- enabling
      // TR4WDebugLog.FTDX10 matched nothing, because no such category existed.
      //
      // Family bases used to declare their own `logger` field; those are gone, so
      // every driver now resolves to this one.
      logger: TLogLogger;
      FCapabilities: TRadioCapabilities;   // what this rig can do (see TRadioCapabilities); set in the subclass ctor

      // Panadapter subscriber, surfaced as the OnSpectrumFrame property.  Held
      // on the base so that every spectrum-capable radio publishes the same
      // way and the nil check lives in exactly one place.
      FOnSpectrumFrame: TSpectrumFrameProc;

      RITState: boolean;
      XITState: boolean;
      vfo: array[Low(TVFO)..High(TVFO)] of TRadioVFO;
      radioState: TRadioState;
      localMode: TRadioMode;
      localDataMode: TRadioMode;
      localSplitEnabled: boolean;
      // COMMANDED, not reported.  localSplitEnabled above is what the radio last
      // SAID; this is what TR4W last ASKED FOR.  They are the same fact on a
      // well-behaved rig and briefly disagree on one that clears split as a side
      // effect of something else -- which is the whole reason both exist.
      splitCommandedOn: boolean;
      // How many times we may re-assert a commanded split against a contradicting
      // report.  Bounded, and spent per command, so a rig that genuinely refuses
      // split cannot become a command loop and the OPERATOR can always win by
      // switching split off at the front panel a moment later.
      splitReassertBudget: integer;
      localRITOffset: integer;
      localXITOffset: integer;
      bandIndependence: boolean;
      CWSendImmediate: boolean;   // see the public property of the same idea

      // Transmit coverage, learned or declared.  30 is the Icom band-segment
      // ceiling ($1E edge numbers run 01-30) and covers any radio comfortably.
      FCoverage: array[1..30] of TRadioFreqRange;
      FCoverageCount: integer;
      FStartupCommandSent: boolean;   // guard for the public StartupCommand
      // Settle window for the startup command -- see STARTUP_COMMAND_SETTLE_MS.
      // FStartupArmed says the link has been seen up at least once since the
      // last arm; FStartupArmTick is when.  Both cleared by RearmStartupCommand.
      FStartupArmed: boolean;
      FStartupArmTick: LongWord;
      procRef: TProcessMsgRef;

      function GetISConnected: boolean; virtual;
      function GetIsOperational: boolean; virtual;
      // True if a Disconnect+Connect cycle would help when the radio sits
      // in IsConnected=True but IsOperational=False for too long.  Default
      // False -- safe for radios where the two dimensions are independent
      // (e.g. Flex: TCP up vs SmartSDR slice valid).  TIcomRadio overrides
      // to True because Icom's "operational" gap means the multi-step
      // handshake stalled and a fresh AYH is the only recovery.
      function GetCanRecycleOnStuckHandshake: boolean; virtual;
      function GetAuthFailed: boolean; virtual;
      function BandToFreq(band: TRadioBand): LongInt;  // Map band enum to typical calling frequency

      // ---- TRANSMIT COVERAGE -----------------------------------------------
      // Which frequencies this radio can actually transmit on.
      //
      // WHY.  TR4W's band-up/down walks ONE fixed list for every radio
      // (LOGSTUFF's BandChangeArray: ... 6m, 2m, 222, 432, 902 ...) and nothing
      // knew which of those a given radio has.  On an IC-7100 -- HF, 6 m, 2 m,
      // 70 cm -- band-up from 2 m sent 222.100 MHz, the radio ignored a
      // frequency it cannot tune, and TR4W's band display advanced anyway
      // (NY4I bench, 2026-08-04).
      //
      // RANGES IN Hz, NOT A BAND SET.  The factory's TRadioBand cannot even name
      // 222 or 23 cm, and coverage varies by region and by fitted option -- an
      // E-model may have 4 m; an IC-9100's 23 cm is a module.  A span in Hz says
      // all of that without a per-model table.
      //
      // EMPTY MEANS NO OPINION: CoversFrequency then answers True for
      // everything, so a radio that cannot report its coverage behaves exactly
      // as it does today.
      // Filling it is the DRIVER's business (protected); asking is everyone's,
      // so the two queries are published below.
      procedure ClearCoverage;
      procedure AddCoverageRange(lowHz, highHz: LongInt);

      // Hand a finished spectrum frame to whoever is listening (the subscriber
      // is the OnSpectrumFrame property, published below).  Does nothing when
      // no one is: a radio may stream spectrum with no window open, which is
      // the normal case and not an error worth logging 36 times a second.
      //
      // Protected -- PRODUCING frames is the driver's business, subscribing is
      // everyone's, the same split as the coverage queries above.
      procedure PublishSpectrumFrame(const AFrame: TSpectrumFrame);





   public
      rigLabel: string;           // "Rig 1" / "Rig 2" — set by LOGRADIO after creation
      // The operator's RADIO n STARTUP COMMAND, handed over right after
      // construction so the radio owns it before it ever connects.  Sent by
      // SendStartupCommand once the link is actually up -- see there for why
      // the caller cannot simply send it when Connect returns.
      StartupCommand: string;
      serialBaudRate: DWORD;
      serialDataBits: Byte;
      serialStopBits: Byte;
      serialParity: Byte;
      serialRts: Boolean;
      serialDtr: Boolean;

      // Polling configuration
      requiresPolling: Boolean;        // True for most radios, False for K4 with AI5
      honorsFreqPollRate: Boolean;     // True (default): the serial poll loop may set pollingInterval to the user's FREQUENCY POLL RATE (fast, e.g. 10ms) -- correct for radios that poll frequency directly (K4). False (Icom): keep the radio's own pollingInterval (1s) -- its PollRadioState is a heavy multi-command CI-V state query (RIT/XIT/split/TX) and freq comes from transceive, so a 10ms cadence floods the rate-limited CI-V send queue.
      autoUpdateCommand: string;       // Command to enable push updates (e.g., 'AI5;')
      pollingInterval: Integer;        // Milliseconds between polls (default 100)
      bAddTermination: Boolean;        // True (default): SendToRadio appends CR/LF (WriteLn). Kenwood TS-890 LAN sets this False -- its CAT parser rejects a trailing CR/LF; the K4 tolerates/ignores it, so it stays True.
      SerialProtocolIsBinary: Boolean; // False (default): serial CAT is ASCII text -> WriteString/ReadString. True (Icom CI-V, set in TIcomRadio): the frame is raw bytes (Ord 0..255 per Char, incl. >= $80 like FE/88/FD) -> byte-exact WriteBytes/ReadBytes, so D12's UTF-16/ASCII encoding can't corrupt them.
      SerialFixedFrameLength: integer;  // >0: serial responses are fixed-length binary with NO terminator (Yaesu FT1000MP: 32-byte status block). Default 0 = terminator-delimited. Implies SerialProtocolIsBinary.

      // Change the expected fixed frame length AFTER the reading thread is running.
      // Needed by radios whose exchange has more than one answer size -- the
      // Yaesu FT-767 replies to a poll with a 5-byte handshake and, only after an
      // ACK, an 86-byte status block, so the delimiter has to change mid-stream.
      //
      // Safe ONLY from ProcessMsg, which runs ON the reading thread: that thread
      // re-reads its fixedFrameLength on each pass of its loop, so the new value
      // takes effect on the next frame with no cross-thread write and no lock.
      // Calling it from another thread would race the reader mid-frame.
      //
      // Exists because `rt` is private; a driver must not reach into the thread.
      // Set by the caller BEFORE SendCW to request the immediate (KYW) form of
      // the KY command instead of the normal buffered one; the driver clears it
      // after use.  A flag rather than a SendCW parameter because SendCW is
      // overridden by every registered radio -- ~100 of them -- and changing the
      // signature would touch all of them to serve a case only the KY drivers
      // care about.  Exposed as a property because the backing field sits in the
      // protected block and LOGRADIO sets it from outside.
      property SendCWImmediate: boolean read CWSendImmediate write CWSendImmediate;

      // Send the operator's startup command, ONCE per radio object, when the
      // link is established.  Safe to call repeatedly: it self-guards, which is
      // what lets both transports use the same call without agreeing on who
      // owns the "already sent" state.
      // Hand the radio whatever the operator configured that only SOME radios
      // need.  Default no-ops.  These exist so SetUpRadioInterface does not have
      // to type-test the object it just built: it used to say
      //     if tFactoryObject is TIcomRadio then TIcomRadio(...).NetworkUsername := ...
      // which put per-family knowledge back in the construction site the factory
      // exists to keep clean, and silently skipped any future radio that also
      // needed credentials.
      procedure ApplyNetworkCredentials(const user, pass: string); virtual;
      // Icom's data sub-mode (D1/D2/D3).  Named for the CONCEPT, not the vendor,
      // so a future radio with the same idea can implement it honestly.
      procedure ApplyDataModeID(id: integer); virtual;
      // Auto-info: the radio pushes state changes instead of being asked.
      // Named for the CONCEPT, not a vendor -- Elecraft calls it AI, Icom
      // calls it transceive, and a driver that supports neither ignores it.
      // What a LEVEL means is the radio's business; the caller only passes
      // the operator's number through.
      procedure ApplyAutoInfoLevel(level: integer); virtual;

      procedure SendStartupCommand;

      // Could THIS radio's wire format carry the operator's startup command?
      //
      // The command is free text from the config, sent raw.  That is right --
      // it exists so an operator can send something TR4W knows nothing about --
      // but "raw" should not mean "unexamined": a K3's 'KY <;' left configured
      // when the radio is swapped for an IC-7100 puts five bytes on a CI-V bus
      // that can never be part of a frame, in silence (NY4I, 2026-08-05).
      //
      // Base has no opinion, which keeps every radio's existing behaviour.  A
      // family whose wire format is checkable overrides this -- see TIcomRadio.
      // `reason` is for the log, so the operator is told WHAT is wrong with it.
      function StartupCommandIsSendable(const cmd: string;
                                        out reason: string): boolean; Virtual;

      // Forget that the startup command was sent, so the next
      // SendStartupCommand fires again.  Called when the LINK DROPS: a radio
      // that went away may have been power-cycled, and a power-cycled radio has
      // lost whatever the startup command configured.  NY4I, 2026-08-01:
      // "resend it after power up."
      // Virtual so a family can also forget what it LEARNED about this link --
      // see TIcomRadio, which re-arms its probes and its refused-command flags,
      // because the rig on the port after a reconnect may not be the one that
      // refused them.
      procedure RearmStartupCommand; Virtual;

      procedure SetExpectedFrameLength(n: integer);

      // Frame check for FIXED-LENGTH framing (ignored when SerialFixedFrameLength = 0).
      // Fixed-length framing has no terminator to re-synchronise on, so a single
      // unexpected byte -- a set-command ACK the manual never documented, or a byte
      // dropped on a noisy link -- would misalign EVERY later frame permanently.
      // A radio whose frames are self-identifying can override this to say "these
      // bytes are not a frame at this alignment"; the reading thread then discards
      // one byte and retries, which re-synchronises within a frame or two.
      // The BASE returns True: no validation, byte-for-byte the original behaviour,
      // so a radio that does not override is completely unaffected.
      function ValidateFrame(const frame: string): Boolean; virtual;

      // Close and reopen the serial port, discarding buffered bytes.  See the
      // implementation for why continuing to poll an open port is not enough.
      function ReopenSerialPort: Boolean;

      // Called every poll iteration while a SERIAL radio is not answering.  The
      // radio owns its own link recovery -- the timing, the backoff and the
      // decision to reopen all live here, so the poll loop only has to tick it.
      procedure MaintainSerialLink;

      // ---- Capabilities: ask the radio what it can do (see TRadioCapabilities). ----
      property Capabilities: TRadioCapabilities read FCapabilities;
      function Supports(cap: TRadioCapability): Boolean;   // = cap in FCapabilities.Flags
      function SupportsCWByCAT: Boolean;                    // named facade (the user-facing example)
      function CapabilitiesAsText: string;                 // HamLib `rigctl -u`-style dump for the log

      // ---- Panadapter / spectrum ----------------------------------------
      // TWO QUESTIONS, KEPT APART.  `Supports(rcSpectrum)` is the MODEL fact --
      // this radio can produce a spectrum stream at all -- declared in the
      // driver's constructor like every other capability, and dumped by
      // CapabilitiesAsText.
      //
      // SpectrumAvailable is the INSTANCE answer: can we actually get frames
      // from THIS radio as it is connected right now.  It is separate because a
      // constructor cannot answer it -- TRadioFactory assigns serialPort
      // (uRadioFactory.pas:154, :206) AFTER the instance exists, so anything
      // decided in the constructor would still be reading the default NoPort.
      //
      // Neither of these decides whether a panadapter window opens.  That is
      // the PROGRAM's call (NY4I, 2026-08-25) and belongs beside
      // IsCWByCATActive in MainUnit, where the operator's setting can be ANDed
      // in -- exactly the capability-versus-config split rcCWByCAT documents.
      //
      // Base: available whenever the model declares the capability.  A radio
      // whose stream is restricted to one transport overrides and says so.
      function SpectrumAvailable: Boolean; virtual;

      // Start and stop producing frames.  EXPLICIT, not implied by assigning
      // OnSpectrumFrame: the K4's stream is ~150 KB/s and a second socket, and
      // paying that whenever a radio happens to be connected -- with no window
      // open to look at it -- would be a cost nobody asked for.  So the window
      // subscribes and calls StartSpectrum, and calls StopSpectrum when it
      // closes.
      //
      // Both are safe to call repeatedly and in either order; a radio with no
      // spectrum ignores them.  Calling Start on a radio whose
      // SpectrumAvailable is False does nothing -- the caller does not have to
      // check first.
      procedure StartSpectrum; virtual;
      procedure StopSpectrum; virtual;
      { Ask the radio to change the width of the spectrum it is sending.

        A REQUEST, NOT A SETTING.  The span the display uses always comes from
        the FRAME (TSpectrumFrame.SpanHz) -- the radio may clamp, round, or
        ignore this entirely, and a display that trusted its own request would
        draw the wrong frequencies against real data.  Does nothing on a radio
        that cannot do it, which is every one but the K4 today. }
      procedure SetSpectrumSpan(const aSpanHz: Integer); virtual;
      { The span the RADIO says it is set to, or 0 when it has not said.

        NOT the same number as TSpectrumFrame.SpanHz.  Measured on a K4: the
        frame reported 384 kHz while the radio reported 368 kHz for the same
        moment.  The frame's span is what is being DRAWN; this is the rig's
        SETTING, and it is the one to step from when asking for a change --
        stepping from the drawn width sends a request derived from a number the
        radio never had. }
      function SpectrumSpanHz: Integer; virtual;
      { Step the span ONE DETENT, in the direction this radio understands.
        aDirection < 0 narrows, > 0 widens; 0 does nothing.

        WHY THIS IS NOT JUST SetSpectrumSpan(current +/- something).  The step
        is a fact about the radio, and the two families do not merely differ in
        size -- they differ in KIND:

          * the K4 takes any span in Hz and CLAMPS what it cannot do, so a fine
            trim of a kHz at a time is meaningful and the rig reports back what
            it settled on;
          * an Icom offers EIGHT discrete spans (2.5 kHz .. 500 kHz) and SNAPS
            a request to the nearest.  A 1 kHz step never crosses the midpoint
            of a gap, so nearest-snapping returns the span it started from and
            the button is INERT -- at every span, in the widening direction.
            AetherSDR measured exactly that: zoom-out dead at all eight spans
            and zoom-in working at seven, an asymmetry that reads as "zoom is
            broken" rather than "zoom is quantised".

        So the caller asks for a detent and the radio decides what a detent is.
        The alternative -- a per-radio step size the window applies itself --
        cannot express snapping, and putting the choice in the window would
        make it ask which radio it has, which is the one thing this factory
        forbids.

        Does nothing on a radio with no span control, which is every one but
        the K4 and the network Icoms. }
      procedure StepSpectrumSpan(const aDirection: Integer); virtual;

      { Which source this radio's panadapter should show by default.

        OPAQUE, and matched against TSpectrumFrame.SourceId by string equality
        -- see uSpectrumTypes.  A radio that streams several sources down one
        link names its primary one here; a radio with one source still has to
        answer, because the window filters unconditionally and a mismatch is a
        window that never draws with nothing logged anywhere.

        THIS EXISTS BECAUSE THE CALL SITE USED TO SPELL IT.  uRadioPanelForm
        held `K4_MAIN_PAN_SOURCE = 'A'` and passed it to every radio, which was
        correct while the K4 was the only producer and silently wrong for the
        second one: an Icom's scope id is a number, so an Icom panadapter would
        have opened, streamed, and drawn nothing at all.

        Empty on a radio with no spectrum, which is the honest answer -- not a
        guess that happens to match one vendor. }
      function PrimarySpectrumSourceId: string; virtual;

      // Has StartSpectrum taken effect -- is a reader alive and trying?
      function SpectrumStreaming: Boolean; virtual;

      // Is the stream's link actually up right now?  DISTINCT from Streaming:
      // between a start and a successful connect, and throughout a reconnect
      // backoff, the reader is alive with no link.  That difference is exactly
      // the "Connecting..." versus "Connected" a panadapter window shows, and
      // collapsing the two would make a rig that is switched off look connected.
      function SpectrumLinkUp: Boolean; virtual;

      // Where finished frames go.  The window subscribes through a
      // TFactoryRadioBase reference and never learns which radio it has, which
      // is the rule this factory is built on.  Raised on the producer's
      // thread -- see TSpectrumFrameProc.
      property OnSpectrumFrame: TSpectrumFrameProc
               read FOnSpectrumFrame write FOnSpectrumFrame;

      constructor Create(ProcRef: TProcessMsgRef); overload;
      constructor Create(address: string; port: integer;ProcRef: TProcessMsgRef); overload;
      Destructor Destroy; overload; Virtual;

      procedure SendToRadio(s: string); overload; virtual;
      procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; Virtual; Abstract;
      // Per-radio state setters -- base owns storage; radio classes call these to
      // reflect on/off state into the field the matching display getter reads.
      procedure SetRITOn(value: boolean);
      procedure SetXITOn(value: boolean);
      procedure SetRITOffset(value: integer);    // Hz; mirrors on/off setters (scalar + every VFO copy)
      procedure SetXITOffset(value: integer);
      procedure SetSplitOn(value: boolean);
      procedure SetTransmitting(value: boolean);
      // True when this VFO is ALREADY known to be in this mode, so commanding it
      // again would put a redundant frame on the wire.  On most radios that is
      // merely wasteful; on some it has a SIDE EFFECT (see
      // rcSplitClearedByModeChange), which is why this is a guard and not a
      // micro-optimisation.
      function ModeAlreadySet(aMode: TRadioMode; aVFO: TVFO): boolean;
      // Record that TR4W has commanded split on or off, and refresh the
      // re-assert budget.  Called by drivers whose Split() can be undone by the
      // radio itself.
      procedure NoteSplitCommanded(aOn: boolean);
      // True when a reported split state contradicts one we commanded, on a radio
      // that declares rcSplitClearedByModeChange, and budget remains.  SPENDS the
      // budget when it returns True, so one call is one re-assert.
      function SplitNeedsReassert(aReportedOn: boolean): boolean;
      function ModeToString(mode: TRadioMode): string;
      property radioPort: integer read GetRadioPort write SetRadioPort;
      property radioAddress: string read GetRadioAddress write SetRadioAddress;
      property serialPort: portType read GetSerialPort write SetSerialPort;
      property PTTviaCAT: boolean read GetPTTviaCAT write SetPTTviaCAT;
      property CWSpeed: integer read GetCWSpeed;
      function Connect: integer; overload; virtual;
      function Connect (address: string; port: integer): integer; overload;
      function VFOToString(whichVFO: TVFO): string;
      procedure UpdateLastValidResponse;  // Call when valid radio response received

      // FLOW CONTROL FOR THE POLL LOOP.
      //
      // THE DEFECT THIS FIXES.  pFactoryRadio fired a poll every
      // pollingInterval whether or not the previous one had EVER been
      // answered.  A radio slower than that interval therefore accumulates
      // unbounded backlog in its own CAT input buffer -- and the moment a
      // radio gets slower is exactly when it is transmitting, which is when
      // latency matters most.
      //
      // Measured on NY4I's K3S, 2026-08-09, with a serial A/B that did not
      // involve TR4W at all:
      //     paced (request/response)      RX; -> receiving in   99 ms
      //     flooded at TR4W's 117 ms rate RX; -> receiving in  820 ms
      // The radio is not slow.  We were talking over it.
      //
      // THREADING.  MarkPollSent runs on the polling thread and the clear
      // runs on the reader thread.  Deliberately unlocked: both touch one
      // aligned Boolean, and the worst outcome of a race is one extra poll
      // or one skipped cycle -- paying for a lock on the hot path to prevent
      // that would be the wrong trade.
      procedure MarkPollSent;
      // True while a poll is unanswered and has not yet timed out.  The
      // timeout matters: without it a radio that stops answering would never
      // be polled again, and polling is how a dead link is DETECTED.
      function  PollOutstanding: boolean;
      // True only if the base constructor actually ran.  Exists because it can
      // silently NOT run: Create(ProcRef) is `overload`ed, so a subclass writing
      // `inherited Create;` instead of `inherited Create(ProcessMsg);` compiles
      // cleanly and resolves to TObject.Create.  The radio then has no
      // baseProcMsg (received frames go nowhere), FLastValidResponse = 0 (so it
      // reports ~126 years of silence and reopens its port forever) and no
      // SocketLock.  There is no compiler warning for this -- it cost a full
      // bench session on the Flex.  Asserted for every registered radio by
      // test/unit/uTestFlexRegistry.pas.
      // See the coverage block above: empty means no opinion, and this answers
      // True for everything.
      function  CoversFrequency(hz: LongInt): boolean;
      function  CoverageRangeCount: integer;

      function BaseConstructorRan: Boolean;
      procedure Disconnect; overload; virtual;
      property IsTransmitting: boolean read GetIsTransmitting;
      property IsReceiving: boolean read GetIsReceiving;
      property IsConnected: boolean read GetIsConnected;
      property IsOperational: boolean read GetIsOperational;
      property CanRecycleOnStuckHandshake: boolean read GetCanRecycleOnStuckHandshake;
      property AuthFailed: boolean read GetAuthFailed;
      property IsRITOn[whichVFO: TVFO]: boolean read GetIsRITOn;
      property IsXITOn[whichVFO: TVFO]: boolean read GetIsXITOn;
      property IsSplitEnabled: boolean read GetSplitEnabled;
      property band[whichVFO: TVFO]: TRadioBand read GetBand;

      { TRANSVERTER OFFSET, in Hz, added to every frequency this radio REPORTS and
        subtracted from every frequency it is TOLD to tune.

        NY4I operates a 10m-to-2m transverter: the radio reads 28.000 MHz and the
        QSO happened on 144.000, so the offset is 116000000 and the log must say
        144. Zero means no transverter, which is every radio by default and costs
        nothing.

        The setting has existed all along (FREQUENCY ADDER, documented in the
        Czech help as "transpozicni kmitocet") but its implementation was applied
        inside the per-model frequency decoders and went with them when the radio
        factory replaced the legacy pollers -- so it has been stored, persisted,
        synced to multi-op peers and editable, while doing nothing. }
      property FrequencyOffset: integer read FFrequencyOffset write FFrequencyOffset;
      property frequency[whichVFO: TVFO]: integer read GetFrequency;
      property mode[whichVFO: TVFO]: TRadioMode read GetMode;
      property dataMode[whichVFO: TVFO]: TRadioMode read GetDataMode;
      property RITOffset[whichVFO: TVFO]: integer read GetRITOffset;
      property XITOffset[whichVFO: TVFO]: integer read GetXITOffset;
      property IFShift[whichVFO: TVFO]: integer read GetIFShift;
      property filter[whichVFO: TVFO]: integer read GetFilter;
      // property Fields[Index: Integer]: TFieldSpec read GetField;
      //property FVFO[whichVFO: TVFO]: TRadioVFO read GetVFO;

      // Active (RX/operating) VFO. Default nrVFOA = "swap" model (K4: A/B
      // exchanges contents, so the active VFO is always A). Selectable-model
      // radios (Kenwood FR, Flex slice) call SetActiveVFO so the aggregate
      // main-window status (in pFactoryRadio) follows the receiving VFO.
      function GetActiveVFO: TVFO;
      procedure SetActiveVFO(vfo: TVFO);

   public

      // Polling interface - radios override to send appropriate query commands
      procedure QueryVFOAFrequency; Virtual;     // Query VFO A frequency
      procedure QueryVFOBFrequency; Virtual;     // Query VFO B frequency
      procedure QueryVFOAMode; Virtual;          // Query VFO A mode (Icom $26 $00)
      procedure QueryVFOBMode; Virtual;          // Query VFO B mode (Icom $26 $01)
      procedure QueryActiveVFO; Virtual;         // Query which VFO is active (Icom $07 $D2)
      procedure QueryMode; Virtual;              // Query current mode
      procedure QueryTXStatus; Virtual;          // Query TX/RX status
      procedure QueryRITState; Virtual;          // Query RIT on/off and value
      procedure QueryXITState; Virtual;          // Query XIT on/off and value
      procedure QueryBand; Virtual;              // Query current band
      procedure QuerySplitState; Virtual;        // Query split on/off
      procedure PollRadioState; Virtual;         // Main polling method - calls Query* methods

      procedure ProcessMsg(msg: string); Virtual; Abstract;
      procedure Transmit; Virtual; Abstract;
      procedure Receive; Virtual; Abstract;
      procedure BufferCW(msg: string); Virtual; Abstract;
      procedure SendCW; Virtual; Abstract;
      procedure StopCW; Virtual; Abstract;
      // Does THIS driver actually key CW itself?
      //
      // False (the default) means CW-by-CAT for this radio runs on the legacy
      // path -- LOGRADIO.RadioObject.SendCW builds the command and hands it to
      // AddToOutputBuffer, which routes to this object's SendToRadio.  The CW
      // methods above are then inert stubs that exist only to satisfy the
      // abstract contract (see uRadioElecraftSerial's header).
      //
      // This MUST be answered honestly, because RadioObject.StopSendingCW asks
      // it before delegating.  It used to delegate unconditionally, so on every
      // radio whose StopCW is an inert stub -- Elecraft serial (K2/K3/KX3),
      // Kenwood serial, Flex CAT, Orion -- Escape was swallowed: CW STARTED via
      // the legacy path and could never be STOPPED, because the legacy abort
      // ('KY '#4';RX;' for the K3) was never reached.  Bench: NY4I, K3,
      // 2026-07-31.
      function CWIsFactoryOwned: Boolean; Virtual;

      // Look this radio's declared spelling up for one of TR4W's prosign tokens.
      //
      // NOT virtual, and no driver overrides it: the mechanism is the same for
      // every radio, and the only thing that varies -- the five strings -- is
      // DATA the radio states in its constructor (FCapabilities.CWProsigns).
      // That is what keeps a new CW-by-CAT family, a Yaesu say, from having to
      // add code to any shared unit.
      function CWProsign(const token: string): TCWProsign;

      // Where a family states its prosign spellings.  Called from the base
      // constructor, so every radio in a family inherits them without touching
      // its own constructor -- and a driver that needs no CW says nothing.
      //
      // A VIRTUAL rather than an assignment in each family's constructor,
      // because the intermediate bases must not introduce a constructor of
      // their own: TFactoryRadioBase.Create is OVERLOADED, and a parameterless
      // `constructor Create; reintroduce` in between HIDES both overloads, so
      // every `inherited Create(ProcessMessage)` below it stops compiling.
      // See BaseConstructorRan for what that class of mistake costs.
      procedure DeclareCWProsigns; Virtual;

      procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); Virtual; Abstract;
      procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); Virtual; Abstract;
      function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; Virtual; Abstract;
      procedure SetCWSpeed(speed: integer); Virtual; Abstract;
      procedure RITClear(vfo: TVFO);  Virtual; Abstract;
      procedure XITClear(vfo: TVFO); Virtual; Abstract;
      procedure RITBumpDown; Virtual; Abstract;
      procedure RITBumpUp; Virtual; Abstract;
      procedure RITOn(vfo: TVFO); Virtual; Abstract;
      procedure RITOff(vfo: TVFO); Virtual; Abstract;
      procedure XITOn(vfo: TVFO); Virtual; Abstract;
      procedure XITOff(vfo: TVFO); Virtual; Abstract;
      procedure Split(splitOn: boolean); Virtual; Abstract;
      procedure SetRITFreq(vfo: TVFO; hz: integer); Virtual; Abstract;
      procedure SetXITFreq(vfo: TVFO; hz: integer); Virtual; Abstract;
      procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); Virtual; Abstract;
      function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; Virtual; Abstract;
      procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); Virtual; Abstract;
      function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; Virtual; Abstract;
      function  MemoryKeyer(mem: integer): boolean; Virtual; Abstract;
      procedure VFOBumpDown(whichVFO: TVFO); Virtual; Abstract;
      procedure VFOBumpUp(whichVFO: TVFO); Virtual; Abstract;

      // radioModel is a PROPERTY so that assigning it re-points the log category.
      // Assignment syntax is unchanged at all 92 call sites.
      //
      // WHY A SETTER AND NOT THE CONSTRUCTOR: nearly every subclass assigns
      // radioModel AFTER `inherited Create`, so the base ctor cannot read it.  The
      // setter also catches uRadioFactory's final
      // `Result.radioModel := DisplayName(model)`, so the category ends up matching
      // the name the operator picked in the radio list.

      // 'Icom IC-7610' -> 'TR4WDebugLog.IcomIC-7610'.  Log4D treats '.' as its
      // category separator, so a model name containing one would silently create a
      // child category; spaces make a category awkward to type in a log filter.
      class function LogCategoryFor(const model: string): string;
      procedure SetRadioModel(const value: string);

      property radioModel: string read FRadioModel write SetRadioModel;


end;


implementation

//Uses Unit1;
// NOT MainUnit -- see the note in uRadioElecraftK4.  This class declares its own
// `logger` field and sets it per radio in SetRadioModel, so it never needed the
// main window's global; pulling that graph into the factory base is what made
// dcc32 die with an internal error and stopped every cold build.
// LogRadio was here and was VESTIGIAL -- no symbol of it was referenced in any
// code in this section (the only textual hits, `rig` and `SetUpRadioInterface`,
// are in comments).  It was also the last edge from the radio factory into
// src/trdos: the base class of the factory depending on the legacy unit the
// factory replaced.  Removed 2026-08-08.  If a future change here needs
// something from LogRadio, that is the signal the concept belongs ON THE RADIO,
// not that this uses clause should come back.
Uses TypInfo;   // TypInfo: GetEnumName, for CapabilitiesAsText

const
   // How long the radio must be SILENT before its poll counts as answered.
   //
   // Sized from the wire, not chosen: on a K3S at 38400 the gaps BETWEEN the
   // replies to one multi-command poll ran a few milliseconds, while the gap
   // between one poll's last reply and the next poll was tens.  30 ms sits
   // clear of the first and well under the second.
   //
   // Too small and the gate releases mid-burst, which is the defect this
   // replaces.  Too large and it eats into the poll rate on a fast link.
   // The timeout in PollOutstanding is the backstop either way.
   POLL_QUIET_MS = 30;

var
   // TReadingThread IS NOT A RADIO.  It is a plain TThread declared beside
   // TFactoryRadioBase, so it does not inherit the `logger` FIELD, and its
   // logging used to resolve to MainUnit's global -- the one reference in this
   // unit that genuinely needed the main window.
   //
   // Log4D's GetLogger is a repository lookup: the same name always returns the
   // same instance (Log4D.pas, DefaultHierarchy.GetLogger).  So asking for
   // 'TR4WDebugLog' here yields the very object tr4w.dpr assigns to the global,
   // and the thread logs exactly where it always did -- without this unit
   // knowing the main window exists.
   //
   // Inside TFactoryRadioBase's own methods the class FIELD still wins over this
   // variable, so per-radio categories are unaffected.
   logger: TLogLogger;

// Byte-exact conversions for binary serial protocols (Icom CI-V). In a CI-V
// frame string each Char carries exactly one wire byte (Ord 0..255, including
// bytes >= $80 like the FE FE preamble, the $88 radio address, and the $FD EOM).
// These move the frame to/from TBytes with NO codepage or ASCII encoding -- the
// D12 default of WriteString(TEncoding.ASCII)/ReadString(SetString) replaces any
// byte >= $80 with '?' ($3F), which is what broke serial CI-V.
function WireBytesFromString(const s: string): TBytes;
var
   i: Integer;
begin
   SetLength(Result, Length(s));
   for i := 1 to Length(s) do
      begin
      Result[i - 1] := Byte(Ord(s[i]) and $FF);
      end;
end;

function WireStringFromBytes(const b: TBytes): string;
var
   i: Integer;
begin
   SetLength(Result, Length(b));
   for i := 0 to High(b) do
      begin
      Result[i + 1] := Char(b[i]);
      end;
end;

// Byte-exact hex for a wire frame carried in a Unicode string (one byte per Char).
// Use this for CI-V/serial trace lines instead of tree.String2Hex, whose AnsiString
// param forces a CP1252 conversion that renders bytes >= $80 (FE/88/FD) as '?' ($3F)
// -- making a correct frame look corrupted in the log.
function WireHex(const s: string): string;
var
   i: Integer;
begin
   Result := '';
   for i := 1 to Length(s) do
      begin
      Result := Result + IntToHex(Ord(s[i]) and $FF, 2) + ' ';
      end;
end;

//var
//   rt: TReadingThread = nil;
Constructor TFactoryRadioBase.Create(ProcRef: TProcessMsgRef);
var iVFO: TVFO;
begin
   {appender := TLogRollingFileAppender.Create('name','K4Test.log');
   appender.Layout := CreateTR4WLogLayout;

   TLogBasicConfigurator.Configure(appender);
   TLogLogger.GetRootLogger.Level := Trace;
   logger := TLogLogger.GetLogger('K4TestDebugLog');
   logger.info('******************** uFactoryRadioBase STARTUP ******************');
   logger.Trace('trace output');
   }
   // Default category, in force until a subclass sets radioModel.  Assigned FIRST
   // so nothing can log through a nil logger during construction.
   logger := TLogLogger.GetLogger('TR4WDebugLog.Radio');
   baseProcMsg := ProcRef;
   bAddTermination := True;   // default: append CR/LF; radios that must not (e.g. TS-890 LAN) set this False in their own constructor
   SerialProtocolIsBinary := False;  // default: serial CAT is ASCII text; TIcomRadio sets True for byte-exact CI-V
   FActiveVFO := nrVFOA;      // default swap-model (active VFO always A); selectable-model radios update via SetActiveVFO
   for iVFO := Low(TVFO) to High(TVFO) do
      begin
      Self.vfo[iVFO] := TRadioVFO.Create;
      Self.vfo[iVFO].ID := iVFO;
      end;
   //Self.vfo[nrVFOB] := TRadioVFO.Create;
   //Self.vfo[nrVFOB].ID := nrVFOB;                                                          -
   
   socket := TIdTCPClient.Create();
   socket.ConnectTimeout := 10000;  // TODO Make this a property
   socket.OnDisconnected := Self.OnRadioDisconnected;
   socket.OnConnected := Self.OnRadioConnected;
   socket.OnStatus := Self.OnRadioStatus;

   serialPortObj := nil;  // Will be created when needed for serial connections

   // Default serial port settings (can be overridden)
   serialBaudRate := 38400;
   serialDataBits := 8;
   serialStopBits := 1;
   serialParity := 0;  // No parity

   // Default polling settings (radios override as needed)
   requiresPolling := True;        // Most radios need polling
   honorsFreqPollRate := True;     // default: serial poll loop may use FREQUENCY POLL RATE; TIcomRadio sets False (heavy CI-V state poll + transceive)
   autoUpdateCommand := '';        // No auto-update by default
   pollingInterval := 100;         // 100ms default poll interval

   // CW-by-CAT framing default: no length limit, no padding, no prosign
   // substitution.  Correct as-is for the great majority of radios, which do not
   // declare rcCWByCAT at all and never reach the keyer.  A radio that DOES key
   // must state its own rule -- this default is indistinguishable from a zeroed
   // record, so a family base that forgets simply stops chunking, in silence.
   // Stated here rather than left implicit so that intent is on the page, and
   // pinned per keying radio by test/unit/uTestCWFraming.
   FCapabilities.CWFrame := uCWFraming.CWFrameRule(0, False);
   FCapabilities.HasXIT := True;   // assume it does; a radio that does not says so

   // Families override this; the base declares nothing, which means "grammar
   // not established -- pass tokens through as text".
   DeclareCWProsigns;

   SocketLock := TCriticalSection.Create;
   Disconnecting := False;
   FLastValidResponse := Now;  // Initialize to current time
   FPollAwaitingReply := False;
   FPollSentTick := 0;
   FPollHeardReply := False;
   FPollLastFrameTick := 0;
   FLastSerialReopenTick := GetTickCount;
   FSerialReopenDelay := RECONNECT_INITIAL_DELAY;
end;

{Constructor TFactoryRadioBase.Create(ProcRef: TProcessMsgRef);
begin
   baseProcMsg := ProcRef;
   inherited Create;
end;}

Constructor TFactoryRadioBase.Create(address: string; port: integer; ProcRef: TProcessMsgRef);
begin
   Self.radioAddress := address;
   Self.radioPort := port;
   Self.Create(ProcRef);
end;

// Default polling method implementations - radios override as needed
procedure TFactoryRadioBase.QueryVFOAFrequency;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryVFOBFrequency;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryVFOAMode;
begin
  // Default: do nothing - Icom overrides with $26 $00
end;

procedure TFactoryRadioBase.QueryVFOBMode;
begin
  // Default: do nothing - Icom overrides with $26 $01
end;

procedure TFactoryRadioBase.QueryActiveVFO;
begin
  // Default: do nothing - Icom overrides with $07 $D2 where supported
end;

procedure TFactoryRadioBase.QueryMode;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryTXStatus;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryRITState;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryXITState;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QueryBand;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.QuerySplitState;
begin
  // Default: do nothing - radio classes override
end;

procedure TFactoryRadioBase.RearmStartupCommand;
begin
   FStartupCommandSent := False;
   FStartupArmed := False;
end;

procedure TFactoryRadioBase.ApplyNetworkCredentials(const user, pass: string);
begin
   // Default: this radio does not authenticate.  Overridden by TIcomRadio and
   // TKenwoodLAN.
end;

procedure TFactoryRadioBase.ApplyDataModeID(id: integer);
begin
   // Default: this radio has no data sub-mode selector.
end;

procedure TFactoryRadioBase.ApplyAutoInfoLevel(level: integer);
begin
   // Most radios have no such concept.  Doing nothing is correct, not a stub.
end;

procedure TFactoryRadioBase.SendStartupCommand;
var
   reason: string;
begin
   // Once per link-up (RearmStartupCommand re-arms it when the link drops, so
   // a power-cycled radio gets it again).  The two transports reach "connected" at different
   // moments -- serial is up when Connect returns, network is not, and is only
   // known to be up when the poll loop sees a good response -- so both call
   // this and the guard decides.  Before this existed the serial path re-sent
   // the command on every SetUpRadioInterface while the network path sent it
   // once ever, which is the same setting behaving differently per transport.
   if FStartupCommandSent or (StartupCommand = '') then
      begin
      Exit;
      end;

   // Called on EVERY poll cycle while connected, not once at the connect
   // transition, so the settle below can actually elapse.  The guard above
   // still makes it one send per link-up; everything here is just "not yet".
   if not FStartupArmed then
      begin
      FStartupArmed := True;
      FStartupArmTick := GetTickCount;
      logger.Debug('[%s] Link up - holding startup command %d ms for the radio to settle',
                   [rigLabel, STARTUP_COMMAND_SETTLE_MS]);
      Exit;
      end;

   // LongWord subtraction, so a GetTickCount wrap is handled correctly.
   if GetTickCount - FStartupArmTick < LongWord(STARTUP_COMMAND_SETTLE_MS) then
      begin
      Exit;
      end;

   if not StartupCommandIsSendable(StartupCommand, reason) then
      begin
      // WARN, not silence: the operator configured this and it is NOT going
      // out.  FStartupCommandSent is set so it is said once per link-up rather
      // than on every poll cycle.
      logger.Warn('[%s] Startup command NOT sent -- %s: %s',
                  [rigLabel, reason, StartupCommand]);
      FStartupCommandSent := True;
      Exit;
      end;

   logger.Info('[%s] Sending startup command: %s', [rigLabel, StartupCommand]);
   Self.SendToRadio(StartupCommand);
   FStartupCommandSent := True;
end;

function TFactoryRadioBase.StartupCommandIsSendable(const cmd: string;
                                                    out reason: string): boolean;
begin
   // No opinion: this radio's wire format is not checkable here, so whatever
   // the operator configured goes out exactly as it always did.
   reason := '';
   Result := True;
end;

function TFactoryRadioBase.CWIsFactoryOwned: Boolean;
begin
  // Default NO: CW-by-CAT runs on the legacy path for most radios, and this
  // object's CW methods are inert stubs.  See the declaration for why an
  // honest answer matters (Escape was being swallowed).  A driver that really
  // keys CW overrides this to True.
  Result := False;
end;

procedure TFactoryRadioBase.DeclareCWProsigns;
begin
   // Deliberately empty.  CWProsigns.Declared stays False, and CWProsign then
   // reports every token unhandled so the caller keys it literally.
end;


function TFactoryRadioBase.CWProsign(const token: string): TCWProsign;
begin
  // Undeclared grammar, or a token that is not a prosign at all: the caller
  // keys it as literal text.
  Result.handled := False;
  Result.text := '';

  if not FCapabilities.CWProsigns.Declared then
     begin
     Exit;
     end;

  // Every arm sets handled := True, INCLUDING the ones whose text is empty.
  // Elecraft has no SN, so its '!' is consumed and keys nothing -- which is not
  // the same as letting '!' through to be keyed as a character.
  if token = '^' then
     begin
     Result.handled := True;
     Result.text := FCapabilities.CWProsigns.HalfSpace;
     end
  else if token = '!' then
     begin
     Result.handled := True;
     Result.text := FCapabilities.CWProsigns.SN;
     end
  else if token = '+' then
     begin
     Result.handled := True;
     Result.text := FCapabilities.CWProsigns.AR;
     end
  else if token = '<' then
     begin
     Result.handled := True;
     Result.text := FCapabilities.CWProsigns.SK;
     end
  else if token = '=' then
     begin
     Result.handled := True;
     Result.text := FCapabilities.CWProsigns.BT;
     end;

  // NOT handled by any radio, deliberately: '&' (AS).  LOGRADIO carried a
  // commented-out arm mapping it to '%' on Elecraft and '<' on Kenwood,
  // disabled because in TR4W '&' is really MYSTATE and only documented as AS.
  // Give it a field if that is ever settled; do not guess first.
end;

function CWProsigns(const halfSpace, sn, ar, sk, bt: string): TCWProsignSet;
begin
   Result.Declared  := True;
   Result.HalfSpace := halfSpace;
   Result.SN        := sn;
   Result.AR        := ar;
   Result.SK        := sk;
   Result.BT        := bt;
end;

procedure TFactoryRadioBase.PollRadioState;
begin
  // Default implementation - query all radio state
  QueryVFOAFrequency;
  QueryVFOBFrequency;
  QueryMode;
  QueryTXStatus;
  QueryRITState;
  QueryXITState;
  QueryBand;
  QuerySplitState;
end;

Destructor TFactoryRadioBase.Destroy;
var iVFO: TVFO;
begin
   // For serial: close the port FIRST so the reading thread's ReadString
   // returns immediately (ESerialError), allowing rt.WaitFor to complete quickly.
   // Without this, WaitFor blocks for up to the ReadString timeout (10ms) but
   // the port stays open, preventing the new radio from opening it.
   if serialPortObj <> nil then
      begin
      if serialPortObj.IsOpen then
         begin
         serialPortObj.Close;
         end;
      end;

   if rt <> nil then
      begin
      rt.Terminate;
      rt.WaitFor;
      FreeAndNil(rt);
      end;

   if socket <> nil then
      begin
      if socket.Connected then
         begin
         socket.Disconnect;
         end;
      FreeAndNil(socket);
      end;

   if serialPortObj <> nil then
      begin
      FreeAndNil(serialPortObj);
      end;

   for iVFO := Low(TVFO) to High(TVFO) do
      begin
      FreeAndNil(Self.vfo[iVFO]);
      end;
   //FreeAndNil(Self.vfo[1]);
   //FreeAndNil(Self.vfo[2]);

   FreeAndNil(SocketLock);
end;

// Events

procedure TFactoryRadioBase.OnRadioConnected(Sender: TObject);
begin
   logger.Info('Network Radio connected');

   // Clear disconnecting flag on successful connection
   Disconnecting := False;

   // Only create reading thread if one doesn't already exist
   // (the thread creates itself during reconnection)
   if rt = nil then
      begin
      rt := TReadingThread.Create(socket, baseProcMsg, SocketLock, @Disconnecting);
      rt.readTerminator := Self.readTerminator;
      rt.radioName := Self.rigLabel + ' ' + Self.radioModel;
      logger.Info('Created new reading thread');
      end
   else
      begin
      logger.Info('Reading thread already exists, no need to create new one');
      end;

   // Initial probing is each subclass's responsibility: K4 sends its own
   // 'RT;XT;RO;FT;ID;MD;DT$;IF;' query, TS-890 sends '##CN;' to start LAN
   // auth (Issue #436), Icom uses its CI-V transport handshake.  A generic
   // 'ID;' here was Kenwood-shaped and either redundant (K4), wasted (Flex
   // rejected it as unknown) or actively broken (TS-890 LAN requires '##CN;'
   // to be the first byte).
end;

procedure TFactoryRadioBase.OnRadioDisconnected(Sender: TObject);
begin
   logger.Info('<<<<<<<<<<<<<< Network Radio disconnected');
   {if rt <> nil then
      begin
      rt.Terminate;
      rt.WaitFor;
      FreeAndNil(rt);
      end;  }
end;

procedure TFactoryRadioBase.OnRadioStatus(Sender: TObject; const Status: TIdStatus; const AStatusText: TIdText);
begin
   // Indy's TIdComponent.OnStatus: the TRANSPORT narrating itself
   // ("Connecting to 192.168.73.108.", "Connected.", "Disconnected."), which is
   // not one byte of radio traffic.  It logged as "Received text from radio"
   // until 2026-08-13, and that framing actively misleads during the one
   // situation the line exists for -- reading back a failed connection, where
   // it reads as the rig answering before it has said anything at all.  Radio
   // bytes are logged by ProcessMessage and the RX/TX hex dumps; nothing that
   // reaches here came from the air.
   logger.trace('[Link] %s', [AStatusText]);
end;

{procedure TFactoryRadioBase.IdThreadComponentRun(Sender: TIdThreadComponent);
var
    msgFromServer : string;
begin
    // ... read message from server
    msgFromServer := socket.IOHandler.ReadLn();

    // ... messages log
    logger.info('[IdThreadComponentRun] Received from NetRadio: [%s]', [msgFromServer]);
end;
// .............................................................................
}

function TFactoryRadioBase.GetRadioPort: integer;
begin
   Result := Self.localPort;
end;

procedure TFactoryRadioBase.SetRadioPort(Value: Integer);
begin
   Self.localPort := Value;
   // Since the port was changed, disconnect? Or just wait until next time?

end;

function TFactoryRadioBase.GetSerialPort: portType;
begin
   Result := Self.localSerialPort;
end;

procedure TFactoryRadioBase.SetSerialPort(Value: portType);
begin
   Self.localSerialPort := Value;
   // Since the port was changed, disconnect? Or just wait until next time?

end;

function TFactoryRadioBase.GetPTTviaCAT: boolean;
begin
   Result := Self.PTTviaCAT;
   logger.trace('[GetPTTviaCAT] Returning %s for PTTviaCAT',[BoolToStr(Result)]);
end;

procedure TFactoryRadioBase.SetPTTviaCAT(Value: boolean);
begin
   Self.PTTviaCAT := Value;
   logger.Debug('[SetPTTviaCAT] Setting PTTviaCAT to %s',[BoolToStr(Value)]);
end;

function TFactoryRadioBase.GetRadioAddress: string;
begin
   Result := Self.localAddress;
end;

procedure TFactoryRadioBase.SetRadioAddress(Value: string);
begin
  Self.localAddress := Value;
end;

function TFactoryRadioBase.Connect: integer;
var
   comPortName: string;
   portNum: Integer;
begin
   Result := 0;

   // Check if this is a serial or network connection
   if Self.serialPort <> NoPort then
      begin
      // Serial connection
      portNum := Ord(Self.serialPort);  // Serial1=1, Serial2=2, etc.
      comPortName := Format('COM%d', [portNum]);

      logger.Info('[TFactoryRadioBase.Connect] Connecting to serial radio on %s', [comPortName]);

      try
         // Create serial port if needed
         if serialPortObj = nil then
            begin
            serialPortObj := TSerialPort.Create(comPortName);
            end;

         // For serial ports: if already open with reading thread, don't close/reopen
         // This prevents race conditions during reconnection attempts
         if serialPortObj.IsOpen and (rt <> nil) then
            begin
            logger.Debug('[TFactoryRadioBase.Connect] Serial port already open with reading thread, keeping connection alive');
            // Clear any accumulated garbage from the buffer
            rt.ClearSerialBuffer;
            Result := 0;
            Exit;
            end;

         // Close if already open (for initial setup or error recovery)
         if serialPortObj.IsOpen then
            begin
            logger.Debug('[TFactoryRadioBase.Connect] Serial port already open, closing first');
            serialPortObj.Close;
            end;

         // Open with configured port settings
         serialPortObj.OpenRaw(serialBaudRate, serialDataBits, serialStopBits, serialParity, serialRts, serialDtr);
         logger.Info('[TFactoryRadioBase.Connect] Serial port %s opened: %d baud, %d data bits, parity %d, %d stop bits, RTS=%s, DTR=%s',
                     [comPortName, serialBaudRate, serialDataBits, serialParity, serialStopBits,
                      BoolToStr(serialRts, True), BoolToStr(serialDtr, True)]);

         // Clear disconnecting flag on successful connection
         Disconnecting := False;

         // Create reading thread for serial port
         if rt = nil then
            begin
            rt := TReadingThread.Create(serialPortObj, baseProcMsg, SocketLock, @Disconnecting);
            rt.readTerminator := Self.readTerminator;
            rt.radioName := Self.rigLabel + ' ' + Self.radioModel;
            rt.binaryProtocol := Self.SerialProtocolIsBinary;  // Icom CI-V: read raw bytes, not a codepage-decoded string
            rt.fixedFrameLength := Self.SerialFixedFrameLength; // Yaesu FT1000MP: fixed-length binary, no terminator
            rt.frameValidator := Self.ValidateFrame;  // virtual: resolves to the radio's override, or the base's accept-all
            logger.Info('[TFactoryRadioBase.Connect] Created serial reading thread');
            end;

         Result := 0;
      except
         on E: Exception do
            begin
            logger.Error('[TFactoryRadioBase.Connect] Exception opening serial port %s: %s', [comPortName, E.Message]);
            Result := -1;
            end;
      end;
      end
   else
      begin
      // Network connection
      logger.Info('[TFactoryRadioBase.Connect] Connecting to network radio at address %s, port = %d',[Self.radioAddress,Self.radioPort]);

      if Self.radioPort = 0 then
         begin
         logger.Error('Called connect with port = 0. result = -1');
         Result := -1;
         Exit;
         end;

      if length(Self.radioAddress) = 0 then
         begin
         logger.Error('Called connect with address = 0. result = -2');
         Result := -2;
         Exit;
         end;

      if not Assigned(socket) then
         begin
         logger.fatal('In TFactoryRadioBase.Connect, socket is NUL');
         end;

      socket.Port := Self.radioPort;
      socket.Host := Self.radioAddress;
      // Connect runs on a background thread (the reconnect loop), so a longer
      // timeout does not block the UI. The original 10ms was too short for
      // anything but a same-subnet LAN: a VPN/WAN TCP handshake to N2SKH's radio
      // measured ~95ms, so 10ms always tripped "Connect timed out" before the
      // handshake finished (ARCP and telnet succeed because they use the multi-
      // second OS default). 5000ms covers a slow/jittery VPN while still failing
      // in ~5s when a radio is genuinely off. - raised from 10 on 2026-05-31.
      socket.ConnectTimeout := 5000;

      try
          // Force disconnect to clear any corrupted socket state
          try
             if socket.Connected then
                begin
                logger.Debug('[TFactoryRadioBase.Connect] Socket already connected, disconnecting first');
                socket.Disconnect;
                end;
          except
             on E: Exception do
                begin
                logger.Debug('[TFactoryRadioBase.Connect] Exception during disconnect check: %s - forcing disconnect', [E.Message]);
                // Force disconnect even if Connected check fails
                try
                   socket.Disconnect;
                except
                   // Ignore disconnect errors
                end;
                end;
          end;

          Sleep(100);  // Brief delay to ensure cleanup

          logger.Debug('[TFactoryRadioBase.Connect] Attempting to connect to %s:%d', [socket.Host, socket.Port]);
          socket.Connect;
          logger.Info('[TFactoryRadioBase.Connect] Connected successfully to network radio');
      except
          on E: Exception do
             begin
             logger.Error('[TFactoryRadioBase.Connect] Exception when connecting to radio (%s:%d]: %s', [socket.Host, socket.Port, E.Message]);
             // Try to disconnect to clear bad state for next attempt
             try
                socket.Disconnect;
             except
                // Ignore disconnect errors
             end;
             end;
      end;
      end;
end;

function TFactoryRadioBase.Connect(address: string; port: integer): integer;
begin
   Self.radioAddress := address;
   Self.radioPort := port;
   Result := Self.Connect;
end;

procedure TFactoryRadioBase.Disconnect;
begin
   if socket.Connected then
      begin
      try
         logger.debug('Calling Disconnect - user request');
         // Disconnect the socket to pull it off the ReadLn so the thread in Execute sees that it is Terminated.
         socket.Disconnect;
         if rt <> nil then
            begin
            rt.Terminate;
            rt.WaitFor;
            FreeAndNil(rt);
            end;
      except
         on E: Exception do
            begin
            logger.Error('Exception when disconnecting from radio: %s', [E.Message]);
            end;
      end;
      end
   else if (serialPortObj <> nil) and serialPortObj.IsOpen then
      begin
      try
         logger.debug('[TFactoryRadioBase.Disconnect] Closing serial port and terminating reading thread');
         // Close serial port first so ReadString in reading thread returns immediately
         serialPortObj.Close;
         if rt <> nil then
            begin
            rt.Terminate;
            rt.WaitFor;
            FreeAndNil(rt);
            end;
      except
         on E: Exception do
            begin
            logger.Error('[TFactoryRadioBase.Disconnect] Exception when disconnecting serial radio: %s', [E.Message]);
            end;
      end;
      end;
end;

// Accept every candidate frame -- the behaviour before validation existed.  Radios
// with self-identifying frames override this; see uRadioYaesuFT817.
function TFactoryRadioBase.ValidateFrame(const frame: string): Boolean;
begin
   Result := True;
end;

// Close and reopen the serial port, discarding anything buffered.
//
// Needed because "the port is still open" does NOT mean "the link still works".
// Bench-proven on NY4I's FT-1000MP (2026-07-27): power the radio off and back on
// and the port stays healthy -- no read exception, every write accepted, polls
// going out -- yet the radio answers NOTHING until the port is reopened.  Opening
// a port is the only moment the control lines are driven and the interface is
// re-initialised; a CAT interface that lost power with the radio never comes back
// without it.  Merely continuing to poll, which is what the recovery path did,
// polls into a void forever.
//
// It also drops any PARTIAL FRAME left over from the outage.  The same capture
// ended with 36 of 38 bytes stuck in the reader: without clearing, the first two
// bytes from the revived radio would have completed a garbage frame and every
// frame after would have been offset -- silently, on a radio with no ValidateFrame.
function TFactoryRadioBase.ReopenSerialPort: Boolean;
begin
   Result := False;
   if (Self.serialPort = NoPort) or (not Assigned(serialPortObj)) then
      begin
      Exit;
      end;
   try
      // Clear FIRST: the reading thread may be mid-read, and closing the port
      // makes its next read fail harmlessly (it catches, sleeps and retries).
      if Assigned(rt) then
         begin
         rt.ClearSerialBuffer;
         end;
      if serialPortObj.IsOpen then
         begin
         serialPortObj.Close;
         end;
      serialPortObj.OpenRaw(serialBaudRate, serialDataBits, serialStopBits,
                            serialParity, serialRts, serialDtr);
      Result := serialPortObj.IsOpen;
      if Result then
         begin
         // A REOPENED PORT IS A NEW LINK, so the disconnecting flag must go --
         // exactly as Connect clears it.  Without this, MaintainSerialLink did
         // the hard part (noticing the silence, closing, reopening) and was
         // then FORBIDDEN TO USE the port it had just opened: SendToRadio drops
         // every command while Disconnecting is set, so no poll ever went out.
         //
         // NY4I found it on an FT-1000MP that would not come back after a power
         // cycle until Reset Radio Ports -- which works because it runs Connect,
         // which clears this.  tr4w.log 2026-08-11 17:34:59 shows the port
         // reopening six times on the 1s..30s backoff while
         // '[SendToRadio] Ignoring command - radio is disconnecting' repeats 688
         // times.  The port was fine; nothing was allowed to talk to it.
         //
         // NOT A YAESU DEFECT, though that is where it shows.  A radio that
         // volunteers data on power-up -- an Elecraft in AI2, an Icom in
         // transceive -- recovers anyway, because the reading thread hears it
         // without TR4W having to ask, and the stuck flag never matters.  The
         // FT-1000MP is strictly polled and says nothing until asked, so
         // silence was the only possible outcome.  Confirmed by prediction
         // before the fix: NY4I set a K3 to AI0, power-cycled it, and it failed
         // in exactly the same way.
         Disconnecting := False;

         logger.Info('[ReopenSerialPort] %s reopened COM%d after prolonged silence',
                     [Self.radioModel, Ord(Self.serialPort)]);
         end
      else
         begin
         logger.Warn('[ReopenSerialPort] %s could not reopen COM%d',
                     [Self.radioModel, Ord(Self.serialPort)]);
         end;
   except
      on E: Exception do
         begin
         logger.Error('[ReopenSerialPort] %s failed to reopen COM%d: %s - %s',
                      [Self.radioModel, Ord(Self.serialPort), E.ClassName, E.Message]);
         Result := False;
         end;
   end;
end;

// Link maintenance for a serial radio that has stopped answering.  Ticked by the
// poll loop; all the policy lives here so recovery belongs to the radio rather
// than to the legacy polling unit.
//
// The reopen is throttled and backs off, because "not answering" is usually just
// a radio switched off: the first retry is prompt (off-and-straight-back-on is
// the common case) and the interval then doubles to RECONNECT_MAX_DELAY so a rig
// left off overnight costs one reopen every 5s rather than a tight loop.  See
// that constant for why 5 and not 30: the wait, not the radio, was most of a
// measured 13.55 s recovery.
// FSerialReopenDelay resets in UpdateLastValidResponse, i.e. the moment the radio
// speaks again -- there is no separate "we are healthy" bookkeeping to get wrong.
procedure TFactoryRadioBase.MaintainSerialLink;
begin
   if Self.serialPort = NoPort then
      begin
      Exit;      // network radios reconnect via the socket path
      end;
   if GetTickCount - FLastSerialReopenTick < LongWord(FSerialReopenDelay) then
      begin
      Exit;
      end;
   logger.Info('[MaintainSerialLink] %s silent for %d ms - reopening the port',
               [Self.radioModel, FSerialReopenDelay]);
   ReopenSerialPort;
   FLastSerialReopenTick := GetTickCount;
   FSerialReopenDelay := FSerialReopenDelay * RECONNECT_BACKOFF_MULTIPLIER;
   if FSerialReopenDelay > RECONNECT_MAX_DELAY then
      begin
      FSerialReopenDelay := RECONNECT_MAX_DELAY;
      end;
end;

function TFactoryRadioBase.BaseConstructorRan: Boolean;
begin
   // Witnesses set only in Create(ProcRef); see the declaration for why.
   Result := Assigned(baseProcMsg) and Assigned(SocketLock) and (FLastValidResponse > 0);
end;

class function TFactoryRadioBase.LogCategoryFor(const model: string): string;
var
   i: Integer;
begin
   Result := '';
   for i := 1 to Length(model) do
      begin
      if not (model[i] in [' ', '.', #9]) then
         begin
         Result := Result + model[i];
         end;
      end;
   if Result = '' then
      begin
      Result := 'Radio';
      end;
   Result := 'TR4WDebugLog.' + Result;
end;

procedure TFactoryRadioBase.SetRadioModel(const value: string);
begin
   FRadioModel := value;
   // Log4D hands back the SAME logger for a repeated category, so re-assigning on
   // every name change is cheap and leaves no orphans.
   logger := TLogLogger.GetLogger(LogCategoryFor(value));
end;

procedure TFactoryRadioBase.MarkPollSent;
begin
   FPollAwaitingReply := True;
   FPollSentTick := GetTickCount;
   FPollHeardReply := False;
   FPollLastFrameTick := FPollSentTick;
end;

function TFactoryRadioBase.PollOutstanding: boolean;
var
   limit: cardinal;
begin
   if not FPollAwaitingReply then
      begin
      Result := False;
      Exit;
      end;

   // Three intervals, floor 500 ms.  Generous on purpose: the point is to
   // stop us TALKING OVER the radio, not to police its response time, and
   // giving up too early puts the flood straight back.
   limit := cardinal(pollingInterval) * 3;
   if limit < 500 then
      begin
      limit := 500;
      end;

   // Unsigned subtraction throughout, so the 49.7-day GetTickCount wrap
   // cannot make a fresh poll look ancient and re-open the flood.
   if (GetTickCount - FPollSentTick) >= limit then
      begin
      // Timed out.  Poll anyway: polling is how a dead link is DETECTED, and
      // a radio that has stopped answering must not stop being asked.
      Result := False;
      Exit;
      end;

   if not FPollHeardReply then
      begin
      // Sent, nothing back yet.  Still outstanding.
      Result := True;
      Exit;
      end;

   // QUIESCENCE, NOT "A FRAME ARRIVED".  A poll is answered when the radio
   // has STOPPED talking, not when it has started.
   //
   // This was the first version's defect and it is worth spelling out,
   // because "any valid frame clears the gate" reads as obviously correct
   // and is not.  A multi-command poll draws several replies.  Releasing on
   // the first one lets the next poll out while the rest are still being
   // processed, so every cycle ADDS more commands than the radio retires and
   // the backlog grows without bound -- positive feedback, not a slightly
   // weaker heuristic.
   //
   // Measured on a K3S over serial (tools/k3watch.py, TR4W not in the path),
   // unkey latency during transmit:
   //
   //     poll          released on first reply     released on quiescence
   //     IF;FB;              3593 ms / wedged              203 ms
   //     IF;FB;MD$;DT$;       672 ms                       609 ms
   //
   // The two-command row is the one that matters: same poll, same radio,
   // 17x difference, and the first-reply run had to be abandoned once
   // because the rig never came out of transmit.
   //
   // Silence is also the only rule that generalises.  Counting expected
   // replies would work for Elecraft, where commands and responses pair up,
   // and cannot work for Icom CI-V or the binary Yaesus, which answer in
   // frames that do not map one-to-one onto what was asked.
   Result := (GetTickCount - FPollLastFrameTick) < POLL_QUIET_MS;
end;

procedure TFactoryRadioBase.UpdateLastValidResponse;
begin
   FLastValidResponse := Now;
   // The radio is TALKING.  That does not mean the poll is answered -- see
   // PollOutstanding, which waits for it to stop.  Note the gate is NOT
   // cleared here: doing that was the bug.
   FPollHeardReply := True;
   FPollLastFrameTick := GetTickCount;
   // The radio is talking, so any reopen backoff has served its purpose.
   // Resetting HERE means the recovery bookkeeping cannot drift out of step
   // with liveness -- there is no separate we-are-healthy flag to forget.
   FSerialReopenDelay := RECONNECT_INITIAL_DELAY;
   logger.Trace('[UpdateLastValidResponse] Updated last valid response timestamp');
end;

procedure TFactoryRadioBase.SendToRadio(s: string);
var nLen: integer;
begin
   // Don't try to send if we're disconnecting
   if Disconnecting then
      begin
      logger.debug('[SendToRadio] Ignoring command (%s) - radio is disconnecting',[s]);
      Exit;
      end;

   SocketLock.Enter;
   try
      try
         // Check if using serial or network
         if (Self.serialPort <> NoPort) and Assigned(serialPortObj) and serialPortObj.IsOpen then
            begin
            // Serial connection.  On a BINARY protocol the frame is raw bytes, so it
            // must NOT be echoed through %s: any $0A/$0D in it (the Yaesu FT-1000MP
            // set-frequency opcode IS $0A) breaks the log line and takes the Hex:[]
            // dump with it -- losing exactly the diagnostic we want.  Log hex only.
            if SerialProtocolIsBinary then
               begin
               logger.Trace('[%s %s TX] Hex:[%s]',[Self.rigLabel, Self.radioModel, WireHex(s)]);
               end
            else
               begin
               logger.Trace('[%s %s TX] (%s) Hex:[%s]',[Self.rigLabel, Self.radioModel, s, WireHex(s)]);
               end;
            if SerialProtocolIsBinary then
               begin
               // Icom CI-V: raw frame, already terminated by $FD -- write byte-exact,
               // no ASCII encoding and no CR (a stray #13 is not part of a CI-V frame).
               serialPortObj.WriteBytes(WireBytesFromString(s));
               end
            else
               begin
               serialPortObj.WriteString(s + #13);  // K4 expects CR terminator
               end;
            end
         else if socket.Connected then
            begin
            // Network connection
            logger.Trace('[%s %s TX] (%s) Hex:[%s]',[Self.rigLabel, Self.radioModel, s, WireHex(s)]);
            nLen := length(s);
            // Most network radios accept or simply ignore a trailing CR/LF, so
            // by default we append one (WriteLn). The Kenwood TS-890 LAN CAT
            // parser is the exception: once authenticated it rejects a trailing
            // CR/LF with '?;', so it sets bAddTermination := False and we send
            // the bare ';'-terminated command -- matching Kenwood's own ARCP.
            if bAddTermination then
               begin
               socket.IOHandler.WriteLn(s);
               end
            else
               begin
               socket.IOHandler.Write(s);
               end;
            end
         else
            begin
            logger.error('[SendToRadio] Cannot send command (%s) to radio as not connected',[s]);
            end;
      except
         on E: Exception do
            begin
            logger.error('Exception caught on TFactoryRadioBase.SendToRadio - Command was (%s) - Exception: %s - %s',[s, E.ClassName, E.Message]);
            end;
      end;
   finally
      SocketLock.Leave;
   end;
end;

function TFactoryRadioBase.GetIsTransmitting: boolean;
begin
   Result := (Self.radioState = rsTransmit);
end;

function TFactoryRadioBase.GetIsReceiving: boolean;
begin
   Result := (Self.radioState = rsReceive);
end;

function TFactoryRadioBase.GetCWSpeed: integer;
begin
   Result := Self.localCWSpeed;
end;

function TFactoryRadioBase.GetIsRITOn(whichVFO: TVFO): boolean;
begin
   Result := Self.vfo[whichVFO].RITState;
   //logger.debug('In GetIsRITON, result = %s',[BoolToString(Result)]);
end;

function TFactoryRadioBase.GetRITOffset(whichVFO: TVFO): integer;
begin
   Result := Self.vfo[whichVFO].RITOffset;
end;


function TFactoryRadioBase.GetIsXITOn(whichVFO: TVFO): boolean;
begin
   Result := Self.vfo[whichVFO].XITState;
end;

function TFactoryRadioBase.GetXITOffset(whichVFO: TVFO): integer;
begin
   Result := Self.vfo[whichVFO].XITOffset;
end;

function TFactoryRadioBase.GetIsConnected: boolean;
begin
   // If we're disconnecting, immediately return false
   if Disconnecting then
      begin
      Result := false;
      Exit;
      end;

   // Check serial connection first
   if (Self.serialPort <> NoPort) and Assigned(serialPortObj) then
      begin
      try
         // For serial, port being "open" isn't enough - radio might be powered off
         // Check if we've received valid responses recently
         if not serialPortObj.IsOpen then
            begin
            Result := false
            end
         else if (Now - FLastValidResponse) * 86400 > SERIAL_RESPONSE_TIMEOUT then
            begin
            logger.Info('[GetIsConnected] Serial radio not responding (%.1f seconds since last valid response)',
                        [(Now - FLastValidResponse) * 86400]);
            Result := false;
            end
         else
            begin
            Result := true;
            end;
      except
         on E: Exception do
            begin
            logger.debug('Exception checking serial connection: %s - %s', [E.ClassName, E.Message]);
            Result := false;
            end;
      end;
      end
   // Otherwise check network connection
   else if Assigned(Self.socket) then
      begin
      try
         Result := socket.Connected;
      except
         on E: Exception do
            begin
            logger.debug('Exception in GetIsConnected: %s - %s', [E.ClassName, E.Message]);
            Result := false;
            end;
      end;
      end
   else
      begin
      logger.debug('In TFactoryRadioBase.GetIsConnected, socket is nil');
      Result := false;
      end;
end;

function TFactoryRadioBase.GetIsOperational: boolean;
begin
   // Default: connected = operational.
   // Radios with richer state (e.g. Flex slices) override this.
   Result := True;
end;

function TFactoryRadioBase.GetCanRecycleOnStuckHandshake: boolean;
begin
   // Default False: don't force a Disconnect+Connect cycle when stuck in
   // IsConnected=True/IsOperational=False.  Radios where the two states
   // are independent (Flex: TCP vs slice) would just churn TCP without
   // fixing the actual issue.  Override and return True for radios where
   // a fresh handshake is the right recovery path (e.g. TIcomRadio).
   Result := False;
end;

function TFactoryRadioBase.GetAuthFailed: boolean;
begin
   Result := False;
end;

function TFactoryRadioBase.GetFrequency(whichVFO: TVFO) : integer;
begin
   Result := Self.vfo[whichVFO].frequency;

   // THE ONE PLACE THE OFFSET IS ADDED. Everything outside the factory reads the
   // frequency through the `frequency[]` property, which is this getter -- the
   // publish into rig^.CurrentStatus.Freq (uRadioPolling) included. Adding it at
   // each driver's decode site is what the legacy code did, and it is how the
   // feature was lost: 21 drivers, and a new one silently opts out.
   //
   // ZERO IS NOT A FREQUENCY. It means "nothing known yet" -- a radio that has
   // not answered, or a VFO B that does not exist. Offsetting it would turn an
   // unknown into a confident 116 MHz and put a band on it.
   if (Result <> 0) and (FFrequencyOffset <> 0) then
      begin
      Inc(Result, FFrequencyOffset);
      end;
end;

function TFactoryRadioBase.BandToFreq(band: TRadioBand): LongInt;
begin
   Result := RadioBandToFreq(band);
end;

procedure TFactoryRadioBase.ClearCoverage;
begin
   FCoverageCount := 0;
end;

procedure TFactoryRadioBase.AddCoverageRange(lowHz, highHz: LongInt);
begin
   if (lowHz <= 0) or (highHz < lowHz) then
      begin
      logger.Warn('[%s] Ignoring nonsense coverage range %d..%d Hz',
                  [radioModel, lowHz, highHz]);
      Exit;
      end;
   if FCoverageCount >= High(FCoverage) then
      begin
      logger.Warn('[%s] Coverage table full at %d ranges; ignoring %d..%d Hz',
                  [radioModel, FCoverageCount, lowHz, highHz]);
      Exit;
      end;
   Inc(FCoverageCount);
   FCoverage[FCoverageCount].lowHz := lowHz;
   FCoverage[FCoverageCount].highHz := highHz;
end;

function TFactoryRadioBase.CoverageRangeCount: integer;
begin
   Result := FCoverageCount;
end;

function TFactoryRadioBase.CoversFrequency(hz: LongInt): boolean;
var
   i: integer;
begin
   // No declared coverage = no opinion = yes.  This is what keeps every radio
   // that cannot report its ranges behaving exactly as it did before.
   if FCoverageCount = 0 then
      begin
      Result := True;
      Exit;
      end;

   for i := 1 to FCoverageCount do
      begin
      if (hz >= FCoverage[i].lowHz) and (hz <= FCoverage[i].highHz) then
         begin
         Result := True;
         Exit;
         end;
      end;
   Result := False;
end;

function TFactoryRadioBase.GetBand(whichVFO: TVFO): TRadioBand;
begin
   // THE BAND MUST FOLLOW THE OFFSET, or the QSO is logged on the wrong one.
   //
   // The band is a STORED field the driver derived from the radio's own reading,
   // and ActiveBand comes straight from it (uRadioPolling: ActiveBand :=
   // rig.FilteredStatus.Band). With a 10m-to-2m transverter that would log
   // 144.200 MHz as 10 METRES -- the right frequency on the wrong band, in the
   // submitted Cabrillo.
   //
   // Only when an offset is in force: with none, the driver's own answer is
   // returned untouched, so no existing radio changes behaviour.
   if FFrequencyOffset <> 0 then
      begin
      Result := FreqToRadioBand(GetFrequency(whichVFO));
      end
   else
      begin
      Result := Self.vfo[whichVFO].band;
      end;
end;

function TFactoryRadioBase.GetMode(whichVFO: TVFO): TRadioMode;
begin
   Result := Self.vfo[whichVFO].mode;
end;

function TFactoryRadioBase.GetActiveVFO: TVFO;
begin
   Result := FActiveVFO;
end;

procedure TFactoryRadioBase.SetActiveVFO(vfo: TVFO);
begin
   FActiveVFO := vfo;
end;

function TFactoryRadioBase.GetDataMode(whichVFO: TVFO): TRadioMode;
begin
   Result := Self.vfo[whichVFO].dataMode;
end;

function TFactoryRadioBase.GetIFShift(whichVFO: TVFO): integer;
begin
   Result := Self.vfo[whichVFO].IFShift;
end;

function TFactoryRadioBase.GetFilter(whichVFO: TVFO): integer;
begin
   Result := Self.vfo[whichVFO].filter;
end;

function TFactoryRadioBase.GetSplitEnabled: boolean;
begin
   Result := Self.localSplitEnabled;
end;

// ---- Capabilities: callers ask the object what it can do (see TRadioCapabilities). ----
procedure TFactoryRadioBase.SetExpectedFrameLength(n: integer);
begin
   // Keep both in step: the field is what a later reconnect copies from, the
   // thread's copy is what actually delimits the stream right now.
   SerialFixedFrameLength := n;
   if rt <> nil then
      begin
      rt.fixedFrameLength := n;
      end;
end;

function TFactoryRadioBase.Supports(cap: TRadioCapability): Boolean;
begin
   Result := cap in FCapabilities.Flags;
end;

function TFactoryRadioBase.SupportsCWByCAT: Boolean;
begin
   Result := rcCWByCAT in FCapabilities.Flags;
end;

// A radio that declares the capability and states no transport restriction is
// available on whatever link it has.  Restrictions are the subclass's business:
// see TK4Radio.SpectrumAvailable, which is network-only.
function TFactoryRadioBase.SpectrumAvailable: Boolean;
begin
   Result := Supports(rcSpectrum);
end;

// No-ops for every radio that cannot produce spectrum, so a caller may drive
// these unconditionally.
procedure TFactoryRadioBase.StartSpectrum;
begin
end;

procedure TFactoryRadioBase.StopSpectrum;
begin
end;

procedure TFactoryRadioBase.SetSpectrumSpan(const aSpanHz: Integer);
begin
end;

function TFactoryRadioBase.SpectrumSpanHz: Integer;
begin
   Result := 0;   { unknown -- a radio that reports its span overrides this }
end;

procedure TFactoryRadioBase.StepSpectrumSpan(const aDirection: Integer);
begin
   { No span control.  Deliberately NOT a default of "SetSpectrumSpan(current
     +/- 1 kHz)": that is the K4's rule, and a base class that applied one
     radio's rule to every radio is the shape this factory exists to avoid. }
end;

function TFactoryRadioBase.PrimarySpectrumSourceId: string;
begin
   { Empty, not 'A'.  A radio with no spectrum has no source, and guessing one
     vendor's spelling would make a mismatch look like a working default. }
   Result := '';
end;

function TFactoryRadioBase.SpectrumStreaming: Boolean;
begin
   Result := False;
end;

function TFactoryRadioBase.SpectrumLinkUp: Boolean;
begin
   Result := False;
end;

procedure TFactoryRadioBase.PublishSpectrumFrame(const AFrame: TSpectrumFrame);
begin
   if Assigned(FOnSpectrumFrame) then
      begin
      FOnSpectrumFrame(AFrame);
      end;
end;

// HamLib `rigctl -m <model> -u`-style one-line dump of what this rig can do.
function TFactoryRadioBase.CapabilitiesAsText: string;
const
   // One name per TRadioCapability member, in declaration order.  Adding a
   // capability without adding its name here is a COMPILE error (E2072), which is
   // the intent -- the dump would otherwise silently mislabel every flag after
   // the new one.
   CapabilityNames: array[TRadioCapability] of string =
      ('ReadVFOB', 'ReadRIT', 'ReadSplit', 'ReadTXStatus', 'DataMode', 'CWByCAT',
       'PlayDVK', 'CWSpeedSync',
       'SharedRITXITOffset', 'Spectrum', 'SplitClearedByModeChange');
var
   c: TRadioCapability;
begin
   Result := '';
   for c := Low(TRadioCapability) to High(TRadioCapability) do
      begin
      if c in FCapabilities.Flags then
         begin
         if Result <> '' then
            begin
            Result := Result + ', ';
            end;
         Result := Result + CapabilityNames[c];
         end;
      end;
   if Result = '' then
      begin
      Result := '(none)';
      end;
   Result := Format('%s [CW %d-%d wpm]',
                    [Result, FCapabilities.CWSpeedMin, FCapabilities.CWSpeedMax]);
   // The CW-by-CAT framing, dumped only for a radio that actually keys.  Worth
   // having in the log: "the message went out unchunked and unpadded" is
   // otherwise invisible, and an undeclared rule looks exactly like a zeroed one.
   if rcCWByCAT in FCapabilities.Flags then
      begin
      Result := Result +
         Format(' [CW frame: maxLen %d, pad %s, busy x%.2f, SK spelled "%s"]',
                [FCapabilities.CWFrame.maxLen,
                 BoolToStr(FCapabilities.CWFrame.pad, True),
                 FCapabilities.CWFrame.busyFactor,
                 // The prosign grammar is no longer an enum to name, so
                 // log what this radio actually keys for one of them.
                 CWProsign('<').text]);
      end;
end;

// ---- Per-radio state setters: one place owns where each flag is stored. ----
// RIT/XIT are written to every VFO copy so the per-VFO display getters return
// the per-radio value regardless of which VFO the window queries. (RIT/XIT/Split
// are per-radio on the rigs we support; a future per-VFO radio can still write
// vfo[].RITState directly.)
procedure TFactoryRadioBase.SetRITOn(value: boolean);
var
   v: TVFO;
begin
   Self.RITState := value;   // legacy scalar, kept in sync
   for v := Low(TVFO) to High(TVFO) do
      begin
      Self.vfo[v].RITState := value;
      end;
end;

procedure TFactoryRadioBase.SetXITOn(value: boolean);
var
   v: TVFO;
begin
   Self.XITState := value;
   for v := Low(TVFO) to High(TVFO) do
      begin
      Self.vfo[v].XITState := value;
      end;
end;

// RIT/XIT offset (Hz) -- same ownership rule as the on/off setters: write the
// legacy scalar plus every VFO copy the per-VFO display getter (GetRITOffset,
// read by the poll loop into CurrentStatus.RITFreq) returns.
procedure TFactoryRadioBase.SetRITOffset(value: integer);
var
   v: TVFO;
begin
   Self.localRITOffset := value;   // legacy scalar, kept in sync
   for v := Low(TVFO) to High(TVFO) do
      begin
      Self.vfo[v].RITOffset := value;
      end;
end;

procedure TFactoryRadioBase.SetXITOffset(value: integer);
var
   v: TVFO;
begin
   Self.localXITOffset := value;
   for v := Low(TVFO) to High(TVFO) do
      begin
      Self.vfo[v].XITOffset := value;
      end;
end;

procedure TFactoryRadioBase.SetSplitOn(value: boolean);
begin
   Self.localSplitEnabled := value;
end;

{ A DATA mode is never treated as already-set.  MD alone does not describe it --
  the sub-mode arrives separately (DT on Elecraft) -- so two QSOs that are both
  "data" can still need different frames.  Comparing only the mode would skip a
  command that mattered, and a skipped command is far worse than a redundant one. }
function TFactoryRadioBase.ModeAlreadySet(aMode: TRadioMode; aVFO: TVFO): boolean;
const
   DATA_MODES = [rmData, rmDataRev, rmFSK, rmFSKRev,
                 rmPSK, rmPSKRev, rmAFSK, rmAFSKRev];
begin
   Result := False;

   if (aMode = rmNone) or (aMode in DATA_MODES) then
      begin
      Exit;
      end;

   if Self.vfo[aVFO] = nil then
      begin
      Exit;
      end;

   Result := Self.vfo[aVFO].mode = aMode;
end;

procedure TFactoryRadioBase.NoteSplitCommanded(aOn: boolean);
begin
   Self.splitCommandedOn := aOn;
   { ONE. Enough to survive a single side effect, not enough to argue with the
     operator or to loop against a radio that will not go into split at all. }
   if aOn then
      begin
      Self.splitReassertBudget := 1;
      end
   else
      begin
      Self.splitReassertBudget := 0;
      end;
end;

function TFactoryRadioBase.SplitNeedsReassert(aReportedOn: boolean): boolean;
begin
   Result := (not aReportedOn)                                  and
             Self.splitCommandedOn                              and
             (Self.splitReassertBudget > 0)                     and
             (rcSplitClearedByModeChange in Self.FCapabilities.Flags);

   if Result then
      begin
      Dec(Self.splitReassertBudget);
      end;
end;

procedure TFactoryRadioBase.SetTransmitting(value: boolean);
begin
   if value then
      begin
      Self.radioState := rsTransmit
      end
   else
      begin
      Self.radioState := rsReceive;
      end;
end;

function TFactoryRadioBase.GetVFO(whichVFO: TVFO): TRadioVFO;
begin
   if Assigned(Self.vfo[whichVFO]) then
      begin
      Result := Self.vfo[whichVFO];
      end;
  
end;

function TFactoryRadioBase.VFOToString(whichVFO: TVFO): string;
begin
   Result := vfoNames[whichVFO];
end;

function TFactoryRadioBase.ModeToString(mode: TRadioMode): string;
begin
   case mode of
      rmNone: Result := 'mode not set';
      rmCW: Result := 'CW';
      rmCWRev: Result := 'CW-R';
      rmLSB: Result := 'LSB';
      rmUSB: Result := 'USB';
      rmFM: Result := 'FM';
      rmAM: Result := 'AM';
      rmData: Result := 'Data';
      rmDataRev: Result := 'DataRev';
      rmFSK: Result := 'FSK';
      rmFSKRev: Result := 'FSK-R';
      rmPSK: Result := 'PSK';
      rmPSKRev: Result := 'PSK-R';
      rmAFSK: Result := 'AFSK';
      rmAFSKRev: Result := 'AFSK-R';
      end;
  // logger.trace('In ModeToString, %d converted to %s',[Ord(mode), Result]);
end;
{ Moved to TF
function IntegerBetween(v: integer; i: integer; k: integer): boolean;
begin
   Result := (v >= i) and (v <= k);
end;
 }
constructor TReadingThread.Create(AConn: TIdTCPConnection; proc: TProcessMsgRef; ASocketLock: TCriticalSection; ADisconnecting: PBoolean);
begin
  logger.debug('************* DEBUG: TReadingThread.Create (network)');
  FConn := AConn;
  FSerialPort := nil;
  msgHandler := proc;
  FSocketLock := ASocketLock;
  FDisconnecting := ADisconnecting;

  logger.Info('Created NetRadioBase::TReadingThread (network) with id %d',[Self.ThreadID]);
  inherited Create(False);
end;

constructor TReadingThread.Create(ASerialPort: TSerialPort; proc: TProcessMsgRef; ASocketLock: TCriticalSection; ADisconnecting: PBoolean);
begin
  logger.debug('************* DEBUG: TReadingThread.Create (serial)');
  FConn := nil;
  FSerialPort := ASerialPort;
  FSerialBuffer := '';  // Initialize empty buffer
  msgHandler := proc;
  FSocketLock := ASocketLock;
  FDisconnecting := ADisconnecting;

  logger.Info('Created NetRadioBase::TReadingThread (serial) with id %d',[Self.ThreadID]);
  inherited Create(False);
end;

procedure TReadingThread.Execute;
var
   cmd: string;
   wasConnected: boolean;
   termPos: Integer;
   completeCmd: string;
begin
   logger.trace('[TFactoryRadioBase.TReadingThread.Execute] Entered');
   logger.info('[TFactoryRadioBase.TReadingThread.Execute] readTerminator is [%s]',[Self.readTerminator]);

   wasConnected := False;

   while not Terminated do
      begin
      try
         // Check if connected (serial or network)
         try
            if (FSerialPort <> nil) and FSerialPort.IsOpen then
               begin
               // Serial port reading
               if not wasConnected then
                  begin
                  logger.Info('[TFactoryRadioBase.TReadingThread] Serial port open, starting to read');
                  wasConnected := True;
                  Self.radioWasDisconnected := False;
                  end;

               // Read data from serial port and buffer it. Binary protocols
               // (Icom CI-V) must be read byte-exact -- ReadString decodes the
               // AnsiChar buffer through the ANSI codepage and mangles bytes
               // >= $80, so a CI-V reply never matches its $FD terminator or
               // radio address. Text CAT (K4/Kenwood) keeps ReadString.
               try
                  if binaryProtocol then
                     begin
                     cmd := WireStringFromBytes(FSerialPort.ReadBytes(1024));
                     end
                  else
                     begin
                     cmd := FSerialPort.ReadString(1024);
                     end;
                  if Length(cmd) > 0 then
                     begin
                     // Add to buffer
                     FSerialBuffer := FSerialBuffer + cmd;
                     // Same rule as the TX side: never echo a binary frame through
                     // %s -- an embedded $0A/$0D truncates the line and loses the hex.
                     if binaryProtocol then
                        begin
                        logger.trace('[%s RX] Serial received: Hex:[%s], Buffer now %d chars',[Self.radioName, WireHex(cmd), Length(FSerialBuffer)]);
                        end
                     else
                        begin
                        logger.trace('[%s RX] Serial received: (%s) Hex:[%s], Buffer now %d chars',[Self.radioName, cmd, WireHex(cmd), Length(FSerialBuffer)]);
                        end;

                     // Hand over complete responses.  fixedFrameLength > 0 = the
                     // radio's replies are fixed-length binary with NO terminator
                     // (Yaesu FT1000MP); otherwise the default terminator split.
                     if fixedFrameLength > 0 then
                        begin
                        while Length(FSerialBuffer) >= fixedFrameLength do
                           begin
                           completeCmd := Copy(FSerialBuffer, 1, fixedFrameLength);
                           // Optional per-radio frame check.  Fixed-length framing
                           // has no terminator, so without this ONE unexpected byte
                           // (an undocumented set-command ACK, or a byte lost on a
                           // noisy link) would misalign every later frame forever.
                           // Drop a single byte and retry: alignment recovers within
                           // a frame or two.  Radios without a validator take the
                           // accept-all base implementation and are unaffected.
                           if Assigned(Self.frameValidator) and
                              (not Self.frameValidator(completeCmd)) then
                              begin
                              Delete(FSerialBuffer, 1, 1);
                              Inc(Self.pendingResyncDrops);
                              Continue;   // loop still terminates: 1 byte consumed
                              end;
                           Delete(FSerialBuffer, 1, fixedFrameLength);
                           if Self.pendingResyncDrops > 0 then
                              begin
                              // A SINGLE dropped byte is the expected, benign case:
                              // some radios acknowledge each set command with one
                              // byte (confirmed for the Yaesu FT-817 by hamlib's
                              // driver, which reads exactly one ack byte after every
                              // set), so one QSY costs one byte.  Anything larger is
                              // a genuine stream problem worth shouting about.
                              if Self.pendingResyncDrops = 1 then
                                 begin
                                 logger.Debug('[%s RX] Frame resync: dropped 1 byte (expected after a set command on radios that ack).',
                                             [Self.radioName]);
                                 end
                              else
                                 begin
                                 logger.Warn('[%s RX] Frame resync: discarded %d byte(s) before a valid frame -- the stream was shifted by more than an ack.',
                                             [Self.radioName, Self.pendingResyncDrops]);
                                 end;
                              Self.pendingResyncDrops := 0;
                              end;
                           logger.trace('[%s RX] Frame(%d) Hex:[%s]',[Self.radioName, fixedFrameLength, WireHex(completeCmd)]);
                           if Assigned(Self.msgHandler) then
                              begin
                              try
                                 Self.msgHandler(completeCmd);
                              except
                                 on E: Exception do
                                    begin
                                    logger.Error('[TFactoryRadioBase.TReadingThread] Exception in message handler: %s - %s', [E.ClassName, E.Message]);
                                    end;
                              end;
                              end;
                           end;
                        end
                     else
                        begin
                        // Process complete commands (terminated by readTerminator)
                        while Pos(Self.readTerminator, FSerialBuffer) > 0 do
                           begin
                           termPos := Pos(Self.readTerminator, FSerialBuffer);
                           completeCmd := Copy(FSerialBuffer, 1, termPos - 1);  // Get command without terminator
                           Delete(FSerialBuffer, 1, termPos);  // Remove from buffer including terminator

                           if Length(completeCmd) > 0 then
                              begin
                              logger.trace('[%s RX] Command: (%s) Hex:[%s]',[Self.radioName, completeCmd, WireHex(completeCmd)]);
                              if Assigned(Self.msgHandler) then
                                 begin
                                 try
                                    Self.msgHandler(completeCmd);
                                 except
                                    on E: Exception do
                                       begin
                                       logger.Error('[TFactoryRadioBase.TReadingThread] Exception in message handler: %s - %s', [E.ClassName, E.Message]);
                                       end;
                                 end;
                                 end;
                              end;
                           end;
                        end;
                     end
                  else
                     begin
                     Sleep(10);  // Brief sleep if no data
                     end;
               except
                  on E: Exception do
                     begin
                     logger.Debug('[TFactoryRadioBase.TReadingThread] Exception during serial read: %s - %s', [E.ClassName, E.Message]);
                     Sleep(100);
                     end;
               end;
               end
            else if (FConn <> nil) and FConn.Connected then
               begin
               // Network socket reading
               if not wasConnected then
                  begin
                  logger.Info('[TFactoryRadioBase.TReadingThread] Radio connected, starting to read');
                  wasConnected := True;
                  Self.radioWasDisconnected := False;
                  end;

            // Read data from radio
            // NOTE: Do NOT lock during ReadLn - it's a blocking call!
            try
               cmd := FConn.IOHandler.ReadLn(Self.readTerminator);
               logger.trace('[%s RX] (%s)',[Self.radioName, cmd]);

               // Call message handler with exception protection
               try
                  Self.msgHandler(cmd);
               except
                  on E: Exception do
                     begin
                     logger.Error('[TFactoryRadioBase.TReadingThread] Exception in message handler: %s - %s', [E.ClassName, E.Message]);
                     // Continue reading despite handler error
                     end;
               end;
            except
               on EIdNotConnected do
                  begin
                  logger.Warn('[TFactoryRadioBase.TReadingThread] Lost connection while reading');
                  wasConnected := False;
                  Self.radioWasDisconnected := True;
                  FDisconnecting^ := True;  // Set disconnecting flag
                  end;
               on EIdConnClosedGracefully do
                  begin
                  logger.Info('[TFactoryRadioBase.TReadingThread] Radio closed connection gracefully');
                  wasConnected := False;
                  Self.radioWasDisconnected := True;
                  FDisconnecting^ := True;  // Set disconnecting flag
                  end;
               on E: Exception do
                  begin
                  logger.Debug('[TFactoryRadioBase.TReadingThread] Exception during read: %s - %s', [E.ClassName, E.Message]);
                  wasConnected := False;
                  Self.radioWasDisconnected := True;
                  FDisconnecting^ := True;  // Set disconnecting flag
                  end;
            end;
               end
         else
            begin
            // Not connected - wait for polling thread to reconnect
            if wasConnected then
               begin
               logger.Warn('[TFactoryRadioBase.TReadingThread] Radio disconnected, waiting for reconnection');
               wasConnected := False;
               Self.radioWasDisconnected := True;
               FDisconnecting^ := True;  // Set disconnecting flag
               end;

            // Just wait - polling thread will handle reconnection
            Sleep(500);
            end;
         except
            on E: EIdSocketError do
               begin
               // Socket in corrupted state - treat as disconnected
               logger.Debug('[TFactoryRadioBase.TReadingThread] Socket error during connection check: %s - treating as disconnected', [E.Message]);
               if wasConnected then
                  begin
                  wasConnected := False;
                  Self.radioWasDisconnected := True;
                  FDisconnecting^ := True;
                  end;
               Sleep(500);
               end;
            on E: Exception do
               begin
               // Other exception during connection check
               logger.Debug('[TFactoryRadioBase.TReadingThread] Exception during connection check: %s - %s', [E.ClassName, E.Message]);
               Sleep(500);
               end;
         end;
      except
         on E: Exception do
            begin
            logger.Error('[TFactoryRadioBase.TReadingThread] Unexpected exception in main loop: %s - %s',
                         [E.ClassName, E.Message]);
            Sleep(1000);  // Brief pause before continuing
            end;
      end;
      end;

   logger.info('<<<<<<<<<<<< Leaving TReadingThread.Execute >>>>>>>>>>>>>>>>>>');
end;

procedure TReadingThread.DoTerminate;
begin
  logger.debug('DEBUG: TReadingThread.DoTerminate');
  inherited;
end;

procedure TReadingThread.ClearSerialBuffer;
begin
  FSerialBuffer := '';
  logger.Info('[TReadingThread.ClearSerialBuffer] Serial buffer cleared');
end;

function BoolToString(b: boolean): string;
begin
   Result := IfThen(b,'True','False');
end;

initialization
   // Fetched once so TReadingThread never sees a nil logger however early it
   // starts.  See the var block above: this is not a second logger, it is the
   // same Log4D instance the program configures.
   logger := TLogLogger.GetLogger('TR4WDebugLog');

end.


