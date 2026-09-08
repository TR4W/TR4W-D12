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
unit LogK1EA;
{$I ..\tr4w.inc}

{$F+}
{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,   // Config -- migrated settings
  {Dos, Crt, SlowTree,} Tree,
  uWinKey,
  (* TSerialPort -- the keyer keys on one. In the INTERFACE clause because
    K1EAKeyer.SerialPortObject is declared there. *)
  uSerialPort,
  TF,
  VC,
  BeepUnit,
  uIO,
{$IFDEF WINDOWS}
  MMSystem,     // the CW element clock -- see tCWSleep
  (* WHAT IS LEFT OF Windows, and all of it is gated at the call site:
       timeBeginPeriod / timeSetEvent   the CW element clock -- there is no
                                        counterpart, and the {$ELSE} says so
       WaitForSingleObject              on the event that clock signals
       AttachThreadInput x2             per-thread input queues, a Win32
                                        concept with nothing to map to
     Messages declared nothing. *)
  Windows,
{$ENDIF}
  (* SysUtils ENDS THE CLAUSE, UNCONDITIONALLY, and both of those matter.

    UNCONDITIONALLY, because the var block below initialises four port
    handles to feInvalidHandle -- an INTERFACE declaration, which cannot see
    the implementation clause. It used to be named only in a {$ELSE} arm,
    which is why swapping INVALID_HANDLE_VALUE for feInvalidHandle compiled
    for Linux and broke the Windows build.

    ENDING THE CLAUSE, because the alternative is a conditional holding the
    terminating semicolon -- and then the {$ELSE} arm has to name SOME unit,
    every candidate is already listed above, and FPC answers "Duplicate
    identifier". Two attempts at that failed here before this shape.

    This unit calls SysUtils.Format explicitly anyway, because TF exports a
    C-style Format of its own, so the ordering carries no hidden meaning. *)
  SysUtils;
//procedure TimerInterrupt(uTimerID, uMessage: UINT; dwUser, dw1, dw2: DWORD) stdcall;
const

  ElementLengthConstant                 = 1200;
  CWBufferSize                          = 1024 * 2 - 1;
  CommandBufferSize                     = 256; { Buffer size for data sent to serial ports }

  { Parallel port bit assignments:  (Bits are shown 0 to 7.  0 = LSB)

    Pin     Port    Bit    Description
    ---     ----    ---    -----------
     1     Base+2    0     Input/Output - Output to emitters of transistors.
     2     Base+0    0     Output - Band bit 0 or DVK Clear
     3     Base+0    1     Output - DVK #1
     4     Base+0    2     Output - DVK #2
     5     Base+0    3     Output - DVK #3 or WX0B SO2R Stereo/Mono KK1L: 6.71
     6     Base+0    4     Output - DVK #4
     7     Base+0    5     Output - Band bit 1 or DVK #5 KK1L: 6.71
     8     Base+0    6     Output - Band bit 2 or DVK #6 KK1L: 6.71
     9     Base+0    7     Output - Band bit 3 or WX0B SO2R Stereo/Mono KK1L: 6.71
    10
    11
    12     Base+1    5     Input - Dit paddle
    13     Base+1    4     Input - Dah paddle
    14     Base+2    1     Input/Output - Used for paddle pullup or relay.
    15     Base+1    3     Input - Foot switch input.
    16     Base+2    2     Input/Output - Output PTT
    17     Base+2    3     Input/Output - Output CW

    18-25                  Grounds

    None   Base+2    5     W9XT card record bit (set to 1, pulse memory, then
                           clear this bit to stop recording).

    BIT Patterns for Band bits:

    BAND   9   8   7   2      Value written to I/O port
    ----  --- --- --- ---     -------------------------
    160   lo  lo  lo  hi      $01   $00 is written if not one of these bands.
     80   lo  lo  hi  lo      $20
     40   lo  lo  hi  hi      $21
     30   lo  hi  lo  lo      $40
     20   lo  hi  lo  hi      $41
     17   lo  hi  hi  lo      $60
     15   lo  hi  hi  hi      $61
     12   hi  lo  lo  lo      $80
     10   hi  lo  lo  hi      $81
      6   hi  lo  hi  lo      $A0
      2   hi  lo  hi  hi      $A1
    222   hi  hi  lo  lo      $C0
    432   hi  hi  lo  hi      $C1
    902   hi  hi  hi  lo      $E0
    1296  hi  hi  hi  hi      $E1

  And if anyone is ever wondering about the Mem [$40:$17] bits

         1 = Right Shift
         2 = Left Shift
         4 = Control Key
         8 = Alt key pressed
        10 = Scroll Lock Active
        20 = Num lock on
        40 = Caps lock on
        80 = Insert mode on

  }

type

  FootSwitchModeType = (
    FootSwitchDisabled,
    CWGrant,
    FootSwitchF1,
    FootSwitchLastCQFreq,
    FootSwitchNextBandMap,
    FootSwitchNextDisplayedBandMap, {KK1L: 6.64}
    FootSwitchNextMultBandMap, {KK1L: 6.68}
    FootSwitchNextMultDisplayedBandMap, {KK1L: 6.68}
    FootSwitchUpdateBandMapBlinkingCall,
    FootSwitchDupecheck,
    Normal,
    QSONormal,
    QSOQuick,
    FootSwitchControlEnter,
    StartSending,
    SwapRadio
    );

  BeepType = (Beepsingle, BeepCongrats, ThreeHarmonics, PromptBeep, Warning, WakeUp, Congrats);

  CWElementRecord = record
    length: integer;
    Key: boolean;
  end;

  K1EAKeyer = object
    NumberInterruptConstant: integer;

//    CurtisModeA: boolean;
    CodeSpeed: integer;

    KeyerInitialized: boolean;

    OldInt0BVector, OldInt0CVector: Pointer;

    //wli      SerialPortConfigured: array[Serial1..Serial9] of boolean;
    (* THE KEYER'S OWN SERIAL PORTS, as objects.

      This was an array of raw THandles opened by Tree.InitializeSerialPort,
      and for years it was ALSO where the radios' CAT ports and the rotators'
      ports lived -- which is what made LOGNET's header claim serial had been
      "consolidated" into this unit. Both of those have their own TSerialPort
      now, so this array holds what its name always implied: the ports the CPU
      keyer keys on.

      nil means not open. *)
    SerialPortObject: array[TSerialPortRange] of TSerialPort;

    //    SerialPortOutputBuffer: array[Serial1..Serial9] of CharacterBuffer;
    //    SerialPortInputBuffer: array[Serial1..Serial9] of CharacterBuffer;

    //ua4wli    SerialPortDefaultDelay: array[Serial1..Serial9] of integer;
    //ua4wli    SerialPortDelay: array[Serial1..Serial9] of integer;

    //    SlowInterrupts: boolean;

    //    UseIRQs: boolean;

    //    procedure AddSerialPortCharacter(port: PortType; Character: Char);
//    procedure AddSerialPortString(port: PortType; data: Str80);

    procedure AddCharacterToCWBuffer(Character: Char);
    procedure AddStringToCWBuffer(Msg: Str160; Tone: integer);
    function BufferEmpty: boolean;
//    procedure CheckPTT;
    //    procedure CheckSerialPortReceiveData(SerialPort: PortType);
    //    procedure CheckSerialPortSendData(SerialPort: PortType);
    procedure ClearSerialPortInputBuffer(port: PortType);

    function CWStillBeingSent: boolean;
    procedure Dah;
    procedure Dat;
    function DeleteLastCharacter: boolean;
    procedure Dit;

    procedure FlushCWBuffer;
    procedure IncrementBufferEnd;
    procedure InitializeKeyer;

//    procedure PTTForceOn;
//    procedure PTTUnForce;
    procedure SetSpeed(Speed: integer {byte});

    (* SetUpSerialPort IS GONE (2026-09-07) -- it had no live caller. Its three
      references, two in LOGNET and one in LOGPACK, are all commented out and
      have been for years, so this opened nothing; it was simply one of the
      last two callers of Tree.InitializeSerialPort keeping that routine
      alive. *)
    procedure UnInitializeKeyer;
  end;

  RealTimeCWElementRecords = record
    CWSendStatus: boolean;
    ClockCount: Word;
  end;

  RealTimeMessageType = array[0..1024] of RealTimeCWElementRecords;

  RealTimeMessagePointer = ^RealTimeMessageType;

const
  FootSwitchModeTypeStringArray         : array[FootSwitchModeType] of PAnsiChar =
    (
    'DISABLED',
    'CW GRANT',
    'F1',
    'LAST CQ FREQ',
    'NEXT BANDMAP',
    'NEXT DISP BANDMAP',
    'NEXT MULT BANDMAP',
    'NEXT MULT DISP BANDMAP',
    'UPDATE BAND MAP BLINKING CALL',
    'DUPE CHECK',
    'NORMAL',
    'QSO NORMAL',
    'QSO QUICK',
    'CONTROL ENTER',
    'START SENDING',
    'SWAP RADIOS'
    );

var

{$IF CWDEBUG}
  cwDebugArray                          : array[0..1000] of integer;
{$IFEND}

  //   ii:integer;

//  tHighCWPerformance                    : boolean ;
//  TimerResolutionIsSet                  : boolean ;

  (* feInvalidHandle, NOT INVALID_HANDLE_VALUE -- same value, but only one of
    the two names exists off Windows, and these four INITIALISERS were what
    stopped this unit compiling for Linux. That in turn blocked MainUnit, so
    the compiler could not be asked what MainUnit itself still needs. *)
  (* TLPTBaseAddress, NOT THandle -- see the type's note in VC.pas. These are
    I/O port addresses, and the handle typing resolved to two DIFFERENT widths
    depending on whether a unit named LCLType. LPT_NO_PORT keeps the exact bit
    pattern feInvalidHandle had on Win32, so no comparison changes value. *)
  tPaddlePortBaseAddress                : TLPTBaseAddress = LPT_NO_PORT;
  tFootSwitchPortBaseAddress            : TLPTBaseAddress = LPT_NO_PORT;
  tRelayControlPortBaseAddress          : TLPTBaseAddress = LPT_NO_PORT;
  tActiveStereoPortBaseAddress          : TLPTBaseAddress = LPT_NO_PORT;

  tUseControlPort                       : boolean;

  TR4W_BeepThread                       : TThreadID;
  tPaddleFootSwitchThread               : TThreadID = feInvalidHandle;

  tExitFromPaddleFootSwitchThread       : boolean;
  tPTTOnCounter                         : Cardinal;
  PaddlePTTOn                           : boolean;
  TR4W_BeepThreadID                     : TThreadID;
  tPaddleThreadID                       : Cardinal;
  tFlashQDThreadID                      : Cardinal;

  tCW_Event                             : Cardinal;
  tCWPaddle_Event                       : Cardinal;
  tDVP_Event                            : Cardinal;
//  tWaitForNextCharEvent                 : Cardinal;

  tDVPTimerEventID                      : Cardinal;
  tExitFromDVPThread                    : boolean;
  //   tNetEvent                       : Cardinal;

  ActiveDVKPort                         : PortType; //���� ������
  ActiveFootSwitchPort                  : PortType {= NoPort};
//  ActiveKeyerPort                       : PortType {= NoPort};
//  tActiveKeyerHandle                    : HWND = INVALID_HANDLE_VALUE;

  ActivePaddlePort                      : PortType {= NoPort};
  ActiveRadio                           : RadioType = RadioOne;

  InactiveRadio                         : RadioType = RadioTwo; {KK1L: 6.73}
  ActiveStereoPort                      : PortType {= NoPort}; {KK1L: 6.71}

  BeepEnable                            : boolean = False; //N4AF performance change
  BeepFreq                              : integer = 1200;

//  CountsSinceLastCW                     : LONGINT = 0;
  CPUKeyer                              : K1EAKeyer =
    (
//    CurtisModeA: False;
    CodeSpeed: 35;
    KeyerInitialized: False;
    (* nil, once for every port in the range. *)
    SerialPortObject: (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    );

  DVKDelay                              : integer;
  DVKPortAddress                        : Word;
  DVPOn                                 : boolean;
  DVKClearAllBits                       : Byte = $80;
  DVKClearMessageBits                   : Byte = $81;
  ElementLength                         : integer;

  EnableSixDVKMessages                  : boolean = True;

  FootSwitchDebug                       : boolean;
  FootSwitchMode                        : FootSwitchModeType {= FootSwitchDisabled};
  tFootSwitchPressed                    : boolean;

  MonitorTone                           : integer = 700;


  PaddleActive                          : boolean;
  PaddleBug                             : boolean;
  PaddleBugDahBeingSent                 : boolean;
  PaddlePTTOffTimerCount                : integer;
  PaddlePTTOffTimer                     : integer;
  tPaddleElementLength                  : Cardinal;

  PortBeingUsed                         : PortType {= NoPort};
  // Default TRUE (NY4I, 2026-08-09).  This selects the PTT INTERFACE -- key by
  // CAT command, or key by the hardware line above -- and defaulting it FALSE
  // meant the CAT path silently did nothing: tPTTVIACAT logs one DEBUG line
  // and returns False, and every caller in the program ignored that result.
  // The switch is kept because the choice is real (CI-V bus contention during
  // transmit, amplifier sequencing off Config.PTTTurnOnDelay, radios with no CAT
  // transmit command at all) -- only the default changes, so a station that
  // wants the hardware line still turns it off.
  //
  // NOTE this moves the default ONLY.  TR4W writes every CommandsArray key
  // back to tr4w.ini, so an existing station already has an explicit
  // 'PTT VIA COMMANDS=' line and the file still wins.  This changes fresh
  // installs.
  tr4w_PTTStartTime                     : QWord;   // GetTickCount64
  { QWord: MainUnit already wrote GetTickCount64 into this, which a DWORD
    silently truncated. Every writer uses the 64-bit clock now. }
  tElapsedTimeFromLastQSO               : QWord;

//  tPTTStatus                            : PTTStatusType = PTT_OFF;
  {
    tr4w_lpt1_address                     : word = $378;
    tr4w_lpt2_address                     : word = $278;
    tr4w_lpt3_address                     : word = $3BC;
  }


  Radio1SerialInvert                    : boolean;
  Radio2SerialInvert                    : boolean;
//  RadioDebugWrite                       : file;

  RealTimeCWMessageArrayType            : array[0..9] of RealTimeMessagePointer;
  RealTimeCWMessagePlaying              : boolean;
  RealTimeCWMessageRecording            : boolean;
  REalTimeCWMessageActive               : integer; { 0 through 9 }
  RealTimeCWMessageAddress              : integer; { 0 through 1024 }

  RelayControlPort                      : PortType {= NoPort};
  RememberCodeSpeed                     : integer;
  RITEnable                             : boolean = True;

  SerialInvert                          : boolean;
  ShiftKeyEnable                        : boolean = True;
  StereoControlPin                      : integer = 9;
  StereoPinState                        : boolean;

  TalkDebugWrite                        : file;
  TuningWithDits                        : boolean;
  //  Trace                                 : boolean;
  Tuning                                : boolean;


  ActiveBeep                            : BeepType;
  CWMessageToNetwork                    : string[CWMessageToNetworkLength];

procedure DoABeep(TypeOfBeep: BeepType);

procedure DVKEnableWrite;
procedure DVKDisableWrite;
function DVKMessagePlaying: boolean;
procedure OutputBandInfo(BaseAddress: TLPTBaseAddress {ParallelPort: PortType}; Band: BandType; Mode: ModeType);
procedure SetDVKDelay(Delay: integer);
procedure SetRelayForActiveRadio(Radio: RadioType);
procedure SetStereoPin(PinNumber: integer; PinSet: boolean); {KK1L: 6.71}
procedure StartDVK(MemorySwitch: integer);

procedure SendCWBufferStart;
procedure CWThreadProc;
procedure tDoABeep;
procedure AutoCQTick;
procedure tCWSleep(millsec, myEvent: Cardinal);
procedure tPaddleFootSwitchThreadProc;

procedure tSetPaddleElementLength;
function DisplayByte(b: Byte): string;
procedure tFootSwitchProcedure;
function tGetPortType(port: PortType): PortInterface;
//procedure testF(uTimerID, uMessage: UINT; dwUser, dw1, dw2: DWORD) stdcall;
procedure BackToInactiveRadioAfterQSO;
(* tSetPriorityClass IS DELETED (2026-09-08). Its ENTIRE BODY was commented
  out -- Windows.SetPriorityClass behind an `if tHighCWPerformance` that was
  also commented -- and it had NO CALLER: both call sites are commented out
  as well. A no-op whose only live content was a DWORD parameter. *)

procedure TurnOnActivePort;
procedure tStartAutoCQ;
function tStartAutoCallTerminate(idAttach: DWORD): boolean;

var
  DoingPaddle                           : boolean;
  tDoingFootSwitchEnable                : boolean;

  CWBufferStart                         : integer;
  CWBufferEnd                           : integer;
  tWaitForNextChar                      : boolean;
//  tAllowIncrementCWBufferStart          : boolean = True;
implementation

uses
   uAppTimers,   (* StartAppTimer / StopAppTimer -- LCL TTimers, not SetTimer *)
  (* FIRST IN THE CLAUSE, deliberately. Every other unit here then takes
    precedence over it, so adding SysUtils to a unit this old cannot quietly
    re-point an existing unqualified call at a different routine. What this
    unit wants from it -- Format, Exception, FreeAndNil -- is written
    SysUtils.Format explicitly, because TF also exports a Format and it is a
    C-style one taking PChars.

    NOT LISTED HERE ANY MORE. It moved to the INTERFACE clause (see the note
    there -- the port-handle var block needs it), and FPC rejects a unit
    named in both: "Duplicate identifier SYSUTILS". The precedence intent
    above survives unchanged, because an implementation clause is searched
    BEFORE the interface one, so every unit listed here still takes
    precedence over SysUtils. *)
  uMainForm,   { QueueStartSendingKey -- the call field is a control }
  uProcessCommand,
  uTelnet,
  LOGSUBS2,
  uRadioRegistry,
  uRadioPolling,
  LogCW,
  MainUnit,
  LogWind,
  LogStuff,
  LOGSUBS1,
  LogRadio,
  Classes;   // MainThreadID -- Delphi puts it in System, FPC in Classes

const
  ParallelOutputPullupOffset            = 5;
  ParallelOutputAddressOffset           = 2;
  ParallelInputAddressOffset            = 1;

type
  SendStatusType = (NothingBeingSent, DitBeingSent, DahBeingSent);

  CWBufferType = array[0..CWBufferSize] of CWElementRecord;
  CWBufferPtr = ^CWBufferType;

var

  CWBuffer                              : CWBufferPtr;
  CWBufferAvailable                     : boolean;

  CWElementLength                       : integer;

  CWLPT1Image                           : Byte = $08;
  CWLPT2Image                           : Byte = $08;
  CWLPT3Image                           : Byte = $08;

  DahMemory                             : boolean;
  DitMemory                             : boolean;
  DelayCount                            : LONGINT; { Used for Wait procedure }
  DoingDVK                              : boolean;

  DVKTimeOut                            : integer;

  FootSwitchState                       : boolean;
  FootSwitchCount                       : integer = 5;

  FrameEscapeFound                      : boolean;

  LPT1Image                             : Byte;
  LPT2Image                             : Byte;
  LPT3Image                             : Byte;

  LastFootSwitchStatus                  : boolean;

  ModemCharacterSentDelayCount          : integer;
  ModemDelayCount                       : integer;
  ModemReceiveMessage                   : Str80;
  ModemPortAddress                      : Word;
//  ModemTestAddress                      : Word;

//  NumberInterruptsConstant              : integer;
//  NumberInterrupts                      : integer;
  OldInt08Vector                        : Pointer;

  PTTDelayCount                         : integer; { When non zero, indicates that
  PTT turn on delay is in progress }

//  PTTAsserted                           : boolean; { Indicates that the PTT signal is asserted.  Comes on Config.PTTTurnOnDelay before CW starts.  }

  PTTFootSwitch                         : boolean; { Indicates that the footswitch wants the PTT
  to be on. }

//  PTTForcedOn                           : boolean = False; { Indicates that someone wants the PTT to stay  on until they turn it off. }

 //    Regs:                 Registers;
  RememberRIT                           : boolean;

  SendStatus                            : SendStatusType;
  SendingADah                           : boolean;
  SerialPort                            : PortType;

function DisplayByte(b: Byte): string;

const
  HexChars                              : array[0..$F] of Char = '0123456789ABCDEF';
begin
  Result := HexChars[b shr 4] + HexChars[b and $F];
end;

procedure DisplayWord(w: Word);

const
  HexChars                              : array[0..$F] of Char = '0123456789ABCDEF';
begin
  Write(HexChars[Hi(w) shr 4],
    HexChars[Hi(w) and $F],
    HexChars[Lo(w) shr 4],
    HexChars[Lo(w) and $F]);
end;


procedure StartDVK(MemorySwitch: integer);

var
  Image                                 : Byte;

begin
  if not DVPOn then Exit;

  case MemorySwitch of
    0:
      begin
        {           IF (Radio1BandOutputPort <> ActiveDVKPort) AND
                      (Radio2BandOutputPort <> ActiveDVKPort) THEN
                         }Image := $1 { Abort message }
        {              ELSE
                          Exit;
                  }
      end;

    1: Image := $2; { Memory one   }
    2: Image := $4; { Memory two   }
    3: Image := $8; { Memory three }
    4: Image := $10; { Memory four  }
    {5: IF EnableSixDVKMessages THEN Image := $20 ELSE Exit; {KK1L: 6.71}{KK1L: 6.72 added IF}{KK1L: 6.73}
    {6: IF EnableSixDVKMessages THEN Image := $40 ELSE Exit; {KK1L: 6.71}{KK1L: 6.72 added IF}{KK1L: 6.73}
    5: Image := $20; { Memory five  } {KK1L: 6.73}
    6: Image := $40; { Memory six   } {KK1L: 6.73}
  else Exit;
  end;

  {WLI}
  {    CASE ActiveDVKPort OF

          Parallel1: BEGIN
                     LPT1Image := (LPT1Image AND DVKClearMessageBits) OR Image;  //KK1L: 6.71 Was $E1 KK1L: 6.72 ClearBits
                     Port [LPT1BaseAddress] := LPT1Image;
                     END;

          Parallel2: BEGIN
                     LPT2Image := (LPT2Image AND DVKClearMessageBits) OR Image;  //KK1L: 6.71 Was $E1  KK1L: 6.72 ClearBits
                     Port [LPT2BaseAddress] := LPT2Image;
                     END;

          Parallel3: BEGIN
                     LPT3Image := (LPT3Image AND DVKClearMessageBits) OR Image;  //KK1L: 6.71 Was $E1  //KK1L: 6.72 ClearBits
                     Port [LPT3BaseAddress] := LPT3Image;
                     END;

          ELSE       Exit;
          END;}

  DVKTimeOut := 40;
end;

{KK1L: 6.71 Started coding for the stereo pin stuff}

procedure SetStereoPin(PinNumber: integer; PinSet: boolean);

var
  //  BaseAddress                      : Word;
  TempByte                              : Byte;
  Mask                                  : TBitSet;
begin
  if tActiveStereoPortBaseAddress = LPT_NO_PORT then Exit;

  case PinNumber of
    5: Mask := bsBIT3; { Pin five, bit 3 }
    9: Mask := bsBIT7; { Pin nine, bit 7 }
  else Exit;
  end;

  TempByte := GetPortByte(tActiveStereoPortBaseAddress, otData);

//  if PinSet then
//    TempByte := TempByte or Mask
//  else
//    TempByte := TempByte and (not Mask);

  DriverBitOperation(TempByte, Mask, TBitOperation(PinSet));

  SetPortByte(tActiveStereoPortBaseAddress, otData, TempByte);

end;

(* DRIVE THE LINE THE OPERATOR NOMINATED FOR CW.

  aKeyDown is what the KEY is doing; whether that asserts or releases the line
  is SerialInvert's business, for a keying interface wired the other way up.

  The old code said this by arithmetic on a Win32 escape CODE -- CLRDTR is 6
  and SETDTR is 5, so `dec` turned a release into an assert, and `inc` in the
  other routine turned an assert into a release. It worked and it explained
  nothing; `aKeyDown xor SerialInvert` is the same truth table with the meaning
  left in.

  RTS WINS IF BOTH LINES ARE MARKED CW, because the original tested DTR first
  and then let the RTS test overwrite the answer. That is almost certainly a
  configuration nobody has, but it is behaviour and it is preserved. *)
procedure DriveCWLine(const aRadio: RadioPtr; const aKeyDown: boolean);
var
  useDTR, useRTS: boolean;
  assert: boolean;
begin
  if (aRadio = nil) or (aRadio^.tKeyerSerialPort = nil) then
     begin
     Exit;
     end;

  useDTR := aRadio^.tr4w_keyer_DTR_state = RtsDtr_CW;
  useRTS := aRadio^.tr4w_keyer_rts_state = RtsDtr_CW;
  if useRTS then
     begin
     useDTR := False;
     end;
  if not (useDTR or useRTS) then
     begin
     Exit;
     end;

  assert := aKeyDown xor SerialInvert;
  if useDTR then
     begin
     aRadio^.tKeyerSerialPort.SetDTR(assert);
     end
  else
     begin
     aRadio^.tKeyerSerialPort.SetRTS(assert);
     end;
end;

procedure TurnOffActivePort;

var
  TempByte                              : Byte;
begin
   if ActiveRadioPtr.tKeyerPort in SerialPorts then
      begin
      DriveCWLine(ActiveRadioPtr, False);
      end
  else

    if ActiveRadioPtr.tKeyerPort in [Parallel1..Parallel3] then
       begin
       if ActiveRadioPtr.tKeyerPortHandle = LPT_NO_PORT then Exit;
       TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
       DriverBitOperation(TempByte, CW_SIGNAL, boSet1);
         {17PIN}
 //      LPTTempByte := LPTTempByte or BIT3;
         {1PIN}
 //      LPTTempByte := LPTTempByte xor BIT0;
       SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);
       end;
end;

procedure DVKEnableWrite;

{ This procedure will turn on the fifth bit of the third LPT port which
  will set the DVK up to be written into. }

begin
  //{wli}
  {    CASE ActiveDVKPort OF

          Parallel1:
              BEGIN
              CWLPT1Image := CWLPT1Image OR  $20;
              Port [LPT1BaseAddress + ParallelOutputAddressOffset] := CWLPT1Image;
              END;

          Parallel2:
              BEGIN
              CWLPT2Image := CWLPT2Image OR  $20;
              Port [LPT2BaseAddress + ParallelOutputAddressOffset] := CWLPT2Image;
              END;

          Parallel3:
              BEGIN
              CWLPT3Image := CWLPT3Image OR  $20;
              Port [LPT3BaseAddress + ParallelOutputAddressOffset] := CWLPT3Image;
              END;

          END;
     }
end;

procedure DVKDisableWrite;

{ This procedure will stop the recording process on the DVK. }

begin
  {    CASE ActiveDVKPort OF

          Parallel1:
              BEGIN
              CWLPT1Image := CWLPT1Image AND $DF;
              Port [LPT1BaseAddress + ParallelOutputAddressOffset] := CWLPT1Image;
              END;

          Parallel2:
              BEGIN
              CWLPT2Image := CWLPT2Image AND $DF;
              Port [LPT2BaseAddress + ParallelOutputAddressOffset] := CWLPT2Image;
              END;

          Parallel3:
              BEGIN
              CWLPT3Image := CWLPT3Image AND $DF;
              Port [LPT3BaseAddress + ParallelOutputAddressOffset] := CWLPT3Image;
              END;

          END;
     }
end;

procedure TurnOnActivePort;

var
  { PTT will always be on if Config.PTTEnable. }
  TempByte                              : Byte;
begin
  if ActiveRadioPtr.tKeyerPort in SerialPorts then
     begin
     DriveCWLine(ActiveRadioPtr, True);
     end
  else
     begin
     if ActiveRadioPtr.tKeyerPortHandle = feInvalidHandle then
        begin
        logger.debug('[TurnOnActivePort] Exiting early: no LPT keyer port');
        Exit;
        end;
     if ActiveRadioPtr.tKeyerPort in [Parallel1..Parallel3] then
        begin
        TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
        DriverBitOperation(TempByte, CW_SIGNAL, boSet0);
            {17PIN}
  //      LPTTempByte := LPTTempByte and (not BIT3);
            {1PIN}
  //      LPTTempByte := LPTTempByte xor BIT0;
        SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);
        end;
     end;

end;

procedure SetRelayForActiveRadio(Radio: RadioType);
var
  TempByte                              : Byte;
  TempRadio                             : RadioType;
  Operation                             : TBitOperation;
begin
  {
    if (ActiveKeyerPort >= Parallel1) and (ActiveKeyerPort <= Parallel3) then
      if tPTTStatus = ptt_ON then
        LPTTempByte := 197
      else
        LPTTempByte := 193;
    if ActiveRadioPtr.tr4w_KeyerPortHandle = feInvalidHandle then Exit;
    SetPortByte(ActiveRadioPtr.tr4w_KeyerPortHandle + 2, LPTTempByte);
  }
  if tRelayControlPortBaseAddress = LPT_NO_PORT then Exit;

  TempRadio := Radio;

  if Config.SwapRadioRelaySense then
    if Radio = RadioOne then
       begin
       TempRadio := RadioTwo
       end
    else
       begin
       TempRadio := RadioOne;
       end;

  if TempRadio = RadioOne then
     begin
     Operation := boSet0;
     end;
  if TempRadio = RadioTwo then
     begin
     Operation := boSet1;
     end;

  TempByte := GetPortByte(tRelayControlPortBaseAddress, otControl);

  DriverBitOperation(TempByte, RELAY_SIGNAL, Operation);

  SetPortByte(tRelayControlPortBaseAddress, otControl, TempByte);
end;
{
procedure K1EAKeyer.PTTForceOn;

begin
//  PTTForcedOn := True;
  TurnOffActivePort;
  //   Frm.PTT . Color := clnavy;
end;
}
{
procedure K1EAKeyer.PTTUnForce;

begin
//  PTTForcedOn := False;
  //   Frm.PTT . Color := clbtnface;
end;
}

procedure K1EAKeyer.IncrementBufferEnd;

begin
  CWBufferEnd := (CWBufferEnd + 1) mod CWBufferSize;
//  tAllowIncrementCWBufferStart := True;
end;
{
procedure K1EAKeyer.CheckPTT;

begin
  if not PTTAsserted then
  begin
    PTTAsserted := True;
    if not PTTForcedOn then PTTDelayCount := Config.PTTTurnOnDelay;
    TurnOffActivePort;
  end;
end;
}

procedure K1EAKeyer.Dit;

begin

  //   SpeakerBeep(Config.CWTone, 90);
  //   Sleep(30);
  if not CWBufferAvailable then
     begin
     New(CWBuffer);
     CWBufferAvailable := True;
     end;

//  CheckPTT;

  CWBuffer^[CWBufferEnd].length := 10;
  CWBuffer^[CWBufferEnd].Key := True;
  IncrementBufferEnd;

  CWBuffer^[CWBufferEnd].length := 10;
  CWBuffer^[CWBufferEnd].Key := False;
  IncrementBufferEnd;

//  CheckPTT;

end;

procedure K1EAKeyer.Dat;

begin
  if not CWBufferAvailable then
     begin
     New(CWBuffer);
     CWBufferAvailable := True;
     end;
{
  if not PTTAsserted then
  begin
    PTTAsserted := True;
    PTTDelayCount := Config.PTTTurnOnDelay;
    TurnOffActivePort;
  end;
}
  CWBuffer^[CWBufferEnd].length := 45;
  CWBuffer^[CWBufferEnd].Key := True;

  IncrementBufferEnd;

  CWBuffer^[CWBufferEnd].length := 10;
  CWBuffer^[CWBufferEnd].Key := False;
  IncrementBufferEnd;
{
  if not PTTAsserted then
  begin
    PTTAsserted := True;
    PTTDelayCount := Config.PTTTurnOnDelay;
    TurnOffActivePort;
  end;
}
end;

procedure K1EAKeyer.Dah;

begin

  //   SpeakerBeep(Config.CWTone, 270);
  //   Sleep(30);

  if not CWBufferAvailable then
     begin
     New(CWBuffer);
     CWBufferAvailable := True;
     end;
{
  if not PTTAsserted then
  begin
    PTTAsserted := True;
    PTTDelayCount := Config.PTTTurnOnDelay;
    TurnOffActivePort;
  end;
}

  CWBuffer^[CWBufferEnd].length := Config.tDitDahRatio * 10;
  CWBuffer^[CWBufferEnd].Key := True;

  IncrementBufferEnd;

  CWBuffer^[CWBufferEnd].length := 10;
  CWBuffer^[CWBufferEnd].Key := False;
  IncrementBufferEnd;
{
  if not PTTAsserted then
  begin
    PTTAsserted := True;
    PTTDelayCount := Config.PTTTurnOnDelay;
    TurnOffActivePort;
  end;
}
end;

function K1EAKeyer.DeleteLastCharacter: boolean;

{ This routine will remove the last character off the keying buffer.  If
  it fouund a letter to remove, it will return TRUE. }

var
  BufferPointer                         : integer;

begin
  if CWBufferEnd <> CWBufferStart then
     begin
     BufferPointer := CWBufferEnd - 1
     end
  else
     begin
     DeleteLastCharacter := False;
     Exit;
     end;

  while BufferPointer <> CWBufferStart do
     begin
     dec(BufferPointer);

     if BufferPointer < 0 then
        begin
        BufferPointer := BufferPointer + CWBufferSize;
        end;

     if (CWBuffer^[BufferPointer].length = 20) and (CWBuffer^[BufferPointer].Key = False) then
        begin
        CWBufferEnd := (BufferPointer + 1) mod CWBufferSize;
        DeleteLastCharacter := True;
        Exit;
        end;
     end;

  DeleteLastCharacter := False;
end;

procedure K1EAKeyer.ClearSerialPortInputBuffer(port: PortType);

begin
  //  SerialPortInputBuffer[Port].ClearBuffer;
end;

procedure K1EAKeyer.AddCharacterToCWBuffer(Character: Char);

begin
{
  if wkActive then
  begin
    wkAddCWMessageToInternalBuffer(UpCase(Character));
    exit;
  end;
}
  logger.debug('[CWThreadProc] AddCharacterToCWBuffer %s',[Character]);

  case UpCase(Character) of
    'A':
      begin
        Dit;
        Dah;
      end;
    'B':
      begin
        Dah;
        Dit;
        Dit;
        Dit;
      end;
    'C':
      begin
        Dah;
        Dit;
        Dah;
        Dit;
      end;
    'D':
      begin
        Dah;
        Dit;
        Dit;
      end;
    'E':
      begin
        Dit;
      end;
    'F':
      begin
        Dit;
        Dit;
        Dah;
        Dit;
      end;
    'G':
      begin
        Dah;
        Dah;
        Dit;
      end;
    'H':
      begin
        Dit;
        Dit;
        Dit;
        Dit;
      end;
    'I':
      begin
        Dit;
        Dit;
      end;
    'J':
      begin
        Dit;
        Dah;
        Dah;
        Dah;
      end;
    'K':
      begin
        Dah;
        Dit;
        Dah;
      end;
    'L':
      begin
        Dit;
        Dah;
        Dit;
        Dit;
      end;
    'M':
      begin
        Dah;
        Dah;
      end;
    'N':
      begin
        Dah;
        Dit;
      end;
    'O':
      begin
        Dah;
        Dah;
        Dah;
      end;
    'P':
      begin
        Dit;
        Dah;
        Dah;
        Dit;
      end;
    'Q':
      begin
        Dah;
        Dah;
        Dit;
        Dah;
      end;
    'R':
      begin
        Dit;
        Dah;
        Dit;
      end;
    'S':
      begin
        Dit;
        Dit;
        Dit;
      end;
    'T':
      begin
        Dah;
      end;
    'U':
      begin
        Dit;
        Dit;
        Dah;
      end;
    'V':
      begin
        Dit;
        Dit;
        Dit;
        Dah;
      end;
    'W':
      begin
        Dit;
        Dah;
        Dah;
      end;
    'X':
      begin
        Dah;
        Dit;
        Dit;
        Dah;
      end;
    'Y':
      begin
        Dah;
        Dit;
        Dah;
        Dah;
      end;
    'Z':
      begin
        Dah;
        Dah;
        Dit;
        Dit;
      end;
    '0':
      begin
        Dah;
        Dah;
        Dah;
        Dah;
        Dah;
      end;
    '1':
      begin
        Dit;
        Dah;
        Dah;
        Dah;
        Dah;
      end;
    '2':
      begin
        Dit;
        Dit;
        Dah;
        Dah;
        Dah;
      end;
    '3':
      begin
        Dit;
        Dit;
        Dit;
        Dah;
        Dah;
      end;
    '4':
      begin
        Dit;
        Dit;
        Dit;
        Dit;
        Dah;
      end;
    '5':
      begin
        Dit;
        Dit;
        Dit;
        Dit;
        Dit;
      end;
    '6':
      begin
        Dah;
        Dit;
        Dit;
        Dit;
        Dit;
      end;
    '7':
      begin
        Dah;
        Dah;
        Dit;
        Dit;
        Dit;
      end;
    '8':
      begin
        Dah;
        Dah;
        Dah;
        Dit;
        Dit;
      end;
    '9':
      begin
        Dah;
        Dah;
        Dah;
        Dah;
        Dit;
      end;
    '.':
      begin
        Dit;
        Dah;
        Dit;
        Dah;
        Dit;
        Dah;
      end;
    ',':
      begin
        Dah;
        Dah;
        Dit;
        Dit;
        Dah;
        Dah;
      end;
    '?':
      begin
        Dit;
        Dit;
        Dah;
        Dah;
        Dit;
        Dit;
      end;
    '/':
      begin
        Dah;
        Dit;
        Dit;
        Dah;
        Dit;
      end;
    '+':
      begin
        Dit;
        Dah;
        Dit;
        Dah;
        Dit;
      end;
    '<':
      begin
        Dit;
        Dit;
        Dit;
        Dah;
        Dit;
        Dah;
      end;
    '=':
      begin
        Dah;
        Dit;
        Dit;
        Dit;
        Dah;
      end;
    '!':
      begin
        Dit;
        Dit;
        Dit;
        Dah;
        Dit;
      end;

    '&':
      begin
        Exit;
        {
                Dit;
                Dah;
                Dit;
                Dit;
                Dit;
        }
      end;

    '-': Dat;

    CHR(197), CHR(229), //wli
      CHR(134), CHR(143):
      begin
        Dit;
        Dah;
        Dah;
        Dit;
        Dah;
      end; {KK1L: NOTE This is A-ring!!}
    CHR(196), CHR(228), //wli
      CHR(132), CHR(142):
      begin
        Dit;
        Dah;
        Dit;
        Dah;
      end; {KK1L: NOTE This is A-umlaut!}
    CHR(214), CHR(246), //wli
      CHR(148), CHR(153):
      begin
        Dah;
        Dah;
        Dah;
        Dit;
      end; {KK1L: NOTE This is O-umlaut!}

    ControlE:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 22;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlDash:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 26;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlK:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 30;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlN:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 34;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlO:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 38;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlP:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 6;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlQ:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 8;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlBackSlash:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlV:
      begin
        CWBuffer^[CWBufferEnd].length := 12;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlL:
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 14;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
        CWBuffer^[CWBufferEnd].length := 10;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlF: { Speed up command }
      begin
        CWBuffer^[CWBufferEnd].length := 0;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
      end;

    ControlS: { Slow down command }
      begin
        CWBuffer^[CWBufferEnd].length := 0;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlX: { Decrease Config.weight command }
      begin
        CWBuffer^[CWBufferEnd].length := -1;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    ControlY: { Increase Config.weight command }
      begin
        CWBuffer^[CWBufferEnd].length := -1;
        CWBuffer^[CWBufferEnd].Key := True;
        IncrementBufferEnd;
      end;

    ' ':
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 30;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

    '^':
      begin
//        CheckPTT;
        CWBuffer^[CWBufferEnd].length := 15;
        CWBuffer^[CWBufferEnd].Key := False;
        IncrementBufferEnd;
      end;

  end;

  if (Character > ' ') and
    (Character <> ' ') and
    (Character <> StartSendingNowKey) and
    (Character <> '^') then
     begin
     CWBuffer^[CWBufferEnd].length := 20;
     CWBuffer^[CWBufferEnd].Key := False;
     IncrementBufferEnd;
     end;
end;

procedure K1EAKeyer.AddStringToCWBuffer(Msg: Str160; Tone: integer);

var
  Character                             : integer;
  CommandState                          : boolean;

begin

  { Next two lines to fix bug where somtimes paddle speed gets ignored }

 //    form1.SendCW(tone,msg);
 //    exit;

//  PaddlePTTOffTimer := 0;
//  PaddleActive := False;

  if not CWBufferAvailable then
     begin
     New(CWBuffer);
     CWBufferAvailable := True;
     end;

  MonitorTone := Tone;
{
  if ActiveKeyerPort <> PortBeingUsed then
  begin
    FlushCWBuffer;
    PortBeingUsed := ActiveKeyerPort;
  end;
}
  CommandState := False;

  if length(Msg) > 0 then
     begin
     for Character := 1 to length(Msg) do
        begin
        if CommandState then
           begin
           CWBuffer^[CWBufferEnd].length := Ord('0') - Ord(Msg[Character]);
           IncrementBufferEnd;
           CommandState := False;
           Continue;
           end;

        case UpCase(Msg[Character]) of
          ControlLeftBracket: CommandState := True;

        else
          AddCharacterToCWBuffer(Char(UpCase(Msg[Character])));
        end;

        end;
     end;

end;

function K1EAKeyer.BufferEmpty: boolean;

begin
  BufferEmpty := CWBufferStart = CWBufferEnd - 0 {������� -1};
end;

function K1EAKeyer.CWStillBeingSent: boolean;
begin
  Result := CWThreadID <> 0;
  // CWStillBeingSent := PTTAsserted;
end;

procedure K1EAKeyer.FlushCWBuffer;
begin
//  GetExitCodeThread(CWThreadHandle, lpExitCode);
//  Windows.TerminateThread(CATWTR^.tRadioInterfaceThreadHandle, lpExitCode);

  //  CWBufferStart := CWBufferEnd; ������ ������ ���-�� �� �������� ������ ���� � �����
{
  I := 0;
  if CWBufferEnd > 0
    then I := 1;
  CWBufferStart := CWBufferEnd - I;
}
//  ExitFromCWThread := True;
  CWBufferStart := CWBufferEnd;
  if CWThreadID <> 0 then
     begin
     dec(CWBufferStart);
     if CWBufferStart = -1 then
        begin
        CWBufferStart := CWBufferSize;
        end;
     end;
  logger.debug('[CWThreadProc] CWBufferStart := CWBuferEnd');
  {$IF tDebugMode}
  AddStringToTelnetConsole('CWBufferStart := CWBufferEnd', tstReceived);
{$IFEND}
//  tAllowIncrementCWBufferStart := False;

//  CWBufferStart := 0;
//  CWBufferEnd := 0;
//if CWThreadID <> 0 then  tCWBufferCleared := True;

  if (MonitorTone <> 0) {and (BeepCount = 0)} then NoSound;

  PTTDelayCount := 0;
//  PTTAsserted := False;

  TurnOffActivePort;
  PortBeingUsed := NoPort;
  // The WinKeyer buffer is deliberately NOT cleared from here.  This is the CPU
  // (port) keyer, and commanding another keyer's hardware meant that
  // LogCW.FlushCWBuffer -- which broadcasts to EVERY keyer -- issued five
  // blocking WinKeyer writes on every function key even when CW was going by
  // CAT and the WinKeyer was sending nothing (task #22).  The clear now lives
  // with the device, in TCWKeyerWinKey.Flush, guarded by wkHasPendingOutput.
end;

procedure K1EAKeyer.SetSpeed(Speed: integer {byte});

begin
  if Speed > 0 then
     begin
     CodeSpeed := Speed;
     ElementLength := round(ElementLengthConstant / Speed);
 //    PaddlePTTOffTimerCount := ElementLength * Config.PaddlePTTHoldCount;
     end;
end;

procedure DoABeep(TypeOfBeep: BeepType);

begin
  if not BeepEnable then Exit;
  ActiveBeep := TypeOfBeep;
  logger.Info('Calling tCreateThread from DoABeep');
  TR4W_BeepThread := tCreateThread(@tDoABeep, TR4W_BeepThreadID);
  logger.Info('Created Beep thread with threadid of %d',[TR4W_BeepThreadID] );
  (* Issue #997: asm SetThreadPriority -> Pascal call. The old `push eax` pushed
    a stale handle (clobbered by the preceding logger.Info), so this never
    applied; now set it on the real handle. BEHAVIOR CHANGE: beep thread now
    runs IDLE.

    ThreadSetPriority IS THE RTL'S, AND ON WINDOWS IT IS THE SAME CALL
    (2026-09-08). FPC's SysThreadSetPriority passes the handle straight to
    SetThreadPriority -- rtl/win/systhrd.inc:334 -- so this is byte-identical
    here, and it exists on every target instead of one.

    -15 IS THREAD_PRIORITY_IDLE. The RTL documents its range as {-15..+15,
    0=normal}, which is the Win32 scale unchanged, so the value is the constant
    rather than a translation of it. Off Windows the call may simply fail
    without privileges; a beep that runs at normal priority is the right
    outcome there, and it is not worth a gate. *)
  ThreadSetPriority(TR4W_BeepThread, -15);

end;

function DVKMessagePlaying: boolean;

begin
  DVKMessagePlaying := DVKDelay > 0;
end;

procedure SetDVKDelay(Delay: integer);

begin
  //  if CPUKeyer.SlowInterrupts then
  //    DVKDelay := round(Delay / 3.36)
  //  else
  DVKDelay := round(Delay / 1.68);

end;

(* OPEN THE KEYER PORT A RADIO NAMES, and leave its lines where the operator
  asked for them.

  ONE ROUTINE, TWO CALLERS. Radio1's and Radio2's arms of InitializeKeyer were
  the same forty lines written out twice, differing only in which radio record
  they read -- so a fix to one reached the other only if somebody noticed. The
  Yaesu stop-bits warning, the open, the idle line states: all of it, twice.

  THE PORT OBJECT IS SHARED, keyed by port, and that is deliberate here: both
  radios may nominate the same keyer port and it can only be opened once. (That
  is a keyer arrangement and not a rotator one -- two rotator controllers cannot
  share a line, and uRotatorControl says so.)

  THE SETTINGS ARE THE ONES Tree.InitializeSerialPort USED, exactly: 8 data
  bits, no parity, two stop bits only when the radio asks for 2 (0 meant one,
  and the Yaesu check below is why 0 is a value anyone passes), and DTR/RTS
  control enabled in the DCB followed immediately by a release of both lines.
  That last pair is what OpenRaw(..., True, True) then SetDTR/SetRTS(False)
  reproduces: enabled, but idle. *)
procedure OpenKeyerPortFor(const aRadio: RadioPtr);
var
  port: TSerialPort;
  stopBits: Byte;
begin
  if (aRadio = nil) or (not (aRadio^.tKeyerPort in SerialPorts)) then
     begin
     Exit;
     end;

  port := CPUKeyer.SerialPortObject[aRadio^.tKeyerPort];

  if (port = nil) or (not port.IsOpen) then
     begin
     if logger.IsErrorEnabled then
        begin
        if (uRadioRegistry.ManufacturerOf(aRadio^.RadioModel) = 'Yaesu') and
           (aRadio^.RadioKeyerStopBits <> 0) then
           begin
           logger.Error('***** Keyer stop bits not set to 0 for a Yaesu radio');
           end;
        end;

     if port = nil then
        begin
        (* Ord(PortType) IS the COM number, the same rule the radios, the
          rotators and the WinKeyer all use. *)
        port := TSerialPort.Create(SysUtils.Format('COM%d', [Ord(aRadio^.tKeyerPort)]));
        CPUKeyer.SerialPortObject[aRadio^.tKeyerPort] := port;
        end;

     if aRadio^.RadioKeyerStopBits = 2 then
        begin
        stopBits := 2;
        end
     else
        begin
        stopBits := 1;
        end;

     try
        port.OpenRaw(aRadio^.RadioBaudRate, 8, stopBits, 0, True, True);
        (* Both lines released, as InitializeSerialPort did on every open.
          Whatever the operator nominated below then asserts what it wants. *)
        port.SetDTR(False);
        port.SetRTS(False);
     except
        on E: Exception do
           begin
           logger.Warn('[Keyer] %s is not available for keying: %s',
                       [string(PortTypeSA[aRadio^.tKeyerPort]), E.Message]);
           Exit;
           end;
     end;
     end;

  if not port.IsOpen then
     begin
     Exit;
     end;

  aRadio^.tKeyerSerialPort := port;

  if aRadio^.tr4w_keyer_DTR_state = RtsDtr_ON then
     begin
     port.SetDTR(True);
     end;
  if aRadio^.tr4w_keyer_DTR_state = RtsDtr_OFF then
     begin
     port.SetDTR(False);
     end;
  if aRadio^.tr4w_keyer_rts_state = RtsDtr_ON then
     begin
     port.SetRTS(True);
     end;
  if aRadio^.tr4w_keyer_rts_state = RtsDtr_OFF then
     begin
     port.SetRTS(False);
     end;

  CPUKeyer.KeyerInitialized := True;
end;

procedure K1EAKeyer.InitializeKeyer;

begin

  DoingDVK := ActiveDVKPort <> NoPort;

  DoingPaddle := ActivePaddlePort <> NoPort;

//  PaddlePTTOffTimerCount := ElementLength * Config.PaddlePTTHoldCount;

//  if BeepCount = 0 then NoSound;

  TurnOffActivePort;

//  NumberInterrupts := 0;
  CWElementLength := 0;
  CWBufferStart := 0;
  CWBufferEnd := 0;
//  PTTAsserted := False;
  PTTDelayCount := 0;
//  TurnOffActivePort;

  (* THE SAME FORTY LINES STOOD HERE FOR EACH RADIO. See OpenKeyerPortFor. *)
  OpenKeyerPortFor(@Radio1);

  if Radio1.tKeyerPort in [Parallel1..Parallel3] then
     begin
     OpenLPT(Radio1.tKeyerPortHandle, Radio1.tKeyerPort);
 //    PTTOff;
     KeyerInitialized := True;
     end;

  OpenKeyerPortFor(@Radio2);

  if (Radio2.tKeyerPort >= Parallel1) and (Radio2.tKeyerPort <= Parallel3) then
     begin
     OpenLPT(Radio2.tKeyerPortHandle, Radio2.tKeyerPort);
 //    PTTOff;
     KeyerInitialized := True;
     end;

  ElementLength := round(ElementLengthConstant / CodeSpeed);

end;

procedure K1EAKeyer.UnInitializeKeyer;

var
  SerialPort                            : PortType;

begin
  (* IT NEVER ACTUALLY CLOSED ANYTHING. The old body set the array slot to
    INVALID_HANDLE_VALUE and THEN called CloseHandle on the slot it had just
    overwritten -- so every serial keyer port TR4W opened stayed open for the
    life of the process, and the operator found out by not being able to
    reopen it. Two statements in the wrong order, invisible in review because
    both name the right thing. *)
  for SerialPort := Serial1 to Serial20 do
     begin
     FreeAndNil(CPUKeyer.SerialPortObject[SerialPort]);
     end;
  Radio1.tKeyerSerialPort := nil;
  Radio2.tKeyerSerialPort := nil;

//  DestroyDlPortio;

end;

procedure OutputBandInfo(BaseAddress: TLPTBaseAddress; Band: BandType; Mode: ModeType);

{ Outputs the appropriate bits to the parallel port }

var
  Image                                 : Byte;

const
   BandInfoArray                         : array[BandType] of Byte = ($01, $20, $21, $41, $61, $81, $40, $60, $80, $A0, $A1, $C0, $C1, $E0, $E1, $00, $00, $00, $00, $00, $00, $00, $00);
begin
  if BaseAddress = LPT_NO_PORT then Exit;
  Image := BandInfoArray[Band];
  if Mode = Phone then
     begin
     Image := Image or (1 shl 1);
     end;
  SetPortByte(BaseAddress, otData, Image);
end;

procedure SendCWBufferStart;
begin
  CallWinKeyDown := False;  //4.52.4
  if CWBuffer^[CWBufferStart].length = 0 then // Bump speed command
     begin
     if CWBuffer^[CWBufferStart].Key then
        begin
        if CPUKeyer.CodeSpeed < 98 then
           begin
           inc(CPUKeyer.CodeSpeed);
           end;
        if (CPUKeyer.CodeSpeed > 25) and (CPUKeyer.CodeSpeed < 98) then
           begin
           inc(CPUKeyer.CodeSpeed);
           end;
        if (CPUKeyer.CodeSpeed > 35) and (CPUKeyer.CodeSpeed < 98) then
           begin
           inc(CPUKeyer.CodeSpeed);
           end;
        if (CPUKeyer.CodeSpeed > 45) and (CPUKeyer.CodeSpeed < 98) then
           begin
           inc(CPUKeyer.CodeSpeed);
           end;
        end
     else
        begin
        if CPUKeyer.CodeSpeed > 49 then
           begin
           dec(CPUKeyer.CodeSpeed);
           end;
        if CPUKeyer.CodeSpeed > 38 then
           begin
           dec(CPUKeyer.CodeSpeed);
           end;
        if CPUKeyer.CodeSpeed > 27 then
           begin
           dec(CPUKeyer.CodeSpeed);
           end;
        if CPUKeyer.CodeSpeed > 2 then
           begin
           dec(CPUKeyer.CodeSpeed);
           end;
        end;
     ElementLength := round(ElementLengthConstant / CPUKeyer.CodeSpeed);
     end

  else
    if CWBuffer^[CWBufferStart].length < 0 then // Command mode
       begin
       case CWBuffer^[CWBufferStart].length of
         -1:
           if CWBuffer^[CWBufferStart].Key then
              begin
              Config.Weight := Config.Weight + 0.03
              end
           else
              begin
              Config.Weight := Config.Weight - 0.03;
              end;

         -2: InvertBoolean(Config.FarnsworthEnable);
         -3: Config.FarnsworthSpeed := 25;
         -4: Config.FarnsworthSpeed := 35;
         -5: Config.FarnsworthSpeed := 45;
         -6: Config.FarnsworthSpeed := 55;
         -7: Config.FarnsworthSpeed := 75;
         -8: Config.FarnsworthSpeed := 95;
       end;
       end
    else
       begin
       if CWBuffer^[CWBufferStart].Key then
          begin
          TurnOnActivePort;
          CWElementLength := round(Config.Weight * (CWBuffer^[CWBufferStart].length * ElementLength) / 10.0);

          (* NO SIDETONE IS GENERATED HERE ANY MORE.  NY4I, 2026-09-08:
            "We do not need a sidetone generated by the program at all. It is
            notoriously unreliable on windows and the sidetone comes from the
            radio."

            What stood here was ntBeep(Config.CWTone, CWElementLength) --
            \Device\Beep by IOCTL, which on Windows 10/11 usually does
            nothing at all because beep.sys is disabled and there is no PC
            speaker, and failed silently when it did.

            THE ELEMENT TIMING IS UNAFFECTED, and that is the thing worth
            checking before believing this change is safe: ntBeep issued a
            DeviceIoControl and returned immediately -- it never waited out the
            element.  tCWSleep below has always been the only thing timing a
            dit or a dah, and it is untouched.

            Config.CWTone survives as the CW-ENABLED FLAG it had already become
            (logddx and MainUnit test it against 0), which is a separate
            tangle -- see BENCH_QUEUE.md. *)
          tCWSleep(CWElementLength, tCW_Event);
          end
       else
          begin
          SendingADah := False;
          TurnOffActivePort;
          if Config.FarnsworthEnable and (CWBuffer^[CWBufferStart].length >= 15) and (CodeSpeed < Config.FarnsworthSpeed) then
             begin
             if CWBuffer^[CWBufferStart].length = 15 then
                begin
                CWBuffer^[CWBufferStart].length := CWBuffer^[CWBufferStart].length + (Config.FarnsworthSpeed - CodeSpeed)
                end
             else
                begin
                CWBuffer^[CWBufferStart].length := CWBuffer^[CWBufferStart].length + ((Config.FarnsworthSpeed - CodeSpeed) * 2);
                end;
             end;
          CWElementLength := round(((CWBuffer^[CWBufferStart].length * ElementLength) / 10.0) - ((Config.Weight - 1.0) * 2 * ElementLength));
          tCWSleep(CWElementLength, tCW_Event);
          end;
       end;
{$IF tDebugMode}
//  Windows.SetWindowTextA(InsertWindowHandle, inttopchar({CWBufferEnd - }CWBufferStart));
{$IFEND}
end;

procedure CWThreadProc;
label
  SendNext, ExitAndPTTof;
var
  b                                     : boolean;
begin
//tCWSleep(15, tCW_Event);

{$IFDEF WINDOWS}
  (* Ask Windows for 1 ms scheduler resolution for the life of this thread.
    There is no counterpart elsewhere -- Linux and macOS simply do not let a
    process ask -- so off Windows this is nothing, and tCWSleep's accuracy is
    whatever the platform gives. *)
  timeBeginPeriod(1);
{$ENDIF}
  Sleep(20);

//  tSetPriorityClass(REALTIME_PRIORITY_CLASS);

  b := False;
//  Sleep(5);

//  tCWSleep(1, tCW_Event);
  SendNext:
  if CWBufferStart <> CWBufferEnd then
     begin
     SendCWBufferStart;
     if CWBufferStart <> CWBufferEnd then
        begin
        CWBufferStart := (CWBufferStart + 1) mod CWBufferSize;
        goto SendNext;
        end;

     end;

  if b = False then
    if tStartAutoCallTerminate(CWThreadID) then
       begin
       b := True;
       goto SendNext;
       end;
//  if tAutoSendMode then goto SendNext;

  if tAutoSendMode or tWaitForNextChar then
     begin
     Sleep(10);
     goto SendNext;
     end;

  ExitAndPTTof:
  logger.debug('[CWThreadProc] ExitAndPTTof');
{$IF tDebugMode}
  AddStringToTelnetConsole('ExitAndPTTof', tstReceived);
{$IFEND}
  CWBufferStart := CWBufferEnd;
  if not PaddlePTTOn then
     begin
     PTTOff;
     end;

//  ExitFromCWThread := False;
   SetSpeed(DisplayedCodeSpeed);   // 4.50.1
  tStartAutoCQ;  // It appears we go here everytime we finish a CW buffer no matter if we just CQ'ed or not ny4i  4.44.5
{$IF OZCR2008}
  CWMessageToNetwork := '';
{$IFEND}

//  if TwoRadioState = SendingExchange then CheckTwoRadioState(ContactDone);

//  tSetPriorityClass(NORMAL_PRIORITY_CLASS);
{$IFDEF WINDOWS}
  timeEndPeriod(1);
{$ENDIF}

  (* CloseThread, NOT CloseHandle -- the RTL's own name for exactly this, and
    on Windows it reaches the same API. It returns a dword rather than a
    boolean, hence the <> 0 test: the RTL follows CloseHandle's convention of
    non-zero for success. *)
  if CloseThread(CWThreadHandle) = 0 then
     begin
     ShowSysErrorMessage('CW');
     end;

  CWThreadID := 0;

  BackToInactiveRadioAfterQSO;

end;

function tStartAutoCallTerminate(idAttach: DWORD): boolean;
begin
  Result := False;
  if Config.AutoCallTerminate = True then
    if ExchangeHasBeenSent = False then
      if tAutoSendMode then
        if ControlAMode = False then
           begin
           (* WINDOWS-ONLY, AND THERE IS NOTHING FOR AN {$ELSE} TO DO.
             AttachThreadInput joins two threads' input queues so keyboard
             state and focus are shared -- a Win32 concept, on a widget set
             that does not have per-thread input queues at all. Off Windows
             the auto-send return simply happens without it. *)
{$IFDEF WINDOWS}
           AttachThreadInput(idAttach, MainThreadID, True);
{$ENDIF}
           ReturnInCQOpMode;
           Result := True;
           end;
end;

procedure tStartAutoCQ;
begin
   logger.trace('[CWThreadProc] In tStartAutoCQ');
{$IF tDebugMode}
  AddStringToTelnetConsole('In tStartAutoCQ', tstReceived);
{$IFEND}
  if tAutoCQMode = True then
     begin
     StartAppTimer(atAutoCQ, AutoCQDelayTime, @AutoCQTick);
     end;

end;

procedure tDoABeep;
var
  OldBeat                               : integer;
begin

  case ActiveBeep of
    ThreeHarmonics:
      begin

        SpeakerBeep(300, 60);
        SpeakerBeep(450, 150);
        SpeakerBeep(550, 60);
        SpeakerBeep(350, 150);

      end;

    Warning:
      begin
        SpeakerBeep(1500, 150);
      end;

    Beepsingle:
      begin
        SpeakerBeep(2000, 75);
      end;

    PromptBeep:
      begin
        SpeakerBeep(2000, 100);
        SpeakerBeep(2000, 40);
        SpeakerBeep(2000, 120);
      end;

    BeepCongrats:
      begin
        SpeakerBeep(500, 80);
        SpeakerBeep(400, 80);
        SpeakerBeep(300, 80);
        SpeakerBeep(600, 80);
        SpeakerBeep(800, 80);
      end;

    WakeUp:
      begin

        SixteenthNote(NoteC);
        SixteenthNote(NoteC);
        SixteenthNote(NoteF);
        SixteenthNote(NoteC);
        SixteenthNote(NoteF);
        SixteenthNote(NoteA);
        SixteenthNote(NoteF);
        SixteenthNote(NoNote);
        SixteenthNote(NoteF);
        SixteenthNote(NoteF);
        SixteenthNote(NoteA);
        SixteenthNote(NoteF);
        SixteenthNote(NoteA);
        SixteenthNote(NoteHiC);
        SixteenthNote(NoteA);
        SixteenthNote(NoNote);
        SixteenthNote(NoteF);
        SixteenthNote(NoteA);
        EigthNote(NoteHiC);
        SixteenthNote(NoteA);
        SixteenthNote(NoteF);
        EigthNote(NoteC);
        SixteenthNote(NoteC);
        SixteenthNote(NoteC);
        EigthNote(NoteF);
        SixteenthNote(NoteF);
        SixteenthNote(NoteF);
        Sleep(10);
        EigthNote(NoteF);
      end;

    Congrats:
      begin
        OldBeat := Beat;
        Beat := 400;
        SixteenthNote(NoteC);
        SixteenthNote(NoteE);
        SixteenthNote(NoteG);
        EigthNote(NoteHiC);
        SixteenthNote(NoteG);
        EigthNote(NoteHiC);
        Beat := OldBeat;
      end;

  end;

end;

(* THE AUTO-CQ REPEAT FIRED. A plain procedure now, not a Win32 TIMERPROC:
  it never read any of the four arguments Windows passed it, and a TNotifyEvent
  cannot be handed a callback of the wrong shape. *)
procedure AutoCQTick;
var
  TempChar                              : Char;
begin
  (* ONE SHOT. The Win32 timer was killed on entry and re-armed by whoever
    wanted another CQ; that is unchanged. *)
  StopAppTimer(atAutoCQ);
  if OpMode = SearchAndPounceOpMode then
     begin
     TryKillAutoCQ;
     Exit;
     end;
  TempChar := AutoCQMemory;
  if (AutoCQMemory = F1) and RandomCQMode then
     begin
     TempChar := Char(Random(4) + 112);
     end;
  if GetCQMemoryString(ActiveMode, TempChar) = '' then
     begin
     TempChar := AutoCQMemory;
     end;
  //   Windows.SetWindowTextA(VC.InsertWindowHandle, inttopchar(ord(TempChar)));
  tDisplayAutoCQStatus;
  SendFunctionKeyMessage(TempChar, OpMode);
end;

procedure tCWSleep(millsec, myEvent: Cardinal);
var
  t                                     : Cardinal;
begin
  if millsec = 0 then Exit;
{$IF tDebugMode}
  Start := GetCPU;
{$IFEND}

  (* THIS IS THE CW ELEMENT CLOCK, and it is the most timing-sensitive thing
    in the program: millsec is one dit or one dah.

    Windows gets a winmm one-shot with 1 ms resolution and waits on the event.
    The `else` arm below is the EXISTING fallback for when winmm refuses, and
    off Windows it is the only arm -- so CW there is timed by Sleep, whose
    granularity is the scheduler's, not a millisecond.

    THAT IS NOT GOOD ENOUGH TO KEY WITH and it is not pretending to be: it is
    a compiling placeholder so the rest of the port can proceed.  The real
    answer is a per-platform high-resolution timer, assessed with measurements
    in docs/PLATFORM_CLOCK_ABSTRACTION.md part 2 -- which is also where the
    Apple Silicon reference lives. *)
{$IFDEF WINDOWS}
  t := timeSetEvent(millsec, 1, TFNTimeCallBack(myEvent), 0, TIME_ONESHOT + TIME_CALLBACK_EVENT_SET);
{$ELSE}
  t := 0;
{$ENDIF}
  if t <> 0 then
     begin
     (* GATED WITH THE CALL THAT MAKES IT REACHABLE. t is the timeSetEvent
       handle, which the {$ELSE} above sets to 0 off Windows, so this branch
       cannot run there -- but it still has to COMPILE, and myEvent is a raw
       Win32 event handle created in uProgramMain. The Sleep below is what
       actually happens off Windows, and the note above says what that costs. *)
{$IFDEF WINDOWS}
     WaitForSingleObject(myEvent, INFINITE);
{$ENDIF}
     end
  else
     begin
     Sleep(millsec);
     end;

{$IF tDebugMode}
//  cw_tick_array[cw_tick] := (GetCPU - Start) {div 17000000};
//  inc(cw_tick);
{$IFEND}

end;

(* SAID ONCE, NOT ONCE PER POLL.

  USE CONTROL PORT asks for the paddle and foot switch to come off the radio's
  serial control port. TR4W cannot do that: the legacy CAT port was the only
  route and nothing has opened it since the factory took over the radios on
  2026-08-02. The operator gets one line saying so instead of a silent
  nothing -- or, as before this change, random keying from an uninitialised
  status word. *)
var
   GControlPortWarned: boolean = False;

procedure ReportControlPortUnavailable;
begin
   if GControlPortWarned then
      begin
      Exit;
      end;
   GControlPortWarned := True;
   logger.Error('USE CONTROL PORT is set, but the paddle and foot switch cannot be '
                + 'read from the radio''s control port: TR4W has no control port open. '
                + 'Use an LPT port, or a keyer that provides them.');
end;

procedure tPaddleFootSwitchThreadProc;
label
  Start;
var
  TempByte                              : Byte;
  TempCardinal                          : Cardinal;
  DitContact                            : boolean;
  DahContact                            : boolean;
  CWElementLength                       : Cardinal;
begin
  tDispalyPaddleAndFootSwitchStatus;

  tPTTOnCounter := 0;
  PaddlePTTOn := False;

  Start:
  CWElementLength := tPaddleElementLength;
//  sleep(100);

  if PaddlePTTOn = False then
     begin
     Sleep(CWElementLength)
     end
  else
     begin
     tCWSleep(CWElementLength, tCWPaddle_Event);
     end;

  if tDoingFootSwitchEnable then
    if FootSwitchMode <> FootSwitchDisabled then
       begin
       if not tUseControlPort then
          begin
             {LPT}
         TempByte := GetPortByte(tFootSwitchPortBaseAddress, otState);
 //        Windows.SetWindowTextA(wh[mweUserInfo], inttopchar(TempByte));
         if TempByte and 8 = 8 then
            begin
            if tFootSwitchPressed = True then
              if FootSwitchMode = Normal then
                 begin
                 PTTOff;
                 end;
            tFootSwitchPressed := False;
            end;
         if TempByte and 8 = 0 then
           if tFootSwitchPressed = False then
              begin
              tFootSwitchPressed := True;
              tFootSwitchProcedure;
              end;

       end
       else
          begin
          (* THE CONTROL-PORT ARM IS GONE (2026-09-08), AND IT WAS WORSE
            THAN DEAD.

            It read the modem status lines with
            GetCommModemStatus(Radio1.tCATPortHandle, TempCardinal). That
            handle was never opened by anything -- see the note in logradio --
            so the call failed and left TempCardinal UNINITIALISED, and the
            tests below it were made against whatever was on the stack. A foot
            switch or paddle that fired at random is exactly what that
            produces.

            Reported once per run rather than per poll: this sits inside the
            keyer's timing loop, so a log line here would flood the file. *)
          ReportControlPortUnavailable;
          end;
       end;

  if DoingPaddle then
    if ActiveMode = CW then
       begin

       DitContact := False;
       DahContact := False;
       if not tUseControlPort then
          begin
          if tPaddlePortBaseAddress <> LPT_NO_PORT then
             begin
             TempByte := GetPortByte(tPaddlePortBaseAddress, otState);
   //          Windows.SetWindowTextA(wh[mweUserInfo], inttopchar(TempByte));
             if TempByte and 32 = 0 then
                begin
                DitContact := True;
                end;
             if TempByte and 16 = 0 then
                begin
                DahContact := True;
                end;
             end;
          end
       else
          begin
          (* THE CONTROL-PORT ARM IS GONE (2026-09-08), AND IT WAS WORSE
            THAN DEAD.

            It read the modem status lines with
            GetCommModemStatus(Radio1.tCATPortHandle, TempCardinal). That
            handle was never opened by anything -- see the note in logradio --
            so the call failed and left TempCardinal UNINITIALISED, and the
            tests below it were made against whatever was on the stack. A foot
            switch or paddle that fired at random is exactly what that
            produces.

            Reported once per run rather than per poll: this sits inside the
            keyer's timing loop, so a log line here would flood the file. *)
          ReportControlPortUnavailable;
          end;
       if (DitContact or DahContact) then
          begin
          tPTTOnCounter := 0;
          CWBufferStart := CWBufferEnd;
          if PaddlePTTOn = False then
             begin
             PaddlePTTOn := True;
             if not CheckPTTLockout then
                begin
                PTTOn;
                end;
             end;
          TurnOnActivePort;

          if DahContact then
             begin
             CWElementLength := tPaddleElementLength * 3;
             end;
          if Config.SwapPaddles then
             begin
             if DahContact then
                begin
                CWElementLength := tPaddleElementLength;
                end;
             if DitContact then
                begin
                CWElementLength := tPaddleElementLength * 3;
                end;
             end;

          (* The paddle sidetone, removed with the CW-buffer one above -- see
            that note.  Same reasoning, same guarantee about the timing:
            tCWSleep below did and does the waiting. *)

              //        Sleep(CWElementLength);
          tCWSleep(CWElementLength, tCWPaddle_Event);

          TurnOffActivePort;
          end
       else
          begin
          if PaddlePTTOn then
             begin
             inc(tPTTOnCounter);
             end;
          end;
       if PaddlePTTOn then if tPTTOnCounter = Config.PaddlePTTHoldCount then
                              begin
                              PaddlePTTOn := False;
                              if CWBufferStart = CWBufferEnd then
                                 begin
                                 PTTOff;
                                 end;
                              end;
       end;

  if tExitFromPaddleFootSwitchThread = False then
     begin
     goto Start;
     end;

end;

procedure tSetPaddleElementLength;
var
  TempSpeed                             : Cardinal;
begin

  TempSpeed := Config.PaddleSpeed;
  if TempSpeed = 0 then
     begin
     TempSpeed := CodeSpeed;
     end;
  tPaddleElementLength := round(ElementLengthConstant / TempSpeed);
end;

procedure tFootSwitchProcedure;
begin
  {
  FootSwitchModeType = (
      CWGrant,
  -    FootSwitchDisabled,
  -    FootSwitchF1,
      FootSwitchLastCQFreq,
  -    FootSwitchNextBandMap,
  -    FootSwitchNextDisplayedBandMap,
  -    FootSwitchNextMultBandMap,
  -    FootSwitchNextMultDisplayedBandMap,
  -    FootSwitchUpdateBandMapBlinkingCall,
      FootSwitchDupecheck,
  -    Normal,
  -    QSONormal,
      QSOQuick,
  -    FootSwitchControlEnter,
  -    StartSending,
      SwapRadio);
  }
  case FootSwitchMode of

    FootSwitchF1:
      begin
        if OpMode = CQOpMode then
           begin
           SendFunctionKeyMessage(F1, CQOpMode)
           end
        else
           begin
           ProcessExchangeFunctionKey(F1);
           end;
      end;

    //    FootSwitchDisabled:      FootSwitchPressed := False;

    FootSwitchLastCQFreq:
      begin
        scLASTCQFREQ;
      end;

    FootSwitchUpdateBandMapBlinkingCall: UpdateBlinkingBandMapCall;

    FootSwitchDupecheck: DupeCheckOnInactiveRadio(False);

    StartSending:
      if ActiveMode = CW then
         begin
         QueueStartSendingKey(AnsiChar(StartSendingNowKey));
         end;

    SwapRadio:
      begin
        SwapRadios;
        //        Str(SpeedMemory[InactiveRadio], SpeedString); {KK1L: 6.73 Used to use a variable CheckSpeed}
      end;

    Normal:
      begin
        if not CheckPTTLockout then
           begin
           PTTOn;
           end;
        //        if TwoRadioState <> TwoRadiosDisabled then          CheckTwoRadioState(FootswitchWasPressed);

        //        FootSwitchPressed := False;
      end;
    QSONormal, FootSwitchControlEnter:
      begin
{$IFDEF WINDOWS}
        { See the note on the other AttachThreadInput, in
          tStartAutoCallTerminate. }
        AttachThreadInput(tPaddleThreadID, MainThreadID, True);
{$ENDIF}
        if FootSwitchMode = QSONormal then
           begin
           ProcessReturn
           end
        else
           begin
           ProcessMenu(menu_ctrl_logqsowithoutcw);
           end;
      end;

  end;

end;

function tGetPortType(port: PortType): PortInterface;
begin
  Result := NoInterface;
  if port in SerialPorts then
     begin
     Result := SerialInterface
     end
  else
    if port in [Parallel1..Parallel3] then
       begin
       Result := ParallelInterface;
       end;
end;

procedure BackToInactiveRadioAfterQSO;
begin
  if (ActiveRadioPtr^.tTwoRadioMode = TR3) then // ny4i Issue 149 This activeradioptr.cwbycat would cause the rigs to swap all the time for CWBC or (activeradioptr.cwbycat) then
     begin
     tClearDupeInfoCall;
     ActiveRadioPtr^.tTwoRadioMode := TR0;
     InActiveRadioPtr^.tTwoRadioMode := TR0;
     SwapRadios;
     SetOpMode(CQOpMode);
      if Config.AltDCQEnable then  // 4.89.3
      if OnDeckCall = '' then
         begin
         SendCrypticMessage(GetCQMemoryString(ActiveMode, F1))
         end
      else
         begin
         PutCallToCallWindow(OnDeckCall);
         end;
     end;

//  if ActiveRadioPtr^.tTwoRadioMode = TR2 then
//   if (GetCQMemoryString(InActiveRadioPtr^.ModeMemory, AltF3) <> '') {and (CalledFromCQMode) } then
//      SendCrypticMessage(ControlA + GetCQMemoryString(InActiveRadioPtr^.ModeMemory, AltF3));

end;

end.
