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
 }unit LogCW;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,
utils_text,
  MMSystem,
  uWinKey,
  uYCCCSO2R,
  uMixW,
  uMMTTY,
  TF,
  VC,
  LogNet,
  LOGDVP, {SlowTree, }
  Sysutils,
  Tree,
  Windows,
  LogWind, {Dos,}
  LogRadio,
  LogK1EA,
  classes
  ;

type
  KeyStatusType = (NormalKeys, AltKeys, ControlKeys);

type
  SendBufferType = array[0..255] of Char;

  MessagePointer = ^ShortString;
  CharPointer = ^Char;
  FunctionKeyMemoryArray = array[CW..Phone, F1..AltF12] of MessagePointer;

  CWMessageCommandType = (NoCWCommand,
    CWCommandControlEnter,
    CWCommandCQMode,
    CWCommandSAPMode,
    CWCommandQSY);

var
  CorrectedCallMessage                  : Str40; // = '} OK %';
  CQExchange                            : Str40;
  CQExchangeNameKnown                   : Str40;
  QSLMessage                            : Str40 { = 'TU \ TEST'};
  QSOBeforeMessage                      : Str40 { = ' SRI QSO B4 TU \ TEST'};
  QuickQSLMessage1                      : Str40 { = 'TU'};
  RepeatSearchAndPounceExchange         : Str40;
  SearchAndPounceExchange               : Str40;
  TailEndMessage                        : Str40 { = 'R'};
  PrevNr                                : Str10;   // 4.53.2
  CorrectedCallPhoneMessage             : ShortString {= 'CORCALL.WAV'};
  CQPhoneExchange                       : ShortString {= 'CQEXCHNG.WAV'};
  CQPhoneExchangeNameKnown              : ShortString {= 'CQEXNAME.WAV'};
  QSLPhoneMessage                       : ShortString {= 'QSL.WAV'};
  QSOBeforePhoneMessage                 : ShortString {= 'QSOB4.WAV'};
  QuickQSLPhoneMessage                  : ShortString {= 'QUICKQSL.WAV'};
  RepeatSearchAndPouncePhoneExchange    : ShortString {= 'RPTSPEX.WAV'};
  SearchAndPouncePhoneExchange          : ShortString {= 'SAPEXCHG.WAV'};
  TailEndPhoneMessage                   : ShortString {= 'TAILEND.WAV'};

  AutoCQDelayTime                       : integer = 3000;
  AutoCQMemory                          : Char = CHR(112);
  CWMessageCommand                      : CWMessageCommandType {= NoCWCommand};
  CQMemory                              : FunctionKeyMemoryArray;
  EXMemory                              : FunctionKeyMemoryArray;

  CQCaptionMemory                       : FunctionKeyMemoryArray;
  EXCaptionMemory                       : FunctionKeyMemoryArray;

  KeyerBeingUsed                        : KeyerType {= NoKeyer};
  KeyersSwapped                         : boolean;
  KeyPressedMemory                      : Char { = CHR(0)};

  LastRSTSent                           : Word;

  NeedToSetCQMode                       : boolean; {KK1L: 6.69 This variable is used to leap around some AutoS&PMode code.}

  QuickQSLMessage2                      : Str40 { = 'TU'}; // 4.88.1

//  RadioOneKeyerOutputPort          : PortType = NoPort;
//  RadioTwoKeyerOutputPort          : PortType = NoPort;

  RememberCWSpeed                       : integer;

  //  RTTYTransmissionStarted          : boolean;

  SendingOnRadioOne                     : boolean; {KK1L: 6.72 Moved from local (IMPLIMENTATION section) for use in LOGSUBS}
  SendingOnRadioTwo                     : boolean; {KK1L: 6.72 Moved from local (IMPLIMENTATION section) for use in LOGSUBS}

  Short0                                : AnsiChar = 'T';
  Short1                                : AnsiChar = 'A';
  Short2                                : AnsiChar = '2';
  Short9                                : AnsiChar = 'N';

procedure AddStringToBuffer(Msg: Str160; Tone: integer);
procedure BeginCWCapture;   // '=' repeat-last-CW-message
procedure EndCWCapture;
procedure AppendConfigFile(AddedLine: Str160);
function CalculateElements(sMsg: string): integer;
//procedure ClearPTTForceOn;
procedure CWInit;
function CWStillBeingSent: boolean;

function DeleteLastCharacter: boolean;
procedure DVKRecordMessage(MemoryString: Str20);
function ElementLength(dots: integer; dashes: integer): integer;
procedure FinishRTTYTransmission(Msg: Str160);
procedure FlushCWBuffer;
// `fromWhere` is DIAGNOSTIC ONLY and defaulted, so every existing call site
// compiles unchanged.  It exists because a bench run on 2026-08-01 showed CW
// being cut off 3.1 s into an 8.98 s message with NO operator action -- NY4I
// confirmed he pressed only two mouse buttons -- and this procedure has a dozen
// callers, several of which fire on display state rather than a keypress.  Tag
// the suspicious ones so the log names the culprit instead of us guessing.
procedure FlushCWBufferAndClearPTT(const fromWhere: string = '');

procedure InitializeKeyer;
procedure LoadElements(sl: TStringList);
procedure SendStringAndStop(Msg: Str160);
procedure SetSpeed(Speed: integer {byte});
procedure SetPTT;
procedure UnInitializeKeyer;

function GetCQMemoryString(Mode: ModeType; Key: Char): ShortString; {KK1L: 6.73 Added mode}
function GetEXMemoryString(Mode: ModeType; Key: Char): ShortString; {KK1L: 6.73 Added mode}

procedure MemoryProgram;

//procedure PTTForceOn;
function QSONumberString(QSONumber: integer): string;
function TimeString: Str10;

procedure SendKeyboardInput;
procedure SetCQMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString {Str80});
procedure SetEXMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString {Str80});

procedure SetCQCaptionMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString);
procedure SetEXCaptionMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString);

procedure SetNewCodeSpeed;
procedure SetUpToSendOnActiveRadio;
procedure SetUpToSendOnInactiveRadio;

procedure SetCWState(Enable, DisplayPrompt: boolean);
procedure ToggleCW(DisplayPrompt: boolean);
procedure ShowOtherMemoryStatus;

procedure ShowCQFunctionKeyStatus;
procedure ShowExFunctionKeyStatus;
procedure DisplayCrypticCWMenu;
procedure DisplayCrypticSSBMenu;

var
  KeyStatus                             : KeyStatusType;
  slElements                            : TStringList;
  // '=' repeat-last-CW-message: BeginCWCapture/EndCWCapture bracket one message;
  // AddStringToBuffer appends the actual expanded characters it sends into
  // CWBurstAccum, which EndCWCapture promotes to LastCWMessage for replay.
  CWCaptureActive                       : boolean = False;
  CWBurstAccum                          : Str160 = '';
  LastCWMessage                         : Str160 = '';
implementation

uses
  LogStuff,
  uTelnet,
  CFGCMD,
  uNet,
  // CW keyer factory: the four adapters are listed so their initialization
  // sections run (they self-install into the KeyerXXX slots).  This unit is
  // now a FACADE over uCWKeyerBase.ActiveCWKeyer rather than a place where the
  // 4-way keyer dispatch is re-implemented per procedure.
  uCWKeyerBase,
  uCWKeyerCAT,
  uCWKeyerWinKey,
  uCWKeyerYCCC,
  uCWKeyerCPU,
  MainUnit; {KK1L: 6.72 Allows use of SniffOutControlCharacters}

type
  SendData = record
    SendTime: integer; { Time in milliseconds }
    SendState: boolean; { True for key on }
  end;

  {SendingOnRadioOne: BOOLEAN; {KK1L: 6.72 Moved to global (INTERFACE section) for use in LOGSUBS}
  {SendingOnRadioTwo: BOOLEAN; {KK1L: 6.72 Moved to global (INTERFACE section) for use in LOGSUBS}

//   NEWCW                           : TCW;


procedure BeginCWCapture;
begin
   CWCaptureActive := True;
   CWBurstAccum := '';
end;

procedure EndCWCapture;
begin
   CWCaptureActive := False;
   if CWBurstAccum <> '' then
      begin
      LastCWMessage := CWBurstAccum;
      end;
end;

procedure AddStringToBuffer(Msg: Str160; Tone: integer);
var
  i                                     : integer;
  //localMsg                              : string;
begin

   //localMsg                                               := Format('Adding %s to CW Buffer', [Msg]);
   //AddStringToTelnetConsole(PChar(localMsg),tstAlert);
   logger.Debug('[AddStringToBuffer] Adding (%s) to CW Buffer',[Msg]);
   // 'ctrl-=' repeat-last-CW-message: record the actual expanded text being sent
   // (skip the CWByCAT control sentinel, which is not on-air content).
   if CWCaptureActive and (Msg <> CWByCATBufferTerminator) then
      begin
      CWBurstAccum := CWBurstAccum + Msg;
      end;
   if ( (Msg = CWByCATBufferTerminator) or
        ((Config.CWEnable and CWEnabled and IsCWByCATActive )) ) then   // ny4i 4.44.5    + Issue 111
      begin
      // Gate expression unchanged (note the terminator BYPASSES the enable
      // gates on purpose).  The arm body moved verbatim into
      // TCWKeyerCAT.SendString, including the KeyersSwapped resolution.
      KeyerCAT.SendString(Msg, Tone);
   //   tStartAutoCQ;   This was a test but it cannot work like this in CWBYCAT.
   { In CWByCat, we need to know when the radio actually stops sending so we can start the timer then.
    The radio has to support a way to interrogate if it is transmitting after we send a cw string.
    We can poll the TX status of the radio  or use the TB command in the K3 which is the number of characters remaining
    to be sent. If we poll with a TB;, then we will get back TB<t><rr><s>, where t (0-9) is the count of characters
    from the KY command remaining to be sent.<rr> is the count of characters remaining in the buffer 00-40  and I think s
    is a variable length string of the characters that remain. This would only work with a K3 or radio that has a similar feature.
    - The real issue is this is received long after we have issued the command so in the regular poling
    of the radio we would need some flags to indicate we are transmitting a CWBYCAT sent buffer, and then when it is done,
    set autocq and other things we do when we are done with transmitting.
     - 12-12-2005 ny4i } //4.44.5
    // The above was just a theory and notes if there are any future issues // 4.44.5
     { First question is how do we poll the radio}
      Exit;
      end;
{$IF MMTTYMODE}
  if ActiveMode = Digital then
     begin
     //    SendMessageToMixW(Msg);
         if ActiveRadioPtr.tPTTStatus = PTT_OFF then
           if Config.PTTEnable then
              begin
              logger.debug('Calling PTTOn from AddStringToBuffer');
              PTTOn;
              PostMmttyMessage(RXM_PTT, RXM_PTT_SWITCH_TO_TX);
              end;

     //    if MMTTY_FIRST_TX_CHAR then ProcessMMTTYMessage(TXM_CHAR, 13);
     //    MMTTY_FIRST_TX_CHAR                                   := False;
         for i                                                   := 1 to length(Msg) do
            begin
            PostMmttyMessage(RXM_CHAR, integer(Msg[i]));
            end;

         if not ControlAMode then
            begin
            PostMmttyMessage(RXM_PTT, RXM_PTT_SWITCH_TO_RX_AFTER_THE_TRANSMISSION_IS_COMPLETED);
            end;

         Exit;
     end;
{$IFEND}

  if Config.CWEnable and CWEnabled then
  begin
{$IF OZCR2008}
    CWMessageToNetwork                                      := CWMessageToNetwork + Msg;
{$IFEND}

    // The WinKeyer / YCCC / CPU arms that stood here are now the adapters'
    // SendString bodies, selected by ActiveCWKeyer in the same precedence.
    // (ActiveCWKeyer cannot return KeyerCAT here in practice -- IsCWByCATActive
    // was just tested False above; a mid-call flip harmlessly routes to the CAT
    // adapter, which is the correct destination anyway.)
    ActiveCWKeyer.SendString(Msg, Tone);
  end;
end;

{------------------------------------------------------------------------------
ny4i Issue 153
This adds up the element lengths to use in a calculation to determine how long it will take to send.
}
function CalculateElements(sMsg: string): integer;
var
   i: integer;
   s: string;
   s1: string;
begin
   Result                                                   := 0;
   if not assigned(slElements) then
      begin
      exit;
      end;
   logger.trace('Calculating elements for %s',[sMsg]);
   for i                                                    := 1 to (length(sMsg)) do
      begin
      s                                                     := Copy(sMsg,i,1);
      if s = ' ' then
         begin
         Result                                             := Result + 7;
         end
      else
         begin
         s1                                                 := slElements.Values[s];
         if length(s1) > 0 then
            begin
            Result                                          := Result + StrToIntDef(s1, 0);
            logger.trace('CW Element %s = %s elements',[s, s1]);
            end
         else
            begin
            logger.trace('Missing CW element for %s',[s]);
            Result                                          := Result + 5; // average 5
            end;
         end;
      end;

end;
//------------------------------------------------------------------------------
function CWStillBeingSent: boolean;
begin
  // Was an if/else chain in exactly ActiveCWKeyer's precedence.
  // ny4i Issue 149: with CWBC it was possible to miss that we were still sending.
  Result := ActiveCWKeyer.StillBeingSent;
end;

function DeleteLastCharacter: boolean;
begin
  // ny4i Issue 149 (general stability of CWBC).  NOTE the WinKeyer arm here
  // used to fall out WITHOUT setting Result (garbage); the adapter pins True.
  Result := ActiveCWKeyer.DeleteLastChar;
end;

procedure FlushCWBuffer;

begin
//  CPUKeyer.PTTUnForce;
  // BROADCAST, not routed -- every backend is flushed, in the historical order
  // (CAT first, then the CPU keyer, the WinKeyer busy latch, and the YCCC box).
  // Each arm's body, and its guards, moved verbatim into that keyer's Flush.
  // Still a broadcast, but each arm now guards its OWN device: the CAT arm was
  // already gated per radio on IsCWByCATActive, and the WinKeyer arm is gated on
  // wkHasPendingOutput.  A keyer that is not sending therefore costs no device
  // I/O.  It stays a broadcast on purpose -- selection is per-message and
  // per-radio (uCWKeyerBase.ActiveCWKeyer), so routing to the active keyer alone
  // would strand buffered state on whichever keyer sent the PREVIOUS message,
  // and would miss the CAT arm's inactive-radio case entirely.
  KeyerCAT.Flush;
  tAutoSendMode                                             := False;
  KeyerCPU.Flush;
  KeyerWinKey.Flush;   // Q1 resolved: this arm now owns the wkClearBuffer (task #22)
  KeyerYCCC.Flush;
end;

procedure FlushCWBufferAndClearPTT(const fromWhere: string = '');

begin
  // Log BEFORE flushing: if this turns out to be aborting CW that should still
  // be running, the caller is the thing we need named.
  if fromWhere <> '' then
     begin
     logger.Debug('[FlushCWBufferAndClearPTT] called from %s (CW-by-CAT sending: active=%s inactive=%s)',
                  [fromWhere,
                   BoolToStr(ActiveRadioPtr.CWByCAT_Sending, True),
                   BoolToStr(InactiveRadioPtr.CWByCAT_Sending, True)]);
     end
  else
     begin
     logger.Debug('[FlushCWBufferAndClearPTT] called from an UNTAGGED site (CW-by-CAT sending: active=%s inactive=%s)',
                  [BoolToStr(ActiveRadioPtr.CWByCAT_Sending, True),
                   BoolToStr(InactiveRadioPtr.CWByCAT_Sending, True)]);
     end;
  FlushCWBuffer;
  PTTOff;
end;

procedure FinishRTTYTransmission(Msg: Str160);


begin
  {
    if (ActiveMode = Digital) and (ActiveRTTYPort <> NoPort) then
    begin
      while not CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].FreeSpace >= length(Msg) + 1 do ;
 
      if length(Msg) > 0 then
        for CharPointer                                     := 1 to length(Msg) do
          CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(Msg[CharPointer]));
 
      if length(RTTYReceiveString) > 0 then
        for CharPointer                                     := 1 to length(RTTYReceiveString) do
          CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(RTTYReceiveString[CharPointer]));
 
    end;
 
    RTTYTransmissionStarted                                 := False;
   }
end;
{-------------------------------------------------------------------------------
ny4i Issie 153
Helper function to easily refer to the number of dot and dashes in a character
}
function ElementLength(dots: integer; dashes: integer): integer;
begin
   Result                                                   := (dots * 1) + (dashes*3) +
             ((dots + dashes) - 1)   + // Internel element space
             3; //space ater character
end;
{------------------------------------------------------------------------------
This procedure is called only at the start of the program to build the StringList name/value pairs
// NY4I Issue154}
procedure LoadElements(sl: TStringList);
begin
   if Assigned(sl) then
      begin
      sl.Sorted                                             := false;
      sl.CommaText                                          := 'A=' + IntToStr(ElementLength(1,1)) +
                     ',B=' + IntToStr(ElementLength(3,1)) +
                     ',C=' + IntToStr(ElementLength(2,2)) +
                     ',D=' + IntToStr(ElementLength(2,1)) +
                     ',E=' + IntToStr(ElementLength(1,0)) +
                     ',F=' + IntToStr(ElementLength(3,1)) +
                     ',G=' + IntToStr(ElementLength(1,2)) +
                     ',H=' + IntToStr(ElementLength(4,0)) +
                     ',I=' + IntToStr(ElementLength(2,0)) +
                     ',J=' + IntToStr(ElementLength(1,3)) +
                     ',K=' + IntToStr(ElementLength(1,2)) +
                     ',L=' + IntToStr(ElementLength(3,1)) +
                     ',M=' + IntToStr(ElementLength(0,2)) +
                     ',N=' + IntToStr(ElementLength(1,1)) +
                     ',O=' + IntToStr(ElementLength(0,3)) +
                     ',P=' + IntToStr(ElementLength(2,2)) +
                     ',Q=' + IntToStr(ElementLength(1,3)) +
                     ',S=' + IntToStr(ElementLength(3,0)) +
                     ',T=' + IntToStr(ElementLength(0,1)) +
                     ',U=' + IntToStr(ElementLength(2,1)) +
                     ',V=' + IntToStr(ElementLength(3,1)) +
                     ',W=' + IntToStr(ElementLength(1,2)) +
                     ',X=' + IntToStr(ElementLength(2,2)) +
                     ',Y=' + IntToStr(ElementLength(1,3)) +
                     ',Z=' + IntToStr(ElementLength(2,2)) +
                     ',1=' + IntToStr(ElementLength(1,4)) +
                     ',2=' + IntToStr(ElementLength(2,3)) +
                     ',3=' + IntToStr(ElementLength(3,2)) +
                     ',4=' + IntToStr(ElementLength(4,1)) +
                     ',5=' + IntToStr(ElementLength(5,0)) +
                     ',6=' + IntToStr(ElementLength(4,1)) +
                     ',7=' + IntToStr(ElementLength(3,2)) +
                     ',8=' + IntToStr(ElementLength(2,3)) +
                     ',9=' + IntToStr(ElementLength(1,4)) +
                     ',0=' + IntToStr(ElementLength(0,5)) +
                     ',?=' + IntToStr(ElementLength(4,2))
                   + ',+=' + IntToStr(ElementLength(3,2)) // AR
                   + ',^=' + '-3' // Icom special character so remove the interspace
                   + ',%=' + IntToStr(ElementLength(4,1)) // K3 AS
                   + ',%=' + IntToStr(ElementLength(4,1)) // K3 AS
                   + ',*=' + IntToStr(ElementLength(4,2)) // K3 SK
                     ;
      sl.Sorted                                             := true;
      end;

end;
{------------------------------------------------------------------------------}
procedure SendStringAndStop(Msg: Str160);

//var
  //CharPointer                           : integer;

begin
  if ActiveMode = CW then
     begin
     if Config.CWEnable and CWEnabled then
        begin
        //            CPUKeyer.AddStringToCWBuffer (MSG, Config.CWTone);
    AddStringToBuffer(Msg, Config.CWTone);
    if IsCWByCATActive then
       begin
       // Q7 no longer bypasses the factory: the terminator goes through the
       // CAT keyer like everything else now that the send logic lives there.
       uCWKeyerCAT.CWByCATSend(ActiveRadioPtr, CWByCATBufferTerminator); // ny4i Issue 149 This closes and sends the buffer
       end;
        end;
     Exit;
     end;

  if (ActiveMode = Digital) then
     begin
     SendMessageToMixW('<TX>' + Msg + '<RXANDCLEAR>');
       {
      PTTOn;
      PostMmttyMessage(RXM_PTT, $00000002);
      AddStringToBuffer(Msg, Config.CWTone);
      PostMessage(MMTTYEXE_Handle, MSG_MMTTY, RXM_PTT, $00000001);
      }
     end;

  {
    if (ActiveMode = Digital) and (ActiveRTTYPort <> NoPort) then
    begin
      CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(CarriageReturn));
      CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(LineFeed));
 
      while not CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].FreeSpace >= length(Msg) + 2 do ;
 
      if length(RTTYSendString) > 0 then
        for CharPointer                                     := 1 to length(RTTYSendString) do
          CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(RTTYSendString[CharPointer]));
 
      for CharPointer                                       := 1 to length(Msg) do
        CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(Msg[CharPointer]));
 
      if length(RTTYReceiveString) > 0 then
        for CharPointer                                     := 1 to length(RTTYReceiveString) do
          CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(RTTYReceiveString[CharPointer]));
 
      CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(CarriageReturn));
      CPUKeyer.SerialPortOutputBuffer[ActiveRTTYPort].AddEntry(ord(LineFeed));
    end;
  }
end;

procedure SetSpeed(Speed: integer {byte});

begin
  DisplayedCodeSpeed                                        := Speed;
  //
  
  if Speed > 0 then
     begin
     CodeSpeed                                               := Speed;
     KeyerCPU.SetSpeed(Speed);
     // Radio speed-sync stays HERE, not in the CAT adapter: it is orthogonal to
     // which keyer keys (it must fire even while the WinKeyer is keying).
     if ActiveRadioPtr.CWSpeedSync then
        begin
        ActiveRadioPtr.SetRadioCWSpeed(Speed);
        end;
     tSetPaddleElementLength;
     // Broadcast, same order as before.  KeyerWinKey.SetSpeed calls wkSetSpeed
     // unconditionally (Q5, handle-guarded internally); KeyerYCCC.SetSpeed is a
     // no-op, preserving the commented-out YCCCSetSpeed (Q2).
     KeyerWinKey.SetSpeed(Speed);
     KeyerYCCC.SetSpeed(Speed);
     end;
end;

procedure SetPTT;

begin
  if not CWEnabled then Exit; { Pretty weird looking code Tree! }
end;

procedure SetNewCodeSpeed;

{ This procedure will ask what code speed you want to use and set it }

var
  WPM                                   : integer;

begin
  WPM                                                       := QuickEditInteger(TC_WPMCODESPEED, 2);
  if WPM <> -1 then
     begin
     SetSpeed(WPM);
     DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
     end;
end;

procedure DisplayBuffer(Buffer: SendBufferType;
  BufferStart: integer;
  BufferEnd: integer);

var
  BufferAddress                         : integer;

begin
  //    ClrScr;

  if BufferStart = BufferEnd then
     begin
     Write('Buffer empty - type something to start sending or RETURN to stop');
     Exit;
     end;

  BufferAddress                                             := BufferStart;

  while BufferAddress <> BufferEnd do
     begin
     Write(Buffer[BufferAddress]);
     inc(BufferAddress);
     if BufferAddress = 256 then
        begin
        BufferAddress               := 0;
        end;
     end;
end;

procedure SendKeyboardInput;

{ This procedure will take input from the keyboard and send it until a
  return is pressed.                                                    }

var
  Key{, ExtendedKey}                      : Char;
  TimeMark                              : Cardinal {TimeRecord};
  Buffer                                : SendBufferType;
  BufferStart, BufferEnd                : integer;

begin
  BufferStart                                               := 0;
  BufferEnd                                                 := 0;

  if not Config.CWEnable then
     begin
     logger.Warn('Trying SendKeyboardInput while CWEnable is false');
     Exit;
     end;

  SetUpToSendOnActiveRadio;

  CWEnabled                                                 := True;
  DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};

//  CPUKeyer.PTTForceOn;

  //  SaveAndSetActiveWindow(QuickCommandWindow);
   //    ClrScr;
   //    Write ('Sending CW from the keyboard.  Use ENTER/Escape/F10 to exit.');

  repeat
    MarkTime(TimeMark);

    repeat
      //         if ActiveMultiPort <> NoPort then
      if ElaspedSec100(TimeMark) > 3000 then { 30 second timeout }
         begin
         //        CPUKeyer.PTTUnForce;
                 CPUKeyer.FlushCWBuffer;
                   //          RemoveAndRestorePreviousWindow;
                 Exit;
         end;

      UpdateTimeAndRateDisplays(True, False);

      if CPUKeyer.BufferEmpty then
        if BufferStart <> BufferEnd then
           begin
           CPUKeyer.AddCharacterToCWBuffer(Buffer[BufferStart]);
           inc(BufferStart);
           if BufferStart = 256 then
              begin
              BufferStart             := 0;
              end;
           DisplayBuffer(Buffer, BufferStart, BufferEnd);
           end;

    until NewKeyPressed;
    Key                                                     := UpCase(NewReadKey);

    if Key >= ' ' then
       begin
       //            IF BufferStart = BufferEnd THEN ClrScr;
     Buffer[BufferEnd]                                     := Key;
     inc(BufferEnd);
     if BufferEnd = 256 then
        begin
        BufferEnd                     := 0;
        end;
     Write(Key);
       end
    else
       begin
       case Key of
         CarriageReturn:
           begin
             while BufferStart <> BufferEnd do
                begin
                InactiveRigCallingCQ                          := False; // n4af 4.42.11
                CPUKeyer.AddCharacterToCWBuffer(Buffer[BufferStart]);
                inc(BufferStart);
                if BufferStart = 256 then
                   begin
                   BufferStart         := 0;
                   end;
                end;

 //            CPUKeyer.PTTUnForce;
             //            RemoveAndRestorePreviousWindow;
             Exit;
           end;

         BackSpace:
           if BufferEnd <> BufferStart then
              begin
              dec(BufferEnd);
              if BufferEnd < 0 then
                 begin
                 BufferEnd                 := 255;
                 end;
              DisplayBuffer(Buffer, BufferStart, BufferEnd);
              end;

         EscapeKey:
           begin
 //            CPUKeyer.PTTUnForce;
             CPUKeyer.FlushCWBuffer;
             //            RemoveAndRestorePreviousWindow;
             Exit;
           end;

         NullKey:
           case NewReadKey of
             F10:
               begin
 //                CPUKeyer.PTTUnForce;
                 CPUKeyer.FlushCWBuffer;
                 //                RemoveAndRestorePreviousWindow;
                 Exit;
               end;

             PageUpKey:
               if CodeSpeed < 96 then
                  begin
                  SetSpeed(CodeSpeed + 3);
                  DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
                  end;

             PageDownKey:
               if CodeSpeed > 4 then
                  begin
                  SetSpeed(CodeSpeed - 3);
                  DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
                  end;

             DeleteKey:
               if BufferEnd <> BufferStart then
                  begin
                  dec(BufferEnd);
                  if BufferEnd < 0 then
                     begin
                     BufferEnd             := 255;
                     end;
                  DisplayBuffer(Buffer, BufferStart, BufferEnd);
                  end;

           end;

       end;
       end;

  until False;
end;

function TimeString: Str10;
begin
  tGetSystemTime;
  Windows.ZeroMemory(@Result, SizeOf(Result));
  TF.Format(@Result[1], '%.2hu%.2hu', UTC.wHour, UTC.wMinute);
  Result[0]                                                 := #4;
end;

function QSONumberString(QSONumber: integer): string;
var
  TempString                            : Str80;
begin
  Str(QSONumber, TempString);
  QSONumberString                                           := TempString;
end;

procedure DisplayCrypticCWMenu;

begin

end;

procedure DisplayCrypticSSBMenu;

begin

end;

procedure ShowCQFunctionKeyStatus;

var
  Key                                   : Char;
  TempString                            : Str160;

begin
  //    GoToXY (1, 1);
//  Windows.SetDlgItemTextA(MemProgHWND, 102, TC_PRESSCQFUNCTIONKEYTOPROGRAM);
//  Windows.SetWindowTextA(MemProgHWND, TC_CQFUNCTIONKEYMEMORYSTATUS);
  case KeyStatus of
    NormalKeys:
      begin
        //            WriteLnCenter ('CQ FUNCTION KEY MEMORY STATUS');

        for Key                                             := F1 to F12 do
           begin
           Str(Ord(Key) - Ord(F1) + 1, TempString);
           TempString                                        := 'F' + TempString + ' - ';

           if (ActiveMode = CW) or (ActiveMode = Digital) then
              begin
              if GetCQMemoryString(CW, Key) <> '' then {KK1L: 6.73 Added Mode}
                 begin
                 TempString                                    := TempString + GetCQMemoryString(CW, Key); {KK1L: 6.73 Added Mode}
                 end;

              end
           else
             if GetCQMemoryString(Phone, Key) <> '' then
                begin
                TempString                                    := TempString {+ DVPPath} + GetCQMemoryString(Phone, Key); {KK1L: 6.73 Added Mode}
                end;

           if length(TempString) > 79 then
              begin
              TempString                                      := Copy(TempString, 1, 78) + '+';
              end;
 //          Windows.SetWindowTextA(MessagesValues[Ord(Key)], PAnsiChar(AnsiString(TempString)));
             //                ClrEol;
             //                WriteLn (TempString);
           end;
      end;

    AltKeys:
      begin
        //            WriteLnCenter ('ALT-CQ FUNCTION KEY MEMORY STATUS');

        for Key                                             := AltF1 to AltF12 do
           begin
           Str(Ord(Key) - Ord(AltF1) + 1, TempString);
           TempString                                        := 'Alt-F' + TempString + ' - ';

           if GetCQMemoryString(ActiveMode, Key) <> '' then {KK1L: 6.73 Added Mode}
              begin
              TempString                                      := TempString + GetCQMemoryString(ActiveMode, Key); {KK1L: 6.73 Added Mode}
              end;

           if length(TempString) > 79 then
              begin
              TempString                                      := Copy(TempString, 1, 78) + '+';
              end;
 //          Windows.SetWindowTextA(MessagesValues[Ord(Key) - 24], PAnsiChar(AnsiString(TempString)));
             //                ClrEol;
             //                WriteLn (TempString);
           end;
      end;

    ControlKeys:
      begin
        //            WriteLnCenter ('CONTROL-CQ FUNCTION KEY MEMORY STATUS');

        for Key                                             := ControlF1 to ControlF12 do
           begin
           Str(Ord(Key) - Ord(ControlF1) + 1, TempString);
           TempString                                        := 'Ctrl-F' + TempString + ' - ';

           if GetCQMemoryString(ActiveMode, Key) <> '' then {KK1L: 6.73 Added mode}
              begin
              TempString                                      := TempString + GetCQMemoryString(ActiveMode, Key); {KK1L: 6.73 Added mode}
              end;

           if length(TempString) > 79 then
              begin
              TempString                                      := Copy(TempString, 1, 78) + '+';
              end;
 //          Windows.SetWindowTextA(MessagesValues[Ord(Key) - 12], PAnsiChar(AnsiString(TempString)));
             //                ClrEol;
             //                WriteLn (TempString);
           end;
      end;
  end;
end;

procedure ShowExFunctionKeyStatus;

var
  Key                                   : Char;
  TempString                            : Str160;

begin
  //    GoToXY (1, 1);
//  Windows.SetDlgItemTextA(MemProgHWND, 102, TC_PRESSEXFUNCTIONKEYTOPROGRAM);
//  Windows.SetWindowTextA(MemProgHWND, TC_EXCHANGEFUNCTIONKEYMEMORYSTATUS);
  case KeyStatus of
    NormalKeys:
      begin
        //            WriteLnCenter ('EXCHANGE FUNCTION KEY MEMORY STATUS');

        if ActiveMode = CW then
           begin
           //          Windows.SetWindowTextA(MessagesValues[VK_F1], 'F1 - Set by the MY CALL statement in config file' {TC_F1SETBYTHEMYCALLSTATEMENTINCONFIG});
           //          Windows.SetWindowTextA(MessagesValues[VK_F2], 'F2 - Set by S&P EXCHANGE and REPEAT S&P EXCHANGE' {TC_F2SETBYSPEXCHANGEANDREPEATSP});
                       //                  WriteLn('F1 - Set by the MY CALL statement in config file');
                       //                  WriteLn('F2 - Set by S&P EXCHANGE and REPEAT S&P EXCHANGE');

                     for Key                                           := F3 to F12 do
                        begin
                        Str(Ord(Key) - Ord(F1) + 1, TempString);
                        TempString                                      := 'F' + TempString + ' - ';

                            {KK1L: 6.73 Added mode to GetExMemoryString}
                        if GetEXMemoryString(ActiveMode, Key) <> '' then
                           begin
                           TempString                                    := TempString + GetEXMemoryString(ActiveMode, Key);
                           end;

                        if length(TempString) > 79 then
                           begin
                           TempString                                    := Copy(TempString, 1, 78) + '+';
                           end;
            //            Windows.SetWindowTextA(MessagesValues[Ord(Key)], PAnsiChar(AnsiString(TempString)));
                            //                    ClrEol;
                            //                    WriteLn (TempString);
                        end;
           end
        else
           begin
           for Key                                           := F1 to F12 do
              begin
              Str(Ord(Key) - Ord(F1) + 1, TempString);
              TempString                                      := 'F' + TempString + ' - ';

                {KK1L: 6.73 Added mode to GetExMemoryString}
              if GetEXMemoryString(ActiveMode, Key) <> '' then
                 begin
                 TempString                                    := TempString {+ DVPPath} + GetEXMemoryString(ActiveMode, Key);
                 end;

              if length(TempString) > 79 then
                 begin
                 TempString                                    := Copy(TempString, 1, 78) + '+';
                 end;
  //            Windows.SetWindowTextA(MessagesValues[Ord(Key)], PAnsiChar(AnsiString(TempString)));
                //                    ClrEol;
                //                    WriteLn (TempString);
              end;
           end;
      end;

    AltKeys:
      begin
        //            WriteLnCenter ('ALT-EXCHANGE FUNCTION KEY MEMORY STATUS');

        for Key                                             := AltF1 to AltF12 do
           begin
           Str(Ord(Key) - Ord(AltF1) + 1, TempString);
           TempString                                        := 'Alt-F' + TempString + ' - ';

             {KK1L: 6.73 Added mode to GetExMemoryString}
           if GetEXMemoryString(ActiveMode, Key) <> '' then
              begin
              TempString                                      := TempString + GetEXMemoryString(ActiveMode, Key);
              end;

           if length(TempString) > 79 then
              begin
              TempString                                      := Copy(TempString, 1, 78) + '+';
              end;
             //                 ClrEol;
             //                WriteLn (TempString);
           end;
      end;

    ControlKeys:
      begin
        //            WriteLnCenter ('CONTROL-EXCHANGE FUNCTION KEY MEMORY STATUS');

        for Key                                             := ControlF1 to ControlF12 do
           begin
           Str(Ord(Key) - Ord(ControlF1) + 1, TempString);
           TempString                                        := 'Ctrl-F' + TempString + ' - ';

             {KK1L: 6.73 Added mode to GetExMemoryString}
           if GetEXMemoryString(ActiveMode, Key) <> '' then
              begin
              TempString                                      := TempString + GetEXMemoryString(ActiveMode, Key);
              end;

           if length(TempString) > 79 then
              begin
              TempString                                      := Copy(TempString, 1, 78) + '+';
              end;
             //    ClrEol;
              //  WriteLn (TempString);
           end;
      end;
  end;
end;

procedure ShowOtherMemoryStatus;

{var
  TempString                            : Str160;
}
begin
//  Windows.SetDlgItemTextA(MemProgHWND, 102, TC_NUMBERORLETTEROFMESSAGETOBEPROGRAM);

  if (ActiveMode = CW) or (ActiveMode = Digital) then
     begin
      //         GoToXY(1, 1);
      //         WriteLnCenter('OTHER CW MESSAGE MEMORY STATUS');

//    Windows.SetWindowTextA(MemProgHWND, TC_OTHERCWMESSAGEMEMORYSTATUS);

      //         ClrEol;
//         TempString                                       := ' 1. Call Okay Now - ' + CorrectedCallMessage;
//         if length(TempString) > 79 then TempString       := Copy(TempString, 1, 78) + '+';
//         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[112], PAnsiChar(AnsiString('Call Okay Now - ' + CorrectedCallMessage)));
      //         ClrEol;
      //         TempString                                 := ' 2. CQ Exchange   - ' + CQExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[113], PAnsiChar(AnsiString('CQ Exchange   - ' + CQExchange)));

      //         ClrEol;
      //         TempString                                 := ' 3. CQ Ex Name    - ' + CQExchangeNameKnown;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[114], PAnsiChar(AnsiString('CQ Ex Name    - ' + CQExchangeNameKnown)));

      //         ClrEol;
      //         TempString                                 := ' 4. QSL Message   - ' + QSLMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[115], PAnsiChar(AnsiString('QSL Message   - ' + QSLMessage)));
      //         ClrEol;
      //         TempString                                 := ' 5. QSO Before    - ' + QSOBeforeMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[116], PAnsiChar(AnsiString('QSO Before    - ' + QSOBeforeMessage)));

      //         ClrEol;
      //         TempString                                 := ' 6. Quick QSL     - ' + QuickQSLMessage1;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[117], PAnsiChar(AnsiString('Quick QSL     - ' + QuickQSLMessage1)));

      //         ClrEol;
      //         TempString                                 := ' 7. Repeat S&P Ex - ' + RepeatSearchAndPounceExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[118], PAnsiChar(AnsiString('Repeat S&P Ex - ' + RepeatSearchAndPounceExchange)));

      //         ClrEol;
      //         TempString                                 := ' 8. S&P Exchange  - ' + SearchAndPounceExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[119], PAnsiChar(AnsiString('S&P Exchange  - ' + SearchAndPounceExchange)));

      //         ClrEol;
      //         TempString                                 := ' 9. Tail end msg  - ' + TailEndMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[120], PAnsiChar(AnsiString('Tail end msg  - ' + TailEndMessage)));

//    Windows.SetWindowTextA(MessagesValues[121], PAnsiChar(AnsiString('Short 0       - ' + Short0)));
//    Windows.SetWindowTextA(MessagesValues[122], PAnsiChar(AnsiString('Short 1       - ' + Short1)));
//    Windows.SetWindowTextA(MessagesValues[123], PAnsiChar(AnsiString('Short 9       - ' + Short9)));

      //         ClrEol;
      //         Write('A. Short 0 = ', Short0, '   ',
      //            'B. Short 1 = ', Short1, '   ',
      //            'C. Short 2 = ', Short2, '   ',
      //            'D. Short 9 = ', Short9);
  end
  else
     begin
      //         GoToXY(1, 1);
      //         WriteLnCenter('OTHER SSB MESSAGE MEMORY STATUS');
//    Windows.SetWindowTextA(MemProgHWND, TC_OTHERSSBMESSAGEMEMORYSTATUS);
      //         ClrEol;
      //         TempString                                 := ' 1. Call Okay Now - ' + DVPPath + CorrectedCallPhoneMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[112], PAnsiChar(AnsiString('Call Okay Now - ' + CorrectedCallPhoneMessage)));

      //         ClrEol;
      //         TempString                                 := ' 2. CQ Exchange   - ' + DVPPath + CQPhoneExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[113], PAnsiChar(AnsiString('CQ Exchange   - ' + CQPhoneExchange)));
      //         ClrEol;
      //         TempString                                 := ' 3. CQ Ex Name    - ' + DVPPath + CQPhoneExchangeNameKnown;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[114], PAnsiChar(AnsiString('CQ Ex Name    - ' + CQPhoneExchangeNameKnown)));
      //         ClrEol;
      //         TempString                                 := ' 4. QSL Message   - ' + DVPPath + QSLPhoneMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[115], PAnsiChar(AnsiString('QSL Message   - ' + QSLPhoneMessage)));
      //         ClrEol;
      //         TempString                                 := ' 5. QSO Before    - ' + DVPPath + QSOBeforePhoneMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[116], PAnsiChar(AnsiString('QSO Before    - ' + QSOBeforePhoneMessage)));
      //         ClrEol;
      //         TempString                                 := ' 6. Quick QSL     - ' + DVPPath + QuickQSLPhoneMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[117], PAnsiChar(AnsiString('Quick QSL     - ' + QuickQSLPhoneMessage)));
      //         ClrEol;
      //         TempString                                 := ' 7. Repeat S&P Ex - ' + DVPPath + RepeatSearchAndPouncePhoneExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[118], PAnsiChar(AnsiString('Repeat S&P Ex - ' + RepeatSearchAndPouncePhoneExchange)));
      //         ClrEol;
      //         TempString                                 := ' 8. S&P Exchange  - ' + DVPPath + SearchAndPouncePhoneExchange;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[119], PAnsiChar(AnsiString('S&P Exchange  - ' + SearchAndPouncePhoneExchange)));
      //         ClrEol;
      //         TempString                                 := ' 9. Tail end msg  - ' + DVPPath + TailEndPhoneMessage;
      //         if length(TempString) > 79 then TempString := Copy(TempString, 1, 78) + '+';
      //         WriteLn(TempString);
//    Windows.SetWindowTextA(MessagesValues[120], PAnsiChar(AnsiString('Tail end msg  - ' + TailEndPhoneMessage)));
      //         ClrEol;
  end;
end;

procedure AppendConfigFile(AddedLine: Str160);

//var
  //FileWrite                             : Text;

begin
{
  if OpenFileForAppend(FileWrite, LogConfigFileName) then
  begin
    WriteLn(FileWrite);
    WriteLn(FileWrite, AddedLine);
    Close(FileWrite);
  end;
}
end;

procedure DVKLIstenMessage(MemoryString: Str20);

begin
  DVPOn                                                     := True;

  MemoryString                                              := UpperCase(MemoryString);
  if MemoryString = 'DVK1' then
     begin
     StartDVK(1);
     end;
  if MemoryString = 'DVK2' then
     begin
     StartDVK(2);
     end;
  if MemoryString = 'DVK3' then
     begin
     StartDVK(3);
     end;
  if MemoryString = 'DVK4' then
     begin
     StartDVK(4);
     end;
  if MemoryString = 'DVK5' then StartDVK(5); {KK1L: 6.71}
  if MemoryString = 'DVK6' then StartDVK(6); {KK1L: 6.71}
  {IF MemoryString = 'DVK7' THEN StartDVK (7); {KK1L: 6.71}{KK1L: 6.72 removed}
end;

procedure DVKRecordMessage(MemoryString: Str20);

begin
  DVPOn                                                     := True;

  MemoryString                                              := UpperCase(MemoryString);

  if Copy(MemoryString, 1, 3) <> 'DVK' then Exit;

  DVKEnableWrite;

  if MemoryString = 'DVK1' then
     begin
     StartDVK(1);
     end;
  if MemoryString = 'DVK2' then
     begin
     StartDVK(2);
     end;
  if MemoryString = 'DVK3' then
     begin
     StartDVK(3);
     end;
  if MemoryString = 'DVK4' then
     begin
     StartDVK(4);
     end;
  if MemoryString = 'DVK5' then StartDVK(5); {KK1L: 6.71}
  if MemoryString = 'DVK6' then StartDVK(6); {KK1L: 6.71}
  {IF MemoryString = 'DVK7' THEN StartDVK (7); {KK1L: 6.71}{KK1L: 6.72 removed}

 //    REPEAT UNTIL KeyPressed;

  DVKDisableWrite;

  //    IF ReadKey = NullKey THEN ReadKey;
end;

procedure MemoryProgram;

var
  Key, FirstExchangeFunctionKey, FunctionKey: Char;
  TempString                            : Str160;
  TimeMark                              : Cardinal {TimeRecord};

begin
  case ActiveMode of
    Phone: FirstExchangeFunctionKey                         := F1;
    CW, Digital: FirstExchangeFunctionKey                   := F3;
  end;

  //  RemoveWindow(QuickCommandWindow);
  //  SaveSetAndClearActiveWindow(EditableLogWindow);

   {    WriteLnCenter ('MEMORY PROGRAM FUNCTION');
       WriteLn ('Press C to program a CQ function key.');
       WriteLn ('Press E to program an exchange/search and pounce function key.');
       WriteLn ('Press O to program the other non function key messages.');
       Write   ('Press ESCAPE to abort.');
   }
  MarkTime(TimeMark);

  repeat
    repeat until NewKeyPressed;
    Key                                                     := UpCase(NewReadKey);

    //      if ActiveMultiPort <> NoPort then
    if ElaspedSec100(TimeMark) > 3000 then
       begin
       //        RemoveAndRestorePreviousWindow;
     Exit;
       end;

  until (Key = 'C') or (Key = 'E') or (Key = 'O') or (Key = EscapeKey);

  //  RemoveAndRestorePreviousWindow;

  if Key = EscapeKey then Exit;

  //  RemoveWindow(TotalWindow);
  //  SaveSetAndClearActiveWindow(BigWindow);

  if (ActiveMode = CW) or (ActiveMode = Digital) then
     begin
     DisplayCrypticCWMenu
     end
  else
     begin
     DisplayCrypticSSBMenu;
     end;

  VisibleDupeSheetRemoved                                   := True;

  KeyStatus                                                 := NormalKeys;

  case Key of
    'C': repeat
        ShowCQFunctionKeyStatus;
        {                 GoToXY (1, Hi (WindMax));
                         Write (' Press CQ function key to program (F1, AltF1, CtrlF1), or ESCAPE to exit) : '); //KK1L: 6.72 changed
        }
        MarkTime(TimeMark);

        repeat
          repeat
            //                  if ActiveMultiPort <> NoPort then
            if ElaspedSec100(TimeMark) > 3000 then
               begin
               //                RemoveAndRestorePreviousWindow;
             Exit;
               end;

          until NewKeyPressed;
          FunctionKey                                       := UpCase(NewReadKey);

        until (FunctionKey = NullKey) or (FunctionKey = EscapeKey);

        if FunctionKey = EscapeKey then
           begin
           //          RemoveAndRestorePreviousWindow;
         Exit;
           end;

        FunctionKey                                         := NewReadKey;

        if ((FunctionKey >= F1) and (FunctionKey <= F10)) or
          ((FunctionKey >= ControlF1) and (FunctionKey <= ControlF10)) or
          ((FunctionKey >= AltF1) and (FunctionKey <= AltF10)) or
          ((FunctionKey >= F11) and (FunctionKey <= AltF12)) then
           begin
           if FunctionKey >= AltF1 then
              begin
              if KeyStatus <> AltKeys then
                 begin
                 KeyStatus                                     := AltKeys;
                 ShowCQFunctionKeyStatus;
                 end;
              end
           else
             if FunctionKey >= ControlF1 then
                begin
                if KeyStatus <> ControlKeys then
                   begin
                   KeyStatus                                   := ControlKeys;
                   ShowCQFunctionKeyStatus;
                   end;
                end
             else
               if KeyStatus <> NormalKeys then
                  begin
                  KeyStatus                                   := NormalKeys;
                  ShowCQFunctionKeyStatus;
                  end;

             //                            SaveSetAndClearActiveWindow(QuickCommandWindow);

           repeat
             TempString                                      := LineInput('Msg = ',
               GetCQMemoryString(ActiveMode, FunctionKey), {KK1L: 6.73 Added mode}
               True,
               (ActiveMode = Phone) and (Config.DVKEnable or (ActiveDVKPort <> NoPort)));

             if TempString[1] = NullKey then
               if Config.DVKEnable then
                  begin
                  //                case TempString[2] of
                             {KK1L: 6.73 Added mode}
                  //                  AltW: DVPRecordMessage(GetCQMemoryString(ActiveMode, FunctionKey), False);
                             {KK1L: 6.73 Added mode}
                  //                  AltR: DVPListenMessage(GetCQMemoryString(ActiveMode, FunctionKey), true);
                  //                end;
                  end
               else
                  begin
                  if ActiveDVKPort <> NoPort then
                        //                  case TempString[2] of
                                    {KK1L: 6.73 Added mode}
                        //                    AltW: DVKRecordMessage(GetCQMemoryString(ActiveMode, FunctionKey));
                                    {KK1L: 6.73 Added mode}
                        //                    AltR: DVKListenMessage(GetCQMemoryString(ActiveMode, FunctionKey));
                  end;
               //              end;

           until (TempString[1] <> NullKey);

           if (TempString <> EscapeKey) and
               {KK1L: 6.73 Added mode}
           (GetCQMemoryString(ActiveMode, FunctionKey) <> TempString) then
              begin
              SetCQMemoryString(ActiveMode, FunctionKey, TempString);

              if ActiveMode = Phone then
                 begin
                 AppendConfigFile('CQ SSB MEMORY ' + KeyId(FunctionKey) + ' = ' + TempString)
                 end
              else
                 begin
                 AppendConfigFile('CQ MEMORY ' + KeyId(FunctionKey) + ' = ' + TempString);
                 end;
              end;

             //          RemoveAndRestorePreviousWindow;
           end;
      until False;

    'E': repeat
        ShowExFunctionKeyStatus;
        //                 GoToXY (1, Hi (WindMax));
        //                 Write (' Press ex function key to program (F3-F12, Alt/Ctrl F1-F12) or ESCAPE to exit :');
                         {KK1L: 6.72 changed above line}

        MarkTime(TimeMark);

        repeat
          repeat
            //                  if ActiveMultiPort <> NoPort then
            if ElaspedSec100(TimeMark) > 3000 then
               begin
               //                RemoveAndRestorePreviousWindow;
             Exit;
               end;

          until NewKeyPressed;
          FunctionKey                                       := UpCase(NewReadKey);
        until (FunctionKey = NullKey) or (FunctionKey = EscapeKey);

        if FunctionKey = EscapeKey then
           begin
           //          RemoveAndRestorePreviousWindow;
         Exit;
           end;

        FunctionKey                                         := NewReadKey;

        if ((FunctionKey >= FirstExchangeFunctionKey) and (FunctionKey <= F10)) or
          ((FunctionKey >= ControlF1) and (FunctionKey <= ControlF10)) or
          ((FunctionKey >= AltF1) and (FunctionKey <= AltF10)) or
          ((FunctionKey >= F11) and (FunctionKey <= AltF12)) then
           begin
           if FunctionKey >= AltF1 then
              begin
              if KeyStatus <> AltKeys then
                 begin
                 KeyStatus                                     := AltKeys;
                 ShowExFunctionKeyStatus;
                 end;
              end
           else
             if FunctionKey >= ControlF1 then
                begin
                if KeyStatus <> ControlKeys then
                   begin
                   KeyStatus                                   := ControlKeys;
                   ShowExFunctionKeyStatus;
                   end;
                end
             else
               if KeyStatus <> NormalKeys then
                  begin
                  KeyStatus                                   := NormalKeys;
                  ShowExFunctionKeyStatus;
                  end;

             //          SaveSetAndClearActiveWindow(QuickCommandWindow);

           repeat
             TempString                                      := LineInput('Msg = ',
                 {KK1L: 6.73 Added mode to GetExMemoryString}
               GetEXMemoryString(ActiveMode, FunctionKey),
               True,
               (ActiveMode = Phone) and (Config.DVKEnable or (ActiveDVKPort <> NoPort)));

             if TempString[1] = NullKey then
               if Config.DVKEnable then
                  begin
                  //                case TempString[2] of
                             {KK1L: 6.73 Added mode to GetExMemoryString}
                  //                  AltW: DVPRecordMessage(GetEXMemoryString(ActiveMode, FunctionKey), False);
                  //                  AltR: DVPListenMessage(GetEXMemoryString(ActiveMode, FunctionKey), true);
                  //                end;
                  end
               else
                   //               if ActiveDVKPort <> NoPort then
                  //                  case TempString[2] of
                             {KK1L: 6.73 Added mode to GetExMemoryString}
                  //                    AltW: DVKRecordMessage(GetEXMemoryString(ActiveMode, FunctionKey));
                  //                    AltR: DVKListenMessage(GetEXMemoryString(ActiveMode, FunctionKey));
                  //                  end;

           until (TempString[1] <> NullKey);

           if TempString <> EscapeKey then
              begin
              SetEXMemoryString(ActiveMode, FunctionKey, TempString);

              if ActiveMode = Phone then
                 begin
                 AppendConfigFile('EX SSB MEMORY ' + KeyId(FunctionKey) + ' = ' + TempString)
                 end
              else
                 begin
                 AppendConfigFile('EX MEMORY ' + KeyId(FunctionKey) + ' = ' + TempString)
                 end
              end;

             //          RemoveAndRestorePreviousWindow;
           end;
      until False;

    'O': repeat
        //            ShowOtherMemoryStatus;
                    //                 GoToXY (1, Hi (WindMax));

                    //                 Write ('Number or letter of message to be programmed (1-9, A-D, or ESCAPE to exit) : ');

        MarkTime(TimeMark);

        repeat
          repeat
            //                  if ActiveMultiPort <> NoPort then
            if ElaspedSec100(TimeMark) > 3000 then
               begin
               //                RemoveAndRestorePreviousWindow;
             Exit;
               end;

          until NewKeyPressed;
          //                     FunctionKey                := Upcase (ReadKey);
        until ((FunctionKey >= '1') and (FunctionKey <= '9')) or
          ((FunctionKey >= 'A') and (FunctionKey <= 'D')) or
          (FunctionKey = EscapeKey);

        if FunctionKey = EscapeKey then
           begin
           //          RemoveAndRestorePreviousWindow;
         Exit;
           end;

        //        SaveSetAndClearActiveWindow(QuickCommandWindow);

        case FunctionKey of
          '1':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ',
                   CorrectedCallMessage,
                   True,
                   False);

                 if TempString <> EscapeKey then
                    begin
                    CorrectedCallMessage                      := TempString;
                    AppendConfigFile('CALL OK NOW MESSAGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     CorrectedCallPhoneMessage,
                     True,
                     True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        {                      case TempString[2] of
                                                  AltW: DVPRecordMessage(CorrectedCallPhoneMessage, False);
                                                  AltR: DVPListenMessage(CorrectedCallPhoneMessage, true);
                                                end;
                                              }
                        end
                     else
                         //                    if ActiveDVKPort <> NoPort then
                       //                        case TempString[2] of
                       //                          AltW: DVKRecordMessage(CorrectedCallPhoneMessage);
                       //                          AltR: DVKListenMessage(CorrectedCallPhoneMessage);
                       //                        end;

                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    CorrectedCallPhoneMessage                 := TempString;
                    AppendConfigFile('CALL OK NOW SSB MESSAGE = ' + TempString);
                    end;
                 end;
            end;

          '2':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', CQExchange, True, False);
                 if TempString <> EscapeKey then
                    begin
                    CQExchange                                := TempString;
                    AppendConfigFile('CQ EXCHANGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     CQPhoneExchange,
                     True,
                     True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(CQPhoneExchange, False);
                          AltR: DVPListenMessage(CQPhoneExchange, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(CQPhoneExchange);
                            AltR: DVKLIstenMessage(CQPhoneExchange);
                          end;
                          end;

                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    CQPhoneExchange                           := TempString;
                    AppendConfigFile('CQ SSB EXCHANGE = ' + TempString);
                    end;
                 end;
            end;

          '3':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', CQExchangeNameKnown, True, False);
                 if TempString <> EscapeKey then
                    begin
                    CQExchangeNameKnown                       := TempString;
                    AppendConfigFile('CQ EXCHANGE NAME KNOWN = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     CQPhoneExchangeNameKnown,
                     True,
                     True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(CQPhoneExchangeNameKnown, False);
                          AltR: DVPListenMessage(CQPhoneExchangeNameKnown, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(CQPhoneExchangeNameKnown);
                            AltR: DVKLIstenMessage(CQPhoneExchangeNameKnown);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    CQPhoneExchangeNameKnown                  := TempString;
                    AppendConfigFile('CQ SSB EXCHANGE NAME KNOWN = ' + TempString);
                    end;
                 end;
            end;

          '4':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', QSLMessage, True, False);
                 if TempString <> EscapeKey then
                    begin
                    QSLMessage                                := TempString;
                    AppendConfigFile('QSL MESSAGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     QSLPhoneMessage,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(QSLPhoneMessage, False);
                          AltR: DVPListenMessage(QSLPhoneMessage, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(QSLPhoneMessage);
                            AltR: DVKLIstenMessage(QSLPhoneMessage);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    QSLPhoneMessage                           := TempString;
                    AppendConfigFile('QSL SSB MESSAGE = ' + TempString);
                    end;
                 end;
            end;

          '5':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', QSOBeforeMessage, True, False);
                 if TempString <> EscapeKey then
                    begin
                    QSOBeforeMessage                          := TempString;
                    AppendConfigFile('QSO BEFORE MESSAGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     QSOBeforePhoneMessage,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(QSOBeforePhoneMessage, False);
                          AltR: DVPListenMessage(QSOBeforePhoneMessage, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(QSOBeforePhoneMessage);
                            AltR: DVKLIstenMessage(QSOBeforePhoneMessage);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    QSOBeforePhoneMessage                     := TempString;
                    AppendConfigFile('QSO BEFORE SSB MESSAGE = ' + TempString);
                    end;
                 end;
            end;

          '6':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', QuickQSLMessage1, True, False);
                 if TempString <> EscapeKey then
                    begin
                    QuickQSLMessage1                          := TempString;
                    AppendConfigFile('QUICK QSL MESSAGE= ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     QuickQSLPhoneMessage,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(QuickQSLPhoneMessage, False);
                          AltR: DVPListenMessage(QuickQSLPhoneMessage, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(QuickQSLPhoneMessage);
                            AltR: DVKLIstenMessage(QuickQSLPhoneMessage);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    QuickQSLPhoneMessage                      := TempString;
                    AppendConfigFile('QUICK QSL SSB MESSAGE = ' + TempString);
                    end;
                 end;
            end;

          '7':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', RepeatSearchAndPounceExchange, True, False);
                 if TempString <> EscapeKey then
                    begin
                    RepeatSearchAndPounceExchange             := TempString;
                    AppendConfigFile('REPEAT S&P EXCHANGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     RepeatSearchAndPouncePhoneExchange,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(RepeatSearchAndPouncePhoneExchange, False);
                          AltR: DVPListenMessage(RepeatSearchAndPouncePhoneExchange, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(RepeatSearchAndPouncePhoneExchange);
                            AltR: DVKLIstenMessage(RepeatSearchAndPouncePhoneExchange);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    RepeatSearchAndPouncePhoneExchange        := TempString;
                    AppendConfigFile('REPEAT S&P SSB EXCHANGE = ' + TempString);
                    end;
                 end;
            end;

          '8':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', SearchAndPounceExchange, True, False);
                 if TempString <> EscapeKey then
                    begin
                    SearchAndPounceExchange                   := TempString;
                    AppendConfigFile('S&P EXCHANGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     SearchAndPouncePhoneExchange,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(SearchAndPouncePhoneExchange, False);
                          AltR: DVPListenMessage(SearchAndPouncePhoneExchange, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(SearchAndPouncePhoneExchange);
                            AltR: DVKLIstenMessage(SearchAndPouncePhoneExchange);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    SearchAndPouncePhoneExchange              := TempString;
                    AppendConfigFile('S&P SSB EXCHANGE = ' + TempString);
                    end;
                 end;
            end;

          '9':
            begin
              if ActiveMode <> Phone then
                 begin
                 TempString                                  := LineInput('Msg = ', TailEndMessage, True, False);
                 if TempString <> EscapeKey then
                    begin
                    TailEndMessage                            := TempString;
                    AppendConfigFile('TAIL END MESSAGE = ' + TempString);
                    end;
                 end
              else
                 begin
                 repeat
                   TempString                                := LineInput('Msg = ',
                     TailEndPhoneMessage,
                     True, True);

                   if TempString[1] = NullKey then
                     if Config.DVKEnable then
                        begin
                        case TempString[2] of
                          AltW: DVPRecordMessage(TailEndPhoneMessage, False);
                          AltR: DVPListenMessage(TailEndPhoneMessage, True);
                        end;
                        end
                     else
                       if ActiveDVKPort <> NoPort then
                          begin
                          case TempString[2] of
                            AltW: DVKRecordMessage(TailEndPhoneMessage);
                            AltR: DVKLIstenMessage(TailEndPhoneMessage);
                          end;
                          end;
                 until (TempString[1] <> NullKey);

                 if TempString <> EscapeKey then
                    begin
                    TailEndPhoneMessage                       := TempString;
                    AppendConfigFile('TAIL END SSB MESSAGE = ' + TempString);
                    end;
                 end;
            end;

          'A':
            if ActiveMode <> Phone then
               begin
               TempString                                    := LineInput('Enter character for short zeros : ', '', True, False);
               if (TempString <> EscapeKey) and (TempString <> '') then
                  begin
                  Short0                                      := TempString[1];
                  AppendConfigFile('SHORT 0 = ' + Short0);
                  end;
               end;

          'B':
            if ActiveMode <> Phone then
               begin
               TempString                                    := LineInput('Enter character for short ones : ', '', True, False);
               if (TempString <> EscapeKey) and (TempString <> '') then
                  begin
                  Short1                                      := TempString[1];
                  AppendConfigFile('SHORT 1 = ' + Short1);
                  end;
               end;

          'C':
            if ActiveMode <> Phone then
               begin
               TempString                                    := LineInput('Enter character for short twos : ', '', True, False);
               if (TempString <> EscapeKey) and (TempString <> '') then
                  begin
                  Short2                                      := TempString[1];
                  AppendConfigFile('SHORT 2 = ' + Short2);
                  end;
               end;

          'D':
            if ActiveMode <> Phone then
               begin
               TempString                                    := LineInput('Enter character for short nines : ', '', True, False);
               if (TempString <> EscapeKey) and (TempString <> '') then
                  begin
                  Short9                                      := TempString[1];
                  AppendConfigFile('SHORT 9 = ' + Short9);
                  end;
               end;

        end; { of case }

        //        RemoveAndRestorePreviousWindow;
      until False;
  end;
end;

function GetCQMemoryString(Mode: ModeType; Key: Char): ShortString; {KK1L: 6.73 Added Mode to do split mode}

{VAR Mode: ModeType;}{KK1L: 6.73 Removed}

begin
  {Mode                                                     := ActiveMode;}{KK1L: 6.73 Removed}

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;

  GetCQMemoryString                                         := '';
  if Mode < Both then
     if CQMemory[Mode, Key] <> nil then
        begin
        GetCQMemoryString                                     := CQMemory[Mode, Key]^;
        end;

    
end;

function GetEXMemoryString(Mode: ModeType; Key: Char): ShortString; {KK1L: 6.73 Added Mode to do split mode}

{VAR Mode: ModeType;}{KK1L: 6.73 Removed}

begin
  {Mode                                                     := ActiveMode;}{KK1L: 6.73 Removed}

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;

  if EXMemory[Mode, Key] <> nil then
     begin
     GetEXMemoryString                                       := EXMemory[Mode, Key]^
     end
  else
     begin
     GetEXMemoryString                                       := ''
     end
end;

procedure SetCQCaptionMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString);

begin

  { REFUSE A KEY THIS ARRAY CANNOT HOLD.

    FunctionKeyMemoryArray is [CW..Phone, F1..AltF12] -- 112..147. Range checking
    is off in this build, so an index outside that does not raise: it writes a
    heap pointer into whatever global happens to sit there, and the damage
    surfaces somewhere else entirely. That is exactly what happened on
    2026-08-15: a config line whose key prefix was not F/A/C produced CHR(1..12)
    here, and the crash appeared later in ShowFMessages dereferencing a
    neighbouring global that now looked like a valid pointer.

    The caller was fixed too, but this is the layer that owns the invariant, and
    a silent out-of-bounds write is worth refusing wherever it arrives from. }
  if not (Key in [F1..AltF12]) then
     begin
     logger.Error('[SetCQCaptionMemoryString] key #%d is outside F1..AltF12 -- ignored',
                  [Ord(Key)]);
     Exit;
     end;

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;

  if CQCaptionMemory[Mode, Key] = nil then
     begin
     New(CQCaptionMemory[Mode, Key]);
     end;
  CQCaptionMemory[Mode, Key]^                               := MemoryString;
  CQCaptionMemory[Mode, Key]^[length(MemoryString) + 1]     := #0;
end;

procedure SetEXCaptionMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString);

begin

  { REFUSE A KEY THIS ARRAY CANNOT HOLD.

    FunctionKeyMemoryArray is [CW..Phone, F1..AltF12] -- 112..147. Range checking
    is off in this build, so an index outside that does not raise: it writes a
    heap pointer into whatever global happens to sit there, and the damage
    surfaces somewhere else entirely. That is exactly what happened on
    2026-08-15: a config line whose key prefix was not F/A/C produced CHR(1..12)
    here, and the crash appeared later in ShowFMessages dereferencing a
    neighbouring global that now looked like a valid pointer.

    The caller was fixed too, but this is the layer that owns the invariant, and
    a silent out-of-bounds write is worth refusing wherever it arrives from. }
  if not (Key in [F1..AltF12]) then
     begin
     logger.Error('[SetEXCaptionMemoryString] key #%d is outside F1..AltF12 -- ignored',
                  [Ord(Key)]);
     Exit;
     end;

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;
  if EXCaptionMemory[Mode, Key] = nil then
     begin
     New(EXCaptionMemory[Mode, Key]);
     end;
  EXCaptionMemory[Mode, Key]^                               := MemoryString;
  EXCaptionMemory[Mode, Key]^[length(MemoryString) + 1]     := #0;
end;

procedure SetCQMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString {Str80});

begin
  { REFUSE A KEY THIS ARRAY CANNOT HOLD -- and this one matters more than
    the caption pair, because of what sits next to it.

    CQMemory, EXMemory, CQCaptionMemory and EXCaptionMemory are four
    adjacent globals of the same type (LogCW.pas:86-90). Range checking
    is off, so an index past AltF12 here does not raise -- it writes a
    freshly New()ed pointer into the NEXT array along. That is a
    non-nil, valid-looking pointer in a slot nothing ever allocated,
    and whoever reads it later takes the access violation, in another
    unit, with nothing to connect the two. }
  if not (Key in [F1..AltF12]) then
     begin
     logger.Error('[SetCQMemoryString] key #%d is outside F1..AltF12 -- ignored, it '
                  + 'would have written into the next array',
                  [Ord(Key)]);
     Exit;
     end;

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;

  if CQMemory[Mode, Key] = nil then
     begin
     New(CQMemory[Mode, Key]);
     end;
  {KK1L: 6.72 NOTE This is where I should interpret the string just as if it were being read from LOGCFG.DAT}
  SniffOutControlCharacters(MemoryString); {KK1L: 6.72}
  CQMemory[Mode, Key]^                                      := MemoryString;
  CQMemory[Mode, Key]^[length(MemoryString) + 1]            := #0;
end;

procedure SetEXMemoryString(Mode: ModeType; Key: Char; MemoryString: ShortString {Str80});

begin
  { REFUSE A KEY THIS ARRAY CANNOT HOLD -- and this one matters more than
    the caption pair, because of what sits next to it.

    CQMemory, EXMemory, CQCaptionMemory and EXCaptionMemory are four
    adjacent globals of the same type (LogCW.pas:86-90). Range checking
    is off, so an index past AltF12 here does not raise -- it writes a
    freshly New()ed pointer into the NEXT array along. That is a
    non-nil, valid-looking pointer in a slot nothing ever allocated,
    and whoever reads it later takes the access violation, in another
    unit, with nothing to connect the two. }
  if not (Key in [F1..AltF12]) then
     begin
     logger.Error('[SetEXMemoryString] key #%d is outside F1..AltF12 -- ignored, it '
                  + 'would have written into the next array',
                  [Ord(Key)]);
     Exit;
     end;

  if Mode = Digital then
     begin
     Mode                               := CW;
     end;

  if EXMemory[Mode, Key] = nil then
     begin
     New(EXMemory[Mode, Key]);
     end;
  {KK1L: 6.72 NOTE This is where I should interpret the string just as if it were being read from LOGCFG.DAT}
  SniffOutControlCharacters(MemoryString); {KK1L: 6.72}
  EXMemory[Mode, Key]^                                      := MemoryString;
  EXMemory[Mode, Key]^[length(MemoryString) + 1]            := #0;
end;

procedure InitializeKeyer;
begin
//  ActiveKeyerPort                                         := Radio1.tKeyerPort;
  SerialInvert                                              := Radio1SerialInvert;
  CPUKeyer.InitializeKeyer;
  // Runs after the config is loaded (LogCfg calls this), so the warning can
  // see the final keyer settings: one Warn per conflicting combination, rather
  // than the operator discovering the precedence by experiment.
  WarnIfKeyerConfigsConflict;
end;

procedure UnInitializeKeyer;

begin
  //  if CPUKeyer.KeyerInitialized then
  CPUKeyer.UnInitializeKeyer;
end;

procedure SetUpToSendOnActiveRadio;

//var
  //TimeOut                               : Byte;

begin

  {
    if (ActiveMode = Phone) and Config.DVKEnable and DVPActive and DVPMessagePlaying then
      begin
        TimeOut                                             := 0;
 
        DVPStopPlayback;
 
        repeat
          Wait(5);
          inc(TimeOut);
        until (not DVPMessagePlaying) or (TimeOut > 50);
      end;
  }
  if ActiveRadio = RadioOne then
     begin
     if not SendingOnRadioOne then
        begin
        FlushCWBufferAndClearPTT('LogCW: SetUpToSendOn*Radio - clear CW on the radio being left');
  //      ActiveKeyerPort                                     := Radio1.tKeyerPort;
  //      tActiveKeyerHandle                                  := Radio1.tKeyerPortHandle;
        SerialInvert                                          := Radio1SerialInvert;
            {CodeSpeed                                        := RadioOneSpeed;}
        if not Radio1.CWSpeedSync then     // ny4i: radio is master → don't push speed back
           begin
           CodeSpeed := Radio1.SpeedMemory; {KK1L: 6.73}
           SetSpeed(CodeSpeed);
           end
        else
           begin
           CodeSpeed := Radio1.SpeedMemory; {KK1L: 6.73}
           end;
            {KK1L: 6.71 Need to set mode to that of ModeMemory [RadioOne] for split mode SO2R}
            {KK1L: 6.72 Moved this to SendCrypticMessage to only handle CTRL-A requests      }
            {           SwapRadios is run prior to coming here for SO2R and that hoses things}
            {ActiveMode                                       := ModeMemory [RadioOne]; {KK1L: 6.71 for split mode SO2R}
        SendingOnRadioOne                                     := True;
        SendingOnRadioTwo                                     := False;
        SetRelayForActiveRadio(ActiveRadio);
        end;
     end

  else { Radio Two }

    if not SendingOnRadioTwo then
       begin
       FlushCWBufferAndClearPTT('LogCW: SetUpToSendOn*Radio - clear CW on the radio being left');

 //      ActiveKeyerPort                                     := Radio2.tKeyerPort;
 //      tActiveKeyerHandle                                  := Radio2.tKeyerPortHandle;
       SerialInvert                                          := Radio2SerialInvert;
         {CodeSpeed                                          := RadioTwoSpeed;}
       if not Radio2.CWSpeedSync then     // ny4i: radio is master → don't push speed back
          begin
          CodeSpeed := Radio2.SpeedMemory; {KK1L: 6.73}
          SetSpeed(CodeSpeed);
          end
       else
          begin
          CodeSpeed := Radio2.SpeedMemory; {KK1L: 6.73}
          end;
         {KK1L: 6.71 Need to set mode to that of ModeMemory [RadioTwo] for split mode SO2R}
         {KK1L: 6.72 Moved this to SendCrypticMessage to only handle CTRL-A requests      }
         {           SwapRadios is run prior to coming here for SO2R and that hoses things}
         {ActiveMode                                         := ModeMemory [RadioTwo]; {KK1L: 6.71 for split mode SO2R}
       SendingOnRadioOne                                     := False;
       SendingOnRadioTwo                                     := True;
       SetRelayForActiveRadio(ActiveRadio);
       end;
    // If this line really wantsa to send F1 upon if CWByCat, it would beed to call IsActiveCWByCAT
    // but as this code is called in other places, I do not believe this is the right thing to do.
    // ny4i
//if cwbycat then ActiveRadioPtr.SendCW(F1);  // ny4i - This does not do anything. This is not the right variable to check.
  wkSetKeyerOutput(ActiveRadioPtr);

  KeyersSwapped                                             := False;
 // InactiveRigCallingCQ                                    := False; // n4af 4.44.7
end;

procedure SetUpToSendOnInactiveRadio;

{ This used to swap ActiveRadio as well, but I decided not to do that
  anymore.  }

{var
  TimeOut                               : Byte;
}
begin

  if KeyersSwapped then Exit; { Already swapped to inactive rig }
  DebugMsg('>>>>>ENTER SetUpToSendOnInactiveRadio');
{
  if (ActiveMode = Phone) and Config.DVKEnable and DVPActive and DVPMessagePlaying then
  begin
    TimeOut                                                 := 0;

      DVPStopPlayback;

      repeat
        Wait(5);
        inc(TimeOut);
      until (not DVPMessagePlaying) or (TimeOut > 50);

  end;
}
  if ActiveRadio = RadioOne then
     begin
     if not SendingOnRadioTwo then
        begin
        FlushCWBufferAndClearPTT('LogCW: SetUpToSendOnInactiveRadio - clear CW on the active radio');
  //      ActiveKeyerPort                                     := Radio2.tKeyerPort;
  //      tActiveKeyerHandle                                  := Radio2.tKeyerPortHandle;
        SerialInvert                                          := Radio2SerialInvert;
            {CodeSpeed                                        := RadioTwoSpeed;}
        CodeSpeed                                             := Radio2.SpeedMemory; {KK1L: 6.73}
        SetSpeed(CodeSpeed);
        SetRelayForActiveRadio(RadioTwo);
            {KK1L: 6.71 Need to set mode to that of ModeMemory [RadioTwo] for split mode SO2R}
            {ActiveMode                                       := ModeMemory [RadioTwo]; {KK1L: 6.71 for split mode SO2R}
        SendingOnRadioOne                                     := False;
        SendingOnRadioTwo                                     := True;
        end;
     end

  else { Active radio = radio two }

    if not SendingOnRadioOne then
       begin
       FlushCWBufferAndClearPTT('LogCW: SetUpToSendOnInactiveRadio - clear CW on the active radio');
 //      ActiveKeyerPort                                     := Radio1.tKeyerPort;
 //      tActiveKeyerHandle                                  := Radio1.tKeyerPortHandle;
       SerialInvert                                          := Radio1SerialInvert;
         {CodeSpeed                                          := RadioOneSpeed;}
       CodeSpeed                                             := Radio1.SpeedMemory; {KK1L: 6.73}
       SetSpeed(CodeSpeed);
       SetRelayForActiveRadio(RadioOne);
         {KK1L: 6.71 Need to set mode to that of ModeMemory [RadioOne] for split mode SO2R}
         {ActiveMode                                         := ModeMemory [RadioOne]; {KK1L: 6.71 for split mode SO2R}
       SendingOnRadioOne                                     := True;
       SendingOnRadioTwo                                     := False;
       end;

  wkSetKeyerOutput(InActiveRadioPtr);

  KeyersSwapped                                             := True;
  DebugMsg('<<<<< EXIT SetUpToSendOnInactiveRadio');
end;

// Single owner of the CW on/off state. Keeps the two flags (Config.CWEnable and
// CWEnabled) coherent, flushes the keyer buffer and drops PTT when disabling,
// and refreshes the speed display. All callers that turn CW on or off should
// route through here so the on-screen state can never disagree with reality.
// ny4i 2026JUN10 (Issue 380)
procedure SetCWState(Enable, DisplayPrompt: boolean);
begin
   if Enable then
      begin
      Config.CWEnable  := True;
      CWEnabled := True;
      QuickDisplay('');
      end
   else
      begin
      if DisplayPrompt then
         begin
         QuickDisplay(TC_CWDISABLEDWITHALTK);
         end;
      FlushCWBufferAndClearPTT;
      Config.CWEnable  := False;
      CWEnabled := False;
      end;
   DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
   SetSpeed(CodeSpeed);
end;

procedure ToggleCW(DisplayPrompt: boolean);
begin
   if ActiveMode = CW then
      begin
      SetCWState(not (CWEnabled or Config.CWEnable), DisplayPrompt);
      end
   else
      begin
      if Config.DVKEnable then
         begin
         Escape_proc;
         if DisplayPrompt then
            begin
            QuickDisplay(TC_VOICEKEYERDISABLEDWITHALTK);
            end;
         end
      else
         begin
         SetTextInQuickCommandWindow('');
         end;
      InvertBoolean(Config.DVKEnable);
      DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
      SetSpeed(CodeSpeed);
      end;
end;

procedure CWInit;
begin

//  SetEXCaptionMemoryString(CW, F1, 'DE+Cl');
//  SetEXCaptionMemoryString(CW, F2, 'Ex');
//  SetEXCaptionMemoryString(CW, F3, 'RST');

//  SetEXCaptionMemoryString(Digital, F1, 'DE+Cl');
//  SetEXCaptionMemoryString(Digital, F2, 'S&P EXCHANGE');
    slElements                                              := TStringList.Create;
    LoadElements(slElements);
end;

begin
  CWInit;
  DebugMsg('foo');
end.

