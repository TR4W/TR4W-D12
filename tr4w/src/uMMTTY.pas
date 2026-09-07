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
unit uMMTTY;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

interface

uses
  //  Richedit,
  TF,
  VC,
  Windows,
  Messages,
  LogK1EA,
  LogWind,
  Tree;

type
  TCharFormatA = record
    cbSize: UINT;
    dwMask: LONGINT;
    dwEffects: LONGINT;
    yHeight: LONGINT;
    yOffset: LONGINT;
    crTextColor: TColorRef;
    bCharSet: Byte;
    bPitchAndFamily: Byte;
    szFaceName: array[0..LF_FACESIZE - 1] of AnsiChar;
  end;

const
  EM_SETCHARFORMAT                      = WM_USER + 68;
  SCF_SELECTION                         = $0001;

  RXM_HANDLE                            = $0000;
  RXM_REQHANDLE                         = $0001;
  RXM_EXIT                              = $0002;

  RXM_PTT                               = $0003;

  RXM_PTT_SWITCH_TO_RX_IMMEDIATELY      = $00000000;
  RXM_PTT_SWITCH_TO_RX_AFTER_THE_TRANSMISSION_IS_COMPLETED = $00000001;
  RXM_PTT_SWITCH_TO_TX                  = $00000002;
  RXM_PTT_CLEAR_THE_TX_BUFFER           = $00000004;

  RXM_CHAR                              = $0004;

  RXM_WINPOS                            = $0005;
  RXM_WIDTH                             = $0006;
  RXM_REQPARA                           = $0007;
  RXM_SETBAUD                           = $0008;
  RXM_SETMARK                           = $0009;

  RXM_SETSPACE                          = $000A;
  RXM_SETSWITCH                         = $000B;
  RXM_SETHAM                            = $000C;
  RXM_SHOWSETUP                         = $000D;
  RXM_SETVIEW                           = $000E;

  RXM_SETSQLVL                          = 15;
  RXM_SHOW                              = 16;
  RXM_SETFIG                            = 17;
  RXM_SETRESO                           = 18;
  RXM_SETLPF                            = 19;

  RXM_SETTXDELAY                        = 20;
  RXM_UPDATECOM                         = 21;
  RXM_SUSPEND                           = 22;
  RXM_NOTCH                             = 23;
  RXM_PROFILE                           = 24;

  RXM_TIMER                             = 25;
  //    RXM_ENBFOCUS =0;	// added on Ver1.63A
  //    RXM_SETDEFFREQ =0;	// added on Ver1.63B
  //    RXM_SETLENGTH =0;	// added on Ver1.63B
  //--------------------------------------
  TXM_HANDLE                            = $8000; // MMTTY -> APP
  TXM_REQHANDLE                         = $8001;
  TXM_START                             = $8002;
  TXM_CHAR                              = $8003;
  TXM_PTTEVENT                          = $8004;

  TXM_HEIGHT                            = $8005;
  TXM_BAUD                              = $8006;
  TXM_MARK                              = $8007;
  TXM_SPACE                             = $8008;
  TXM_SWITCH                            = $8009;

  TXM_VIEW                              = $800A;
  TXM_LEVEL                             = $800B;
  TXM_FIGEVENT                          = $800C;
  TXM_RESO                              = $800D;
  TXM_LPF                               = $800E;

  TXM_THREAD                            = $800F;
  TXM_PROFILE                           = $8010;
  TXM_NOTCH                             = $8011;
  TXM_DEFSHIFT                          = $8012;
  //    TXM_RADIOFREQ = $8000;	// added on Ver1.63

type

  TCallSignProcessObject = record
    cpBuffer: array[0..15] of AnsiChar;
    cpEnable: boolean;
    cpPos: integer;
    cpPos1: integer;
    cpPos2: integer;
    cpContainN: boolean;
    cpContainA: boolean;
    cpStartPos: integer;
  end;

  MMTTYObject = record
    mmttyMSG: Cardinal;
    mmttyEngine: HWND;
    mmttyRichEdit: HWND;
    mmttyTXIsOn: boolean;
    mmttyTwoBytes: array[0..1] of AnsiChar;
    mmttyCF: TCharFormatA;
    mmttyCallProcess: TCallSignProcessObject;
    mmttyLastCallsign: CallString;
    mmttyCurrentPos: integer;
  end;

procedure mmttyProcessMessage(wp: integer; lp: integer);
procedure PostMmttyMessage(Command: integer; lParam: integer);
function NewMMTTYRichEditProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): integer; stdcall;

var

  MMTTY                                 : MMTTYObject;
{
  mmttyMSG                             : Cardinal;
  mmttyEngine                           : HWND;
  mmttyRichEdit                         : HWND;
  mmttyTXIsOn                           : boolean;
//  MMTTY_FIRST_TX_CHAR                   : boolean = True;
  mmttyTwoBytes                       : array[0..1] of Byte = (73, 0);
  mmttyCF                               : TCharFormatA;
}
  OldMMTTYRichEditProc                  : Pointer;

implementation

(* THE WHOLE IMPLEMENTATION IS WINDOWS-ONLY, AND THAT IS THE FEATURE, NOT A
  PORTING GAP.

  MMTTY is a separate Windows EXE -- launched with WinExec, not loaded as a
  library -- and every interaction with it is a Win32 window message:
  PostMessage to its top-level window, SendMessage to a RichEdit control, and a
  subclassed window procedure for the double-click that copies a decoded
  callsign. None of that has a macOS or Linux counterpart to port it to; the
  RTTY engine itself does not run there. So on another platform the three
  exported routines do nothing, and MMTTY.mmttyEngine stays 0, which is what
  every caller already treats as "not running".

  NY4I, 2026-09-06: "put the mmtty code under a {$IF WINDOWS}... that implicitly
  means any related items like ShowWindow" -- the ShowWindow pair in
  uMainWindowProc is gated in the same change.

  {$IFDEF WINDOWS}, not {$IF WINDOWS}: WINDOWS is a symbol FPC DEFINES for a
  Windows target, not a boolean constant. {$IF} would ask for the value of an
  identifier named WINDOWS and, under FPC's compile-time evaluator, an
  unresolved identifier degrades to a string of its own name instead of
  erroring -- so it would evaluate quietly and wrongly.

  WHAT STILL BLOCKS A NON-WINDOWS COMPILE OF THIS UNIT, written down rather
  than guessed at because THERE IS NO CROSS TARGET INSTALLED HERE (FPC has
  i386-win32 and nothing else, so the other branch cannot be compiled even
  once):

    * the INTERFACE's `uses Windows, Messages` -- HWND, UINT, WPARAM/LPARAM,
      TColorRef, LF_FACESIZE, WM_USER. LCLType declares the handle and message
      types for every widget set and is the likely answer; EM_SETCHARFORMAT is
      WM_USER + 68 and can be the number.
    * MMTTYObject's HWND fields, which about twenty other units read.

  Those are TYPE declarations. An empty procedure body is safe to write without
  a compiler; a type alias chosen from memory is not, and writing one would be
  the same class of mistake as the unverified library file name CLAUDE.md
  records under the HamLib note. *)

{$IFDEF WINDOWS}

uses
  uMainForm,          // QueuePasteIntoCallField -- the call field is a control
  uPlatformProcess,   // RunWindowsUtility -- the only launcher
  SysUtils,           // Format -- the RTL one, not TF's buffer shim
  LogEdit,
  uFileView,
  uMMTTYForm,         // the window is a form -- set its Caption, not its HWND
  MainUnit;


procedure mmttyUpdateCharFormat();
begin
  SendMessage(MMTTY.MMTTYRichEdit, EM_SETCHARFORMAT, SCF_SELECTION, integer(@MMTTY.mmttyCF));
end;

procedure mmttyProcessChar(c: AnsiChar);
var
  isDupe                                : boolean;
begin
  if MMTTY.mmttyTXIsOn then Exit;

  if c in ['.', ' ', #13, #10] then
     begin

     if MMTTY.mmttyCallProcess.cpEnable then
       if MMTTY.mmttyCallProcess.cpPos in [3..8] then
         if MMTTY.mmttyCallProcess.cpContainN then
           if MMTTY.mmttyCallProcess.cpContainA then
              begin
              { THE DECODED CALLSIGN GOES IN THE TITLE BAR.

                WAS SetWindowTextA against the window's raw HWND.  That is the
                hand-rolled route now the window is a form: the LCL CACHES
                Caption and repaints from its own copy, so a title set behind
                its back survives only until the next repaint -- and this fires
                on every decoded callsign, so it would have looked intermittent
                rather than broken. }
              if TR4WMMTTYForm <> nil then
                 begin
                 TR4WMMTTYForm.Caption := string(AnsiString(PAnsiChar(@MMTTY.mmttyCallProcess.cpBuffer[0])));
                 end;

              Windows.ZeroMemory(@MMTTY.mmttyLastCallsign, SizeOf(MMTTY.mmttyLastCallsign));
              Windows.CopyMemory(@MMTTY.mmttyLastCallsign[1], @MMTTY.mmttyCallProcess.cpBuffer, MMTTY.mmttyCallProcess.cpPos);
              MMTTY.mmttyLastCallsign[0] := AnsiChar(MMTTY.mmttyCallProcess.cpPos);
              isDupe := VisibleLog.CallIsADupe(MMTTY.mmttyLastCallsign, ActiveBand, ActiveMode);
  //            PutCallToCallWindow(MMTTY.mmttyLastCallsign);

              SendMessage(MMTTY.mmttyRichEdit,
                EM_SETSEL,
                MMTTY.mmttyCallProcess.cpStartPos,
                MMTTY.mmttyCallProcess.cpStartPos + MMTTY.mmttyCallProcess.cpPos + 1 - 1);

              MMTTY.mmttyCF.dwMask := CFM_COLOR + CFM_BOLD + CFM_STRIKEOUT;
  //            MMTTY.mmttyCF.crTextColor := $00FF0000;
              //MMTTY.mmttyCF.crTextColor := $000000FF;

              MMTTY.mmttyCF.dwEffects := CFE_BOLD;
              if isDupe then
                 begin
                 MMTTY.mmttyCF.dwEffects := {CFE_STRIKEOUT + }CFE_BOLD;
                 MMTTY.mmttyCF.crTextColor := $000000FF;
                 end;

              mmttyUpdateCharFormat;

              SendMessage(MMTTY.mmttyRichEdit, EM_SETSEL, -1, -1);

  //            MMTTY.mmttyCF.dwMask := CFM_COLOR + CFM_BOLD + CFM_STRIKEOUT;
              MMTTY.mmttyCF.crTextColor := $00000000;
              MMTTY.mmttyCF.dwEffects := 0;
              mmttyUpdateCharFormat;

              end;

     Windows.ZeroMemory(@MMTTY.mmttyCallProcess, SizeOf(MMTTY.mmttyCallProcess));
     MMTTY.mmttyCallProcess.cpEnable := True;
     MMTTY.mmttyCallProcess.cpStartPos := MMTTY.mmttyCurrentPos;
     Exit;
     end;

  if MMTTY.mmttyCallProcess.cpPos = 15 then
     begin
     MMTTY.mmttyCallProcess.cpEnable := False;
     end;

  if not MMTTY.mmttyCallProcess.cpEnable then Exit;

  MMTTY.mmttyCallProcess.cpBuffer[MMTTY.mmttyCallProcess.cpPos] := c;

  if c in ['0'..'9'] then
     begin
     MMTTY.mmttyCallProcess.cpContainN := True
     end
  else
    if c in ['A'..'Z', {'a'..'z',} '/'] then MMTTY.mmttyCallProcess.cpContainA := True
    else
       begin
       MMTTY.mmttyCallProcess.cpEnable := False;
       end;

  inc(MMTTY.mmttyCallProcess.cpPos);

end;

procedure mmttyProcessMessage(wp: integer; lp: integer);
var
  h                                     : HWND;
begin
  case wp of

    TXM_PTTEVENT:
      begin
        if lp = 0 then
           begin
           PTTOff;
           MMTTY.mmttyTXIsOn := False;

           MMTTY.mmttyCF.dwMask := CFM_COLOR;
           MMTTY.mmttyCF.crTextColor := clblack;
           mmttyUpdateCharFormat;
           tStartAutoCQ;
           end;
        if lp = 1 then
           begin
           MMTTY.mmttyTXIsOn := True;
           MMTTY.mmttyCF.dwMask := CFM_COLOR;
           MMTTY.mmttyCF.crTextColor := $00AAAAAA;
           mmttyUpdateCharFormat;
           end;
      end;

    TXM_HANDLE:
      begin
        MMTTY.MMTTYEngine := lp;
        PostMmttyMessage(RXM_HANDLE, MainWindowHandle);
      end;

    TXM_CHAR:
      begin
        MMTTY.mmttyTwoBytes[0] := AnsiChar(lp);
        h := MMTTY.MMTTYRichEdit;
        SendMessage(h, EM_SETSEL, -1, -1);
//        SendMessage(h, EM_SCROLLCARET, 0, 0);
        SendMessageA(h, EM_REPLACESEL, integer(False), integer(@MMTTY.mmttyTwoBytes));
        mmttyProcessChar(AnsiChar(lp));
        inc(MMTTY.mmttyCurrentPos);
      end;
  end;

end;

procedure PostMmttyMessage(Command: integer; lParam: integer);
begin
  if MMTTY.MMTTYEngine = 0 then Exit;
  PostMessage(MMTTY.MMTTYEngine, MMTTY.mmttyMSG, Command, lParam);
end;

function NewMMTTYRichEditProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): integer; stdcall;
begin
  Result := 0;
  if Msg = WM_LBUTTONDBLCLK then
     begin
     tCleareCallWindow;
     PostMessage(MMTTY.MMTTYRichEdit, WM_COPY, 0, 0);
     QueuePasteIntoCallField;

       //      Windows.SetFocus(CallWindowHandle);
       //      Exit;
     end;
  Result := CallWindowProc(OldMMTTYRichEditProc, hwnddlg, Msg, wParam, lParam);

end;

{$ELSE}

(* NO RTTY ENGINE OFF WINDOWS, so these do nothing and say so.

  Not stubs that pretend: MMTTY.mmttyEngine is left 0, which every caller
  already reads as "the engine is not running" -- the same state as a Windows
  machine where the operator has not configured MMTTY ENGINE. So the callers
  need no gate of their own to behave correctly here. *)

procedure mmttyProcessMessage(wp: integer; lp: integer);
begin
end;

procedure PostMmttyMessage(Command: integer; lParam: integer);
begin
end;

function NewMMTTYRichEditProc(hwnddlg: HWND; Msg: UINT; wParam: wParam;
                              lParam: lParam): integer; stdcall;
begin
   Result := 0;
end;

{$ENDIF}

end.

