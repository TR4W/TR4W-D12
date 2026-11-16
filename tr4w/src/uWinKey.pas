{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uWinKey;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  (* CreateUpDownControl -- the WinKeyer settings dialog is still a raw Win32 dialog.
    That window is not converted yet; this uses entry goes with it. *)
  LogRadio,
  (* LCLType replaces Messages entirely and Windows almost entirely
    (2026-09-08): DWORD on the serial read/write signatures is what they were
    here for, and the one live Win32 UI call was a WINKEYDEBUG trace that could
    not have compiled, now deleted.

    Windows SURVIVES, gated, for QueryPerformanceCounter alone -- see wkPerfNow. *)
  LCLType,
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
  VC,
  utils_file,
  (* TSerialPort -- the WinKeyer is on the same transport as the radios and
    the rotators now. In the INTERFACE clause because WinKeyPort below is. *)
  uSerialPort,
  TF,
  Tree
  ,
  uTR4WStrings;

(* THE ONE WAY TO STOP AND START THE WINKEYER -- startup, the Alt-menu re-open
  and a profile apply (uRadioConfigApply.ApplyProfile: Preferences Activate or
  Save, the setup wizard) all go through this pair, and nothing else calls
  wkOpen.

  wkStop WAITS: for an open in progress to finish, then for the reader thread
  to leave, and only then closes the port and frees its object, so the next
  open is made against the port the settings name NOW (a TSerialPort's name is
  fixed when it is created).  Bounded: if either thread outlives
  WK_STOP_WAIT_MS it logs an Error and touches nothing -- a port still held
  is a leak, a port closed under a running thread is a fault -- and wkStart
  refuses until that thread has gone.

  wkStart OPENS ON A WORKER THREAD, never on the caller's: the echo test and
  the HOST OPEN reply are blocking reads.  It does nothing when the WinKeyer is
  not enabled, while an open or an old reader is still running, or in a run
  with no station (the headless /EXPORT, the unit tests). *)
procedure wkStop;
procedure wkStart;

(* False with aReason saying why -- for the log; wkOpenThreadProc reports it. *)
function wkOpen(out aReason: string): boolean;
function wkOpenThreadProc(aParameter: Pointer): DWORD; stdcall;   (* wkOpen, as a tCreateThread body *)
function wkOpenPort(out aReason: string): boolean;
function wkSendByte(b: Byte): Cardinal;
function wkSendTwoBytes(B1, B2: Byte): Cardinal;
procedure wkSetSpeed(Speed: integer);
//procedure wkChangeSpeedBuffered;
function wkRead(nNumberOfBytesToRead: DWORD): boolean;
procedure wkClose;
procedure wkClearBuffer;
function wkHasPendingOutput: boolean;
procedure wkSendCWChar(c: AnsiChar);
procedure wkSetupSpeedPot;
//procedure wkSaveSettings;
//procedure wkLoadSettings;
function wkTurnPTT(Turn: boolean): boolean;
procedure wkDispayState;
function wkReadThreadProc(aParameter: Pointer): DWORD; stdcall;
// DEAD CODE.  Nothing starts this thread -- wkInit creates wkReadThreadProc
// (tCreateThread(wkReadThreadProc, ...)) and wkReadThreadProc1 is referenced
// nowhere else.  Kept only as the older parsing variant.  Beware: its status
// handling DIFFERS from the live one -- it sets wkBUSY True for ANY byte below
// $C0 and detects end-of-buffer with byte = 192, where the live parser uses the
// status byte's busy BIT.  Editing this procedure has no effect at run time; it
// cost a bench cycle on 2026-07-31.
procedure wkReadThreadProc1;
procedure wkAddCWMessageToInternalBuffer(Msg: Str160);
procedure wkAddCharToHostBuffer(c: AnsiChar);
procedure wkSetKeyerOutput(r: RadioPtr);
function wkSendNextByteFromHostBuffer: boolean;
procedure wkSwapTune;
//procedure wkSetLeadInTail;

type
  TWK2KeyerMode = (kmIambicB, kmIambicA, kmUltimatic, kmBugMode);
  TWKSidetoneFrequency = (stf4000, stf2000, stf1333, stf1000, stf800, stf666, stf571, stf500, stf444, stf400);

const
  KeyerModeSA                           : array[TWK2KeyerMode] of string = ('IAMBIC B', 'IAMBIC A', 'ULTIMATIC', 'BUG MODE');
  SidetoneFrequencySA                   : array[TWKSidetoneFrequency] of string = ('4000', '2000', '1333', '1000', '800', '666', '571', '500', '444', '400');
type
  TwkValueList = packed record
    {(*}
    vlCommandCode      : Byte;//$0F - default value
    vlModeRegister     : Byte;//$02 - default value
    vlSpeedinWPM       : Byte;//$10 - default value
    vlSidetoneFrequency: TWKSidetoneFrequency{Byte};//$05 - default value

    vlWeight           : Byte;//$32 - default value
    vlLeadInTime       : Byte;//$00 - default value
    vlTailTime         : Byte;//$00 - default value
    vlMinWPM           : Byte;//$05 - default value

    vlWPMRange         : Byte;//$14 - default value
    vl1stExtension     : Byte;//$00 - default value
    vlKeyCompensation  : Byte;//$00 - default value
    vlFarnsworthWPM    : Byte;//$12 - default value

    vlPaddleSWPoint    : Byte;//$32 - default value
    vlDitDahRatio      : Byte;//$32 - default value
    vlPinConfiguration : Byte;//$06 - default value
    vlDontcare         : Byte;//$FF - default value
    {*)}
  end;

type
  TWinKeySettings = packed record
    {(*}
    {16}wksValueList      : TwkValueList;

    {01}wksWinKey2Port    : PortType;

    (* THE OS NAME OF THE PORT -- 'COM7', '/dev/ttyUSB0'.  NY4I, 2026-09-13:
      "ports should be the OS name... It is not pretty but what the user would
      expect versus an artificial abstraction."

      BESIDE THE ORDINAL, NOT INSTEAD OF IT -- the widen half of
      widen-then-narrow, and the same shape the radio already carries as
      tCATPortName.  Empty means "no name configured", and the ordinal answers
      as it always did, so Windows behaviour is unchanged until a name is
      stored.

      WITHOUT IT A WINKEYER CANNOT BE CONFIGURED OFF WINDOWS AT ALL: no
      arithmetic on an ordinal produces /dev/ttyUSB0, so the guard below saw
      NoPort and refused a port that was perfectly real.

      SAFE IN A PACKED RECORD.  Only the INNER TwkValueList is a wire format
      -- wkWriteRaw sends exactly SizeOf(TwkValueList) -- and nothing copies,
      FillChars or sizes the outer record, which was checked rather than
      assumed before a managed type was put in it. *)
    wksWinKey2PortName: string;
    {01}wksWinKey2Enable  : boolean;
    {01}wksAutospace      : boolean;
    {01}wksCTSpacing      : boolean;

    {01}wksPaddleSwap     : boolean;
    {01}wksKeyerMode      : TWK2KeyerMode;
    {01}wksIgnoreSpeedSpot: boolean;
    {01}wksSideTEnable    : boolean;

    {01}wksPadOnlySideT   : boolean;
    {01}wkres02           : Byte;
    {01}wkres03           : Byte;
    {01}wkres04           : Byte;

    {01}wkres05           : Byte;
    {01}wkres06           : Byte;
    {01}wkres07           : Byte;
    {01}wkres08           : Byte;

    {01}wkres09           : Byte;
    {01}wkres10           : Byte;
    {01}wkres11           : Byte;
    {01}wkres12           : Byte;

    {01}wkres13           : Byte;
    {01}wkres14           : Byte;
    {01}wkres15           : Byte;
    {01}wkres16           : Byte;
//    {01}wkres17           : Byte;
//    {01}wkres18           : Byte;
    {*)}
  end;

  (* AN ADMIN COMMAND IS EXACTLY TWO BYTES, and naming the type makes the
    compiler hold it to that: wkSendAdminCommand used to take an untyped
    `const Buffer` and read two bytes through an `absolute` view of whatever
    it was given (P12, 2026-10-18). *)
  TwkAdminCommand = array[0..1] of Byte;

const
  // ADMIN COMMANDS -- two RAW BYTES on the wire ($00 + sub-command), passed to
  // wkSendAdminCommand and written verbatim.
  //
  // These MUST be typed as bytes, not written as character literals.  They used
  // to read `wkECHOTEST = #$00#$04;`, which under Delphi 7 was an AnsiString --
  // exactly the two bytes 00 04.  Under Delphi 12 the same literal is a
  // UnicodeString, so its bytes are 00 00 04 00, and the `array[0..1] of Byte
  // absolute Buffer` view inside wkSendAdminCommand read the first two of those:
  // $00 $00.  EVERY admin command therefore went out as CALIBRATE.  The keyer
  // never saw an ECHO TEST, never answered, and wkOpen failed on every attempt
  // -- the WinKeyer simply would not connect under D12 (NY4I bench, COM20,
  // 2026-07-31; the log showed the handshake bytes going out and nothing
  // coming back, with [wkSendAdminCommand] B1=$00 B2=$00).
  //
  // A byte array cannot silently change width, so this class of bug cannot
  // recur here.
  wkCALIBRATE   : TwkAdminCommand = ($00, $00);
  wkRESET       : TwkAdminCommand = ($00, $01);
  wkHOSTOPEN    : TwkAdminCommand = ($00, $02);
  wkHOSTCLOSE   : TwkAdminCommand = ($00, $03);
  wkECHOTEST    : TwkAdminCommand = ($00, $04);
  wkGETVALUES   : TwkAdminCommand = ($00, $07);

  wkSETWK1MODE  : TwkAdminCommand = ($00, $0A);
  wkSETWK2MODE  : TwkAdminCommand = ($00, $0B);

  wkECHOTESTBYTE                        = $55;

  WKCMD_SIDETONECONTROL                 = $01;
  wkCMD_SETWPMSPEED                     = $02;
  wkCMD_SETWEIGHTING                    = $03;
  wkCMD_SETPTTLEADTAIL                  = $04;
  wkCMD_SETUPSPEEDPOT                   = $05;
  wkCMD_GETPOT                          = $07;
  wkCMD_BACKSPACE                       = $08;

  wkCMD_SETPINCONFIG                    = $09;
  wkCMD_CLEARBUFFER                     = $0A;
  wkCMD_KEYIMMEDIATE                    = $0B;
  wkCMD_SETWINKEYER2MODE                = $0E;
  wkCMD_LOADDEFAULTS                    = $0F;
  wkCMD_NULLIMM                         = $13;
  wkCMD_SETDITDAHRATIO                  = $17;
  wkCMD_PTTONOFF                        = $18;
  wkCMD_CHANGESPEEDBUFFERED             = #$1C;
  SizeOfHostBuffer                      = 512;

//  wk_STATUS_BYTE_START                  = 196;
//  wk_STATUS_BYTE_END                    = 192;
var
  wkTune                                : boolean;
  WK2                                   : boolean;
  wkSpeedUp                             : integer;
  wkSpeedDown                           : integer;

  wkSpeedChanged                        : boolean;
  wkActive                              : LongBool = False;
  wkCWSpeed                             : integer;

  wkBUSY                                : boolean = False; // 4.90.5
  wkBREAKIN                             : boolean;
  wkXOFF                                : boolean;

  wkThreadID                            : TThreadID;
  wkCWThreadID                          : Cardinal;

//  wkThreadHWND                          : HWND = INVALID_HANDLE_VALUE;
  (* THE PORT, AS AN OBJECT. This was a raw THandle with its own CreateFileA,
    DCB and COMMTIMEOUTS -- a third private serial stack beside the radios' and
    the rotators'. It is the same TSerialPort as both of those now, so a
    WinKeyer is as portable as a radio is.

    nil means closed, and every routine that used to compare the handle against
    INVALID_HANDLE_VALUE asks wkPortOpen instead. *)
  WinKeyPort                            : TSerialPort = nil;

  wkREADBuffer                         : array[0..32] of Byte;
  wkThreadReadBuffer                    : array[0..15] of Byte;
  wkInternalCWBuffer                    : array[0..SizeOfHostBuffer - 1] of AnsiChar;

  wkHostBufferIndex                     : integer;
  wkHostBufferSendIndex                 : integer;

  wkWaitingBytesInHost                  : integer;
  wkWaitingBytesInWK                    : integer;

//  wkClearEnable                         : boolean;
  wkPTTOn                               : boolean;

//  wkSpeedUpPos                          : integer = -1;
//  wkSpeedDownPos                        : integer = -1;

//  wkSpeedUpValue                        : integer = -1;
//  wkSpeedDownValue                      : integer = -1;


  WinKeySettings                        : TWinKeySettings =
    (
{(*}
    wksValueList: (
    vlCommandCode:       wkCMD_LOADDEFAULTS;
    vlModeRegister:      2;
    vlSpeedinWPM:        35;
    vlSidetoneFrequency: stf800; //10000100
    vlWeight:            $32;
    vlLeadInTime:        0;
    vlTailTime:          0;
    vlMinWPM:            2;
    vlWPMRange:          99;
    vl1stExtension:      0;
    vlKeyCompensation:   0;
    vlFarnsworthWPM:     $12;
    vlPaddleSWPoint:     $32;
    vlDitDahRatio:       $32;
    vlPinConfiguration:  6;
    vlDontcare:          $FF;
    );
    wksWinKey2Port:      NoPort;
    wksWinKey2PortName:  '';
    wksWinKey2Enable:    False;

    wksAutospace:        False;
    wksCTSpacing:        False;
    wksPaddleSwap:       False;
    wksKeyerMode:        kmIambicB;
    wksIgnoreSpeedSpot:  True;
    wksSideTEnable:   True;
{*)}
    );

    //0F 02 5D 06 32 00 00 05 5E 00 00 12 32 32 06 FF   07 15

const
  wkMINWPM                              = 10;
  wkWPMRANGE                            = 40;

procedure wkSendAdminCommand(const aCommand: TwkAdminCommand);

type
  (* LOAD DEFAULTS is a sixteen-byte message; the type says so. *)
  TwkValueListWire = array[0..15] of Byte;

(* THE LOAD DEFAULTS VALUE LIST AS IT GOES ON THE WIRE: sixteen bytes in the
  WinKeyer's own order, one per field. It used to be written as the packed
  record's memory image, which made the record's field order the wire format
  by accident; this states it (P12, 2026-10-18). Pinned by uTestWinKeyWire. *)
function wkValueListBytes(const aList: TwkValueList): TwkValueListWire;

implementation


uses
   uPortAddress,   // SerialDeviceName -- the one port-name rule
   uSettingsModel, // Settings.Cq.AutoDelay
   uAppTimers,   (* StartAppTimer / StopAppTimer -- LCL TTimers, not SetTimer *)
  uMainForm,   { the main window's elements are LCL controls }
  uKeyerState, { the keyer's state. This unit runs on read threads and must not
                 name a control -- see wkDispayState and wkOpen }
  uMainThreadWork, (* mtCodeSpeedDisplay -- the speed pot's readout, issue #108;
                      mtWinKeyerSendEnded -- the end of a message, issue #132 *)
  SysUtils,
  uNet,
  LogDupe,
  uTelnet, {LogRadio,}
  LogWind,
  LogCW,
  LogK1EA,
  CfgCmd,
  uCWKeyerBase,   (* ActiveCWKeyer -- where CW goes when the open fails (H5) *)
  MainUnit;

(* FORWARD, because the port helpers are defined beside wkOpenPort at the
  bottom of the unit -- with the routine whose port they belong to -- and
  almost everything above calls them. *)
function wkPortOpen: boolean; forward;
function wkWriteRaw(const aBytes: array of Byte): Cardinal; forward;

const
  (* The open's worst case is about 1 s at 1200 baud (wkOpenPort's 200 ms
    settle, two 250 ms reads, the configuration writes); the reader leaves
    within one 10 ms read.  Three seconds is a generous bound on both. *)
  WK_STOP_WAIT_MS = 3000;

var
  (* THE TWO THREADS, BY FLAG -- set by the CREATOR before tCreateThread and
    cleared by the thread itself in a finally, the PollingThreadRunning rule.
    wkThreadID cannot answer: both threads have always written it. *)
  wkOpening       : Boolean = False;
  wkReaderRunning : Boolean = False;

  (* THE HANDSHAKE IS THE OPEN THREAD'S ALONE (review M12).  wkPortOpen goes
    True when the port opens, before the settle delay, the echo test and the
    configuration writes -- and wkSetSpeed, wkSetKeyerOutput and wkTurnPTT
    guard on wkPortOpen alone, so a byte from the main thread could land
    between ECHO TEST and its echo byte and fail the open.  wkWriteRaw, the
    one write path, refuses every other thread while this is up.  Set and
    cleared by wkOpen; cleared BEFORE the reader starts, so the reader and the
    main thread write freely from then on. *)
  wkHandshaking      : Boolean = False;
  wkHandshakeThread  : TThreadID;

(* CLOSE THE PORT AND FREE ITS OBJECT -- the second half of a stop, and what a
  start does first with a port a timed-out stop left behind. Only when no
  thread of ours can reach it: the caller has seen both flags down. *)
procedure wkReleasePort;
begin
  wkClose;
  (* FREED, NOT ONLY CLOSED: the port name is fixed at Create, so a keyer moved
    to another port would otherwise be reopened on the old one. *)
  FreeAndNil(WinKeyPort);
end;

(* A WINKEYER THAT DID NOT OPEN IS REPORTED, EVERY TIME (review H5).  It used
  to fail in silence -- no echo, no log line -- and ActiveCWKeyer then fell
  through to the next keyer, so a keyer that was off or on the wrong port
  keyed CW through DTR/RTS with nothing said.  The precedence itself is not
  changed here (that is the open CW INTERFACE question); what changes is that
  the operator is told, once, and the log says why and where CW goes now.
  Any thread: the open runs on a worker, and the notice marshals itself. *)
procedure wkReportNotOpened(const aReason: string);
var
  portName: string;
  keyer: TCWKeyer;
  keyerName: string;
begin
  portName := EffectiveDeviceName(WinKeySettings.wksWinKey2PortName,
                                  WinKeySettings.wksWinKey2Port);
  if portName = '' then
     begin
     portName := 'NONE';
     end;
  keyer := ActiveCWKeyer;
  if keyer <> nil then
     begin
     keyerName := keyer.Name;
     end
  else
     begin
     keyerName := 'no keyer';
     end;
  logger.Error('[WinKey] the WinKeyer on %s did not open: %s. CW now goes to the %s',
               [portName, aReason, keyerName]);
  QuickDisplay(UnicodeFormat(TC_WINKEYERDIDNOTOPEN, [portName]));
end;

procedure wkStop;
begin
  (* THE OPEN FIRST.  Clearing wkActive while it is still running would be
    undone: it sets wkActive and starts a reader nobody is waiting for. *)
  if not WaitForFlagToClear(wkOpening, GetTickCount64 + WK_STOP_WAIT_MS) then
     begin
     logger.Error('[WinKey] stop: the open in progress did not finish within %d ms; ' +
                  'the port is left as it is', [WK_STOP_WAIT_MS]);
     Exit;
     end;

  wkActive := False;
  if not WaitForFlagToClear(wkReaderRunning, GetTickCount64 + WK_STOP_WAIT_MS) then
     begin
     logger.Error('[WinKey] stop: the reader thread did not exit within %d ms; ' +
                  'the port is left as it is', [WK_STOP_WAIT_MS]);
     Exit;
     end;

  (* Safe because no thread of ours can reach the port now. *)
  wkReleasePort;
end;

procedure wkStart;
begin
  (* NO STATION, NO PORT.  The headless /EXPORT never reaches startup's open,
    but this is the one place every open passes, so it says so here too. *)
  if tSilentExport or WarningsHaveNoOperator then
     begin
     Exit;
     end;
  if not WinKeySettings.wksWinKey2Enable then
     begin
     Exit;
     end;
  if wkOpening then
     begin
     logger.Warn('[WinKey] not opening: an open is already in progress');
     Exit;
     end;
  if wkReaderRunning then
     begin
     wkReportNotOpened('the previous reader thread is still running');
     Exit;
     end;

  (* A PORT A TIMED-OUT STOP LEFT BEHIND (review M12).  wkStop leaves the port
    alone when a thread outlives its wait, and a profile apply carries on and
    rewrites the keyer's port.  Once that thread has gone -- both flags are
    down here -- the next start found the old object and wkOpenPort reopened
    it, on the OLD port, whatever the settings now say.  Finish the stop. *)
  if WinKeyPort <> nil then
     begin
     logger.Warn('[WinKey] releasing the port object a previous stop did not free, ' +
                 'so the open uses the port the settings name now');
     wkReleasePort;
     end;

  wkOpening := True;
  logger.Info('Calling tCreateThread from WinKeyer');
  if not ThreadStarted(tCreateThread(wkOpenThreadProc, wkThreadID)) then
     begin
     wkOpening := False;
     logger.Error('[WinKey] the open thread could not be started');
     Exit;
     end;
  logger.Info('Created WinKeyer thread with threadid of %u',[PtrUInt(wkThreadID)] );
end;

(* THE OPEN ITSELF; wkOpen wraps it in the handshake gate.  Every False comes
  with a reason, which wkOpenThreadProc reports. *)
function wkOpenAndConfigure(out aReason: string): boolean;
var
  versionByte : Byte;
  family      : Byte;
begin
  Result := False;
  aReason := '';

  if WinKeySettings.wksWinKey2Enable = False then
     begin
     aReason := 'WINKEYER ENABLE is off';
     Exit;
     end;
  (* NO ORDINAL GUARD HERE ANY MORE.  `wksWinKey2Port = NoPort` exited before
    wkOpenPort could apply its name-first rule, and a device node such as
    '/dev/ttyUSB0' has no ordinal -- so a WinKeyer on Linux or macOS was never
    opened, in silence.  wkOpenPort decides, and says why when it refuses. *)
  if not wkOpenPort(aReason) then
     begin
     Exit;
     end;

  // Send three null commands to resync host to WK2
  wkSendByte(wkCMD_NULLIMM);
  wkSendByte(wkCMD_NULLIMM);
  wkSendByte(wkCMD_NULLIMM);

  wkSendAdminCommand(wkECHOTEST);
  wkSendByte(wkECHOTESTBYTE);
//  Sleep(150);

  if not wkRead(1) then
     begin
     aReason := 'no reply to the echo test (is the keyer powered, and on this port?)';
     wkClose;
     Exit;
     end;
  if wkREADBuffer[0] <> wkECHOTESTBYTE then
     begin
     aReason := UnicodeFormat('the echo test returned $%s, not $%s (is this port a WinKeyer?)',
                       [IntToHex(wkREADBuffer[0], 2), IntToHex(wkECHOTESTBYTE, 2)]);
     wkClose;
     Exit;
     end;

  wkSendAdminCommand(wkHOSTOPEN);
//  Sleep(150);

  (* Zero the byte the next read fills. Only [0] is ever looked at afterwards
    (the version byte), so the old four-byte store through PCardinal -- itself
    from an asm "zero first dword" -- cleared three bytes nothing reads.
    Pointer audit 3.4. *)
  wkREADBuffer[0] := 0;
  if wkRead(1) then
     begin
     // The keyer's HOST OPEN response is its firmware-revision byte.
     // Map it to a family digit for the status display:
     //   v < 20   -> WK1     (legacy WinKeyer)
     //   v 20-29  -> WK2     (WinKeyer2)
     //   v >= 30  -> WK3     (WinKeyer3 — was previously displayed as WK2
     //                        because the family was tracked as a single
     //                        Boolean WK2 := version >= 20.  Issue #891)
     versionByte := wkREADBuffer[0];
     WK2 := versionByte >= 20;
     if versionByte >= 30 then
        begin
        family := 3
        end
     else if versionByte >= 20 then
        begin
        family := 2
        end
     else
        begin
        family := 1;
        end;
     { STATE, NOT A WIDGET. This built 'WK%d v%d' and assigned it straight to
       mweWinKey -- from wkOpen, which uProgramMain starts with tCreateThread.
       The family and the version are the FACTS; how the main window spells
       them is uStateBridge's business. Set together so the view cannot see a
       new family beside an old version. }
     if KeyerState <> nil then
        begin
        KeyerState.SetIdentity(family, versionByte);
        end;
     end;
  (* DOWN TO 10 ms, now that identification is done and the reader thread is
    about to take over. See the note below on why the thread starts last. *)
  WinKeyPort.ReadTimeoutMs := 10;

  wkSendAdminCommand(wkSETWK1MODE);

//  WinKeySettings.wksValueList.vlModeRegister := WinKeySettings.wksValueList.vlModeRegister + 4;
  WinKeySettings.wksValueList.vlModeRegister :=
    integer(WinKeySettings.wksCTSpacing) * 1 +
    integer(WinKeySettings.wksAutospace) * 2 +
    4 +
    integer(WinKeySettings.wksPaddleSwap) * 8 +
    integer(WinKeySettings.wksKeyerMode) * 16 +
    128;

//          if WinKeySettings.wksKeyerMode = kmIambicA then TempInteger := TempInteger + 16;
//          if WinKeySettings.wksKeyerMode = kmUltimatic then TempInteger := TempInteger + 32;
//          if WinKeySettings.wksKeyerMode = kmBugMode then TempInteger := TempInteger + 48;

  WinKeySettings.wksValueList.vlSpeedinWPM := ActiveRadioPtr.SpeedMemory;
  wkWriteRaw(wkValueListBytes(WinKeySettings.wksValueList));
//  wkSetupSpeedPot;
  wkSendByte(wkCMD_GETPOT);
//  wkSendTwoBytes(wkCMD_SETWEIGHTING, WinKeySettings.wkWeighting);
//  wkSendTwoBytes(wkCMD_SETDITDAHRATIO, WinKeySettings.wkDitDahRatio);
  wkSendTwoBytes(WKCMD_SIDETONECONTROL, Byte(WinKeySettings.wksPadOnlySideT) * 128 + Byte(WinKeySettings.wksValueList.vlSidetoneFrequency) + 1);
  wkSetKeyerOutput(ActiveRadioPtr);
  wkClearBuffer;
//  wkSetLeadInTail;

  // Start the reader ONLY after the device is fully configured.
  //
  // The port is opened WITHOUT FILE_FLAG_OVERLAPPED, so Windows serializes
  // reads and writes on this handle: a write queues behind any in-flight read.
  // wkReadThreadProc loops on ReadFile at ~100% duty, so starting it first made
  // every configuration write above fight the reader for the handle.  Measured
  // on NY4I's bench 2026-07-31: the wkClearBuffer immediately above took 424.9
  // ms (5 bytes, ~42 ms of line time at 1200 baud) with the reader already
  // running, against 13.6 ms for the identical call later in the same session.
  // Earlier runs reached 1978.7 ms.
  //
  // It was also an ordering bug in its own right -- the thread used to be
  // created ABOVE the SetCommTimeouts call, so its first read blocked on the
  // old 250 ms timeout instead of the intended 10 ms.
  //
  // Nothing above needs the reader: the two synchronous wkRead calls (echo test
  // and HOST OPEN) both run earlier, and the GETPOT response simply waits in the
  // driver's receive buffer until the thread starts.
  //
  // wkActive IS SET HERE, BEFORE THE THREAD EXISTS, not by the reader as it
  // starts: a wkStop landing between the create and the reader's first line
  // would otherwise be undone by the reader itself, which then loops on with
  // nobody waiting for it.  wkReaderRunning likewise, so wkStop can wait.
  //
  // THE HANDSHAKE GATE COMES DOWN FIRST: from here the reader sends the host
  // buffer, and the main thread may change the speed or the output.
  wkHandshaking := False;
  wkActive := True;
  wkReaderRunning := True;
  logger.Info('Calling tCreateThread from WkOpen');
  if not ThreadStarted(tCreateThread(wkReadThreadProc, wkThreadID)) then
     begin
     wkReaderRunning := False;
     aReason := 'the reader thread could not be started';
     (* Closed, not left open with nothing reading it. *)
     wkClose;
     Exit;
     end;
  logger.Info('Created WK thread with id %u',[PtrUInt(wkThreadId)]);
  Result := True;
end;

function wkOpen(out aReason: string): boolean;
begin
  wkHandshakeThread := System.GetCurrentThreadID;
  wkHandshaking := True;
  try
     Result := wkOpenAndConfigure(aReason);
  finally
     wkHandshaking := False;
  end;
end;

(* wkOpen ON A WORKER THREAD (pointer audit P1, 2026-10-16). uProgramMain
  started wkOpen itself as the thread body, through the untyped thread start,
  although it is a parameterless register-convention function -- the shape
  that, on i386, made the trampoline write nil into the thread's SEH chain
  head on exit. wkOpen keeps its own signature and this is the thread's
  entry; wkStart is its only starter, and nothing calls wkOpen directly any
  more (MainUnit's Alt-menu re-open did, on the main thread).

  A FAILED OPEN IS REPORTED HERE, with wkOpen's reason (review H5): this is
  the one path every open takes.  It used to discard the result.

  wkOpening IS CLEARED IN THE FINALLY, whatever wkOpen did -- including
  raising, which the tCreateThread trampoline logs. By then a successful open
  has already raised wkReaderRunning, so wkStop never sees both down while a
  reader is about to start. *)
function wkOpenThreadProc(aParameter: Pointer): DWORD; stdcall;
var
  reason: string;
begin
  Result := 0;
  try
     if not wkOpen(reason) then
        begin
        wkReportNotOpened(reason);
        end;
  finally
     wkOpening := False;
  end;
end;

procedure wkSendAdminCommand(const aCommand: TwkAdminCommand);
begin
  logger.Trace('[wkSendAdminCommand] B1=$%s B2=$%s', [IntToHex(aCommand[0], 2), IntToHex(aCommand[1], 2)]);
  if not wkPortOpen then
     begin
     Exit;
     end;
  wkWriteRaw(aCommand);
end;

function wkValueListBytes(const aList: TwkValueList): TwkValueListWire;
begin
  Result[0]  := aList.vlCommandCode;
  Result[1]  := aList.vlModeRegister;
  Result[2]  := aList.vlSpeedinWPM;
  Result[3]  := Ord(aList.vlSidetoneFrequency);
  Result[4]  := aList.vlWeight;
  Result[5]  := aList.vlLeadInTime;
  Result[6]  := aList.vlTailTime;
  Result[7]  := aList.vlMinWPM;
  Result[8]  := aList.vlWPMRange;
  Result[9]  := aList.vl1stExtension;
  Result[10] := aList.vlKeyCompensation;
  Result[11] := aList.vlFarnsworthWPM;
  Result[12] := aList.vlPaddleSWPoint;
  Result[13] := aList.vlDitDahRatio;
  Result[14] := aList.vlPinConfiguration;
  Result[15] := aList.vlDontcare;
end;

var
   // Summed WriteFile time (ms) since the last bracket reset.  Added to by
   // wkSendByte / wkSendTwoBytes; reset and read by the bracketed callers.
   wkWriteMsAccum: Double = 0;

   // Last pin configuration actually written to the device; -1 = unknown, which
   // forces the next write.  Invalidated on port open and close.
   wkLastPinConfig: integer = -1;

   // True from the moment TR4W hands the WinKeyer a CW character until the
   // device reports end-of-buffer ($C0).  This is the ONLY trustworthy "we have
   // CW outstanding" signal -- see wkHasPendingOutput for why wkBUSY and the
   // byte counters each fail on their own.
   wkCWOutstanding: boolean = False;

// ---- Diagnostic timing (task #22) -------------------------------------------
// The function-key -> CW latency trace (2026-07-31) showed ~370 ms elapsing
// inside the WinKeyer calls below while CW was going by CAT.  The gaps between
// successive bytes were 15/46/122 ms, which does NOT match 1200-baud serial
// time (~9 ms a byte), so the cost is NOT yet explained.  These brackets report
// the true wall time of each device call and how much of it is inside
// WriteFile, so the next change optimises a measured thing rather than a guess.
// Note the existing logger.Trace in wkSendByte is OUTSIDE the measured region:
// if total >> WriteFile, the logging itself is a prime suspect.
(* THE HIGH-RESOLUTION CLOCK, AND THE ONE PLACE THIS UNIT IS WINDOWS-BOUND.

  QueryPerformanceCounter has no RTL equivalent -- GetTickCount64 is
  milliseconds, and the gaps being measured here are 15/46/122 ms, so a
  1 ms floor would blur exactly the thing the trace exists to see.

  OFF WINDOWS IT FALLS BACK TO GetTickCount64 AND SAYS SO IN THE NUMBER: the
  result is still milliseconds, just quantised to whole ones. That is honest
  for a diagnostic and wrong for anything that keys a radio -- which is why
  the real answer is the platform HPTimer in
  docs\PLATFORM_CLOCK_ABSTRACTION.md and not a second guess here. *)
function wkPerfNow: Int64;
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(Result);
{$ELSE}
   Result := Int64(GetTickCount64);
{$ENDIF}
end;

function wkPerfMs(const StartTick: Int64): Double;
{$IFDEF WINDOWS}
var
   nowTick, freq: Int64;
begin
   QueryPerformanceCounter(nowTick);
   QueryPerformanceFrequency(freq);
   if freq = 0 then
      begin
      Result := 0;
      end
   else
      begin
      Result := ((nowTick - StartTick) * 1000.0) / freq;
      end;
{$ELSE}
begin
   { Already milliseconds -- see the note above. }
   Result := Int64(GetTickCount64) - StartTick;
{$ENDIF}
end;

function wkSendByte(b: Byte): Cardinal;
var
  t0: Int64;
begin
  (* THE COUNT WRITTEN, 0 when nothing went out -- it was left unassigned. *)
  Result := 0;
  logger.Trace('[wkSendByte] b=%s ($%s)', [string(Char(b)), IntToHex(b, 2)]);
  if not wkPortOpen then Exit;
  t0 := wkPerfNow;
  Result := wkWriteRaw([b]);
  wkWriteMsAccum := wkWriteMsAccum + wkPerfMs(t0);

//  wkBuffer[0] := b;
//  tWriteFile(WinKeyHandle, wkBuffer, 1, RESULT);
//  wkWriteToDebugFile(Char(wkBuffer[0]), True);
end;

function wkSendTwoBytes(B1, B2: Byte): Cardinal;
var
  t0                                    : Int64;
begin
  (* 0 when nothing went out -- the not-open exit left it unassigned. *)
  Result := 0;
  logger.Trace('[wkSendTwoBytes] B1=%s ($%s) B2=%s ($%s)',
               [string(Char(B1)), IntToHex(B1, 2), string(Char(B2)), IntToHex(B2, 2)]);
  if not wkPortOpen then Exit;
  t0 := wkPerfNow;
  Result := wkWriteRaw([B1, B2]);
  wkWriteMsAccum := wkWriteMsAccum + wkPerfMs(t0);

//  wkSendByte(B1);
//  wkSendByte(B2);
{
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkBuffer[0] := B1;
  wkBuffer[1] := B2;
  tWriteFile(WinKeyHandle, wkBuffer, 2, RESULT);
  wkWriteToDebugFile(Char(wkBuffer[0]), True);
  wkWriteToDebugFile(Char(wkBuffer[1]), True);
}
end;
{
procedure wkSetLeadInTail;
begin
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkBuffer[0] := wkCMD_SETPTTLEADTAIL;
  wkBuffer[1] := WinKeySettings.wksLeadIn;
  wkBuffer[2] := WinKeySettings.wkTail;
  sWriteFile(WinKeyHandle, wkBuffer, 3);
end;
}

procedure wkSetSpeed(Speed: integer);
begin
  if not wkPortOpen then Exit;
  (* RECORDED ONLY WHEN IT WENT OUT: a write refused during the open (the
    handshake gate) or one that failed must not leave wkCWSpeed claiming a
    speed the keyer was never given. *)
  if wkSendTwoBytes(wkCMD_SETWPMSPEED, Speed) = 2 then
     begin
     wkCWSpeed := Speed;
     end;
end;


function wkRead(nNumberOfBytesToRead: DWORD): boolean;
var
  got: TBytes;
begin
  Result := False;
  if not wkPortOpen then
     begin
     Exit;
     end;
  got := WinKeyPort.ReadBytes(nNumberOfBytesToRead);
  if Length(got) = 0 then
     begin
     Exit;
     end;
  if DWORD(Length(got)) > DWORD(SizeOf(wkREADBuffer)) then
     begin
     SetLength(got, SizeOf(wkREADBuffer));
     end;
  Move(got[0], wkREADBuffer[0], Length(got));
  (* SHORT IS A FAILURE, as it was: the callers ask for an exact number of
    bytes -- one echo byte, one version byte -- and treat anything less as the
    device not answering. *)
  Result := DWORD(Length(got)) = nNumberOfBytesToRead;
end;

procedure wkClose;
begin
  wkActive := False;
  wkLastPinConfig := -1;   // device state is no longer ours to assume
  wkDispayState;
  if not wkPortOpen then Exit;
  wkClearBuffer;
  wkSendAdminCommand(wkHOSTCLOSE);
  (* Closed, not freed: wkOpenPort reopens the same object, and the WinKeyer
    comes and goes with its USB adapter. *)
  WinKeyPort.Close;
end;

function wkHasPendingOutput: boolean;
begin
   // True when the device can actually be holding CW worth clearing.
   //
   // NOT wkBUSY: that flag is set by ANY byte below $C0 arriving from the
   // device (see the read thread), which includes character echoes and speed-pot
   // reports, and it is only cleared by a $C0 end-of-buffer.  Routine chatter
   // therefore latches it True -- measured on the bench 2026-07-31, where it
   // made this guard fire with the WinKeyer sending nothing.
   //
   // NOT the byte counters alone: they only count what goes through the host
   // buffer, and TCWKeyerWinKey.SendChar (autosend) writes a character straight
   // out with wkSendByte, which touches neither counter.
   //
   // wkCWOutstanding covers both paths and is cleared by the device's own
   // end-of-buffer report.  Deliberately inclusive: any doubt reports True and
   // the caller still clears.
   Result := wkCWOutstanding or (wkWaitingBytesInWK > 0) or (wkWaitingBytesInHost > 0);
end;

procedure wkSendCWChar(c: AnsiChar);
begin
   // The direct (autosend) CW path.  Goes out immediately rather than through
   // the host buffer, so it must flag the outstanding CW itself -- otherwise a
   // flush would decline to clear a device that is actively keying.
   wkCWOutstanding := True;
   wkSendByte(Ord(c));
end;

procedure wkClearBuffer;            // 4.36.13 GM0GAV
var
  t0: Int64;
begin
  if not wkPortOpen then Exit;
  wkWriteMsAccum := 0;
  t0 := wkPerfNow;
  wkSendByte(wkCMD_CLEARBUFFER);
//  wkHostBufferIndex := 0;

  wkWaitingBytesInHost := 0;
  wkWaitingBytesInWK := 0;
  wkCWOutstanding := False;   // whatever was queued is being discarded

  wkHostBufferIndex := 0; //
  wkHostBufferSendIndex := 0; //

  wkSendByte(wkCMD_NULLIMM);                               //Gav   add 4.36.13
  wkSendByte(wkCMD_NULLIMM);                                //Gav   4.36.13
  wkSendByte(wkCMD_NULLIMM);                                //Gav    4.36.13
 wkSendByte(wkCMD_CLEARBUFFER);                           //Gav     4.36.13

  logger.Debug('[wkClearBuffer] 5 bytes: total %.1f ms, of which WriteFile %.1f ms',
               [wkPerfMs(t0), wkWriteMsAccum]);

{$IF WINKEYDEBUG}
//  AddStringToTelnetConsole('CLEAR');
{$IFEND}

end;

procedure wkSetupSpeedPot;
begin
  if not wkPortOpen then Exit;
  wkWriteRaw([wkCMD_SETUPSPEEDPOT, wkMINWPM, wkWPMRANGE, 0]);
end;

function wkTurnPTT(Turn: boolean): boolean;
begin
  Result := False;
  if not wkPortOpen then Exit;
  Result := wkWriteRaw([wkCMD_PTTONOFF, Byte(Turn)]) = 2;
{$IF WINKEYDEBUG}
//  AddStringToTelnetConsole('PTT');
{$IFEND}
end;

(* Fill wkThreadReadBuffer from the port and answer how many bytes arrived.

  Both reader threads did this inline with Windows.ReadFile. They are otherwise
  near-duplicates of each other and always were; this at least gives them one
  read. A zero answer is the ordinary case -- it means the 10 ms read timeout
  expired with the device quiet -- and not an error. *)
function wkReadIntoThreadBuffer: DWORD;
var
  got: TBytes;
begin
  Result := 0;
  if not wkPortOpen then
     begin
     Exit;
     end;
  got := WinKeyPort.ReadBytes(SizeOf(wkThreadReadBuffer));
  if Length(got) = 0 then
     begin
     Exit;
     end;
  Move(got[0], wkThreadReadBuffer[0], Length(got));
  Result := Length(got);
end;

(* mtWinKeyerSendEnded -- ON THE MAIN THREAD (issue #132).  What the reader ran
  when the busy bit dropped, in its order: auto call terminate's return to CQ,
  or else the auto-CQ re-arm; then the return to the inactive radio. *)
procedure RunWinKeyerSendEnded;
begin
  if AutoCallTerminateIsDue then
     begin
     ReturnInCQOpMode;
     end
  else
     begin
     tStartAutoCQ;
     end;
  BackToInactiveRadioAfterQSO;
end;

function wkReadThreadProc(aParameter: Pointer): DWORD; stdcall;
label
  1, 2;
var
  lpNumberOfBytesRead                   : DWORD;
  i                                     : integer;
begin
  Result := 0;   (* the thread exit code -- see TF.TTR4WThreadStart *)
  (* wkActive is NOT set here any more: wkOpen sets it before creating this
    thread, and wkStop's wait depends on that -- see the note there.  The
    finally at the end clears wkReaderRunning as the thread leaves. *)
  try
  wkDispayState;
  while wkActive = True do
  begin
    if not wkSendNextByteFromHostBuffer then

    begin
      lpNumberOfBytesRead := wkReadIntoThreadBuffer;
      if lpNumberOfBytesRead > 0 then
        for i := 0 to lpNumberOfBytesRead - 1 do
        begin

          if (wkThreadReadBuffer[i] and $C0) = $C0 then
          begin

//216 - 11011000
//220 - 11011100

//227 - 11100011
//192 - 11000000
//196 - 11000100
//198 - 11000110

          {it?s a status byte. (Host may or may not have asked for it.)process status change, note that it could be a pushbutton change}
{$IF WINKEYDEBUG}
            AddStringToTelnetConsole('status byte ' + IntToStr(wkThreadReadBuffer[i]), tstSend);
//            sWriteFile(wkDebugFileRX, wkThreadReadBuffer[I], 1);
{$IFEND}
    {(*}
            wkBUSY    := (wkThreadReadBuffer[I] and (1 shl 2)) <> 0;
            wkBREAKIN := (wkThreadReadBuffer[I] and (1 shl 1)) <> 0;
            wkXOFF    := (wkThreadReadBuffer[I] and (1 shl 0)) <> 0;
    {*)}

{$IF WINKEYDEBUG}
            if wkBUSY then
               begin
               AddStringToTelnetConsole('YES', tstSend)
               end
            else
               begin
               AddStringToTelnetConsole('NO', tstSend);
               end;

{$IFEND}

            ActiveRadioPtr.tPTTStatus := PTTStatusType(wkBUSY);
            logger.debug('PTTStatus=WKBUSY');
            // logger.debug('Exiting ParametersOkay early: ExchangeString=<%s>',[ExchangeString]);

            SendStationStatus(sstPTT);

          if not wkBUSY then
             begin
              logger.debug('PTTStatus=WK-NOT-BUSY');
              wkWaitingBytesInWK := 0;
              // The device has stopped keying, so nothing of ours is
              // outstanding.  This is the LIVE end-of-send edge: only
              // wkReadThreadProc is ever started (see wkInit), so the
              // byte = 192 branch in wkReadThreadProc1 never executes.
              wkCWOutstanding := False;
//              wkHostBufferIndex := 0;
//              wkHostBufferSendIndex := 0;
//              wkWaitingBytesInHost := 0;
              (* THE STATE IS SET HERE; WHAT FOLLOWS THE MESSAGE RUNS ON THE
                MAIN THREAD (issue #132).  Auto call terminate's return to CQ
                (or else the auto-CQ re-arm, an LCL TTimer) and the return to
                the inactive radio ran on this reader, which has no message
                loop.  mtWinKeyerSendEnded runs them in the same order, and
                asks AutoCallTerminateIsDue there -- nothing on this thread
                depends on the answer.  Coalesced: this block runs for EVERY
                status byte with the busy bit clear, as it always has, and
                two that arrive within one turn of the main loop are one pass
                -- BackToInactiveRadioAfterQSO is a no-op the second time, and
                the auto-CQ interval starts from the later byte either way,
                give or take that turn. *)
              RequestMainThreadJob(mtWinKeyerSendEnded);
            end;
          end
          else
            if (wkThreadReadBuffer[i] and $C0) = $80 then
            begin
            {it?s a speed pot byte (Host may or may not have asked for it.) process speed pot change}
{$IF WINKEYDEBUG}
//              AddStringToTelnetConsole('speed pot byte');
{$IFEND}
              if not WinKeySettings.wksIgnoreSpeedSpot then
                 begin
                 SetSpeed(wkThreadReadBuffer[i] - 128 + wkMINWPM);
                 (* A READ THREAD: the readout is drawn on the main thread
                   (issue #108) -- DisplayCodeSpeed assigns a caption. *)
                 RequestMainThreadJob(mtCodeSpeedDisplay);
                 end;
            end
            else
            begin

              begin
                if wkWaitingBytesInWK > 0 then
                   begin
                   dec(wkWaitingBytesInWK);
                   end;
              end;
{$IF WINKEYDEBUG}
//              AddStringToTelnetConsole('> RX ' + CHR(wkThreadReadBuffer[I]));
{$IFEND}
            end;
        end;

    end;
  end;
  finally
     wkReaderRunning := False;
  end;
end;

procedure wkReadThreadProc1;
label
  1, 2;
var
  lpNumberOfBytesRead                   : DWORD;
  i                                     : integer;
begin
  wkActive := True;
  wkDispayState;

  while wkActive = True do
  begin
    lpNumberOfBytesRead := wkReadIntoThreadBuffer;
    if lpNumberOfBytesRead = 0 then
       begin
       wkSendNextByteFromHostBuffer;
       goto 1;
       end;

    for i := 0 to lpNumberOfBytesRead - 1 do
    begin
{$IF WINKEYDEBUG}
      if wkThreadReadBuffer[i] >= $C0 then
         begin

         end
      else
//        sWriteFile(wkDebugFileRX, wkThreadReadBuffer[I], 1);
{$IFEND}
        if wkThreadReadBuffer[i] < $C0 then
        begin
{$IF WINKEYDEBUG}
//          AddStringToTelnetConsole('> RX ' + CHR(wkThreadReadBuffer[i]));
{$IFEND}
          if wkWaitingBytesInWK > 0 then
             begin
             dec(wkWaitingBytesInWK);
             end;
//        wkSendNextByteFromHostBuffer;
          wkBUSY := True;
        end
        else
        begin
{$IF WINKEYDEBUG}
//          AddStringToTelnetConsole('> C0 ' + IntToStr(wkThreadReadBuffer[i]));
{$IFEND}
        end;

      if wkThreadReadBuffer[i] = 192 then
      begin
{$IF WINKEYDEBUG}
//        AddStringToTelnetConsole('BUFFER=end');
{$IFEND}
        wkBUSY := False;
        wkWaitingBytesInWK := 0;
//        wkHostBufferIndex := 0;
        wkWaitingBytesInHost := 0;
        wkCWOutstanding := False;   // device says the buffer drained

        if tr4w_PTTStartTime <> 0 then
           begin
           (* GetTickCount64, matching tr4w_PTTStartTime's own declaration
             (QWord, commented "GetTickCount64") and matching what
             uRadioPolling does with the same two variables. This path was
             the odd one out: a 32-bit read against a 64-bit stamp, which
             agrees only while uptime is under 49.7 days. riPTTOnTotalTime
             stays Cardinal -- it is a field of the restart file. *)
           tRestartInfo.riPTTOnTotalTime := tRestartInfo.riPTTOnTotalTime +
              Cardinal(GetTickCount64 - tr4w_PTTStartTime);
           end;
        tDispalyOnAirTime;
        wkPTTOn := False;
        if tAutoCQMode = True then
           begin
            
           StartAppTimer(atAutoCQ, Settings.Cq.AutoDelay, @AutoCQTick);
           end;
      end;

      if (wkThreadReadBuffer[i] = 196) then
      begin
{$IF WINKEYDEBUG}
//        AddStringToTelnetConsole('START');
{$IFEND}
        if wkPTTOn = False then
           begin
           tr4w_PTTStartTime := GetTickCount64;
           end;
        wkPTTOn := True;
      end;

{$IF WINKEYDEBUG}
      if (wkThreadReadBuffer[i] = 198) then
         begin
         //        AddStringToTelnetConsole('PADDLE');
         //        wkHostBufferIndex := 0;
                 wkWaitingBytesInHost := 0;
                 wkWaitingBytesInWK := 0;
         end;
{$IFEND}

      if (wkThreadReadBuffer[i] and $C0) = $80 then if not WinKeySettings.wksIgnoreSpeedSpot then
                                                       begin
                                                       SetSpeed(wkThreadReadBuffer[i] - 128 + wkMINWPM);
                                                       (* A read thread too: see wkReadThreadProc (issue #108). *)
                                                       RequestMainThreadJob(mtCodeSpeedDisplay);
                                                       end;
    end;
{$IF WINKEYDEBUG}
//    Windows.SetWindowTextA(InsertWindowHandle, inttopchar(wkWaitingBytesInWK));
{$IFEND}
    1:
    Sleep(0);
  end;
end;

procedure wkDispayState;
begin
  { Reached from wkReadThreadProc and wkReadThreadProc1 -- BOTH READ THREADS --
    as well as from wkClose. It used to call EnableElement(mweWinKey, wkActive)
    directly, so two reader threads were enabling and disabling a control.
    Now it records whether the keyer is answering and uStateBridge does the
    enabling, on the main thread. }
  if KeyerState <> nil then
     begin
     KeyerState.Active := wkActive;
     end;
end;

procedure wkAddCharToHostBuffer(c: AnsiChar);
begin

{$IF WINKEYDEBUG}
//  AddStringToTelnetConsole(c);
{$IFEND}
  logger.Trace('[wkAddCharToHostBuffer] char=%s (ord=%d $%s)',
              [string(c), Ord(c), IntToHex(Ord(c), 2)]);
  wkInternalCWBuffer[wkHostBufferIndex] := c;
  inc(wkHostBufferIndex);
  if wkHostBufferIndex = SizeOfHostBuffer then
     begin
     wkHostBufferIndex := 0;
     end;
  inc(wkWaitingBytesInHost);
  wkCWOutstanding := True;
 
end;

procedure wkAddCWMessageToInternalBuffer(Msg: Str160);

  procedure CheckSpeedChange;
  begin
    if wkSpeedUp <> 0 then
       begin
       wkCWSpeed := round(wkCWSpeed * (1 + (0.06 * wkSpeedUp)));
       wkAddCharToHostBuffer(wkCMD_CHANGESPEEDBUFFERED);
       wkAddCharToHostBuffer(AnsiChar(wkCWSpeed));
       wkSpeedUp := 0;
       end;

    if wkSpeedDown <> 0 then
       begin
       wkCWSpeed := round(wkCWSpeed * (1 - (0.06 * wkSpeedDown)));
       wkAddCharToHostBuffer(wkCMD_CHANGESPEEDBUFFERED);
       wkAddCharToHostBuffer(AnsiChar(wkCWSpeed));
       wkSpeedDown := 0;
       end;
  end;

var
  i                                     : integer;
begin
  if length(Msg) = 0 then
     begin
     Exit;
     end;

  logger.Debug('[wkAddCWMessageToInternalBuffer] Msg="%s" len=%d', [Msg, length(Msg)]);

  for i := 1 to length(Msg) do
     begin
     if Msg[i] in ['A'..'Z', ' ', '0'..'9','.', '/', '?'] then
        begin
        CheckSpeedChange;
        wkAddCharToHostBuffer(Msg[i]);

        end;

     if Msg[i] = '^' then
        begin
        wkAddCharToHostBuffer('|');
        end;
     if Msg[i] = #$06 then
        begin
        inc(wkSpeedUp);
        end;
     if Msg[i] = #$13 then
        begin
        inc(wkSpeedDown);
        end;
     end;
  CheckSpeedChange;
end;

procedure wkSetKeyerOutput(r: RadioPtr);
var
  TempByte                              : Byte;
  t0                                    : Int64;
const
  WK_RADIO_ONE                          = 4;
  WK_RADIO_TWO                          = 8;
  WK_CW_MODE                            = 1;
begin
  if not wkPortOpen then Exit;
  if r = @Radio1 then TempByte := WK_RADIO_ONE else TempByte := WK_RADIO_TWO;
  if r.ModeMemory <> Phone then
     begin
     TempByte := TempByte + WK_CW_MODE;
     end;

 // if r = RadioOne then TempByte := 4 {+ 1} else TempByte := 8 {+ 1};
  TempByte := TempByte + Byte(WinKeySettings.wksSideTEnable) * 2;

  // The device already holds this pin configuration, so re-sending it buys
  // nothing.  There are three call sites (LogCW.SetUpToSendOnActiveRadio,
  // LOGSUBS1, LOGWIND), so it fires on routine band/mode/radio updates as well
  // as on every function key -- and the write is not free (task #22).  The
  // cache is invalidated on port open and close, so a device that was reset
  // behind our back is always reconfigured.
  if TempByte = wkLastPinConfig then
     begin
     Exit;
     end;

  wkWriteMsAccum := 0;
  t0 := wkPerfNow;
  (* CACHED ONLY WHEN IT WENT OUT.  A main-thread call refused by the
    handshake gate used to cache the byte anyway, and wkOpen's own call a
    moment later then found it cached and wrote nothing -- a keyer never told
    its output or sidetone. *)
  if wkSendTwoBytes(wkCMD_SETPINCONFIG, TempByte) = 2 then
     begin
     wkLastPinConfig := TempByte;
     end;
  logger.Debug('[wkSetKeyerOutput] pin config $%s: total %.1f ms, of which WriteFile %.1f ms',
               [IntToHex(TempByte, 2), wkPerfMs(t0), wkWriteMsAccum]);
end;

(* Is there a port to talk to? Replaces `WinKeyHandle = INVALID_HANDLE_VALUE`
  at every guard, and answers False both before the first open and after
  wkClose. *)
function wkPortOpen: boolean;
begin
  Result := (WinKeyPort <> nil) and WinKeyPort.IsOpen;
end;

(* Write raw bytes.

  The WinKeyer protocol is binary -- command bytes, a value list, echoed
  characters -- so this is the byte-exact path and never WriteString. It
  answers the number of bytes written, as tWriteFile did, so the two callers
  that report it need no change.

  AN OPEN ARRAY (P12, 2026-10-18): it used to take an untyped buffer and a
  count and Move one into the other. Callers pass `[b]`, `[B1, B2]`, an admin
  command or the value list's wire bytes, and the count comes with them. *)
function wkWriteRaw(const aBytes: array of Byte): Cardinal;
var
  bytes: TBytes;
  i: integer;
begin
  Result := 0;
  if (Length(aBytes) = 0) or (not wkPortOpen) then
     begin
     Exit;
     end;
  (* THE HANDSHAKE GATE -- see wkHandshaking.  Refused, and said: a speed or
    output change made in the second the keyer is opening reaches it only
    through the value list wkOpen sends. *)
  if wkHandshaking and (System.GetCurrentThreadID <> wkHandshakeThread) then
     begin
     logger.Warn('[WinKey] %d byte(s) from another thread not sent: the keyer is being opened',
                 [Length(aBytes)]);
     Exit;
     end;
  (* TSerialPort.WriteBytes takes a TBytes; an open array is not one, so the
    bytes are copied -- at most sixteen. *)
  SetLength(bytes, Length(aBytes));
  for i := 0 to High(aBytes) do
     begin
     bytes[i] := aBytes[i];
     end;
  try
     WinKeyPort.WriteBytes(bytes);
     Result := Length(aBytes);
  except
     on E: Exception do
        begin
        logger.Warn('[uWinKey] write of %d byte(s) failed: %s', [Length(aBytes), E.Message]);
        end;
  end;
end;

function wkOpenPort(out aReason: string): boolean;
var
  portName: string;
begin
  Result := False;
  aReason := '';

  (* A WINKEYER IS A SERIAL DEVICE.  The caller's guard was `= NoPort` (gone:
    it refused every device node), which a port configured as NETWORK
    passed, and the name formatter would then have produced 'COM65'.

    ASKED OF THE NAME FIRST, which is what makes a device node work: a
    configured '/dev/ttyUSB0' has no ordinal, so `in SerialPorts` is False for
    a port that is real and open-able.  PortKindOf reads the name before the
    ordinal for exactly that reason. *)
  portName := EffectiveDeviceName(WinKeySettings.wksWinKey2PortName,
                                  WinKeySettings.wksWinKey2Port);

  if PortKindOf(WinKeySettings.wksWinKey2PortName,
                WinKeySettings.wksWinKey2Port) <> pkSerial then
     begin
     (* THE NAME, NOT THE TOKEN.  This reported through PortTypeSA, so an
       operator saw 'SERIAL 7' -- a spelling that exists nowhere but inside
       TR4W.  It says what they chose, or NONE. *)
     if portName = '' then
        begin
        portName := 'NONE';
        end;
     aReason := UnicodeFormat('the keyer needs a serial port and is configured for %s',
                       [portName]);
     Exit;
     end;

  if WinKeyPort = nil then
     begin
     (* One rule, one place -- uPortAddress.  This used to build the name with
       TF.Format into wkREADBuffer, which is also the READ buffer, so the
       device name and the first reply shared one array. *)
     WinKeyPort := TSerialPort.Create(portName);
     end;

  try
     (* 1200 baud, 8N1, DTR ASSERTED AND RTS NOT.

       The DCB said exactly that -- Flags := dcb_DtrControlEnable, with no RTS
       bit -- and it is not decoration: a WinKeyer takes its power from DTR on
       the common builds, so RTS=False DTR=True is the difference between a
       keyer that works and one that is simply dark. FPC's SerSetParams leaves
       both lines low, so it is stated here rather than inherited. *)
     WinKeyPort.OpenRaw(1200, 8, 1, 0, False, True);
  except
     on E: Exception do
        begin
        (* THE NAME WE ACTUALLY TRIED TO OPEN.  'COM%d' off the ordinal was
          wrong twice over: it printed COM0 for an unconfigured keyer, and it
          could not name a device node at all.

          REPORTED ONCE, by wkOpenThreadProc, like every other failed open --
          not by a modal from here as well (review H5: one notice, one log
          line with the reason). *)
        aReason := UnicodeFormat('the port %s could not be opened: %s', [portName, E.Message]);
        Exit;
        end;
  end;

  (* 250 ms while the device is being identified -- the echo test and the
    version read are synchronous and a WinKeyer takes its time answering after
    a host open. wkOpen drops it to 10 ms once the reader thread starts. *)
  WinKeyPort.ReadTimeoutMs := 250;
  Sleep(200);
  wkLastPinConfig := -1;   // freshly opened device: nothing configured yet
  Result := True;
end;

function wkSendNextByteFromHostBuffer: boolean;
var
  BytesSendNow                          : integer;
begin
  Result := False;
  if wkWaitingBytesInHost <= 0 then Exit;

  BytesSendNow := 0;
  while BytesSendNow < 5 do
  begin
    if wkWaitingBytesInHost <= 0 then Exit;
{!!!}

    logger.Trace('[wkSendNextByteFromHostBuffer] sending char=%s (ord=%d $%s)',
                 [string(wkInternalCWBuffer[wkHostBufferSendIndex]),
                  Ord(wkInternalCWBuffer[wkHostBufferSendIndex]),
                  IntToHex(Ord(wkInternalCWBuffer[wkHostBufferSendIndex]), 2)]);
    wkSendByte(Ord(wkInternalCWBuffer[wkHostBufferSendIndex]));


    if wkWaitingBytesInHost > 0 then
       begin
       dec(wkWaitingBytesInHost);
       end;
    inc(BytesSendNow);
    inc(wkHostBufferSendIndex);
    if wkHostBufferSendIndex >= SizeOfHostBuffer then
       begin
       wkHostBufferSendIndex := 0;
       end;
    (* A {$IF WINKEYDEBUG} trace stood here, writing the send index into a
      window with Windows.SetWindowTextA. It is deleted (2026-09-08) rather
      than gated: WINKEYDEBUG is False in VC and InsertWindowHandle IS NO
      LONGER DECLARED ANYWHERE, so enabling the switch would not have compiled.
      The other four copies of this line in the tree are already commented
      out. *)
    inc(wkWaitingBytesInWK);
    Result := True;
    ;

  end;
end;

procedure wkSwapTune;
begin
  wkSendTwoBytes(wkCMD_KEYIMMEDIATE, Byte(not wkBUSY));
end;

initialization
  (* Issue #132 -- what the reader used to do to the UI itself. *)
  RegisterMainThreadJob(mtWinKeyerSendEnded, @RunWinKeyerSendEnded);

end.

