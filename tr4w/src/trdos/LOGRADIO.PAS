{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit LogRadio;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}

{ This unit has the RadioObject in it, which is used to do everything
  associated with radio interface.  It relies on LogK1EA for sent and
  received data buffer support, but nothing else.  LogWind pulls data
  out of this unit without using any other interface to the radio (I
  hope. }

interface

uses
  uConfigValues,
   Classes,
   Math,
   SysUtils,
   TF,
   Tree,
   VC,
   Windows,
   utils_text,
   uWinTimer,   // TWinTimer -- was VCL ExtCtrls.TTimer; see that unit's header
   uFactoryRadioBase,
   uRadioElecraftK4,
   uRadioFactory,
   uRadioRegistry;

var
   Icom_Filter_Width: integer;     // n4af 4.43.4

const

   // The CI-V command vocabulary that used to live here is GONE from the
   // interface.  Track E deleted the per-model Icom code that spoke it; these
   // constants outlived their only callers and nothing outside this unit had
   // referenced them since.  The factory owns CI-V now -- see uIcomCIV.pas and
   // uRadioIcomBase.pas, where the commands sit beside the code that sends them.
   // Five that this unit still uses internally moved to the implementation
   // section below; do not promote them back without a caller to justify it.

   ICOM_END_OF_MESSAGE_CODE = #$FD;

   ICOM_CONTROLLER_ADDRESS   = #$E0;

type
   tr4w_RTSDTRType = (RtsDtr_Nothing, RtsDtr_OFF, RtsDtr_ON, RtsDtr_CW, RtsDtr_PTT);
   TEventHandlers = class
      procedure OnTimerTick(Sender : TObject);
   end;

// var EventHandlers : TEventHandlers;
const

   // Live: uCFG.pas CommandsArray uses this as the lpArray for the four
   // RTS/DTR state commands, so it is read by the config parser, not by radio
   // code.  Its type tr4w_RTSDTRType is a RadioObject field type and stays too.
   tr4w_RTSDTRTypeSA: array[tr4w_RTSDTRType] of PAnsiChar =
      (
      'NONE',
      'OFF',
      'ON',
      'CW',
      'PTT'
      );


type
   ActiveVFOStatusType = (vfoUnknown, VFOA, VFOB, vfoMem);

   //  SplitType = (NoSplit, SplitOn);
   //  RITType = (NoRIT, RITOn);

   TRMode = (
      TR0,
      TR1, //spacebar Config.TwoRadioMode = false
      TR2, //spacebar Config.TwoRadioMode = true
      TR3
      );

   // PollingStatusType (NoPollStatus, PollStatus1..5) is GONE.  It described the
   // legacy poller's state machine; its only field, RadioObject.PollStatus, was
   // written once and never read after Track E deleted that state machine.  The
   // factory tracks link state on the radio (see TFactoryRadioBase.MaintainSerialLink
   // and the connect/settle gate), not in an enum on a shared record.

   VFOStatusType = record
      {04}Frequency: longint;
      {04}RITFreq:   integer;
      {01}Band:      BandType;
      {01}Mode:      ModeType;
      {01}Split:     boolean;
      {01}RIT:       boolean;
      {01}XIT:       boolean;
       ExtendedMode: ExtendedModeType;
   end;

   RadioStatusRecord = record
      //    {24}VFOA: VFOStatusType;
      //    {24}VFOB: VFOStatusType;
      VFO:           array[ActiveVFOStatusType] of VFOStatusType;
      previousVFO:   array[ActiveVFOStatusType] of VFOStatusType;
      {04}Freq:      longint; // This is the active frequency for the radio
      {04}Split:     longbool;
      {04}RIT:       longbool;
      {04}XIT:       longbool;
      {04}RITFreq:   integer;
      {04}PrevRITFreq: integer;
      {01}Band:      BandType;
      {01}Mode:      ModeType;
      ExtendedMode:  ExtendedModeType;
      {01}VFOStatus: ActiveVFOStatusType;
      {01}PrevVFOStatus: ActiveVFOStatusType;
      {01}TXOn:      boolean;
        //  ModeActual:ExtendedRadioModeType; // tom
   end;

   RadioObject = object
      tDupeSheetWnd:     HWND;
      tDisableCIVTransceive: boolean;
      tPTTStatus:        PTTStatusType;
      tTwoRadioMode:     TRMode;
      RadioOnTheMove:    boolean;
      LastDisplayedFreq: integer;
      tCommandedQSYFreq: integer;  // Issue #795 vs bandmap: last app-commanded VFO-A freq; auto-S&P treats a QSY landing here as commanded (don't clear the entry), not a manual dial tune
      SpeedMemory:       integer;
      BandMemory:        BandType;
      ModeMemory:        ModeType;
      tFactoryObject:          TFactoryRadioBase;  // Factory creates K4 or HamLibDirect
      FreqWindowHandle:    HWND;
      RadioNameWndHandle:  HWND;
      RadioDisconnected:   Boolean;
      tLastValidResponse:  Cardinal;   // GetTickCount of last good serial read; drives the serial liveness indicator
      RadioName:        Str20;
      StartupCommand  : Str50;
      HamLibID:          integer;
      //    lpOverlapped: TOverlapped;
      //    pOver: POverlapped;

      CommandsBuffer:        array[0..7] of array[0..{19}40] of AnsiChar;
      CommandsBufferPointer: cardinal;
      CommandsTempBuffer:    array[0..{19}40] of AnsiChar; // ny4i extended for icom cw  // 4.44.5

      //    ICOM_COMMAND_B1: Str80;
      //    ICOM_COMMAND_SET_MODE: string[8];
      //    ICOM_COMMAND_SET_FREQ: string[11];
      //    ICOM_COMMAND_B2: Str80;
      //    ICOM_COMMAND_CUSTOM: Str80;

      //    ICOM_COMMAND_PTT: Char;
      //    ICOM_SET_PTT: array[0..7] of Char;
      //    ICOM_SET_SPLIT: array[0..7] of Char;


      tRadioInterfaceThreadID: cardinal;
      tRadioInterfaceThreadHandle: HWND;
      PollingStopRequested: Boolean;
      tPollCount: integer;
      tRadioInterfaceWndHandle: HWND;
      RITWndHandle:     HWND;
      XITWndHandle:     HWND;
      SplitWndHandle:   HWND;
      ModeVFOAWndHandle: HWND;  // Issue #566: mode label beside VFO A freq
      ModeVFOBWndHandle: HWND;  // Issue #566: mode label beside VFO B freq
      tBuf: array[1..512] of AnsiChar;
      active : boolean;
      CurrentStatus:   RadioStatusRecord; { Last reading taken }
      PreviousStatus:  RadioStatusRecord; { Reading before Last }
      FilteredStatus:  RadioStatusRecord; { Updated if Current = Previous }
      FilteredStatusChanged: boolean;

      // Seqlock version guarding CurrentStatus + FilteredStatus as a pair.
      // ODD while the polling thread is mid-update, EVEN when the two records
      // are coherent.  Read through ReadRadioStatus / ReadRadioCurrentStatus;
      // see the note on BeginStatusPublish for why this exists and why not
      // every reader needs converting.
      StatusVersion: cardinal;
      BandOutputPort:  PortType;
      tBandOutputPortBaseAddress: HWND;
      FrequencyAdder:  longint;
      FT1000MPCWReverse: boolean;
      CWByCAT:         boolean;                    // ny4i 4.44.5
      CWSpeedSync:     boolean;
      CWByCAT_Sending: boolean;                    // ny4i Issue 129
      // True once a poll has actually SEEN this radio transmitting since the
      // current CW-by-CAT message was handed over.  uRadioPolling treats
      // "TX off" as end-of-message, which races the radio: the keyer abort we
      // send first is 'KY <abort>;RX;' -- it puts the radio in RECEIVE -- and the
      // message follows within milliseconds, before the rig has keyed up.  A
      // poll landing in that gap sees TX off and declares a message finished
      // that has not started.  Requiring a TX-ON sighting first closes it.
      // Radios that cannot report TX status (no rcReadTXStatus) never set this
      // and fall back to tmrCWByCAT, which is what they already relied on.
      CWByCAT_SawTX: boolean;
      CATSerialLock:   TRTLCriticalSection;        // serialize a poll cycle vs a CW-by-CAT write on this radio's serial port
      UseHamLib:       boolean;
      WideCWFilter:    boolean;
      IcomFilterByte:  byte;
      IDCharacter:     AnsiChar;
      IPAddress:       str50;
      NetworkUsername: str50;  // Network radio username (Icom CI-V/IP, Kenwood TS-890, etc.) -- Issue #904
      NetworkPassword: str50;  // Network radio password -- Issue #904
      IcomDataModeID: Byte;        // Icom data sub-mode: 1=D1 (default), 2=D2, 3=D3
      CWByCATBuffer:   string;                  // ny4i 4.44.5
      //    PartialRadioResponse: string;
      PollingEnable:   boolean;
      // Auto-info level this radio should run at, 0 = off.  Owned by
      // Preferences (the radio library), rendered into 'RADIO n AUTO INFO'.
      // Handed to the driver through ApplyAutoInfoLevel, because what a level
      // MEANS is the radio's business -- an Elecraft AI2 and a K4 AI5 are not
      // the same thing and this record must not know the difference.
      AutoInfoLevel:   integer;
      RadioModel:      InterfacedRadioType;
      FactoryId:       Str50;   // non-empty => a string-id factory radio (RadioModel is NoInterfacedRadio)
      RadioBaudRate:   cardinal;
      RadioNumberBits: integer;
      RadioStopBits:   integer;
      RadioKeyerStopBits: integer;
      RadioParity:     ParityType;
      SerialFormat:    Str50;   // 'RADIO n SERIAL FORMAT' ('8N2'); '' = use the
                                // radio's registered defaults (SerialParamsFor)
      RadioTCPPort:    integer;
      ReceiverAddress: integer; { Used for Icom interfaces }

      tCATPortType:   PortType;
      tCATPortHandle: HWND;

      tKeyerPort:       PortType;
      tKeyerPortHandle: HWND;

      tr4w_keyer_rts_state: tr4w_RTSDTRType; //keyer RTS
      tr4w_keyer_DTR_state: tr4w_RTSDTRType; //keyer DTR
      tr4w_cat_rts_state:   tr4w_RTSDTRType; //CAT RTS
      tr4w_cat_dtr_state:   tr4w_RTSDTRType; //CAT DTR

      tYaesuFreq5Bytes: array[0..4] of byte;


      tIcom6Bytes: array[0..5] of byte;
      tIcom7Bytes: array[0..6] of byte; //ny4i  // 4.44.5
      tIcom11Bytes: array[0..10] of byte; //ny4i
      tIcomFilterWidth: integer;


      CommandPause: integer;
      nextExtendedMode : ExtendedModeType;
      tmrCWByCAT: TWinTimer;
      EventHandlers : TEventHandlers;
      procedure AddCommandToBuffer;
      function  CheckAutoCallTerminate: boolean;
      function DeleteLastCWCharacter: boolean;
      procedure FlushCWByCATBuffer;
      procedure PutRadioIntoSplit;
      procedure PutRadioOutOfSplit;
      procedure SendIcomCommand(Command: byte);
      procedure SendIcomTwoByteCommand(Command: byte; opCode: byte);
      procedure SendXMITStatusCommand;
     { procedure SendIcomExtendedVFO(bVFO: boolean);
     }
      procedure SendRITStatusCommand;
      procedure SendRITFreqCommand;
      procedure GetIcomDataStateCommand;
      procedure SetICOMRITFrequency(hz: integer);
      function MemoryKeyer(mem: integer): boolean;
      procedure ProcessIcomMode(mode: integer);
     // procedure SendIcomClearRITCommand;
    //  function CalculateIcomFilterWidth: integer;
      function HasCapability(cap: TRadioCapability): boolean;
      procedure SetRadioCWSpeed(speed: longint);
      procedure SetRadioFreq(Freq: longint; Mode: ModeType; VFO: char); overload;
      procedure SetRadioFreq(Freq: longint; Mode: ModeType; VFO: char; extendedMode: ExtendedModeType); overload;
      // Hand a newly built factory radio everything it needs to own about
      // itself, in ONE place.  Call immediately after construction and BEFORE
      // Connect: the drivers re-key their logger from rigLabel during
      // Initialize, which runs on the reading thread once Connect starts.
      procedure AdoptFactoryObject;
      procedure SetUpRadioInterface;
      // Stops the polling thread and frees the factory object, leaving the slot
      // genuinely empty.  Split out of SetUpRadioInterface because CLEARING a
      // slot needs exactly this and nothing else -- see the call in
      // CheckAndInitializePorts_ForThisRadio.
      procedure ShutDownRadioInterface;
      procedure StopSendingCW;
      //    procedure StartNextPoll;
      //    function TimeToGiveUp: boolean;
      procedure UpdateBandOutputInfo(Band: BandType; Mode: ModeType);
      procedure UpdateRadioStatus;
      function ConvertBCDStringToFreq(BCDString: Str20): longint;

      procedure FreqToBCD(Freq: longint; Swap: boolean; OpCode: byte);
      procedure ResolveSerialFrameSettings;
      // Dumps this radio's operator-settable configuration to the log at DEBUG.
      // Called before anything can bail out, so a radio that is NOT set up still
      // says so and says why.
      procedure LogRadioConfiguration;
      procedure CheckAndInitializePorts_ForThisRadio;
      function WriteToCATPort(const Buffer; nNumberOfBytesToWrite: DWORD): longbool;
      function WritePollRequest(const Buffer; nNumberOfBytesToWrite: DWORD): longbool;
      procedure WriteBufferToCATPort(const Buffer);
      procedure OnCWByCATTimeEvent(Sender :TObject);
      procedure EnableCWBYCATTimer(ms: integer);
      procedure AddTimeToCWByCATTimer(ms: integer);

      //    property fddd;
   end;
   RadioPtr = ^RadioObject;

var
   IcomResponseTimeout:    integer;
   // newIcomResponseTimeout is the target of the "ICOM RESPONSE TIMEOUT"
   // config command (uCFG.pas CommandsArray takes its address), so it is live
   // even though no radio code reads it.  cmdIcomResponseTimeout,
   // newIcomResponseTimeoutAuto and icomCIVTransceiveEnable are GONE: they
   // configured the deleted per-model Icom poller and had no reader left.
   newIcomResponseTimeout: integer = 60;
   InBandLock:     boolean = True;      // 4.92.1

   Radio1:           RadioObject {=
    (
    SpeedMemory: InitialCodeSpeed;
    BandMemory: Band160;
    ModeMemory: CW;
    RadioName: 'Rig 1';
    ICOM_COMMAND_PTT: #255;
    tRadioInterfaceWndHandle: 0;
    FT1000MPCWReverse: False;
    IDCharacter: #0;
    //    PollTimeout: 500;
    PollingEnable: True;
    AutoInfoLevel: 0;
    PollStatus: NoPollStatus;
    RadioModel: NoInterfacedRadio;

    RadioBaudRate: 4800;

    RadioNumberBits: 8;

    RadioStopBits: 2;

    RadioParity: tNoParity;

    ReceiverAddress: 4;
    WaitingForCommandPause: False;
    //    TrackingEnable: True;
    //    UpdateSeconds: 0;

    tCATPortType: NoPort;
    tCATPortHandle: INVALID_HANDLE_VALUE;

    tKeyerPortHandle: INVALID_HANDLE_VALUE;
    tr4w_keyer_rts_state: RtsDtr_PTT;
    tr4w_keyer_DTR_state: RtsDtr_CW;
    tr4w_cat_rts_state: RtsDtr_OFF; //CAT RTS
    tr4w_cat_dtr_state: RtsDtr_OFF; //CAT DTR
    );
};
   Radio2:           RadioObject {=
    (
    SpeedMemory: InitialCodeSpeed;
    BandMemory: Band160;
    ModeMemory: CW;
    RadioName: 'Rig 2';
    ICOM_COMMAND_PTT: #255;
    tRadioInterfaceWndHandle: 0;
    FT1000MPCWReverse: False;
    IDCharacter: #0;
    //    PollTimeout: 500;
    PollingEnable: True;
    AutoInfoLevel: 0;
    PollStatus: NoPollStatus;
    RadioModel: NoInterfacedRadio;
    RadioBaudRate: 4800;
    RadioNumberBits: 8;
    RadioStopBits: 2;
    RadioParity: tNoParity;
    ReceiverAddress: 4;
    WaitingForCommandPause: False;
    //    TrackingEnable: True;
    //    UpdateSeconds: 0;
    tCATPortType: NoPort;
    tCATPortHandle: INVALID_HANDLE_VALUE;

    tKeyerPortHandle: INVALID_HANDLE_VALUE;
    tr4w_keyer_rts_state: RtsDtr_PTT;
    tr4w_keyer_DTR_state: RtsDtr_CW;
    tr4w_cat_rts_state: RtsDtr_OFF; //CAT RTS
    tr4w_cat_dtr_state: RtsDtr_OFF; //CAT DTR
    );
};
   //  RITCommandTimeStamp              : Cardinal {TimeRecord};
   ActiveRadioPtr:   RadioPtr = @Radio1;
   InActiveRadioPtr: RadioPtr = @Radio2;
   // RadioSupportsCWByCAT / RadioSupportsCWSpeedSync / RadioSupportsPlayDVK are
   // GONE.  They were hand-maintained model lists competing with the registry's
   // rcCWByCAT / rcCWSpeedSync / rcPlayDVK, and two sources of truth for "can
   // this radio do X" is a bug generator: it produced the Q9 CW-by-CAT split,
   // and the same style of list in this file silently omitted the KX3 from the
   // Elecraft prosign table.  Ask the radio instead -- RadioObject.HasCapability.
   // The equivalence is pinned by test/unit/uTestRadioSupportsCaps.pas, which
   // still carries all three legacy sets transcribed independently.
   // The manufacturer/transport taxonomy sets (ICOMRadios, KenwoodRadios,
   // YaesuRadios, HamLibONLYRadios) are RETIRED.  The registry answers those
   // questions now: uRadioRegistry.IsHamLibOnly (native = registered),
   // uRadioRegistry.ManufacturerOf (first word of the display name), and the
   // legacy table's own rt field for protocol grouping.

const
   RTS_DTR_Values_Array: array[1..4] of PAnsiChar =
      ('OFF', 'ON', 'CW', 'PTT');

type
   RigType = (rtUnknown, rtICOM, rtKenwood, rtYaesu1, rtYaesu2, rtYaesu3, rtYaesu4, rtJST, rtOrion, rtHamlib);

   BaudRateType = (BR1200, BR2400, BR4800, BR9600, BR19200, BR38400, BR57600, BR115200);
{
const
  Baud_Rate_Array                       : array[BaudRateType] of integer =
    (
    1200, 2400, 4800, 9600, 19200, 38400, 57600 , 115200
    );
}
// RadioParametersArray STAYS, and is not dead code.  Nothing in the running
// program reads it any more -- but test/unit/uTestIcomRegistry.pas does, as the
// ORACLE for the Icom migration: it builds each Icom through the registry and
// compares its CI-V address against RadioParametersArray[m].RA, so a mistake in
// the 28 hand-transcribed addresses fails a test instead of looking like a bad
// cable.  Deleting the table would delete the proof.  It goes when that test
// does, and not before.  To ADD a radio, do not touch this table -- it is no
// longer a registry.  Read docs/ADDING_A_RADIO.md.
type
   TRadioParameters = record
      //    Name: PChar;
      br:   BaudRateType; //Baud Rate
      p:    byte; //Polling
      c:    byte; //ShiftInCQMode
      s:    byte; //ShiftInSPMode
      t:    byte; //PTTViaCommand
      RA:   byte; //ReceiverAddress
      SW:   byte; //Swap
      SFOC: byte; //SetFreqOpCode
      SMOC: byte; //SetModeOpCode
      SPOC: byte; //SetPTTOpCode
      RX:   byte; //RXOpCode
      TX:   byte; //TXOpCode
      mb:   byte; //PositionOfModeByte

      CW:   byte; //CWLOpCode
      //    CWU: Byte; //CWLOpCode
      LSB:  byte; //LSBOpCode
      USB:  byte; //USBOpCode
      FM:   byte; //FMOpCode
      AM:   byte; //AMOpCode
      DIGL: byte; //DigLOpCode
      DIGU: byte; //DigUOpCode

      hamlibID: integer;
      rt: RigType;
   end;

//const
//  YaesuReplyRigs                        : array[0..1] of InterfacedRadioType = (FT857, FT897);
{
 When adding an item here, you have to
    1. Add a type to the InterfacedRadioType around line 1060 in VC.pas
    2. Each new radio requires the type in InterfacedRadioType, the entry
       below in the RadioParametersArray array and the literal name of the
       radio in InterfacedRadioTypeSA below.  // Issue 120
    3. Also update the Sets in InitRadio wherever applicable for the new radio. ** Important for CWBYCAT ad RIT functions
 - ny4i
       PLS NOTE VC INTERFACEDRADIOTYPE ARRAY AND THE BELOW ARRAY ARE IN THE SAME ORDER OF ENTRY !
 -- n4af
}
const
   RadioParametersArray: array[InterfacedRadioType] of
      TRadioParameters =
      (
{(*}
    ({Name: 'NONE';       } BR:BR4800;  P: 1; C: 0; S: 0; T:0; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00),
    ({Name: 'K2';         } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2021; rt: rtKenwood),
    ({Name: 'K3';         } BR:BR38400; P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2029; rt: rtKenwood),
    ({Name: 'KX3';        } BR:BR38400; P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2045; rt: rtKenwood),
    ({Name: 'K4';         } BR:BR38400; P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2047; rt: rtKenwood),
    ({Name: 'FLEX';       } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2036; rt: rtKenwood),     // 4.87.2; 2036 = RIG_MODEL_F6K (6000 series) -- 2048 was POWERSDR, the OLD Flex-5000 backend (NY4I 2026-07-30)
    ({Name: 'TS140';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2025; rt: rtKenwood),
    ({Name: 'TS440';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2002; rt: rtKenwood),
    ({Name: 'TS450';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2003; rt: rtKenwood),
    ({Name: 'TS480';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2028; rt: rtKenwood),
    ({Name: 'TS570';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2016; rt: rtKenwood),
    ({Name: 'TS590';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2031; rt: rtKenwood),   // 2031 = RIG_MODEL_TS590S; the old 2004 was the TS570D backend (riglist.h, cross-check 2026-07-30)
    ({Name: 'TS690';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2005; rt: rtKenwood),
    ({Name: 'TS850';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2009; rt: rtKenwood),
    ({Name: 'TS870';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2010; rt: rtKenwood),
    ({Name: 'TS890';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2041; rt: rtKenwood),  // Issue #436 -- native Kenwood serial; default 4800 baud (radio menu can raise to 115200)
    ({Name: 'TS940';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2011; rt: rtKenwood),
    ({Name: 'TS950';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2012; rt: rtKenwood),
    ({Name: 'TS990';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2039; rt: rtKenwood),
    ({Name: 'TS2000';     } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 2014; rt: rtKenwood),   // 2014 = RIG_MODEL_TS2000; the old 2041 was a copy-paste of the TS890 row (the TS890S backend)
    ({Name: 'FT100';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $02;  LSB: $00; USB: $01; FM: $06; AM: $04; DIGL: $05; DIGU: $05; hamlibID: 1021; rt: rtYaesu1),
    ({Name: 'FTDX10';     } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1042; rt: rtYaesu4),
    ({Name: 'FTDX101';    } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1040; rt: rtYaesu4),
    ({Name: 'FTX1F';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1051; rt: rtYaesu4),  // FTX-1F/FTX-1R — Issue #817
    ({Name: 'FT450';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1027; rt: rtYaesu2),
    ({Name: 'FT710';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00;  LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; rt: rtYaesu4),   // Issue 640 ny4i
    // HamLib-only (unregistered in the factory -- uRadioRegistry.IsHamLibOnly):
    // no native read path ever existed.
    // Baud stays 4800 -- the FT-736R is a real 4800-baud rig and rigctld opens the
    // actual serial port, unlike the software bridges here which are TCP at 57600.
    ({Name: 'FT736R';     } BR:BR4800;  P: 0; C: 0; S: 0; T:0; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $02;  LSB: $00; USB: $01; FM: $08; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1010; rt: rtHamlib),
    ({Name: 'FT747GX';    } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03;  LSB: $00; USB: $01; FM: $06; AM: $05; DIGL: $00; DIGU: $00; hamlibID: 1005; rt: rtYaesu1),
    ({Name: 'FT767';      } BR:BR4800;  P: 1; C: 1; S: 1; T:0; RA: $00; SW: 1; SFOC: $08; SMOC: $0A; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $12;  LSB: $10; USB: $11; FM: $14; AM: $13; DIGL: $15; DIGU: $15; hamlibID: 1009; rt: rtYaesu1),
    ({Name: 'FT817';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $88; TX: $08; MB: 0; CW: $02;  LSB: $00; USB: $01; FM: $08; AM: $04; DIGL: $0C; DIGU: $0A; hamlibID: 1020; rt: rtYaesu1),
    ({Name: 'FT818';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $88; TX: $08; MB: 0; CW: $02;  LSB: $00; USB: $01; FM: $08; AM: $04; DIGL: $0C; DIGU: $0A; hamlibID: 1041; rt: rtYaesu1),
    ({Name: 'FT840';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03;  LSB: $00; USB: $01; FM: $06; AM: $05; DIGL: $FF; DIGU: $FF; hamlibID: 1011; rt: rtYaesu1),
    ({Name: 'FT847';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $02; LSB: $00; USB: $01; FM: $08; AM: $04; DIGL: $FF; DIGU: $FF; hamlibID: 1001; rt: rtYaesu1),
    ({Name: 'FT857';      } BR:BR4800;  P: 1; C: 0; S: 0; T:0; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $02; LSB: $00; USB: $01; FM: $08; AM: $04; DIGL: $FF; DIGU: $0A; hamlibID: 1022; rt: rtYaesu1),
    ({Name: 'FT890';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03; LSB: $00; USB: $01; FM: $06; AM: $04; DIGL: $FF; DIGU: $FF; hamlibID: 1015; rt: rtYaesu1),
    ({Name: 'FT891';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1036; rt: rtYaesu3),
    ({Name: 'FT897';      } BR:BR4800;  P: 1; C: 0; S: 0; T:0; RA: $00; SW: 0; SFOC: $01; SMOC: $07; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $02; LSB: $00; USB: $01; FM: $08; AM: $04; DIGL: $FF; DIGU: $0A; hamlibID: 1023; rt: rtYaesu1),
    ({Name: 'FT900';      } BR:BR4800;  P: 1; C: 0; S: 0; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03; LSB: $00; USB: $01; FM: $06; AM: $05; DIGL: $FF; DIGU: $FF; hamlibID: 1013; rt: rtYaesu1),
    ({Name: 'FT920';      } BR:BR4800;  P: 1; C: 0; S: 0; T:0; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $02; LSB: $00; USB: $01; FM: $06; AM: $04; DIGL: $08; DIGU: $0A; hamlibID: 1014; rt: rtYaesu1),
    ({Name: 'FT950';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1028; rt: rtYaesu2),
    ({Name: 'FT990';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03; LSB: $00; USB: $01; FM: $06; AM: $05; DIGL: $08; DIGU: $09; hamlibID: 1016; rt: rtYaesu1),
    ({Name: 'FT991';      } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1035; rt: rtYaesu3),
    ({Name: 'FT1000';     } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $03; LSB: $00; USB: $01; FM: $06; AM: $04; DIGL: $08; DIGU: $09; hamlibID: 1003; rt: rtYaesu1),
    ({Name: 'FT1000MP';   } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $0A; SMOC: $0C; SPOC: $00; RX: $00; TX: $00; MB: 3; CW: $02; LSB: $00; USB: $01; FM: $06; AM: $04; DIGL: $08; DIGU: $09; hamlibID: 1024; rt: rtYaesu1),
    ({Name: 'FT1200';     } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1034; rt: rtYaesu2),
    ({Name: 'FT2000';     } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1029; rt: rtYaesu2),
    ({Name: 'FTDX3000';   } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1037; rt: rtYaesu2),
    ({Name: 'FTDX5000';   } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1032; rt: rtYaesu2),
    ({Name: 'FTDX9000';   } BR:BR4800;  P: 1; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1030; rt: rtYaesu2),
    ({Name: 'IC78';       } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $62; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3045; rt: rtIcom),
    ({Name: 'IC705';      } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $A4; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3085; rt: rtIcom),
    ({Name: 'IC706';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $48; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3009; rt: rtIcom),
    ({Name: 'IC706II';    } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $4E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3010; rt: rtIcom),
    ({Name: 'IC706IIG';   } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $58; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3011; rt: rtIcom),
    ({Name: 'IC707';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $3E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3012; rt: rtIcom),
    ({Name: 'IC718';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $5E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3013; rt: rtIcom),
    ({Name: 'IC725';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $28; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3014; rt: rtIcom),
    ({Name: 'IC726';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $30; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3015; rt: rtIcom),
    ({Name: 'IC728';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $38; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3016; rt: rtIcom),
    ({Name: 'IC729';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $3A; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3017; rt: rtIcom),
    ({Name: 'IC735';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $04; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3019; rt: rtIcom),
    ({Name: 'IC736';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $40; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3020; rt: rtIcom),
    ({Name: 'IC737';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $3C; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3021; rt: rtIcom),
    ({Name: 'IC738';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $44; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3022; rt: rtIcom),
    ({Name: 'IC746';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $56; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3023; rt: rtIcom),
    ({Name: 'IC746PRO';   } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $66; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3046; rt: rtIcom),
    ({Name: 'IC756';      } BR:BR1200;  P: 1; C: 0; S: 0; T:0; RA: $50; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3026; rt: rtIcom),
    ({Name: 'IC756PRO';   } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $5C; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3027; rt: rtIcom),
    ({Name: 'IC756PROII'; } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $64; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3047; rt: rtIcom),
    ({Name: 'IC756PROIII';} BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $6E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3057; rt: rtIcom),
    ({Name: 'IC761';      } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $1E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3028; rt: rtIcom),
    ({Name: 'IC765';      } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $2C; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3029; rt: rtIcom),
    ({Name: 'IC775';      } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $46; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3030; rt: rtIcom),
    ({Name: 'IC781';      } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $26; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3031; rt: rtIcom),
    ({Name: 'IC905';      } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $AC; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 0; rt: rtIcom),
    ({Name: 'IC910';      } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $60; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3044; rt: rtIcom),
    ({Name: 'IC970D';     } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $2E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3035; rt: rtIcom),
    ({Name: 'IC7000';     } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $70; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3060; rt: rtIcom),
    ({Name: 'IC7100';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $88; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3070; rt: rtIcom),
    ({Name: 'IC7200';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $76; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3061; rt: rtIcom),
    ({Name: 'IC7300';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $94; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3073; rt: rtIcom),
    ({Name: 'IC7300MK2';  } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $B6; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 0; rt: rtIcom),
    ({Name: 'IC7410';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $80; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3067; rt: rtIcom),
    ({Name: 'IC7600';     } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $7A; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3063; rt: rtIcom),
    ({Name: 'IC7610';     } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $98; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3078; rt: rtIcom), // 4.65.7 issue #282 #282   // 4.68.12
    ({Name: 'IC7700';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $74; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3062; rt: rtIcom),
    ({Name: 'IC7760';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $B2; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3092; rt: rtIcom),
    ({Name: 'IC7800';     } BR:BR9600;  P: 1; C: 0; S: 0; T:0; RA: $6A; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3056; rt: rtIcom),
    ({Name: 'IC7850';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $8E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3075; rt: rtIcom),
    ({Name: 'IC7851';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $8E; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3075; rt: rtIcom),
    ({Name: 'IC9100';     } BR:BR19200; P: 1; C: 0; S: 0; T:0; RA: $7C; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3068; rt: rtIcom),
    ({Name: 'IC9700';     } BR:BR38400; P: 1; C: 0; S: 0; T:0; RA: $A2; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3081; rt: rtIcom),
    ({Name: 'OMNI6';      } BR:BR9600;  P: 1; C: 1; S: 1; T:0; RA: $04; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 3051; rt: rtIcom),
    ({Name: 'ORION';      } BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 16008; rt:rtOrion),
    ({Name: 'FLRIG';      } BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 4; rt:rtHamlib),
    ({Name: 'TRXMANAGER';} BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 5; rt:rtHamlib),
    ({Name: 'FT757GXII';  } BR:BR4800;  P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1007; rt:rtHamlib),
    ({Name: 'EXPERTTCI'; } BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 7; rt:rtHamlib),
    ({Name: 'ACLOG';      } BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 8; rt:rtHamlib),
    ({Name: 'HAMLIBANY';  } BR:BR57600; P: 0; C: 1; S: 1; T:1; RA: $00; SW: 1; SFOC: $00; SMOC: $00; SPOC: $00; RX: $00; TX: $00; MB: 0; CW: $00; LSB: $00; USB: $00; FM: $00; AM: $00; DIGL: $00; DIGU: $00; hamlibID: 1; rt:rtHamLib)
);
{*)}
const
   InterfacedRadioTypeSA: array[InterfacedRadioType] of PAnsiChar = (

      'NONE',
      'K2',
      'K3',
      'KX3',
      'K4',
      'FLEX',
      'TS440',
      'TS450',
      'TS480',
      'TS530',
      'TS570',
      'TS590',
      'TS690',
      'TS850',
      'TS870',
      'TS890',
      'TS940',
      'TS950',
      'TS990',
      'TS2000',
      'FT100',
      'FTDX10',
      'FTDX101',
      'FTX-1',
      'FT450',
      'FT710',
      'FT736R',
      'FT747GX',
      'FT767',
      'FT817',
      'FT818',
      'FT840',
      'FT847',
      'FT857',
      'FT890',
      'FT891',
      'FT897',
      'FT900',
      'FT920',
      'FT950',
      'FT990',
      'FT991',
      'FT1000',
      'FT1000MP',
      'FT1200',
      'FT2000',
      'FTDX3000',
      'FTDX5000',
      'FTDX9000',
      'IC78',
      'IC705',
      'IC706',
      'IC706II',
      'IC706IIG',
      'IC707',
      'IC718',
      'IC725',
      'IC726',
      'IC728',
      'IC729',
      'IC735',
      'IC736',
      'IC737',
      'IC738',
      'IC746',
      'IC746PRO',
      'IC756',
      'IC756PRO',
      'IC756PROII',
      'IC756PROIII',
      'IC761',
      'IC765',
      'IC775',
      'IC781',
      'IC905',
      'IC910H',
      'IC970D',
      'IC7000',
      'IC7100',
      'IC7200',
      'IC7300',
      'IC7300MK2',
      'IC7410',
      'IC7600',
      'IC7610',
      'IC7700',
      'IC7760',
      'IC7800',
      'IC7850',
      'IC7851',
      'IC9100',
      'IC9700',
      'OMNI6',
      'ORION',
      'FLRIG',          // HamLib Only
      'TRX-MANAGER',    // HamLib Only
      'FT757GXII',      // HamLib Only
      'EXPERTTCI',     // HamLib Only
      'ACLOG',          // HamLib Only
      'HAMLIB-ANY'      // HamLib Only
      );

 {
    const
    Radio_Type_Array: array[InterfacedRadioType] of PChar = (
    'NONE',
    'K2',
    'TS850',
    'FT100',
    'FT450',
    'FT736R',
    'FT767',
    'FT817',
    'FT818',
    'FT840',
    'FT847',
    'FT857',
    'FT890',
    'FT897',
    'FT900',
    'FT920',
    'FT950',
    'FT990',
    'FT1000',
    'FT1000MP',
    'FT2000',
    'FTDX9000',
    'IC706',
    'IC706II',
    'IC706IIG',
    'IC707',
    'IC718',
    'IC725',
    'IC726',
    'IC728',
    'IC729',
    'IC735',
    'IC736',
    'IC737',
    'IC738',
    'IC746',
    'IC746PRO',
    'IC756',
    'IC756PRO',
    'IC756PROII',
    'IC756PROIII',
    'IC761',
    'IC765',
    'IC775',
    'IC781',
    'IC7000',
    'IC7800',
    'OMNI6',
    'JST245',
    'ORION');
}


// Has the radio's status changed since the last poll?
//
// This replaces a raw byte scan over SizeOf(RadioStatusRecord) in
// uRadioPolling.UpdateStatus.  The byte scan worked, and it is not being
// replaced because it was failing -- it is being replaced because it compares
// something other than what it claims to.
//
// WHAT A BYTE SCAN ACTUALLY COMPARES.  RadioStatusRecord's declared fields sit
// in a larger aligned footprint: VFOStatusType packs two longints and six
// one-byte enums, so the compiler pads it, and the two arrays of it multiply
// that padding.  Padding is memory no field owns.  It reads equal today only
// because ClearRadioStatus zeroes the whole record and every later write goes
// through a named field, so the pad bytes are set once and never touched again.
//
// That is a property of today's code, not an invariant.  Give this record a
// managed field -- a string, a dynamic array, an interface -- and Delphi stops
// copying it as a block: `PreviousStatus := CurrentStatus` becomes field-wise,
// the padding in the two records diverges, and the byte scan then reports a
// change on EVERY poll forever.  The symptom is a display and a UDP stream that
// never stop repainting, with nothing in the diff to explain it.
//
// Comparing named fields cannot fail that way, and it is what the routine was
// always trying to express.  test/unit/uTestRadioStatus.pas pins it field by
// field in both directions, so a field added to the record but not added here
// fails a test rather than becoming silently invisible to change detection.
function RadioStatusDiffers(const a, b: RadioStatusRecord): boolean;

// ---------------------------------------------------------------------------
// Coherent status snapshots (a seqlock).
//
// THE PROBLEM.  The polling thread fills CurrentStatus one named field at a
// time and then copies it into FilteredStatus, while the main thread reads
// those records whenever it repaints, logs, or retunes.  There is no
// synchronisation of any kind between the two.
//
// MOST READS ARE SAFE ANYWAY, and it is worth being precise about why rather
// than pretending otherwise: nearly every consumer reads ONE field --
// `.Freq`, `.Mode`, `.Split` -- and a naturally-aligned 32-bit read is atomic
// on x86.  Those cannot tear and gain nothing from a snapshot.
//
// THE READS THAT ARE NOT SAFE are the ones that take several fields and expect
// them to describe the same instant.  uProcessCommand.scExchangeRadios is the
// clearest: it CopyMemory's the whole 160-byte record out of a live one and
// then RETUNES BOTH RADIOS from it, so a copy that straddles a poll can QSY the
// operator to a frequency from one cycle with a mode from another.
//
// HOW IT WORKS.  The writer brackets its whole update -- the CurrentStatus fill
// AND the FilteredStatus copy, which happen back to back on the same thread --
// between BeginStatusPublish and EndStatusPublish.  The version is odd while a
// write is in progress and even when the pair is coherent.  A reader takes the
// version, copies, and takes it again; if it changed or was odd, the copy may
// have straddled a write and is retried.
//
// WHY A SEQLOCK RATHER THAN A LOCK.  There is exactly one writer and it is a
// real-time-ish poll loop; readers must never be able to stall it, and a reader
// that is descheduled must not hold anything.  Readers pay a retry only when
// they genuinely collide.
//
// WHY PARTIAL ADOPTION IS LEGITIMATE HERE.  Converting a reader is opt-in and
// local: a reader that uses ReadRadioStatus gets a coherent snapshot, and one
// that still touches the field directly is exactly as safe as it was before --
// no worse.  That is a property of a seqlock specifically; with a mutex,
// leaving some readers unconverted would be a broken invariant rather than an
// unfinished migration.  So these are being converted where multi-field
// coherence is actually required, not swept through mechanically.
procedure BeginStatusPublish(rig: RadioPtr);
procedure EndStatusPublish(rig: RadioPtr);

// A coherent copy of the settled (filtered) status.  Use this whenever more
// than one field is read and the fields must agree with each other.
function ReadRadioStatus(rig: RadioPtr): RadioStatusRecord;

// The same, for the live (unsettled) status.
function ReadRadioCurrentStatus(rig: RadioPtr): RadioStatusRecord;

// Key or unkey a SPECIFIC radio.  aRadio nil means "whichever is active",
// which is what an operator-driven action wants.
//
// THE EXPLICIT FORM EXISTS BECAUSE A CALLER CAN MEAN A PARTICULAR RADIO.  A
// TCI client addresses a receiver by number -- trx:1,true means radio 2 --
// and the active-radio form keys whatever happens to be active instead, so a
// client working the second radio keys the first.  This is the same lesson as
// CWByCATSend, which was given the radio explicitly for exactly this reason:
// SO2R and the interlock nominate a radio, and assuming the active one is a
// guess dressed as a default.
function tPTTVIACATForRadio(aRadio: RadioPtr; PTTOn: boolean): boolean;
function tPTTVIACAT(PTTOn: boolean): boolean;

// Put EVERY radio back into receive.  Call it before anything is torn down.
//
// WHY IT LIVES HERE.  It was first written inside MainUnit's implementation,
// which meant ExitProgram -- in LOGSUBS2, and the place it actually has to be
// called from -- could not see it.  It is about radios; it belongs with them.
//
// UNCONDITIONAL BY DESIGN.  It does not ask who keyed the radio, whether we
// believe it is transmitting, or whether PTT VIA COMMANDS is set: an RX to a
// receiving radio is a no-op, and "we thought it was not transmitting" is
// exactly how a rig gets left on.  It also bypasses tPTTVIACAT, which answers
// only for ActiveRadio -- the second radio can be the one transmitting.
procedure PutAllRadiosIntoReceive;
//function GetRadioFromString(RadioName: ShortString): InterfacedRadioType;
procedure TestRadioInterface;


{ Old style function calls supported here }

{ Works on the radio specified  (Radio1 or Radio2) }

procedure PutRadioIntoSplit(Radio: RadioType);
procedure PutRadioOutOfSplit(Radio: RadioType);
procedure SetRadioFreq(Radio: RadioType; Freq: longint; Mode: ModeType; VFO: char);


{ These work on the ActiveRadio }

//procedure CheckRITKeys;

procedure RITClear;
procedure RITBumpDown;
procedure RITBumpUp;

procedure VFOBumpDown;
procedure VFOBumpUp;

// The Yaesu poll strings that used to close this interface (FT767/FT847/
// FT747GX/FT1000MP/FT100 and the two 847 CAT-enable strings) are GONE.  They
// were the wire vocabulary of the per-model pollers Track E deleted, and after
// that deletion nothing -- in this unit or any other -- referenced them.  The
// Yaesu families own their own framing now: uRadioYaesuBinary.pas,
// uRadioYaesuASCII.pas and the FT-817 group.

implementation


uses
   LogK1EA,
   LogWind,
   MainUnit, uRadioPolling,
   uTelnet,
   LogStuff,
   LogSUBS2,
   LogCW,
   uRadioHamLibDirect,
   uRadioIcomBase,
   uRadioKenwoodLAN,  // Issue #436 -- TKenwoodLAN base (TS-890S / TS-990S)
   uCWFraming,        // per-model CW length/padding rules (shared with the factory)
   uCWKeyerBase;      // KeyerCAT -- owns the cross-radio CW-by-CAT interlock

// ---------------------------------------------------------------------------
// IMPLEMENTATION-ONLY SURFACE
//
// These were declared in the interface but nothing outside LOGRADIO referenced
// them.  Narrowing the interface is the point: this unit is the last legacy
// radio unit standing, and every public symbol it keeps is a symbol some future
// change can bind to by accident.
//
// The routines are FORWARD-declared rather than simply moved, because the
// interface declaration was also what let their bodies be called from anywhere
// in this 3,000-line implementation regardless of definition order.  Dropping
// the declaration without `forward` would make call-order load-bearing.
// ---------------------------------------------------------------------------

const
   ICOM_XMIT_SETTINGS   = #$1C;
   ICOM_GET_RIT_FREQ    = #$21;
   ICOM_STATE           = #$1A;
   ICOM_STATE_DATA_MODE = #$06;
   ICOM_PREAMBLE_CODE   = #$FE;

function IntegerToBCD(Value: DWORD): integer; forward;      // ny4i  // 4.44.5
function Integer4ToBCD(Value: DWORD): integer; forward;     // ny4i  // 4.44.5
function ModeTypeToNetMode(mode: ModeType): TRadioMode; forward;
procedure InitRadios; forward;
procedure SetK3ExtendedCommandMode; forward;
function GetRadioParameters(Radio: RadioType; RadioInfoString: string;
   var Freq: longint; var Band: BandType; var Mode: ModeType;
   Polling: boolean; Debug: boolean): boolean; forward;

// ---------------------------------------------------------------------------
// Parity ordinal conversion.  Tree.ParityType and the Win32 DCB (which the
// registry's TSerialParams.parity and the factory's serialParity use) disagree
// on the middle ordinals:
//
//     Tree.ParityType:  tNoParity = 0,  EvenParity = 1,  OddParity = 2
//     Win32 / registry:  NOPARITY = 0,  ODDPARITY  = 1,  EVENPARITY = 2
//
// Passing Ord() straight across therefore SWAPS odd and even.  Unobservable
// for as long as every radio ran no-parity, but 'RADIO n SERIAL FORMAT' makes
// parity configurable, so the conversion is now explicit in both directions.
// ---------------------------------------------------------------------------
// NOTE the Tree. qualification throughout: the Windows unit declares ODDPARITY
// and EVENPARITY as INTEGER constants (1 and 2), and Pascal's case-insensitive
// scope resolution makes a bare OddParity/EvenParity here resolve to THOSE, not
// to Tree.ParityType's members -- E2010 at best, a silent wrong ordinal at worst.
function Win32ParityToParityType(w: Byte): ParityType;

begin
   case w of
      uRadioRegistry.PARITY_ODD:  Result := Tree.OddParity;
      uRadioRegistry.PARITY_EVEN: Result := Tree.EvenParity;
   else
      Result := Tree.tNoParity;
   end;
end;

function ParityTypeToWin32(p: ParityType): Byte;
begin
   case p of
      Tree.OddParity:  Result := uRadioRegistry.PARITY_ODD;
      Tree.EvenParity: Result := uRadioRegistry.PARITY_EVEN;
   else
      Result := uRadioRegistry.PARITY_NONE;
   end;
end;



procedure TEventHandlers.OnTimerTick(Sender : TObject);
var callInactive: boolean;
begin
  DebugMsg('TimerTick event fired');
  TWinTimer(Sender).Enabled := false;
  if IsCWByCATActive(ActiveRadioPtr) then
     begin
     if ActiveRadioPtr.CWByCAT_Sending then
        begin
        ActiveRadioPtr.CWByCAT_Sending := false;
        callInactive := true;
        end;
     end;

  if IsCWByCATActive(InActiveRadioPtr) then
     begin
     if InActiveRadioPtr.CWByCAT_Sending then
        begin
        InActiveRadioPtr.CWByCAT_Sending := false;
        callInactive := true;
        end;
     end;

  if callInactive then
     begin
     BackToInactiveRadioAfterQSO;
     end;
end;

function IntegerToBCD(Value: DWORD): integer;
const
   Dividers: array[1..8] of integer = (1, 10, 100, 1000, 10000, 100000, 1000000, 10000000);
var
   j: integer;
begin
   Result := 0;
   for j := 8 downto 1 do //8 digits
      begin
      Result := (Result shl 4) or ((Value div Dividers[j]) mod 10);
      end;
end;//IntegerToBCD

function Integer4ToBCD(Value: DWORD): integer;
const
   Dividers: array[1..8] of integer = (1, 10, 100, 1000, 10000, 100000, 1000000, 10000000);
var
   j: integer;
begin
   Result := 0;
   for j := 2 downto 1 do //4 digits
      begin
      Result := (Result shl 4) or ((Value div Dividers[j]) mod 10);
      end;
end;//Integer4ToBCD

function ModeTypeToNetMode(mode: ModeType): TRadioMode; // TRadioMode is the Network mode type
begin
{Type TRadioMode = (rmNone,rmCW, rmCWRev, rmLSB, rmUSB, rmFM, rmAM,
                   rmData, rmDataRev, rmFSK, rmFSKRev, rmPSK, rmPSKRev,
                   rmAFSK, rmAFSKRev);
                   }
   case mode of
      CW: Result := rmCW;
      Digital: Result := rmData;
      Phone: Result := rmUSB;
      FM: Result := rmFM;
   else
      // Both / NoMode have no specific radio mode. Without this else the
      // function Result was left UNINITIALIZED -> garbage TRadioMode (often
      // rmData), which made a band change shove the radio into DATA. Return the
      // "none" mode so the caller sends no mode command and the radio keeps its
      // mode. (Use Low(TRadioMode), which is rmNone.)
      Result := Low(TRadioMode);
   end;
 //  ModeType = (CW, Digital, Phone, Both, NoMode, FM); { Use for TR }
           //AM, CW, CW-R, DATA-L, DATA-U, FM, LSB, USB, RTTY, RTTY-R, WBFM
  //ExtendedRadioModeType = (rNoMode, rCW, rLSB, rUSB, rAM, rFM, rRTTY, rRTTY_R, rAFSK, rDATA_U, rDATA_L, rDIGITAL, rCW_R);


end;


function BufToStr(var buf; bufSize: integer): string;
begin
   SetLength(Result, bufSize);
   Move(buf, pointer(Result)^, bufSize);
end;
//------------------------------------------------------------------------------
procedure LinkToActiveRadio(IntRadioType: InterfacedRadioType;
   SerialPort: PortType);
begin
   if ActiveRadio = RadioOne then
      begin
      //      IntRadioType := Radio1.RadioModel;
      //      SerialPort := Radio1.tCATPortType;
      end
   else
      begin
      //      IntRadioType := Radio2.RadioModel;
      //      SerialPort := Radio2.tCATPortType;
      end;
end;


procedure SetK3ExtendedCommandMode;
begin
   ActiveRadioPtr.WriteBufferToCATPort('K31;');
end;


procedure RITClear;

var
   ActiveNetObj: TFactoryRadioBase;

begin
   if ActiveRadio = RadioOne then
      begin
      ActiveNetObj := Radio1.tFactoryObject
      end
   else
      begin
      ActiveNetObj := Radio2.tFactoryObject;
      end;

   if ActiveNetObj <> nil then
      begin
      ActiveNetObj.RITClear(nrVFOA);
      end
   else
      begin
      // No factory driver -- not connected, or construction was refused.  That
      // is the same situation as having no radio, so doing nothing is correct;
      // it is logged only so a dead RIT key can be told apart from a broken one.
      logger.warn('[RITClear] No radio driver -- RIT clear not sent');
      end;
   {
   case IntRadioType of
      TS140, TS440, TS450, TS480, TS570, TS590, TS690, TS850, TS870, TS890, TS940,
      TS950, TS990, TS2000, FLEX, K2, K3, K4, FTDX10, FTDX101, FTX1F, FT450, FT891, FT950, FT991, FT1200, FT2000, FTDX3000,
      FTDX5000, FTDX9000:
         begin
         ActiveRadioPtr.WriteBufferToCATPort('RC;');
         end;
      FT710:
         begin
         ActiveRadioPtr.WriteBufferToCATPort('CF001+0000;'); // Set frequency to +0
         end;
      FT747GX, FT890, FT920, FT990, FT1000, FT1000MP:
         begin
         ActiveRadioPtr.WriteToCATPort(CHR(0) + CHR(0) + CHR(0) + CHR($FF) + CHR($09), 5);
         end;

      IC78..IC9700:
         begin
         // Ask the RADIO, not a table keyed by model.  rcReadRIT is the same
         // fact IcomRadiosThatSupportRIT encoded, but owned by the radio object.
         if ActiveRadioPtr.HasCapability(rcReadRIT) then
            begin
            ActiveRadioPtr.SendIcomClearRITCommand;
            end;
         end;
      OMNI6: {KK1L: 6.73 Added OMNI6}
      {   begin
         // Check what radios support this and send command to clear 21 00 00 00 00 on 9700
         Exit;
         end;

      Orion:
         begin
         ActiveRadioPtr.WriteBufferToCATPort('*RMR0' + CarriageReturn);
         Exit;
         end;

      else
         begin
         Exit;
         end;
      end;
      }
end;

procedure RITBumpUp;

var
   IntRadioType: InterfacedRadioType;
   ActiveNetObj: TFactoryRadioBase;
//   SerialPort: PortType;

begin
   if ActiveRadio = RadioOne then
      begin
      ActiveNetObj := Radio1.tFactoryObject
      end
   else
      begin
      ActiveNetObj := Radio2.tFactoryObject;
      end;

   if ActiveNetObj <> nil then
      begin
      ActiveNetObj.RITBumpUp;
      end
   else
      begin
      // No factory driver: same as no radio.  See RITClear.
      logger.warn('[RITBumpUp] No radio driver -- RIT bump not sent');
      end;
 {  if ActiveRadio = RadioOne then
      begin
      IntRadioType := Radio1.RadioModel;
//      SerialPort := Radio1.tCATPortType;
      end
   else
      begin
      IntRadioType := Radio2.RadioModel;
//      SerialPort := Radio2.tCATPortType;
      end;

   case IntRadioType of
      TS140, TS440, TS450, TS480, TS570, TS590, TS690, TS850, TS870, TS890, TS940,
      TS950, TS990, TS2000, K2, K3, K4 {, FTDX9000}{:
         begin
         ActiveRadioPtr.WriteBufferToCATPort('RU;');
         end;

      FT890, FT920, FT990, FT1000, FT1000MP:
         begin
         Exit;
         end;

      IC78..IC9700, OMNI6: {KK1L: 6.73 Added OMNI6}    // This does not work for all Icom radios.
     {    begin
         // NOTE: nothing here is implemented -- the guard that used to wrap
         // these comments (IntRadioType in IcomRadiosThatSupportRIT) protected
         // no code at all, so it is gone rather than translated.
         // Have to know what RIT is set to now and then increase it by a bit. RIT should be in radio poll so we always know
         // Not implemented yet due to issues converting the hz to BCD
         //ActiveRadioPtr.SetICOMRITFrequency(ActiveRadioPtr.CurrentStatus.RITFreq + 10);
         Exit;
         end;

      Orion:
         begin
         ActiveRadioPtr.WriteBufferToCATPort('*RMR200' + CarriageReturn);
         Exit;
         end;

      else
         begin
         Exit;
         end;
      end;
      }
end;

procedure RITBumpDown;

var
   IntRadioType: InterfacedRadioType;
   ActiveNetObj: TFactoryRadioBase;
//   SerialPort: PortType;

begin
   if ActiveRadio = RadioOne then
      begin
      ActiveNetObj := Radio1.tFactoryObject
      end
   else
      begin
      ActiveNetObj := Radio2.tFactoryObject;
      end;

   if ActiveNetObj <> nil then
      begin
      ActiveNetObj.RITBumpDown;
      end
   else
      begin
      // No factory driver: same as no radio.  See RITClear.
      logger.warn('[RITBumpDown] No radio driver -- RIT bump not sent');
      end;

 //  if ActiveRadio = RadioOne then
//      begin
//      IntRadioType := Radio1.RadioModel;
////      SerialPort := Radio1.tCATPortType;
//      end
//   else
//      begin
//      IntRadioType := Radio2.RadioModel;
////      SerialPort := Radio2.tCATPortType;
//      end;
//
//   case IntRadioType of
//      TS140, TS440, TS450, TS480, TS570, TS590, TS690, TS850, TS870, TS890, TS940,
//      TS950, TS990, TS2000, K2, K3, K4 {, FTDX9000}:
//         begin
//         ActiveRadioPtr.WriteBufferToCATPort('RD;');
//         end;
//
//      FT890, FT920, FT990, FT1000, FT1000MP:
//         begin
//         Exit;
//         end;
//
//      IC78..IC9700, OMNI6: {KK1L: 6.73 Added OMNI6} // Add code somewhere tohandle radios that do not support 21 code.
//         begin
//         // NOTE: nothing here is implemented -- the guard that used to wrap
//         // these comments (IntRadioType in IcomRadiosThatSupportRIT) protected
//         // no code at all, so it is gone rather than translated.
//         // Not implemented yet due to issues converting the hz to BCD
//         //ActiveRadioPtr.SetICOMRITFrequency(ActiveRadioPtr.CurrentStatus.RITFreq - 10);
//         Exit;
//         end;
//
//      Orion:
//         begin
//         ActiveRadioPtr.WriteBufferToCATPort('*RMR-200' + CarriageReturn);
//         Exit;
//         end;
//
//      else
//         begin
//         Exit;
//         end;
//      end;
end;

procedure VFOBumpUp;

var
   ActiveNetObj: TFactoryRadioBase;

begin
   if ActiveRadio = RadioOne then
      begin
      ActiveNetObj := Radio1.tFactoryObject
      end
   else
      begin
      ActiveNetObj := Radio2.tFactoryObject;
      end;

   if ActiveNetObj <> nil then
      begin
      ActiveNetObj.VFOBumpUp(nrVFOA);
      end
   else
      begin
      // No factory driver: same as no radio.  See RITClear.
      logger.warn('[VFOBumpUp] No radio driver -- VFO bump up not sent');
      end;

   // The per-model `case IntRadioType of` that sent 'UP;' here is DELETED.
   // Both branches above delegate to the driver and Exit, so this was only
   // reachable when construction failed -- already a logged ERROR from
   // SetUpRadioInterface.  Each driver's VFOBumpUp owns its own command.
   //
   // This also retires the LAST callers of RadioObject.AddToOutputBuffer,
   // whose (PAnsiChar, length) signature is the shape NY4I wants gone from
   // the main data path: the program should hand around strings and let the
   // transport worry about bytes.
end;

procedure VFOBumpDown;

var
   ActiveNetObj: TFactoryRadioBase;

begin
   if ActiveRadio = RadioOne then
      begin
      ActiveNetObj := Radio1.tFactoryObject
      end
   else
      begin
      ActiveNetObj := Radio2.tFactoryObject;
      end;

   if ActiveNetObj <> nil then
      begin
      ActiveNetObj.VFOBumpDown(nrVFOA);
      end
   else
      begin
      // No factory driver: same as no radio.  See RITClear.
      logger.warn('[VFOBumpDown] No radio driver -- VFO bump down not sent');
      end;

   // The per-model `case IntRadioType of` that sent 'DN;' here is DELETED.
   // Both branches above delegate to the driver and Exit, so this was only
   // reachable when construction failed -- already a logged ERROR from
   // SetUpRadioInterface.  Each driver's VFOBumpDown owns its own command.
   //
   // This also retires the LAST callers of RadioObject.AddToOutputBuffer,
   // whose (PAnsiChar, length) signature is the shape NY4I wants gone from
   // the main data path: the program should hand around strings and let the
   // transport worry about bytes.
end;



 {
procedure CheckRITKeys;

var
  TestByte                         : Byte;

begin
  if not ShiftKeyEnable then Exit;

  //WLI    TestByte := Mem [$40:$17];

  TestByte := TestByte and $0F; // Mask off the lock keys

  case TestByte of
    1:
      if MicroTimeElapsed(RITCommandTimeStamp) > 0 then
      begin
        RITBumpUp;
        MarkTime(RITCommandTimeStamp);
      end;

    2:
      if MicroTimeElapsed(RITCommandTimeStamp) > 0 then
      begin
        RITBumpDown;
        MarkTime(RITCommandTimeStamp);
      end;

    3:
      if MicroTimeElapsed(RITCommandTimeStamp) > 0 then
      begin
        RITClear;
        MarkTime(RITCommandTimeStamp);
      end;

  end;

end;
} 

function GetRadioParameters(Radio: RadioType; RadioInfoString: string;
   var Freq: longint; var Band: BandType; var Mode: ModeType;
   Polling: boolean; Debug: boolean): boolean;

begin
   //  GetRadioParameters := true;

   case Radio of
      RadioOne:
         begin
         with Radio1 do
            begin
            Freq := FilteredStatus.Freq;
            Band := FilteredStatus.Band;
            Mode := FilteredStatus.Mode;
            GetRadioParameters := {true} FilteredStatus.Freq <> 0; //wli
            end;
         end;

      RadioTwo:
         begin
         with Radio2 do
            begin
            Freq := FilteredStatus.Freq;
            Band := FilteredStatus.Band;
            Mode := FilteredStatus.Mode;
            GetRadioParameters := {true} FilteredStatus.Freq <> 0; //wli
            end;
         end;
      end;
end;

procedure PutRadioIntoSplit(Radio: RadioType);

begin
   case Radio of
      RadioOne:
         begin
         Radio1.PutRadioIntoSplit;
         end;
      RadioTwo:
         begin
         Radio2.PutRadioIntoSplit;
         end;
      end;
end;

procedure PutRadioOutOfSplit(Radio: RadioType);

begin
   case Radio of
      RadioOne:
         begin
         Radio1.PutRadioOutOfSplit;
         end;
      RadioTwo:
         begin
         Radio2.PutRadioOutOfSplit;
         end;
      end;
end;

procedure SetRadioFreq(Radio: RadioType; Freq: longint; Mode: ModeType; VFO: char);

{ Backwards compatable routine to the pre TR680 days }

begin
   case Radio of
      RadioOne:
         begin
         Radio1.SetRadioFreq(Freq, Mode, VFO);
         end;
      RadioTwo:
         begin
         Radio2.SetRadioFreq(Freq, Mode, VFO);
         end;
      end;
end;

procedure RadioObject.WriteBufferToCATPort(const Buffer);
begin
   WriteToCATPort(Buffer, lstrlenA(@Buffer));
end;

function RadioObject.WritePollRequest(const Buffer;
   nNumberOfBytesToWrite: DWORD): longbool;
begin
 { if NoPollDuringPTT then
  if tPTTStatus = PTT_ON then
  Sleep(500);   }
 //     try
     begin
      Result := WriteToCATPort(Buffer, nNumberOfBytesToWrite);
  //    except //on E : Exception do
      ; // TLogger.GetInstance.Debug(Format('In WritePollRequest, %s error raised, with message <%s> ',[E.ClassName,E.Message]));
      end;
   if not Result then
      begin
      Sleep(200);
      end;
end;


function RadioObject.WriteToCATPort(const Buffer;
   nNumberOfBytesToWrite: DWORD): longbool;
var
   lpNumberOfBytesWritten: DWORD;

  // i: integer;
  // s: string;
   nLen: integer;

begin
{
  if not DVKEnable then
    if RadioModel = TS850 then
      if nNumberOfBytesToWrite = 4 then
        if PChar(Buffer)[0] = 'P' then
          if PChar(Buffer)[1] = 'B' then
            if PChar(Buffer)[2] in ['1'..'3'] then
              if PChar(Buffer)[3] = ';' then
              begin
//                Result := 0;
                Exit;
              end;
}
      try
      if logger.IsTraceEnabled then
         begin
         if true then //not (nNumberOfBytesToWrite in [3,6,7]) then
            begin
            logger.trace('>>>>Enter WriteToCATPort');
            SetString(debugStr,PAnsiChar(@Buffer),nNumberOfBytesToWrite);
            nLen := nNumberOfBytesToWrite; //Ord(Buffer[0]);
            // Binary traffic traces as hex only (text would be garbage).
            //
            // Was `RadioParametersArray[...].rt = rtICOM`, which asked the wrong
            // question: the property that matters here is whether the bytes are
            // BINARY, not who made the radio.  The driver already states that --
            // SerialProtocolIsBinary, set True by TIcomRadio for CI-V -- so ask
            // it instead of a table.
            //
            // SLIGHT BEHAVIOUR CHANGE, and an improvement: any driver that
            // declares a binary protocol now hex-traces, not just the CI-V ones.
            // The Yaesu FT-1000MP is the case in point -- its 32-byte status
            // block is binary (SerialFixedFrameLength implies it) and used to be
            // logged as text, which is exactly the garbage this branch exists to
            // avoid.
            if (Self.tFactoryObject <> nil) and
               Self.tFactoryObject.SerialProtocolIsBinary then
               begin
               logger.trace(Format('[%s] Calling WriteFile to write %u bytes <%s>',
                  [RadioName, nNumberOfBytesToWrite, BinToHexStr(Buffer, nLen)]));
               end
            else
               begin
               // Hex alongside the text so non-printable control bytes are visible
               // -- e.g. the K3 keyer-abort 'KY <04>;RX;' (Chr(4)) shows as plain
               // 'KY ;RX;' in a text-only trace, hiding the control byte entirely.
               logger.trace(Format('[%s] Calling WriteFile to write %u bytes <%s> hex[%s]',
                  [RadioName, nNumberOfBytesToWrite, debugStr, BinToHexStr(Buffer, nLen)]));
               end;
            end;
         end;

      Windows.WriteFile(tCATPortHandle, Buffer, nNumberOfBytesToWrite,
         lpNumberOfBytesWritten, nil);
      except // on E : Exception do
      ; // TLogger.GetInstance.Debug(Format('In WriteToCATPort..WriteFile, %s error raised, with message <%s> ',[E.ClassName,E.Message]));
      end;
{
  if not Windows.WriteFile(tCATPortHandle, Buffer, nNumberOfBytesToWrite, lpNumberOfBytesWritten, pOver) then
    if pOver <> nil then
      if GetLastError = ERROR_IO_PENDING then
      begin
        Result := True;
        Exit;
      end;
}
   Result := nNumberOfBytesToWrite = lpNumberOfBytesWritten;
{$IF NEWER_DEBUG}
   if not (nNumberOfBytesToWrite in [3,6,7]) then
      begin
      DebugMsg('<<<<Exit WriteToCATPort');
      end;
{$IFEND}
end;

// Effective data bits / parity / stop bits for this connection, in priority:
//   1. 'RADIO n SERIAL FORMAT' (e.g. 8N2) when configured and valid;
//   2. else the radio's registered defaults (uRadioRegistry.SerialParamsFor) --
//      the same values the dialog shows when the model is picked;
//   3. else (an unregistered, HamLib-only model) 8-N-2 -- exactly what the old
//      hardcoded test produced for those models.
//
// This replaces `if RadioModel in [IC78..IC9700, FT100, Orion] then 1 else 2`,
// which ran on EVERY connect and so silently clobbered any configured stop
// bits -- and disagreed with the radio's own documentation in one case: the
// Omni VI (Model 563 manual section 5.2: 1 stop bit) sits outside the range
// and was forced to 2.  The registered default now takes effect.
// The BAUD RATE is deliberately not touched here: it has been config-driven
// ('RADIO n BAUD RATE') all along.
procedure RadioObject.ResolveSerialFrameSettings;
var
   db, par, sb: Byte;
   sp: uRadioRegistry.TSerialParams;
begin
   if uRadioRegistry.TryParseSerialFormat(string(SerialFormat), db, par, sb) then
      begin
      RadioNumberBits := db;
      RadioParity     := Win32ParityToParityType(par);
      RadioStopBits   := sb;
      Exit;
      end;
   if SerialFormat <> '' then
      begin
      logger.Warn('[%s] SERIAL FORMAT ''%s'' is not valid (expected e.g. 8N2) -- using the radio''s defaults',
         [RadioName, SerialFormat]);
      end;
   if uRadioRegistry.IsRegistered(RadioModel) then
      begin
      sp := uRadioRegistry.SerialParamsFor(RadioModel);
      RadioNumberBits := sp.dataBits;
      RadioParity     := Win32ParityToParityType(sp.parity);
      RadioStopBits   := sp.stopBits;
      end
   else
      begin
      RadioNumberBits := 8;
      RadioParity     := tNoParity;
      RadioStopBits   := 2;
      end;
end;

{ The initializtion of BeginPolling is in this procedure so if we are not using serial ports, it has to be setup somewhere else.}
// Issue: a misconfigured radio used to fail in silence -- no setup, no thread,
// nothing in the log to say which radio the program thought it was driving.
// NY4I 2026-08-02: dump what we believe, at DEBUG, so an operator can compare
// it against what they intended, and so a user bug report carries it.
procedure RadioObject.LogRadioConfiguration;
var
   what:   string;
   how:    string;
   parity: string;

   function OrElse(const s, fallback: string): string;
   begin
      if s = '' then
         begin
         Result := fallback;
         end
      else
         begin
         Result := s;
         end;
   end;

begin
   // No IsEnabledFor guard: logger.Debug already no-ops below DEBUG, and this
   // runs twice at startup (and on Reset Radio Ports), so the string building
   // is not worth a level test that could go stale.

   // WHICH radio.  A string-id radio has NO enum member, so report whichever
   // actually identifies it -- that distinction is what hid the TCI bug.
   if Self.FactoryId <> '' then
      begin
      what := 'factory-id ' + string(Self.FactoryId) + ' (' +
              uRadioRegistry.DisplayNameId(string(Self.FactoryId)) + ')';
      end
   else if Self.RadioModel = NoInterfacedRadio then
      begin
      what := 'NONE (no RADIO n TYPE and no RADIO n FACTORY ID configured)';
      end
   else
      begin
      what := uRadioRegistry.DisplayName(Self.RadioModel);
      end;

   // HOW it is wired.
   if Self.UseHamLib then
      begin
      how := Format('HamLib (rig_model %d)', [Self.HamLibID]);
      end
   else if Self.tCATPortType = Network then
      begin
      how := Format('network %s:%d', [string(Self.IPAddress), Self.RadioTCPPort]);
      end
   else if Self.tCATPortType = NoPort then
      begin
      how := 'NO PORT SET';
      end
   else
      begin
      case Self.RadioParity of
         Tree.OddParity:   parity := 'O';
         Tree.EvenParity:  parity := 'E';
      else
         parity := 'N';
      end;
      how := Format('COM%d %d baud %d%s%d',
                    [Ord(Self.tCATPortType), Self.RadioBaudRate,
                     Self.RadioNumberBits, parity, Self.RadioStopBits]);
      end;

   logger.Debug('[%s config] radio=%s  connection=%s',
                [string(Self.RadioName), what, how]);
   logger.Debug('[%s config] polling=%s  CW-speed-sync=%s  serial-format=%s  startup-command=%s',
                [string(Self.RadioName),
                 BoolToStr(Self.PollingEnable, True),
                 BoolToStr(Self.CWSpeedSync, True),
                 OrElse(string(Self.SerialFormat), '(radio default)'),
                 OrElse(string(Self.StartupCommand), '(none)')]);
   // Credentials: report only WHETHER one is set, never the value.
   logger.Debug('[%s config] network-username=%s  Icom-data-mode=D%d',
                [string(Self.RadioName),
                 OrElse(string(Self.NetworkUsername), '(none)'),
                 Self.IcomDataModeID]);
end;

procedure RadioObject.CheckAndInitializePorts_ForThisRadio;
begin
   LogRadioConfiguration;
   // Reset data-mode capability for this connection: assume no data mode until
   // the radio proves it by answering a valid $1A06. This lets an old Icom put
   // on a slot previously held by a data-mode radio commit its mode via $04.
   // "No radio configured" is NOT the same as "RadioModel = NoInterfacedRadio".
   // A STRING-ID radio (RegisterRadioById) has no InterfacedRadioType member at
   // all, so its RadioModel IS NoInterfacedRadio by design -- see the note in
   // SetUpRadioInterface.  Testing the enum alone silently skipped setup for the
   // entire string-id mechanism: no SetUpRadioInterface, no polling thread, and
   // not one line in the log to say why.  TCI was the first such radio, so this
   // path had never been exercised until 2026-08-02.
   if (RadioModel = NoInterfacedRadio) and (Self.FactoryId = '') then
      begin
      // "No radio configured" must also mean "STOP whatever was here".  A
      // profile that CLEARS a slot lands exactly here, and returning early
      // skipped SetUpRadioInterface -- the only thing that frees the old
      // factory object and stops its polling thread.  NY4I switched from the
      // K4/K3 profile to a K4-only one and the K3 kept polling from 14:16:56
      // until the program closed at 14:22:10, so the main window went on
      // showing its frequency (2026-08-08).
      Self.ShutDownRadioInterface;
      ClearRadioStatus(@Self);
      Exit;
      end;
   ResolveSerialFrameSettings;
   SetUpRadioInterface;

   if (tCATPortHandle <> INVALID_HANDLE_VALUE) or
      (Self.tFactoryObject <> nil)                 then
      begin
      if PollingEnable then
         begin
         tPollCount := -1;
         tRadioInterfaceThreadHandle :=
            CreateThread(nil, 0, @BeginPolling, @Self, 0, tRadioInterfaceThreadID);
         logger.Info('Created Radio %s thread with threadid of %d',[Self.RadioName, tRadioInterfaceThreadID] );
         end;
      end;

end;

procedure RadioObject.FreqToBCD(Freq: longint; Swap: boolean; OpCode: byte);
var
   TempByte, sb1, sb2: byte;
   c: cardinal;
   TempFreq: longint;
begin
   ZeroMemory(@tYaesuFreq5Bytes, SizeOf (tYaesuFreq5Bytes));
   tYaesuFreq5Bytes[4] := OpCode;
   TempFreq := Freq div 10;
   for c := 3 downto 0 do
      begin
      TempByte := TempFreq mod 100;
      TempFreq := TempFreq div 100;
      sb1 := TempByte div 10;
      sb2 := TempByte mod 10;
      if c = 0 then
         begin
         if Freq > 1000000000 then
            begin
            sb1 := sb1 + 10;
            end;
         end;
      TempByte := sb1 * 16 + sb2;
      tYaesuFreq5Bytes[c] := TempByte;
      end;

   if Swap then
      begin
      c := PDWORD(@tYaesuFreq5Bytes)^;
      // Issue #997: BSWAP EAX -> reverse the four bytes (c is Cardinal).
      c := ((c and $000000FF) shl 24) or
           ((c and $0000FF00) shl 8)  or
           ((c and $00FF0000) shr 8)  or
           ((c and $FF000000) shr 24);
      PDWORD(@tYaesuFreq5Bytes)^ := c;
      end;
end;

function RadioObject.ConvertBCDStringToFreq(BCDString: Str20): longint;

var
   F1: longint;

begin
   if length(BCDString) = 5 then
      begin
      F1 := (Ord(BCDString[5]) and $F0) shr 4; { 1000s of mhz }
      F1 := F1 * 10;
      F1 := F1 + (Ord(BCDString[5]) and $0F); { 100s of mhz}
      F1 := F1 * 10;
      end
   else
      begin
      F1 := 0;
      end;

   F1 := F1 + ((Ord(BCDString[4]) and $F0) shr 4); { 10s of mhz }
   F1 := F1 * 10;
   F1 := F1 + (Ord(BCDString[4]) and $0F); { 1s of mhz}
   F1 := F1 * 10;

   F1 := F1 + ((Ord(BCDString[3]) and $F0) shr 4);
   F1 := F1 * 10;
   F1 := F1 + (Ord(BCDString[3]) and $0F);
   F1 := F1 * 10;

   F1 := F1 + ((Ord(BCDString[2]) and $F0) shr 4);
   F1 := F1 * 10;
   F1 := F1 + (Ord(BCDString[2]) and $0F);
   F1 := F1 * 10;

   F1 := F1 + ((Ord(BCDString[1]) and $F0) shr 4);
   F1 := F1 * 10;

   F1 := F1 + (Ord(BCDString[1]) and $0F);

   ConvertBCDStringToFreq := F1;
end;

function FrequencyFromFourBytes(FreqStr: string): longint;

var
   F1, F2, F3: longint;

begin
   F1 := Ord(FreqStr[1]);
   F1 := F1 * 256 * 256 * 256;
   F2 := Ord(FreqStr[2]);
   F2 := F2 * 256 * 256;
   F3 := Ord(FreqStr[3]);
   F3 := F3 * 256;
   FrequencyFromFourBytes := F1 + F2 + F3 + Ord(FreqStr[4]);
end;

procedure RadioObject.SendIcomTwoByteCommand(Command: byte; opCode: byte);

begin

   tIcom7Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[2] := ReceiverAddress;
   tIcom7Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom7Bytes[4] := Command;
   tIcom7Bytes[5] := Ord(Chr(opCode));
   tIcom7Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom6Bytes, 7);
end;
procedure RadioObject.SendIcomCommand(Command: byte);

begin

   tIcom6Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom6Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom6Bytes[2] := ReceiverAddress;
   tIcom6Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom6Bytes[4] := Command;
   tIcom6Bytes[5] := Ord(ICOM_END_OF_MESSAGE_CODE);

   //TLogger.GetInstance.Debug(Format('In SendIcomCommand, Sending command %s',[Chr(Command)]));
   WriteToCATPort(tIcom6Bytes, 6);
end;
//------------------------------------------------------------------------------
procedure RadioObject.SendXMITStatusCommand;
begin
   tIcom7Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[2] := ReceiverAddress;
   tIcom7Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom7Bytes[4] := Ord(ICOM_XMIT_SETTINGS);
   tIcom7Bytes[5] := (Ord(Chr(0)));
   tIcom7Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom7Bytes, 7);
end; // SendXMITStatusCommand;
 //------------------------------------------------------------------------------
 procedure RadioObject.GetIcomDataStateCommand;
begin
   tIcom7Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[2] := ReceiverAddress;
   tIcom7Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom7Bytes[4] := Ord(ICOM_STATE);
   tIcom7Bytes[5] := (Ord(ICOM_STATE_DATA_MODE));
   tIcom7Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom7Bytes, 7);
end; // GetDatyaStateCommand;
//---------------------------------------------------------------------------
 procedure RadioObject.SendRITStatusCommand;
begin
   tIcom7Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[2] := ReceiverAddress;
   tIcom7Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom7Bytes[4] := Ord(ICOM_GET_RIT_FREQ);
   tIcom7Bytes[5] := (Ord(Chr(1)));
   tIcom7Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom7Bytes, 7);
end; // SendRITStatusCommand;

procedure RadioObject.SendRITFreqCommand;
begin
   tIcom7Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom7Bytes[2] := ReceiverAddress;
   tIcom7Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom7Bytes[4] := Ord(ICOM_GET_RIT_FREQ);
   tIcom7Bytes[5] := (Ord(Chr(0)));
   tIcom7Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom7Bytes, 7);
end; // SendRITFreqCommand;


procedure RadioObject.SetICOMRITFrequency(hz: integer);

begin
   {CommandsTempBuffer[0] := AnsiChar(11);
   CommandsTempBuffer[1] := ICOM_PREAMBLE_CODE;
   CommandsTempBuffer[2] := ICOM_PREAMBLE_CODE;
   CommandsTempBuffer[3] := AnsiChar(ReceiverAddress);
   CommandsTempBuffer[4] := ICOM_CONTROLLER_ADDRESS;
   CommandsTempBuffer[5] := ICOM_GET_RIT_FREQ;
   CommandsTempBuffer[6] := AnsiChar(0);
   {absHz := abs(hz);
   foo := Integer4ToBCD(absHz);
   newFreq := ((absHz mod 100) * 100) + absHz div 100;

   CommandsTempBuffer[7] := AnsiChar(absHz mod 100);// Put frequency here
   CommandsTempBuffer[8] := AnsiChar(absHz div 100);
   CommandsTempBuffer[7] := AnsiChar(absHz div 1000 mod 10);
   CommandsTempBuffer[8] := AnsiChar(absHz div 100 mod 10);
   CommandsTempBuffer[7] := AnsiChar(foo div 100);
   CommandsTempBuffer[8] := AnsiChar(foo mod 100);



    if hz < 0 then
      begin
      CommandsTempBuffer[9] := AnsiChar(1);
      end
   else
      begin
      CommandsTempBuffer[9] := AnsiChar(0);
      end;
   CommandsTempBuffer[10] := ICOM_END_OF_MESSAGE_CODE;
   AddCommandToBuffer;
   }
end;

function RadioObject.MemoryKeyer(mem: integer): boolean;
begin
   // The per-model `case RadioModel of` that played DVK memories here is DELETED
   // (2026-07-31): every selectable model has a factory driver, so it was the
   // silent fallback for a construction failure, which SetUpRadioInterface now
   // reports as an ERROR.  Each driver's MemoryKeyer owns its own commands.
   if Self.tFactoryObject <> nil then
      begin
      Result := Self.tFactoryObject.MemoryKeyer(mem);
      Exit;
      end;

   // No factory object: the radio is misconfigured (already logged at setup).
   // True is the answer the deleted code gave for "nothing was keyed" -- both
   // its unsupported-radio guard and its else arm returned True -- so callers
   // see no change.
   logger.Warn('[MemoryKeyer] No factory driver for this radio; memory %d not played', [mem]);
   Result := True;
end;


procedure RadioObject.ProcessIcomMode(mode: integer);
begin
   case mode of
   0:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eLSB;
      end;
   1:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eUSB;
      end;
   2:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eAM;
      end;
   3:
      begin
      Self.CurrentStatus.Mode := CW;
      Self.CurrentStatus.ExtendedMode := eCW;
      end;
   4:
      begin
      Self.CurrentStatus.Mode := Digital;
      Self.CurrentStatus.ExtendedMode := eRTTY;
      end;
   5:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eFM;
      end;
   6:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eWFM;
      end;
   7:
      begin
      Self.CurrentStatus.Mode := CW;
      Self.CurrentStatus.ExtendedMode := eCW_R;
      end;
   8:
      begin
      Self.CurrentStatus.Mode := Digital;
      Self.CurrentStatus.ExtendedMode := eRTTY_R;
      end;
   12:
      begin
      Self.CurrentStatus.Mode := Digital;
      Self.CurrentStatus.ExtendedMode := ePSK31;
      end;
   13:
      begin
      Self.CurrentStatus.Mode := Digital;
      Self.CurrentStatus.ExtendedMode := ePSK_R;
      end;
   17:
      begin
      Self.CurrentStatus.Mode := Phone;
      Self.CurrentStatus.ExtendedMode := eDSTAR;
      end;
   else
      DEBUGMSG('Unknown Mode command from Icom ' + IntToStr(mode));
   end;
end;


{procedure RadioObject.SendIcomClearRITCommand;
begin
   tIcom11Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom11Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom11Bytes[2] := ReceiverAddress;
   tIcom11Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom11Bytes[4] := Ord(ICOM_GET_RIT_FREQ);
   tIcom11Bytes[5] := (Ord(Chr(0)));
   tIcom11Bytes[6] := (Ord(Chr(0)));
   tIcom11Bytes[7] := (Ord(Chr(0)));
   tIcom11Bytes[8] := (Ord(Chr(0)));
   tIcom11Bytes[9] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom11Bytes, 10);
end; // SendRITFreqCommand;


procedure RadioObject.SendIcomExtendedVFO(bVFO: boolean);
begin
   tIcom11Bytes[0] := Ord(ICOM_PREAMBLE_CODE);
   tIcom11Bytes[1] := Ord(ICOM_PREAMBLE_CODE);
   tIcom11Bytes[2] := ReceiverAddress;
   tIcom11Bytes[3] := Ord(ICOM_CONTROLLER_ADDRESS);
   tIcom11Bytes[4] := Ord(ICOM_GET_EXTENDEDVFO);
   tIcom11Bytes[5] := ifthen(bVFO,Ord(Chr(1)),Ord(Chr(0)));
   tIcom11Bytes[6] := Ord(ICOM_END_OF_MESSAGE_CODE);
   WriteToCATPort(tIcom11Bytes, 7);
end; // SendIcomExtendedVFO

}
procedure RadioObject.PutRadioIntoSplit;

begin
   //TLogger.GetInstance.Debug(Format('      In PutRadioIntoSplit: %s',[RadioName]));
   // The per-model `case RadioModel of` that used to follow is DELETED
   // (2026-07-31).  Every selectable model has a factory driver -- the enum was
   // diffed against the registry and only NoInterfacedRadio is unregistered --
   // so this arm was reachable only when construction failed, which
   // SetUpRadioInterface now reports as an ERROR instead of silently running a
   // second implementation here.  The split commands live in each driver's
   // Split(), where they are per-family and bench-tested.  (Kenwood especially:
   // a bare FR CANCELS SPLIT on a TS-570, which is why the old line wrote
   // 'FR0;FT1;' as ONE command -- a fact now owned by the Kenwood driver.)
   if Self.tFactoryObject <> nil then
      begin
      Self.tFactoryObject.Split(true);
      end;
end;

procedure RadioObject.PutRadioOutOfSplit;

begin
   //TLogger.GetInstance.Debug(Format('      In PutRadioOutOfSplit: %s',[RadioName]));
   // Per-model `case RadioModel of` DELETED -- see PutRadioIntoSplit above for
   // why (every model has a driver; this arm was the silent fallback for a
   // failed construction, which is now an ERROR from SetUpRadioInterface).
   if Self.tFactoryObject <> nil then
      begin
      Self.tFactoryObject.Split(false);
      end;
end;

procedure RadioObject.UpdateRadioStatus;

{ Updates the filtered radio status } // This is not called anymore

begin
   if CurrentStatus.Freq = PreviousStatus.Freq then
      begin
      FilteredStatus.Freq := CurrentStatus.Freq;
      end;

   if CurrentStatus.Mode = PreviousStatus.Mode then
      begin
      FilteredStatus.Mode := CurrentStatus.Mode;
      end;

      if CurrentStatus.ExtendedMode = PreviousStatus.ExtendedMode then
         begin
         FilteredStatus.ExtendedMode := CurrentStatus.ExtendedMode;
         end;

   if CurrentStatus.Band = PreviousStatus.Band then
      begin
      FilteredStatus.Band := CurrentStatus.Band;
      end;

   if CurrentStatus.Split = PreviousStatus.Split then
      begin
      FilteredStatus.Split := CurrentStatus.Split;
      end;

   if CurrentStatus.VFO[VFOA].Frequency = PreviousStatus.VFO[VFOA].Frequency then
      begin
      FilteredStatus.VFO[VFOA].Frequency := CurrentStatus.VFO[VFOA].Frequency;
      end;

   if CurrentStatus.VFO[VFOA].Band = PreviousStatus.VFO[VFOA].Band then
      begin
      FilteredStatus.VFO[VFOA].Band := CurrentStatus.VFO[VFOA].Band;
      end;

   if CurrentStatus.VFO[VFOA].Mode = PreviousStatus.VFO[VFOA].Mode then
      begin
      FilteredStatus.VFO[VFOA].Mode := CurrentStatus.VFO[VFOA].Mode;
      end;

   if CurrentStatus.VFO[VFOA].ExtendedMode = PreviousStatus.VFO[VFOA].ExtendedMode then
      begin
      FilteredStatus.VFO[VFOA].ExtendedMode := CurrentStatus.VFO[VFOA].ExtendedMode;
      end;

   //   if CurrentStatus.VFOA.TXRX = PreviousStatus.VFOA.TXRX then
   //      FilteredStatus.VFOA.TXRX := CurrentStatus.VFOA.TXRX;

   if CurrentStatus.VFO[VFOB].Frequency = PreviousStatus.VFO[VFOB].Frequency then
      begin
      FilteredStatus.VFO[VFOB].Frequency := CurrentStatus.VFO[VFOB].Frequency;
      end;

   if CurrentStatus.VFO[VFOB].Band = PreviousStatus.VFO[VFOB].Band then
      begin
      FilteredStatus.VFO[VFOB].Band := CurrentStatus.VFO[VFOB].Band;
      end;

   if CurrentStatus.VFO[VFOB].Mode = PreviousStatus.VFO[VFOB].Mode then
      begin
      FilteredStatus.VFO[VFOB].Mode := CurrentStatus.VFO[VFOB].Mode;
      end;

   if CurrentStatus.VFO[VFOB].ExtendedMode = PreviousStatus.VFO[VFOB].ExtendedMode then
      begin
      FilteredStatus.VFO[VFOB].ExtendedMode := CurrentStatus.VFO[VFOB].ExtendedMode;
      end;

   //   if CurrentStatus.VFOB.TXRX = PreviousStatus.VFOB.TXRX then
   //      FilteredStatus.VFOB.TXRX := CurrentStatus.VFOB.TXRX;

   if CurrentStatus.TXOn = PreviousStatus.TXOn then        // ny4i  // 4.44.5
      begin
      FilteredStatus.TXOn := CurrentStatus.TXOn;
      end;

   PreviousStatus := CurrentStatus;
end;

procedure RadioObject.OnCWByCATTimeEvent(Sender :TObject);
begin
   // Q9: the radio's own capability, not the legacy typeset (see SendCW).
   if Self.CWByCAT and Self.HasCapability(rcCWByCAT) then
      begin
      if Self.CWBYCAT_Sending then
         begin
         QuickDisplay('CW Timer fired');
         Self.tmrCWByCat.enabled := false;
         end;
      end;
end;

procedure RadioObject.EnableCWBYCATTimer(ms: integer);
begin
{ Updating the time in a timer does not work properly. Need to come up up with a better way for that. NY4I
   if Self.tmrCWBYCAT.enabled then
      begin
      // Add the time
      DebugMsg('Adding ' + IntToStr(ms) + ' mS to tmrCWByCAT timer - Interval now = to ' + IntToStr(Self.tmrCWByCAT.interval) + ' mS.');
      Self.tmrCWByCAT.interval := Self.tmrCWByCAT.interval + ms;
      end
   else }
      begin
      logger.trace('Setting tmrCWByCAT timer to %d ms',[ms]);
      Self.tmrCWByCAT.interval := ms;
      Self.tmrCWByCat.enabled := true;
      end;
end;
{-------------------------------------------------------------------------------}
procedure RadioObject.AddTimeToCWByCATTimer(ms: integer);    // ny4i Issue 159 - Added procedure
begin
   if Self.tmrCWBYCAT.enabled then
      begin
      Self.tmrCWByCAT.interval := Self.tmrCWByCAT.interval + ms;
      end
   else
      begin
      DebugMsg('[AddTimerToCWByCATTimer] Trying to add ' + IntToStr(ms) + ' ms but timer is disabled');
      end;
end;
{------------------------------------------------------------------------------}
procedure RadioObject.AddCommandToBuffer;
begin
   // TLogger.GetInstance.Debug('Entering AddCommandToBuffer');
   if not PollingEnable then
      begin
      WriteToCATPort(PAnsiChar(@CommandsTempBuffer[1])^, Ord(CommandsTempBuffer[0]) - 1);
      // TLogger.GetInstance.Debug('Entering sleep(250)');
      Sleep(250);
      // TLogger.GetInstance.Debug('Returning from sleep(250)');
      // TLogger.GetInstance.Debug('Leaving AddCommandToBuffer via Exit');
      Exit;
      end;

   if CommandsBufferPointer = 8 then
      begin
      CommandsBufferPointer := 0;
      end;
   DebugRadioTempBuffer('AddCommandToBuffer',CommandsTempBuffer); // ny4i Issue 145 - Decorator string, pointer, length
   Windows.CopyMemory(@CommandsBuffer[CommandsBufferPointer],
      @CommandsTempBuffer, Ord(CommandsTempBuffer[0]));
   Inc(CommandsBufferPointer);
   //TLogger.GetInstance.Debug('Leaving AddCommandToBuffer');
end;


//------------------------------------------------------------------------------
function RadioObject.DeleteLastCWCharacter: boolean;  // ny4i Procedure added Issue149
begin
   Result := false;
   if length(Self.CWByCATBuffer) > 1 then
      begin
      SetLength(Self.CWByCATBuffer,length(Self.CWByCATBuffer)-1); // Remove one byte from end of string
      Result := true;
      end
   else if length(Self.CWByCATBuffer) = 1 then
      begin
      if Copy(Self.CWByCATBuffer,1,1) <> CWByCATBufferTerminator then
         begin
         SetLength(Self.CWByCATBuffer,length(Self.CWByCATBuffer)-1); // Remove one byte from end of string
         Result := true;
         end;
      end;
end;
//------------------------------------------------------------------------------
procedure RadioObject.FlushCWByCATBuffer;      // ny4i 4.44.5
begin
   SetLength(Self.CWByCATBuffer,0);    // ny4i Issue 149 Added (general cleanup)
end;
//------------------------------------------------------------------------------
// CW-by-CAT send.  ONE path for every radio -- the `case rt of` with separate
// Kenwood/Elecraft, Icom and Orion arms is gone.  What differed between them is
// now owned by whoever should own it:
//
//   prosign spellings   uCWFraming.CWProsignFor   (three dialects, unit-tested)
//   length + padding    uCWFraming.CWFrameRuleFor
//   busy-window factor  the frame rule (Icom needs 1.25, the KY radios 1.0)
//   the command itself  the driver's BufferCW/SendCW (KY, CI-V, Orion per-char)
//   two-radio interlock TCWKeyerCAT.EnsureSoleTransmitter
//
// What stays here is the part that is genuinely NOT per-radio: the buffer, the
// terminator/speed-change trigger, and the busy flag -- which must be set
// BEFORE the driver writes, so the poll thread pauses before the command
// reaches the wire.  Set it after and a short message can be stepped on by an
// interleaved IF; poll and never key.
//------------------------------------------------------------------------------
procedure RadioObject.StopSendingCW;
begin
   // Every per-model abort is now in its own driver's StopCW: the Elecraft
   // 'KY <abort>;RX;' (TElecraftSerial, with TK2Radio overriding the abort
   // character), the Kenwood 'KY0;'+'RX;', the Flex 'ZZSS;' and the Icom CI-V
   // $17 $FF.  Nothing here knows what radio it is talking to.
   //
   // The CWIsFactoryOwned test stays and is NOT redundant: it asks "does this
   // driver really key CW", and for a radio that does not, StopCW is a no-op we
   // should skip rather than a command to send.  It also earns its keep as the
   // guard that caught a real bug -- delegating to ANY factory object once
   // swallowed Escape entirely, because most drivers' StopCW was inert and the
   // legacy abort below was never reached (NY4I, K3, 2026-07-31).
   if (Self.tFactoryObject <> nil) and Self.tFactoryObject.CWIsFactoryOwned then
      begin
      Self.tFactoryObject.StopCW;
      end;
end;
//------------------------------------------------------------------------------
procedure RadioObject.AdoptFactoryObject;
begin
   // Five construction sites (HamLib, serial x2, network x2) all need the same
   // two facts handed over.  StartupCommand was already duplicated at all five;
   // rigLabel was set at exactly ONE of them -- inside the network branch --
   // which is why every serial radio logged "[]" instead of its name.  One
   // helper so a sixth construction site cannot reintroduce the same gap.
   if Self.tFactoryObject = nil then
      begin
      Exit;
      end;
   Self.tFactoryObject.rigLabel := Self.RadioName;          // e.g. "K3S-15"
   Self.tFactoryObject.StartupCommand := string(Self.StartupCommand);

   // Auto-info, HERE and not in a branch.  It was added next to
   // ApplyDataModeID, which lives inside the NETWORK arm -- so it was never
   // called for a serial radio, and the K3S it was written for silently kept
   // level 0.  That is the exact gap the comment above describes for
   // rigLabel: a fact handed over at one construction site instead of all of
   // them.  Adopt runs before Connect at every site, which is the ordering
   // this needs -- the level has to be known before the driver sends AI.
   Self.tFactoryObject.ApplyAutoInfoLevel(Self.AutoInfoLevel);
end;

procedure RadioObject.ShutDownRadioInterface;
begin
   if Self.tFactoryObject = nil then
      begin
      Exit;
      end;

   logger.Info('[%s.ShutDownRadioInterface] Stopping polling thread', [Self.RadioName]);
   Self.PollingStopRequested := True;
   if Self.tRadioInterfaceThreadHandle <> 0 then
      begin
      WaitForSingleObject(Self.tRadioInterfaceThreadHandle, 3000);
      CloseHandle(Self.tRadioInterfaceThreadHandle);
      Self.tRadioInterfaceThreadHandle := 0;
      Self.tRadioInterfaceThreadID := 0;
      end;
   Self.PollingStopRequested := False;

   logger.Info('[%s.ShutDownRadioInterface] Freeing radio object', [Self.RadioName]);
   Self.tFactoryObject.Disconnect;
   Self.tFactoryObject.Free;
   Self.tFactoryObject := nil;
end;

procedure RadioObject.SetUpRadioInterface;
var
   hand: HWND;
//   TempCardinal: cardinal;
   dwFlagsAndAttributes: DWORD;
   EvtChar: char;
begin
   // If a radio object already exists, stop the polling thread and free it before creating a new one.
   // This prevents the old thread from accessing freed memory (dangling pointer AV).
   Self.ShutDownRadioInterface;

   // INVARIANT: a HamLib-only radio always uses HamLib.  TR4W has no native CAT
   // implementation for these models, so the serial path would start a polling
   // thread that can never read anything.
   //
   // The CAT dialog already forces the flag and greys the checkbox, but that only
   // covers configs that went through the dialog.  'RADIO ONE USE HAMLIB' is a
   // config-file command (uCFG), so a hand-edited .cfg -- or one written before a
   // model became HamLib-only -- can arrive here with the flag clear.
   // Enforce it where the interface is actually chosen, not only where it is edited.
   // "HamLib-only" is now derived from the registry: a real model with no factory
   // registration has no native driver (uRadioRegistry.IsHamLibOnly).
   if uRadioRegistry.IsHamLibOnly(Self.RadioModel) then
      begin
      if not Self.UseHamLib then
         begin
         logger.Info('[%s.SetUpRadioInterface] Forcing UseHamLib -- this radio has no native CAT support in TR4W',
            [Self.RadioName]);
         Self.UseHamLib := True;
         end;
      end;

   // Check if we should use HamLib Direct (works with both serial and network)
   if Self.UseHamLib then
      begin
      logger.Info('[%s.SetUpRadioInterface] Using HamLib Direct', [Self.RadioName]);

      // Create HamLib Direct radio via factory
      Self.tFactoryObject := TRadioFactory.CreateHamLibDirect(nil);
      // The radio owns its name and startup command from birth;
      // SendStartupCommand fires the latter once the link is actually up.
      Self.AdoptFactoryObject;

      if Self.tFactoryObject <> nil then
         begin
         if Self.tFactoryObject is THamLibDirect then
            begin
            with THamLibDirect(Self.tFactoryObject) do
               begin
               // THE OPERATOR'S OVERRIDE NOW ACTUALLY WORKS.  RADIO n HAMLIB ID
               // has had a config command and a dialog row, but NOTHING read it
               // at connect -- this line always took the table value -- so
               // typing a rig number for a generic HamLib radio was silently
               // ignored and HAMLIBANY always came up as rig_model 1.
               //
               // Honoured only for HAMLIBANY, matching the dialog, which enables
               // the field for that model alone and shows a read-only registry
               // value otherwise.  A stale HamLibID left in the config from an
               // earlier setup must not be allowed to beat a real model's ID.
               if (Self.RadioModel = HAMLIBANY) and (Self.HamLibID > 0) then
                  begin
                  HamLibModelID := Self.HamLibID;
                  logger.Info('[%s] HamLib rig_model %d (operator override)',
                              [Self.RadioName, HamLibModelID]);
                  end
               else
                  begin
                  // The REGISTRY owns the HamLib rig_model now.  Every enum
                  // registration carries its own, transcribed from the legacy
                  // table and pinned by test/unit/uTestHamLibIDs -- because a
                  // wrong number here does not fail to compile or to connect,
                  // it just makes the rig behave as some OTHER radio.
                  //
                  // RadioParametersArray keeps the values for historic
                  // reference; nothing reads them for this any more.  That
                  // matters: two live sources for one fact is what put three
                  // WRONG hamlibIDs in the table (TS-590, TS-2000, FLEX) until
                  // task #16 went looking for them.
                  HamLibModelID := uRadioRegistry.RegisteredHamLibID(Self.RadioModel);
                  logger.Info('[%s] HamLib rig_model %d (per-model default)',
                              [Self.RadioName, HamLibModelID]);
                  end;

               // Check if using network or serial connection
               if tCATPortType = Network then
                  begin
                  // Network connection
                  logger.Info('[%s] HamLib via network: %s:%d',
                              [Self.RadioName, Self.IPAddress, Self.RadioTCPPort]);
                  UseIPAddress := True;
                  IPAddress := Self.IPAddress;
                  IPPort := Self.RadioTCPPort;
                  end
               else if tCATPortType in SerialPorts then
                  begin
                  // Serial connection
                  COMPortName := ConvertPortTypeToCOMString(Self.tCATPortType);
                  BaudRate := Self.RadioBaudRate;
                  logger.Info('[%s] HamLib via serial: %s at %d baud',
                              [Self.RadioName, COMPortName, BaudRate]);
                  UseIPAddress := False;
                  end;

               if Self.ReceiverAddress > 0 then
                  begin
                  CIVAddress := IntToStr(Self.ReceiverAddress);
                  end;
               end;
            end;

         // Connect the radio
         Self.tFactoryObject.Connect;
         logger.Info('[%s.SetUpRadioInterface] HamLib Direct connected', [Self.RadioName]);
         end
      else
         begin
         logger.error('[%s.SetUpRadioInterface] Failed to create HamLib Direct radio', [Self.RadioName]);
         end;
      end
   else if tCATPortType in SerialPorts then
      begin
      // Check if we should use modern radio class (e.g., K4, Icom) or legacy serial code
      // A string-id factory radio (no InterfacedRadioType member) takes precedence.
      if (Self.FactoryId <> '') and uRadioRegistry.IsRegisteredId(string(Self.FactoryId)) and
         uRadioRegistry.SupportsSerialId(string(Self.FactoryId)) then
         begin
         logger.Info('[%s.SetUpRadioInterface] Setting up %s serial via factory id: Port=%d, Baud=%d',
                     [Self.RadioName, uRadioRegistry.DisplayNameId(string(Self.FactoryId)), Ord(tCATPortType), RadioBaudRate]);
         Self.tFactoryObject := TRadioFactory.CreateRadioSerialById(
            string(Self.FactoryId),
            tCATPortType,
            RadioBaudRate,
            RadioNumberBits,
            RadioStopBits,
            ParityTypeToWin32(RadioParity),   // serialParity is the Win32 value; Ord() would swap odd/even
            tr4w_cat_rts_state = RtsDtr_ON,
            tr4w_cat_dtr_state = RtsDtr_ON
         );
         // The radio owns its name and startup command from birth;
         // SendStartupCommand fires the latter once the link is actually up.
         Self.AdoptFactoryObject;
         if Self.tFactoryObject <> nil then
            begin
            Self.tFactoryObject.Connect;
            end
         else
            begin
            // A factory radio has no legacy fallback -- if the factory could not
            // build it, surface it to the operator and do NOT connect.
            logger.Error('[%s.SetUpRadioInterface] Factory could not create serial radio "%s" (id) -- not connecting',
                        [Self.RadioName, uRadioRegistry.DisplayNameId(string(Self.FactoryId))]);
            QuickDisplayError('Radio "' + string(Self.RadioName) + '" could not be created -- not connected. Check its configuration.');
            end;
         Self.EventHandlers := EventHandlers;
         Self.tmrCWByCAT := TWinTimer.Create(nil);
         Self.tmrCWByCAT.Enabled := false;
         Self.tmrCWByCAT.OnTimer := Self.EventHandlers.OnTimerTick;
         with FilteredStatus do
            begin
            Band := NoBand;
            Mode := NoMode;
            Freq := 0;
            end;
         if Self.tFactoryObject <> nil then
            begin
            Self.tFactoryObject.SendStartupCommand;
            end;
         Exit;
         end
      else if uRadioRegistry.IsRegistered(Self.RadioModel) and
         uRadioRegistry.SupportsSerial(Self.RadioModel) then
         begin
         // Registered serial-capable radio -> build it through the factory.
         logger.Info('[%s.SetUpRadioInterface] Setting up %s serial via factory: Port=%d, Baud=%d, DataBits=%d, Parity=%d, StopBits=%d',
                     [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel), Ord(tCATPortType),
                      RadioBaudRate, RadioNumberBits, Ord(RadioParity), RadioStopBits]);
         Self.tFactoryObject := TRadioFactory.CreateRadioSerial(
            Self.RadioModel,
            tCATPortType,
            RadioBaudRate,
            RadioNumberBits,
            RadioStopBits,
            ParityTypeToWin32(RadioParity),   // serialParity is the Win32 value; Ord() would swap odd/even
            tr4w_cat_rts_state = RtsDtr_ON,
            tr4w_cat_dtr_state = RtsDtr_ON
         );
         // The radio owns its name and startup command from birth;
         // SendStartupCommand fires the latter once the link is actually up.
         Self.AdoptFactoryObject;
         if Self.tFactoryObject <> nil then
            begin
            // ASK WHETHER IT WORKED.  Connect's result was discarded and
            // success logged unconditionally, so a port that could not be
            // opened produced "serial radio connected via factory" in the
            // log while the radio was dead -- and the operator, reasonably,
            // went looking anywhere but here (NY4I: COM15 came back
            // "Cannot open (error 5)" and the next line said connected).
            // Connect returns an integer whose meaning is not documented, so
            // ASK THE RADIO instead -- which is the idiom the K4 driver
            // already uses after calling inherited Connect.
            Self.tFactoryObject.Connect;
            if Self.tFactoryObject.IsConnected then
               begin
               logger.Info('[%s.SetUpRadioInterface] %s serial radio connected via factory',
                          [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel)]);
               end
            else
               begin
               logger.Error('[%s.SetUpRadioInterface] %s did NOT connect -- ' +
                            'serial port %d is in use or unavailable',
                            [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel),
                             Ord(tCATPortType)]);
               QuickDisplayError('Radio "' + string(Self.RadioName) +
                                 '" could not open its port -- not connected.');
               end;
            end
         else
            begin
            // A factory radio has no legacy fallback -- if the factory could not
            // build it, surface it to the operator and do NOT connect.
            logger.Error('[%s.SetUpRadioInterface] Factory could not create serial radio "%s" -- not connecting',
                        [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel)]);
            QuickDisplayError('Radio "' + string(Self.RadioName) + '" could not be created -- not connected. Check its configuration.');
            end;

         // Initialize timer and event handlers — must happen for all radio paths
         Self.EventHandlers := EventHandlers;
         Self.tmrCWByCAT := TWinTimer.Create(nil);
         Self.tmrCWByCAT.Enabled := false;
         Self.tmrCWByCAT.OnTimer := Self.EventHandlers.OnTimerTick;
         // Reset filtered status
         with FilteredStatus do
            begin
            Band := NoBand;
            Mode := NoMode;
            Freq := 0;
            end;
         // Send startup command if configured
         if Self.tFactoryObject <> nil then
            begin
            Self.tFactoryObject.SendStartupCommand;
            end;
         // Exit to prevent any legacy serial code from executing
         Exit;
         end
      else
         begin
         // NO LEGACY FALLBACK.  This used to open the COM port by hand and let
         // BeginPolling dispatch to a per-model poller in uRadioPolling.  Every
         // selectable radio is now built by the factory (100 registrations; the
         // only enum member without one is NoInterfacedRadio), so reaching here
         // means the operator put a radio on a transport it does not support --
         // a hand-edited .cfg, since the dialog will not offer it.
         //
         // Opening a port we cannot then poll is worse than not opening it: the
         // rig looks connected and silently does nothing.  Fail loudly instead,
         // exactly as the by-id branch above already does.
         logger.Error('[%s.SetUpRadioInterface] %s does not support a serial connection -- not connecting. Check RADIO n TYPE / PORT.',
                      [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel)]);
         QuickDisplayError('Radio "' + string(Self.RadioName) + '" is not a serial radio -- not connected. Check its configuration.');
         end;
      end
   else if tCATPortType = Network then
      begin
      // Non-HamLib network radio (e.g., K4, Icom with native network protocol)
      logger.Info('[%s.SetUpRadioInterface] Setting up non-HamLib network radio: IP=%s, Port=%d',
                  [Self.RadioName, Self.IPAddress, Self.RadioTCPPort]);

      // Build the radio through the factory.  A string-id factory radio (no
      // InterfacedRadioType member) takes precedence over the enum gate.
      if (Self.FactoryId <> '') and uRadioRegistry.IsRegisteredId(string(Self.FactoryId)) and
         uRadioRegistry.SupportsNetworkId(string(Self.FactoryId)) then
         begin
         Self.tFactoryObject := TRadioFactory.CreateRadioNetworkById(
            string(Self.FactoryId),
            Self.IPAddress,
            Self.RadioTCPPort
         );
         // The radio owns its name and startup command from birth;
         // SendStartupCommand fires the latter once the link is actually up.
         Self.AdoptFactoryObject;
         logger.Info('[%s] Using %s network protocol (id)', [Self.RadioName, uRadioRegistry.DisplayNameId(string(Self.FactoryId))]);
         end
      else if uRadioRegistry.IsRegistered(Self.RadioModel) and
         uRadioRegistry.SupportsNetwork(Self.RadioModel) then
         begin
         Self.tFactoryObject := TRadioFactory.CreateRadioNetwork(
            Self.RadioModel,
            Self.IPAddress,
            Self.RadioTCPPort
         );
         // The radio owns its name and startup command from birth;
         // SendStartupCommand fires the latter once the link is actually up.
         Self.AdoptFactoryObject;
         logger.Info('[%s] Using %s network protocol', [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel)]);
         end
      else
         begin
         logger.warn('[%s] Unknown network radio model (RadioModel=%d), cannot create factory instance',
                    [Self.RadioName, Ord(Self.RadioModel)]);
         end;

      if Self.tFactoryObject <> nil then
         begin
         // rigLabel and StartupCommand are handed over by AdoptFactoryObject at
         // each construction site above, so the network path no longer sets
         // rigLabel here -- it was the only path that ever did.

         // E-2: ASK THE RADIO, do not type-test it.  This used to be two
         // `if tFactoryObject is TIcomRadio / TKenwoodLAN` blocks that reached in
         // and set properties -- per-family knowledge in the construction site
         // the factory exists to keep clean, and a silent gap for any future
         // radio that also needs credentials.  Both are no-ops on a radio that
         // does not authenticate.
         Self.tFactoryObject.ApplyNetworkCredentials(string(Self.NetworkUsername),
                                                     string(Self.NetworkPassword));
         Self.tFactoryObject.ApplyDataModeID(Self.IcomDataModeID);

         // Connect is deferred to the polling thread (pFactoryRadio).  Running
         // it synchronously here blocked the main thread for up to 10 s
         // (Indy ConnectTimeout) whenever the radio was off or unreachable.
         // The polling thread's existing reconnect-with-backoff path now
         // handles the very first connect as well.  Issue #436.
         logger.Info('[%s.SetUpRadioInterface] Network radio %s:%d configured; Connect deferred to polling thread (main thread not blocked)',
                     [Self.RadioName, Self.IPAddress, Self.RadioTCPPort]);
         end
      else
         begin
         // A factory radio has no legacy fallback -- if the factory could not
         // build it, surface it to the operator and do NOT connect.
         logger.Error('[%s.SetUpRadioInterface] Factory could not create the network radio -- not connecting', [Self.RadioName]);
         QuickDisplayError('Radio "' + string(Self.RadioName) + '" could not be created -- not connected. Check its configuration.');
         end;
      end;

   { Initialize the radio variables }

   Self.tmrCWByCAT := TWinTimer.Create(nil);
   Self.tmrCWByCAT.Enabled := false;
   Self.EventHandlers := EventHandlers;
   Self.tmrCWByCAT.OnTimer := Self.EventHandlers.OnTimerTick;


   with CurrentStatus do
      begin
      Band := NoBand;
      Mode := NoMode;
      Freq := 0;
      VFO[VFOA].Frequency := 0;
      VFO[VFOB].Frequency := 0;
      end;

   with PreviousStatus do
      begin
      Band := NoBand;
      Mode := NoMode;
      Freq := 0;
      end;

   with FilteredStatus do
      begin
      Band := NoBand;
      Mode := NoMode;
      Freq := 0;
      end;
   logger.debug('[RadioObject.SetUpRadioInterface] Startup command length = %d, startup command = %s',[length(Self.StartupCommand),Self.StartupCommand]);
   // The startup command is the RADIO's business now: it is handed the string at
   // construction and sends it from SendStartupCommand once the link is up.
   // Nothing to do here.
   //
   // The per-model `case rt of` that used to sit in the no-factory branch is
   // DELETED, and with it the LAST read of RadioParametersArray.  It was
   // reachable only when construction failed -- already a logged ERROR -- and
   // it never worked for Icom anyway: that arm was
   //     logger.Warn('Startup command not yet implemented for Icom').
   // ------------------------------------------------------------------
   // NO FACTORY DRIVER WAS BUILT for a radio the operator actually selected.
   //
   // Every model in InterfacedRadioType has a factory registration (verified
   // 2026-07-31: the only unregistered member is NoInterfacedRadio, the "no
   // radio" sentinel).  So reaching here with a configured radio does not mean
   // "this rig has no driver" -- it means construction was REFUSED or FAILED:
   // the transport guards above require IsRegisteredId/IsRegistered AND
   // SupportsSerial/SupportsNetwork, so a radio configured on a transport it
   // does not support lands here, as does a driver that failed to build.
   //
   // Until now that was SILENT, and the legacy `case RadioModel of` tails
   // scattered through this unit quietly became the implementation -- a
   // different code path from the one every other user of that rig runs, with
   // no clue in the log.  Legacy was acting as the error handler.  Say so
   // instead: this is the diagnostic that has to exist BEFORE those tails can
   // be deleted, or removing them would replace a silent fallback with silence.
   if (Self.tFactoryObject = nil) and
      ( (Self.RadioModel <> NoInterfacedRadio) or (Self.FactoryId <> '') ) then
      begin
      if Self.FactoryId <> '' then
         begin
         logger.Error('[%s] NO FACTORY DRIVER built for factory id "%s" on port %d ' +
                      '- falling back to the legacy radio path. The radio may not ' +
                      'support this connection type.',
                      [Self.RadioName, string(Self.FactoryId), Ord(Self.tCATPortType)]);
         end
      else
         begin
         logger.Error('[%s] NO FACTORY DRIVER built for %s on port %d ' +
                      '- falling back to the legacy radio path. The radio may not ' +
                      'support this connection type.',
                      [Self.RadioName, uRadioRegistry.DisplayName(Self.RadioModel),
                       Ord(Self.tCATPortType)]);
         end;
      end;

   { Enable polling }

   //  PollingEnable := True;
end;

//------------------------------------------------------------------------------
// Does THIS radio have a capability?  ONE place asks, so a hand-maintained
// model list can never disagree with what the radio itself declares -- the
// defect that produced the Q9 CW-by-CAT split and, in the same file, a
// prosign table that silently omitted the KX3.
//
// The live factory object is preferred over the registry because it also
// answers for STRING-ID radios: those have RadioModel = NoInterfacedRadio, so
// the enum-keyed registry lookup can never find them and would report every
// capability as absent.
function RadioObject.HasCapability(cap: TRadioCapability): boolean;
begin
   if Self.tFactoryObject <> nil then
      begin
      Result := Self.tFactoryObject.Supports(cap);
      end
   else
      begin
      Result := uRadioRegistry.SupportsFor(Self.RadioModel, cap);
      end;
end;

procedure RadioObject.SetRadioCWSpeed(speed: longint);
begin
   // Was `RadioModel in RadioSupportsCWSpeedSync` -- a hand-maintained typeset
   // competing with the registry's rcCWSpeedSync, whose own comment says it
   // replaces exactly this.  The typeset ran BEFORE the factory delegation
   // below, so a radio the factory knows can sync speed but that was missing
   // from the list exited here and never synced at all.
   if not Self.HasCapability(rcCWSpeedSync) then
      begin
      DebugMsg('Current radio model does not support CWSpeedSync');
      exit;
      end;

   // The per-model `case rt of` that formatted KS/CI-V speed commands here is
   // DELETED (2026-07-31) -- unreachable for any correctly constructed radio,
   // and each driver's SetCWSpeed owns its own encoding (which matters: the
   // Icom wpm->level mapping is per-model, 6..60 on the IC-718 family against
   // 6..48 elsewhere, and that fact belongs with the radio, not here).
   if Self.tFactoryObject <> nil then
      begin
      Self.tFactoryObject.SetCWSpeed(speed);
      end;
end;
//------------------------------------------------------------------------------
procedure RadioObject.SetRadioFreq(Freq: longint; Mode: ModeType; VFO: char; extendedMode: ExtendedModeType);
begin
   Self.nextExtendedMode := extendedMode;
   Self.SetRadioFreq(Freq, Mode, VFO);
end;

// Returns mode adjusted for frequency: if mode is SSB, selects LSB below 8 MHz
// and USB at or above 8 MHz (standard ham radio sideband convention).
// Non-SSB modes are returned unchanged.
function AdjustSSBModeForFreq(mode: TRadioMode; freq: longint): TRadioMode;
begin
   if mode in [rmLSB, rmUSB] then
      begin
      if freq < 8000000 then
         begin
         Result := rmLSB;
         end
      else
         begin
         Result := rmUSB;
         end;
      end
   else
      begin
      Result := mode;
      end;
end;

procedure RadioObject.SetRadioFreq(Freq: longint; Mode: ModeType; VFO: char);

var
   tNetMode: TRadioMode;

begin
   logger.debug('[SetRadioFreq] set frequency to %u',[freq]);

   if Freq <= 0 then
      begin
      logger.debug('[SetRadioFreq] freq <= 0 (no band memory or default for this band/mode) -- skipping tune');
      Exit;
      end;

   // Issue #795 vs bandmap double-click: record the app-commanded VFO-A
   // frequency so the auto-S&P "QSY clears the entry" logic (uRadioPolling) can
   // tell a COMMANDED QSY (bandmap/spot/typed freq -- a call may have been
   // placed deliberately) from a MANUAL dial QSY (which #795 wants to clear).
   if VFO = 'A' then
      begin
      Self.tCommandedQSYFreq := Freq;
      end;

   // The ~600-line `case rt of` that used to follow -- every family's own
   // frequency/mode encoding, and 12 of this unit's 22 per-model tests -- is
   // DELETED (2026-07-31).  It was unreachable for any correctly constructed
   // radio, and a construction failure is now an ERROR from SetUpRadioInterface
   // instead of a silent fall-through to a second implementation.  Each driver's
   // SetFrequency owns its own encoding, where it is per-family and testable.
   if Self.tFactoryObject <> nil then
      begin
      tNetMode := AdjustSSBModeForFreq(ModeTypeToNetMode(mode), freq);
      if VFO = 'B' then
         begin
         Self.tFactoryObject.SetFrequency(freq, nrVFOB, tNetMode);
         end
      else
         begin
         Self.tFactoryObject.SetFrequency(freq, nrVFOA, tNetMode);
         end;
      end;
end;

procedure RadioObject.UpdateBandOutputInfo(Band: BandType; Mode: ModeType);

begin
   if BandOutputPort <> NoPort then
      begin
      OutputBandInfo(tBandOutputPortBaseAddress {BandOutputPort}, Band, Mode);
      end;
end;


procedure TestRadioInterface;

{ This procedure will display the data coming back from the interfaced
  radios }

var
   RadioOneLastDisplayedCurrentStatus:  Str80;
   RadioOneLastDisplayedPreviousStatus: Str80;
   RadioOneLastDisplayedFilteredStatus: Str80;

   RadioTwoLastDisplayedCurrentStatus:  Str80;
   RadioTwoLastDisplayedPreviousStatus: Str80;
   RadioTwoLastDisplayedFilteredStatus: Str80;

//   TempStatusString: Str80;
//   TempValue: real;

begin
   //{WLI}    Window (1, 1, 80, 25);

   //{WLI}    TextBackground (Black);
   //{WLI}    NoCursor;

   ShowMessage('TEST RADIO INTERFACE');

   //{WLI}    WriteLn ('This procedure will display the data coming back from the interfaced radios');
   //{WLI}    WriteLn ('Press the ESCAPE key to exit and halt TR.');
   //{WLI}    WriteLn;

   RadioOneLastDisplayedCurrentStatus  := '';
   RadioOneLastDisplayedPreviousStatus := '';
   RadioOneLastDisplayedFilteredStatus := '';

   RadioTwoLastDisplayedCurrentStatus  := '';
   RadioTwoLastDisplayedPreviousStatus := '';
   RadioTwoLastDisplayedFilteredStatus := '';


end;

function RadioObject.CheckAutoCallTerminate: boolean;
begin
  Result := False;
  if AutoCallTerminate then
     begin
     if not ExchangeHasBeenSent then
        if tAutoSendMode then
           if not ControlAMode then
              begin
              //ReturnInCQOpMode;
              Result := True;
              end;
     end;
end;
// Field-by-field, in declaration order.  See the note on the declaration for
// why this is not a byte compare.
//
// The two VFO arrays are compared over their FULL index range -- vfoUnknown and
// vfoMem included, not just VFOA/VFOB.  pFactoryRadio only ever fills A and B
// today, so the other two slots are always zero and the extra comparisons are
// free; but a byte scan covered them, and quietly narrowing what counts as a
// change while claiming to preserve behaviour is exactly the kind of silent
// difference this whole exercise exists to avoid.
function VFOStatusDiffers(const a, b: VFOStatusType): boolean;
begin
   Result := (a.Frequency    <> b.Frequency)    or
             (a.RITFreq      <> b.RITFreq)      or
             (a.Band         <> b.Band)         or
             (a.Mode         <> b.Mode)         or
             (a.Split        <> b.Split)        or
             (a.RIT          <> b.RIT)          or
             (a.XIT          <> b.XIT)          or
             (a.ExtendedMode <> b.ExtendedMode);
end;

function RadioStatusDiffers(const a, b: RadioStatusRecord): boolean;
var
   v: ActiveVFOStatusType;
begin
   Result := True;

   if (a.Freq          <> b.Freq)          or
      (a.Split         <> b.Split)         or
      (a.RIT           <> b.RIT)           or
      (a.XIT           <> b.XIT)           or
      (a.RITFreq       <> b.RITFreq)       or
      (a.PrevRITFreq   <> b.PrevRITFreq)   or
      (a.Band          <> b.Band)          or
      (a.Mode          <> b.Mode)          or
      (a.ExtendedMode  <> b.ExtendedMode)  or
      (a.VFOStatus     <> b.VFOStatus)     or
      (a.PrevVFOStatus <> b.PrevVFOStatus) or
      (a.TXOn          <> b.TXOn)          then
      begin
      Exit;
      end;

   for v := Low(ActiveVFOStatusType) to High(ActiveVFOStatusType) do
      begin
      if VFOStatusDiffers(a.VFO[v], b.VFO[v]) then
         begin
         Exit;
         end;
      if VFOStatusDiffers(a.previousVFO[v], b.previousVFO[v]) then
         begin
         Exit;
         end;
      end;

   Result := False;
end;

// InterlockedIncrement, not Inc.  Two reasons, and the second is the one that
// bites: it is a full memory barrier, so neither the compiler nor the CPU may
// move the record writes outside the odd/even window -- without that the whole
// scheme is decoration, because a reader could observe an even version while
// the field stores are still in flight.
procedure BeginStatusPublish(rig: RadioPtr);
begin
   Windows.InterlockedIncrement(integer(rig^.StatusVersion));   // -> odd: writing
end;

procedure EndStatusPublish(rig: RadioPtr);
begin
   Windows.InterlockedIncrement(integer(rig^.StatusVersion));   // -> even: coherent
end;

// Seqlock read.  Copy, then check the version did not move under us.
//
// The retry is bounded rather than a bare `repeat until`: the writer is a poll
// loop that touches this a few times a second, so a reader that has spun this
// many times is not losing a race, it is looking at a stuck or never-published
// version.  Spinning forever on the UI thread would hang the program; returning
// the last copy is what the caller would have got before this existed.
function ReadStatusSnapshot(rig: RadioPtr; const aFiltered: boolean): RadioStatusRecord;
const
   MAX_ATTEMPTS = 64;
var
   before, after: cardinal;
   attempts: integer;
begin
   attempts := 0;
   repeat
      before := rig^.StatusVersion;
      if aFiltered then
         begin
         Result := rig^.FilteredStatus;
         end
      else
         begin
         Result := rig^.CurrentStatus;
         end;
      after := rig^.StatusVersion;
      Inc(attempts);
      // Stable when the version did not move AND was not mid-write to begin
      // with.  Testing Odd(before) alone would accept a copy that started
      // during a write and finished after the next one began.
      if (before = after) and ((before and 1) = 0) then
         begin
         Exit;
         end;
   until attempts >= MAX_ATTEMPTS;
   // Fell through: hand back the last copy taken.  No worse than a direct field
   // read, which is what every unconverted caller still does.
end;

function ReadRadioStatus(rig: RadioPtr): RadioStatusRecord;
begin
   Result := ReadStatusSnapshot(rig, True);
end;

function ReadRadioCurrentStatus(rig: RadioPtr): RadioStatusRecord;
begin
   Result := ReadStatusSnapshot(rig, False);
end;

procedure PutAllRadiosIntoReceive;

   procedure Unkey(rig: RadioPtr; const aWhich: string);
   begin
      if (rig = nil) or (rig^.tFactoryObject = nil) then
         begin
         Exit;
         end;

      // REPORT WHAT ACTUALLY HAPPENED.  The first version logged "returning
      // radio 1 to receive" and then called SendToRadio on a radio that had
      // already been disconnected -- which drops the command SILENTLY, with no
      // open port and no error.  The log claimed the rig had been unkeyed
      // while it was still transmitting, which is worse than saying nothing
      // (NY4I exited mid-transmission and the K3 stayed keyed).
      if not rig^.tFactoryObject.IsConnected then
         begin
         logger.Warn('[Unkey] %s is already disconnected -- CANNOT return it to receive',
                     [aWhich]);
         Exit;
         end;

      try
         logger.Info('[Unkey] returning %s to receive', [aWhich]);
         rig^.tFactoryObject.Receive;
      except
         on E: Exception do
            begin
            logger.Error('[Unkey] could NOT return %s to receive: %s - %s',
                         [aWhich, E.ClassName, E.Message]);
            end;
      end;
   end;

begin
   Unkey(@Radio1, 'radio 1');
   Unkey(@Radio2, 'radio 2');
end;

function tPTTVIACATForRadio(aRadio: RadioPtr; PTTOn: boolean): boolean;

var
   ro: TFactoryRadioBase;
const

   FT890PTTOn =
      CHR($00) + CHR($00) + CHR($00) + CHR($01) + CHR($0F);
   FT890PTTOff =
      CHR($00) + CHR($00) + CHR($00) + CHR($00) + CHR($0F);

   FT817PTTOn =
      CHR($00) + CHR($00) + CHR($00) + CHR($00) + CHR($08);
   FT817PTTOff =
      CHR($00) + CHR($00) + CHR($00) + CHR($00) + CHR($88);

begin
   Result := False;
   if not tPTTViaCommand then
      begin
      logger.debug('**** tPTTVIACAT called but tPTTViaCommand is false');
      Exit;
      end;
   if NoPollDuringPTT then
      begin
      Exit;
      end;
   if aRadio <> nil then
      begin
      // The caller named a radio.  Use it.
      ro := aRadio^.tFactoryObject;
      end
   else if ActiveRadio = RadioOne then
      begin
      ro := Radio1.tFactoryObject;
      end
   else
      begin
      ro := Radio2.tFactoryObject;
      end;
   if ro <> nil then
      begin
      if PTTOn then
         begin
         ro.Transmit;
         end
      else
         begin
         ro.Receive;
         end;
      Result := true;
      end
   else
      begin
      // No factory driver: same as no radio, so PTT is not sent.
      logger.warn('[tPTTVIACAT] No radio driver -- PTT %s not sent',
                  [BoolToStr(PTTOn, True)]);
      end;

   //case IntRadioType of
//      TS140, TS440, TS450, TS480, TS570, TS590, TS690, TS850, TS870, TS890, TS940, TS950, TS990,
//      TS2000, FLEX, K2, K3, KX3, K4:
//         begin
//         if PTTOn then
//            begin
//            TempString := 'TX;';
//            DEBUGMSG('Setting Kenwood/Flex/K3/KX3/K4 to TX mode');
//            end else
//            begin
//            DEBUGMSG('Setting Kenwood/Flex/K3/KX3/K4 to RX mode');
//            TempString := 'RX;';
//            end;
//         end;
//
//      FTDX10, FTDX101, FTX1F, FT710, FT450, FT950, FT891, FT991, FT1200, FT2000,
//      FTDX3000, FTDX5000, FTDX9000:
//         begin
//         if PTTOn then
//            begin
//            TempString := 'TX1;';
//            end
//         else
//            begin
//            TempString := 'TX0;';
//            end;
//         end;
//
//      FT747GX, FT100, FT840, FT890, FT900, FT990, FT1000, FT1000MP:
//         begin
//         if PTTOn then
//            begin
//            TempString := FT890PTTOn;
//            end else
//            begin
//            TempString := FT890PTTOff;
//            end;
//         end;
//
//      FT736R, FT817, FT818, FT847 {, FT857, FT897}:
//         begin
//         if PTTOn then
//            begin
//            TempString := FT817PTTOn;
//            end else
//            begin
//            TempString := FT817PTTOff;
//            end;
//         end;
//
//      FT920, FT767:
//         begin
//         logger.debug('FT920 or FT767 do not support PTT via CAT commands');
//         Exit;
//         end;
//
//
//    IC78..IC9700:
//       begin
//          TempString := AnsiChar($FE) + CHR($FE) + CHR(Radio1.ReceiverAddress) + CHR($E0) + CHR($1C) + CHR($00) + CHR($00) + CHR($FD);
//          if PTTOn then
//             begin
//             logger.debug('Setting Icom to TX');
//             TempString[7] := AnsiChar($01);
//             end
//          else
//             begin
//             logger.debug('Setting Icom to RX');
//             end;
//          WaitAnswer := 14;
//       end;
//
//      //      IC78..IC9700, OMNI6: Exit;
//
//      Orion:
//         begin
//         if PTTOn then
//            begin
//            TempString := '*TK' + CarriageReturn;
//            end
//         else
//            begin
//            TempString := '*TU' + CarriageReturn;
//            end;
//         end;
//      else
//         begin
//         logger.warn('Radio model does not support TX/RX commands');
//         Exit;
//         end;
//      end;

   // The per-model `case` above built TempString and this sent it.  Both are
   // gone: with the case commented out nothing assigns TempString, and a local
   // Str80 is NOT initialised -- its length byte is whatever was on the stack,
   // so this line would have pushed 0..255 bytes of stack contents at the CAT
   // port and then returned True as though PTT had been keyed.
end;

// The historic form: whichever radio is ACTIVE.  Correct for anything driven
// by the operator, because that is what "the radio" means to them.
function tPTTVIACAT(PTTOn: boolean): boolean;
begin
   Result := tPTTVIACATForRadio(nil, PTTOn);
end;


//function RadioObject.CalculateIcomFilterWidth: integer;
//begin
//   Result := 0;
//   case tIcomFilterWidth of             // Not set in CFG so send current value
//      0: begin
//         if Icom_Filter_Width > 0 then     // this is the module global stored fromthe rig message in uRadioPolling
//            begin
//            Result := Icom_Filter_Width;  // n4af 4.43.4    tIcomFilterWidth
//            end
//         else
//            begin
//            Result := 1;       // Default to 1 if no CFG set and we do not have a value from the radio. We cannot send 0 to some radios as they reject the command. Others handle the zero though.
//            end;
//         end;
//      1..3: Result := tIcomFilterWidth;
//      else
//         begin
//         Result := 0;
//         end;
//      end; // case
//end;


procedure InitRadios;
var
   TempRadio: RadioPtr;
   i: integer;
const
   ra: array[1..2] of RadioPtr = (@Radio1, @Radio2);
begin
   // The three RadioSupports* typesets that were built here are retired -- the
   // radios declare rcCWByCAT / rcCWSpeedSync / rcPlayDVK themselves.  See the
   // note at their old declarations, and uTestRadioSupportsCaps for the proof
   // that the capabilities cover exactly the models these lists did.
   // Icoms whose $0F is set-only (no readable split status; the read NAKs with FA).
   // Confirmed on the IC-718 (bench + CI-V manual). Add other older Icoms here as
   // each is confirmed on the bench.
   // Icoms whose $06 set-mode takes the mode byte ONLY (no trailing filter byte).
   // The IC-718 NAKs a "06 <mode> <filter>" frame (confirmed on the bench + its
   // CI-V manual: the set-mode frame is "FE FE ra E0 06 <mode> FD"). Add other
   // older Icoms here as each is confirmed on the bench.
   // Icoms that cannot report TX/RX status over CI-V. The IC-718 NAKs the $1C read on
   // BOTH sub-command 00 and 01 and never broadcasts PTT via transceive (bench-confirmed;
   // its manual lists "1C 01" as read/write but the firmware only honors the write).
   // Skip the TX-status poll for these. Add other older Icoms as confirmed on the bench.
   // Icoms whose CW keyer speed spans 6..60 wpm. Every OTHER legacy Icom is 6..48 --
   // the long-standing mapping that matches the modern factory path; forcing 6..60 on
   // a 6..48 radio runs it ~11% slow. Only the bench-confirmed IC-718 is 6..60 so far.
   // The taxonomy sets that were initialized here (ICOMRadios, KenwoodRadios,
   // YaesuRadios, HamLibONLYRadios) are retired -- see the note at their old
   // declaration site.  The FT736R history (an unfinished driver in both trees,
   // routed to HamLib instead of carrying the stub into the factory) is
   // preserved in uTestRegistryTaxonomy alongside the pinned HamLib-only list.
   for i := 1 to 2 do
      begin
      TempRadio := ra[i];

      TempRadio.RadioNumberBits := 8;
      TempRadio.RadioStopBits  := 2;
      TempRadio.tCATPortHandle := INVALID_HANDLE_VALUE;

      TempRadio.tKeyerPortHandle := INVALID_HANDLE_VALUE;
      TempRadio.tr4w_keyer_rts_state := RtsDtr_PTT;
      TempRadio.tr4w_keyer_DTR_state := RtsDtr_CW;
      TempRadio.tr4w_cat_rts_state := RtsDtr_OFF; //CAT RTS
      TempRadio.tr4w_cat_dtr_state := RtsDtr_OFF; //CAT DTR
      TempRadio.PollingEnable := True;
      //    TempRadio.ICOM_COMMAND_PTT := #255;
      TempRadio.SpeedMemory := InitialCodeSpeed;
      TempRadio.tIcomFilterWidth := 2;
      InitializeCriticalSection(TempRadio.CATSerialLock);

      end;
   Radio1.RadioName := TC_RADIO1;
   Radio2.RadioName := TC_RADIO2;
   Radio1.active := true;
   Radio2.active := false;

   // Create CWByCATTimer

end;



initialization
   InitRadios;

finalization
   DeleteCriticalSection(Radio1.CATSerialLock);
   DeleteCriticalSection(Radio2.CATSerialLock);

end.
