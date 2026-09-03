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
  uCommctrl,
  LogRadio,
  Messages,
  Windows,
  VC,
  utils_file,
  TF,
  Tree
  ,
  uTR4WStrings;

function wkOpen: boolean;
function wkOpenPort: boolean;
function wkSend(const Buffer; nNumberOfBytesToWrite: DWORD): Cardinal;
procedure wkSendAdminCommand(const Buffer);
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
function WinKeyer2SettingsDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
//procedure wkSaveSettings;
//procedure wkLoadSettings;
function wkTurnPTT(Turn: boolean): boolean;
procedure wkDispayState;
procedure wkReadThreadProc;
// DEAD CODE.  Nothing starts this thread -- wkInit creates wkReadThreadProc
// (tCreateThread(@wkReadThreadProc, ...)) and wkReadThreadProc1 is referenced
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
  KeyerModeSA                           : array[TWK2KeyerMode] of PAnsiChar = ('IAMBIC B', 'IAMBIC A', 'ULTIMATIC', 'BUG MODE');
  SidetoneFrequencySA                   : array[TWKSidetoneFrequency] of PAnsiChar = ('4000', '2000', '1333', '1000', '800', '666', '571', '500', '444', '400');
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

const
  // ADMIN COMMANDS -- two RAW BYTES on the wire ($00 + sub-command), passed to
  // wkSendAdminCommand's untyped `const Buffer` and written verbatim.
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
  wkCALIBRATE   : array[0..1] of Byte = ($00, $00);
  wkRESET       : array[0..1] of Byte = ($00, $01);
  wkHOSTOPEN    : array[0..1] of Byte = ($00, $02);
  wkHOSTCLOSE   : array[0..1] of Byte = ($00, $03);
  wkECHOTEST    : array[0..1] of Byte = ($00, $04);
  wkGETVALUES   : array[0..1] of Byte = ($00, $07);

  wkSETWK1MODE  : array[0..1] of Byte = ($00, $0A);
  wkSETWK2MODE  : array[0..1] of Byte = ($00, $0B);

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

  wkThreadID                            : Cardinal;
  wkCWThreadID                          : Cardinal;

//  wkThreadHWND                          : HWND = INVALID_HANDLE_VALUE;
  WinKeyHandle                          : HWND = INVALID_HANDLE_VALUE;

  wkBuffer                              : array[0..7] of Byte;
  wkREADBuffer                          : array[0..32] of Byte;
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

  wklpCommTimeouts                      : TCommTimeouts;
  wkDCB                                 : TDCB;

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


implementation


uses
  uMainForm,   { the main window's elements are LCL controls }
  uKeyerState, { the keyer's state. This unit runs on read threads and must not
                 name a control -- see wkDispayState and wkOpen }
  SysUtils,
  uNet,
  LogDupe,
  uTelnet, {LogRadio,}
  LogWind,
  LogCW,
  LogK1EA,
  CFGCMD,
  MainUnit;

function wkOpen: boolean;
var
  versionByte : Byte;
  family      : Byte;
begin
  Result := False;

  if WinKeySettings.wksWinKey2Enable = False then Exit;
  if WinKeySettings.wksWinKey2Port = NoPort then Exit;

  if not wkOpenPort then Exit;

  // Send three null commands to resync host to WK2
  wkSendByte(wkCMD_NULLIMM);
  wkSendByte(wkCMD_NULLIMM);
  wkSendByte(wkCMD_NULLIMM);

  wkSendAdminCommand(wkECHOTEST);
  wkSendByte(wkECHOTESTBYTE);
//  Sleep(150);

  if ((not wkRead(1)) or (wkREADBuffer[0] <> wkECHOTESTBYTE)) then
     begin
     wkClose;
     Exit;
     end;

  wkSendAdminCommand(wkHOSTOPEN);
//  Sleep(150);

  PCardinal(@wkREADBuffer[0])^ := 0;   // Issue #997: was asm (zero first dword)
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
  wklpCommTimeouts.ReadTotalTimeoutConstant := 10 - 0;
//  wklpCommTimeouts.WriteTotalTimeoutConstant := 1;
  SetCommTimeouts(WinKeyHandle, wklpCommTimeouts);

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
  sWriteFile(WinKeyHandle, WinKeySettings.wksValueList, SizeOf(TwkValueList));
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
  logger.Info('Calling tCreateThread from WkOpen');
  tCreateThread(@wkReadThreadProc, wkThreadID);
  logger.Info('Created WK thread with id %d',[wkThreadId]);
end;

function wkSend(const Buffer; nNumberOfBytesToWrite: DWORD): Cardinal;
begin
  logger.Debug('[wkSend] writing %d byte(s) to WinKeyer', [nNumberOfBytesToWrite]);
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  tWriteFile(WinKeyHandle, Buffer, nNumberOfBytesToWrite, Result);
end;

procedure wkSendAdminCommand(const Buffer);
var
  Bytes: array[0..1] of Byte absolute Buffer;
begin
  logger.Trace('[wkSendAdminCommand] B1=$%s B2=$%s', [IntToHex(Bytes[0], 2), IntToHex(Bytes[1], 2)]);
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  sWriteFile(WinKeyHandle, Buffer, 2);
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
function wkPerfNow: Int64;
begin
   QueryPerformanceCounter(Result);
end;

function wkPerfMs(const StartTick: Int64): Double;
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
end;

function wkSendByte(b: Byte): Cardinal;
var
  t0: Int64;
begin
  logger.Trace('[wkSendByte] b=%s ($%s)', [string(Char(b)), IntToHex(b, 2)]);
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  t0 := wkPerfNow;
  sWriteFile(WinKeyHandle, b, 1);
  wkWriteMsAccum := wkWriteMsAccum + wkPerfMs(t0);

//  wkBuffer[0] := b;
//  tWriteFile(WinKeyHandle, wkBuffer, 1, RESULT);
//  wkWriteToDebugFile(Char(wkBuffer[0]), True);
end;

function wkSendTwoBytes(B1, B2: Byte): Cardinal;
var
  TwoBytesBuffer                        : array[0..1] of Byte;
  t0                                    : Int64;
begin
  logger.Trace('[wkSendTwoBytes] B1=%s ($%s) B2=%s ($%s)',
               [string(Char(B1)), IntToHex(B1, 2), string(Char(B2)), IntToHex(B2, 2)]);
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  TwoBytesBuffer[0] := B1;
  TwoBytesBuffer[1] := B2;
  t0 := wkPerfNow;
  tWriteFile(WinKeyHandle, TwoBytesBuffer, 2, Result);
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
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkSendTwoBytes(wkCMD_SETWPMSPEED, Speed);
  wkCWSpeed := Speed;
end;


function wkRead(nNumberOfBytesToRead: DWORD): boolean;
var
  lpNumberOfBytesRead                   : DWORD;
begin
  Windows.ReadFile(WinKeyHandle, wkREADBuffer, nNumberOfBytesToRead, lpNumberOfBytesRead, nil);
  Result := lpNumberOfBytesRead = nNumberOfBytesToRead;
end;

procedure wkClose;
begin
  wkActive := False;
  wkLastPinConfig := -1;   // device state is no longer ours to assume
  wkDispayState;
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkClearBuffer;
  wkSendAdminCommand(wkHOSTCLOSE);
  CloseHandle(WinKeyHandle);
  WinKeyHandle := INVALID_HANDLE_VALUE;
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
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
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
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkBuffer[0] := wkCMD_SETUPSPEEDPOT;
  wkBuffer[1] := wkMINWPM;
  wkBuffer[2] := wkWPMRANGE;
  wkBuffer[3] := 0;
  sWriteFile(WinKeyHandle, wkBuffer, 4);
end;

function wkTurnPTT(Turn: boolean): boolean;
begin
  Result := False;
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
  wkBuffer[0] := wkCMD_PTTONOFF;
  wkBuffer[1] := Byte(Turn);
  Result := sWriteFile(WinKeyHandle, wkBuffer, 2);
{$IF WINKEYDEBUG}
//  AddStringToTelnetConsole('PTT');
{$IFEND}
end;

function WinKeyer2SettingsDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  ExitAndClose, 1;
var
  c                                     : Cardinal;
  Top                                   : Cardinal;
  Left                                  : Cardinal;
  TempInteger                           : integer;
  lpTranslated                          : BOOL;
  TempHWND                              : HWND;
const
  wkBool                                = 7;
  wkRange                               = 7;
  wkCombo                               = 4 - 1;

//  wkSidetoneFrequencyArrayWK1           : array[1..10] of Word = (3759, 1879, 1252, 0940, 0752, 0625, 0535, 0469, 0417, 0375);
//  wkSidetoneFrequencyArrayWK2           : array[1..10] of Word = (4000, 2000, 1333, 1000, 0800, 0666, 0571, 0500, 0444, 0400);

  wkSidetoneFrequencyArray              : array[1..20] of Word =
    (
    3759, 1879, 1252, 0940, 0752, 0625, 0535, 0469, 0417, 0375, //wk1
    4000, 2000, 1333, 1000, 0800, 0666, 0571, 0500, 0444, 0400 //wk2
    );


  { The four label tables below are FILLED IN WM_INITDIALOG, not here. They
    were PAnsiChar initialised from TC_ constants, which folds the English
    in at compile time and no catalogue can reach. }
//  WK2HangTimeArray                      : array[1..4] of PChar = ('1.0', '1.33', '1.66', '2.0');


  WK2UpDownValue                        : array[1..wkRange] of PByte = (
    @WinKeySettings.wksValueList.vlWeight,
    @WinKeySettings.wksValueList.vlDitDahRatio,
    @WinKeySettings.wksValueList.vlLeadInTime,
    @WinKeySettings.wksValueList.vlTailTime,
    @WinKeySettings.wksValueList.vl1stExtension,
    @WinKeySettings.wksValueList.vlKeyCompensation,
    @WinKeySettings.wksValueList.vlPaddleSWPoint
    );

  WK2BoolValue                          : array[1..wkBool] of PBoolean = (
    @WinKeySettings.wksWinKey2Enable,
    @WinKeySettings.wksAutospace,
    @WinKeySettings.wksCTSpacing,
    @WinKeySettings.wksSideTEnable,
    @WinKeySettings.wksPaddleSwap,
    @WinKeySettings.wksIgnoreSpeedSpot,
    @WinKeySettings.wksPadOnlySideT
    );

  WK2UpDownUpperValue                   : array[1..wkRange] of integer = (090, 066, 250, 250, 250, 250, 090);
  WK2UpDownLowerValue                   : array[1..wkRange] of integer = (010, 033, 000, 000, 000, 000, 010);

var
  { Between the two const groups, and it has to be here.

    They are sized by wkBool / wkCombo / wkRange above, so they cannot come
    earlier; and PORT_CB / MODE_CB below are consts computed from High() of
    them, so they cannot come later.

    Filled in WM_INITDIALOG. They were PAnsiChar typed constants initialised
    from TC_ names -- a compile-time fold no catalogue can reach. }
  WK2SettingsNamesArray                 : array[1..wkBool] of string;
  WK2ComboSettingsNamesArray            : array[1..wkCombo] of string;
  WK2KeyerModesArray                    : array[1..4] of string;
  WK2SliderLabelArray                   : array[1..wkRange] of string;

const
  CC                                    = 24;
  PORT_CB                               = 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + 1;
  MODE_CB                               = 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + 2;
  FREQ_CB                               = 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + 3;
  HANG_CB                               = 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + 4;

  WEIGHTING_SLIDER                      = 117;
  DITDAH_RATIO_SLIDER                   = WEIGHTING_SLIDER + 1;
  LEADIN_SLIDER                         = WEIGHTING_SLIDER + 2;
  TAIL_SLIDER                           = WEIGHTING_SLIDER + 3;
  w                                     = 130;
  w3                                    = 80;
  o                                     = 10;
  w2                                    = 25;
  w4                                    = ((wkBool div 2) + 1);
  UpDownControlStyle                    = WS_CHILD or WS_BORDER or WS_VISIBLE or UDS_NOTHOUSANDS or UDS_ARROWKEYS or UDS_ALIGNRIGHT or UDS_SETBUDDYINT;

  procedure SETCHECK(ID: integer; b: boolean);
  begin
    Windows.SendDlgItemMessage(hwnddlg, ID, BM_SETCHECK, integer(b), 0);
  end;
begin

  Result := False;
  case Msg of
    //    WM_HELP: tWinHelp(49);

    WM_INITDIALOG:
      begin
        // The translated labels, once per dialog rather than per message.
        WK2SettingsNamesArray[1] := TC_WINKEYERENABLE;
        WK2SettingsNamesArray[2] := TC_AUTOSPACE;
        WK2SettingsNamesArray[3] := TC_CTSPACING;
        WK2SettingsNamesArray[4] := TC_SIDETONE;
        WK2SettingsNamesArray[5] := TC_PADDLESWAP;
        WK2SettingsNamesArray[6] := TC_IGNORESPEEDPOT;
        WK2SettingsNamesArray[7] := TC_PADDLEONLYSIDETONE;
        WK2ComboSettingsNamesArray[1] := TC_WINKEYERPORT;
        WK2ComboSettingsNamesArray[2] := TC_KEYERMODE;
        WK2ComboSettingsNamesArray[3] := TC_SIDETONEFREQ;
        WK2KeyerModesArray[1] := TC_IAMBICB;
        WK2KeyerModesArray[2] := TC_IAMBICA;
        WK2KeyerModesArray[3] := TC_ULTIMATIC;
        WK2KeyerModesArray[4] := TC_BUGMODE;
        WK2SliderLabelArray[1] := TC_WEIGHTING;
        WK2SliderLabelArray[2] := TC_DITDAHRATIO;
        WK2SliderLabelArray[3] := TC_LEADIN;
        WK2SliderLabelArray[4] := TC_TAIL;
        WK2SliderLabelArray[5] := TC_FIRSTEXTENSION;
        WK2SliderLabelArray[6] := TC_KEYCOMP;
        WK2SliderLabelArray[7] := TC_PADDLESWITCHPOINT;

//        Windows.SendDlgItemMessage(hwnddlg, 300, TBM_SETTHUMBLENGTH , 10, 0);
        Top := 0;
        for c := 1 to length(WK2SettingsNamesArray) do
           begin

           if ((c - 1) mod 2) = 0 then
              begin
              Left := o;
              inc(Top, CC);
              end
           else

              begin
              Left := o * 2 + w;
              end;
 //          Top := c * CC;
           tCreateButtonWindow(0, WK2SettingsNamesArray[c], $50010003, Left, Top, w, 17, hwnddlg, 100 + c);
 //          showint(c mod 2);
           end;

        for c := 1 to wkCombo do
           begin
           Top := c * CC + w4 * CC;
           tCreateStaticWindow(WK2ComboSettingsNamesArray[c], LeftVisNoSunStyle, o {* 2 + w}, Top, w, 17, hwnddlg, 100 + High(WK2SettingsNamesArray) + c);

           CreateWindowExW(
             WS_EX_STATICEDGE,
             COMBOBOX,
             nil,
             CBS_DROPDOWNLIST or WS_CHILD or WS_VISIBLE or WS_VSCROLL or WS_TABSTOP,
             o * 2 + w,
             Top,
             w3,
             200,
             hwnddlg,
             100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + c,
             hInstance,
             nil
             );

           // Issue #997: asm tWM_SETFONT (EAX = the COMBOBOX just created above);
           // re-fetch it by its child id and set its font.
           tWM_SETFONT(GetDlgItem(hwnddlg, 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + c), MSSansSerifFont);
           end;

        for c := 1 to wkRange do
           begin
           Top := c * CC + length(WK2ComboSettingsNamesArray) * CC + w4 * CC;
           tCreateStaticWindow(WK2SliderLabelArray[c], LeftVisNoSunStyle, o, Top, w, 17, hwnddlg, 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + length(WK2ComboSettingsNamesArray) + c);
           TempHWND := tCreateEditWindow(WS_EX_STATICEDGE, '', ES_CENTER + ES_NUMBER + WS_CHILD or WS_TABSTOP or WS_VISIBLE, o * 2 + w, Top, w3, 20, hwnddlg, 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + length(WK2ComboSettingsNamesArray) + length(WK2SliderLabelArray) + c);
           CreateUpDownControl(UpDownControlStyle, 0, 0, 0, 0, hwnddlg, 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + length(WK2ComboSettingsNamesArray) + length(WK2SliderLabelArray) + c, hInstance, TempHWND, WK2UpDownUpperValue[c], WK2UpDownLowerValue[c], integer(WK2UpDownValue[c]^));
           end;

        for c := 1 to 4 do
           begin
           tCB_ADDSTRING(hwnddlg, MODE_CB, WK2KeyerModesArray[c]);
           end;
        tCB_SETCURSEL(hwnddlg, MODE_CB, Cardinal(WinKeySettings.wksKeyerMode));

        // SERIAL 1..MAX_SERIAL_PORT.  This list was hard-coded to 20 -- the OLD
        // serial ceiling -- and was missed when the ceiling rose to COM64
        // (171bc72), so a WinKeyer on COM21 or above simply could not be
        // selected here (NY4I bench, 2026-07-31).
        //
        // The list stays UNFILTERED and contiguous from 1 on purpose: this combo
        // is read back by INDEX (PortType(tCB_GETCURSEL) below), so index must
        // equal Ord(PortType).  The radio dialog's filtered/friendly-name port
        // list carries each row's PortType in item data instead; doing the same
        // here belongs with the planned FMX rewrite of this dialog, not with a
        // ceiling fix.
        tCB_ADDSTRING(hwnddlg, PORT_CB, 'NONE');
        for c := 1 to MAX_SERIAL_PORT do
           begin
           // Issue #997: asm wsprintf-push -> TF.Format (c is the integer loop var).
           TF.Format(@wkREADBuffer, 'SERIAL %u', c);
           tCB_ADDSTRING_PCHAR(hwnddlg, PORT_CB, string(PAnsiChar(@wkREADBuffer[0])));
           end;
        tCB_SETCURSEL(hwnddlg, PORT_CB, Cardinal(WinKeySettings.wksWinKey2Port));

        for c := 1 to 10 do
           begin
           TempInteger := integer(wk2) * 10 + c;
           tCB_ADDSTRING_PCHAR(hwnddlg, FREQ_CB, inttopchar(wkSidetoneFrequencyArray[TempInteger]));
           end;
        tCB_SETCURSEL(hwnddlg, FREQ_CB, Byte(WinKeySettings.wksValueList.vlSidetoneFrequency) - 1);
        goto 1;
      end;
    WM_COMMAND:
      begin
        if wParam = 2 then
           begin
           goto ExitAndClose;
           end;
        if wParam = 1 then
           begin
           {SIDETONE}
             Byte(WinKeySettings.wksValueList.vlSidetoneFrequency) := tCB_GETCURSEL(hwnddlg, FREQ_CB) + 1;
             WinKeySettings.wksKeyerMode := TWK2KeyerMode(tCB_GETCURSEL(hwnddlg, MODE_CB));

             for c := 1 to wkBool do
                begin
                WK2BoolValue[c]^ := boolean(TF.SendDlgItemMessage(hwnddlg, 100 + c, BM_GETCHECK));
                end;


             WinKeySettings.wksWinKey2Port := PortType(tCB_GETCURSEL(hwnddlg, PORT_CB));

   //          if Windows.SendDlgItemMessage(hwnddlg, 104, BM_GETCHECK, 0, 0) = BST_CHECKED then WinKeySettings.wksValueList.vlSidetoneFrequency := WinKeySettings.wksValueList.vlSidetoneFrequency or (1 shl 7);

             TempInteger :=
               4 + 128 + //64 +
               integer(WinKeySettings.wksCTSpacing) * 1 +
               integer(WinKeySettings.wksAutospace) * 2 +
               integer(WinKeySettings.wksPaddleSwap) * 8;

             if WinKeySettings.wksKeyerMode = kmIambicA then
                begin
                TempInteger := TempInteger + 16;
                end;
             if WinKeySettings.wksKeyerMode = kmUltimatic then
                begin
                TempInteger := TempInteger + 32;
                end;
             if WinKeySettings.wksKeyerMode = kmBugMode then
                begin
                TempInteger := TempInteger + 48;
                end;

   //1000 0100
             WinKeySettings.wksValueList.vlModeRegister := TempInteger;
   //          showint(tCB_GETCURSEL(hwnddlg, 116) + 34);

             for c := 1 to wkRange do
                begin
                TempInteger := Windows.GetDlgItemInt(hwnddlg, 100 + High(WK2ComboSettingsNamesArray) + High(WK2SettingsNamesArray) + length(WK2ComboSettingsNamesArray) + length(WK2SliderLabelArray) + c, lpTranslated, False);
                if TempInteger <= WK2UpDownUpperValue[c] then
                  if TempInteger >= WK2UpDownLowerValue[c] then
                     begin
                     WK2UpDownValue[c]^ := Byte(TempInteger);
                     end;
                end;

             wkClose;
             wkOpen;
             goto ExitAndClose;
           end;

        if (HiWord(wParam) in [CBN_SELCHANGE {, BN_CLICKED}]) or (HiWord(wParam) = EN_CHANGE) then EnableWindowTrue(hwnddlg, 1);
        if HiWord(wParam) = BN_CLICKED then if LoWord(wParam) = 101 then
                                               begin
                                               1:
                                               TempInteger := TF.SendDlgItemMessage(hwnddlg, 101, BM_GETCHECK);
                                               for c := 102 to 124 + 3 do
                                                  begin
                                                  Windows.EnableWindow(GetDlgItem(hwnddlg, c), LongBool(TempInteger));
                                                  end;
                                               if not wk2 then
                                                  begin
                                                  TF.EnableWindowFalse(hwnddlg, 107);
                                                  end;
                                               end;
      end;

    WM_CLOSE:
      begin
        ExitAndClose:
        EndDialog(hwnddlg, 0);
      end;

  end;
end;


procedure wkReadThreadProc;
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
    if not wkSendNextByteFromHostBuffer then

    begin
      Windows.ReadFile(WinKeyHandle, wkThreadReadBuffer, SizeOf(wkThreadReadBuffer), lpNumberOfBytesRead, nil);
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
              if not tStartAutoCallTerminate(wkThreadID) then
                 begin
                 tStartAutoCQ;
                 end;
             BackToInactiveRadioAfterQSO;
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
                 DisplayCodeSpeed;
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
    Windows.ReadFile(WinKeyHandle, wkThreadReadBuffer, SizeOf(wkThreadReadBuffer), lpNumberOfBytesRead, nil);
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
           tRestartInfo.riPTTOnTotalTime := tRestartInfo.riPTTOnTotalTime + GetTickCount - tr4w_PTTStartTime;
           end;
        tDispalyOnAirTime;
        wkPTTOn := False;
        if tAutoCQMode = True then
           begin
            
           tAutoCQTimerID := SetTimer(tr4whandle, AUTOCQ_TIMER_HANDLE, AutoCQDelayTime, @tAutoCQTimerProc);
           end;
      end;

      if (wkThreadReadBuffer[i] = 196) then
      begin
{$IF WINKEYDEBUG}
//        AddStringToTelnetConsole('START');
{$IFEND}
        if wkPTTOn = False then
           begin
           tr4w_PTTStartTime := GetTickCount;
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
                                                       DisplayCodeSpeed;
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
  if WinKeyHandle = INVALID_HANDLE_VALUE then Exit;
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
  wkSendTwoBytes(wkCMD_SETPINCONFIG, TempByte);
  wkLastPinConfig := TempByte;
  logger.Debug('[wkSetKeyerOutput] pin config $%s: total %.1f ms, of which WriteFile %.1f ms',
               [IntToHex(TempByte, 2), wkPerfMs(t0), wkWriteMsAccum]);
end;

function wkOpenPort: boolean;
var
  msg: string;
begin
  Result := False;
  // Issue #997: asm wsprintf-push -> TF.Format (_COM = '\\.\COM%u', same as
  // tree.pas). wksWinKey2Port is a PortType enum -> Ord = the port number.
  TF.Format(@wkREADBuffer, _COM, Ord(WinKeySettings.wksWinKey2Port));
  WinKeyHandle := CreateFileA(@wkREADBuffer, GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL {FILE_FLAG_OVERLAPPED}, 0);
  if WinKeyHandle = INVALID_HANDLE_VALUE then
     begin
     // SysErrorMessage returns an AnsiString via a hidden var-parameter, not in
     // eax. Assign to a local so the string data remains alive, then build the
     // full message with SysUtils.Format. No inline asm / varargs juggling.
     msg := Format('Winkeyer port COM%d: %s',
                   [Integer(WinKeySettings.wksWinKey2Port),
                    SysErrorMessage(GetLastError)]);
     showwarning(msg);
     Exit;
     end;
  GetCommState(WinKeyHandle, wkDCB);
  wkDCB.BaudRate := CBR_1200;
  wkDCB.StopBits := ONESTOPBIT;
  wkDCB.Parity := NOPARITY;
  wkDCB.ByteSize := 8;
  wkDCB.Flags := dcb_DtrControlEnable;
  SetCommState(WinKeyHandle, wkDCB);

//  wklpOverlapped.hEvent := Windows.CreateEvent(nil, True, False, nil);
//  SetCommMask(WinKeyHandle, EV_RXCHAR);

  Windows.ZeroMemory(@wklpCommTimeouts, SizeOf(TCommTimeouts));
  wklpCommTimeouts.ReadTotalTimeoutConstant := 250;
  SetCommTimeouts(WinKeyHandle, wklpCommTimeouts);
  Sleep(200);
  PurgeComm(WinKeyHandle, PURGE_RXCLEAR);
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
{$IF WINKEYDEBUG}
    Windows.SetWindowTextA(InsertWindowHandle, inttopchar(wkHostBufferSendIndex));
{$IFEND}
    inc(wkWaitingBytesInWK);
    Result := True;
    ;

  end;
end;

procedure wkSwapTune;
begin
  wkSendTwoBytes(wkCMD_KEYIMMEDIATE, Byte(not wkBUSY));
end;

end.

