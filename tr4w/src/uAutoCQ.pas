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
 unit uAutoCQ;
{$I tr4w.inc} {AutoCQ WinAPI}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Windows,
  uCommctrl,
  LogEdit,
  LogWind,
  LogCW,
  Tree,
  Messages;
{ ====== UPDOWN CONTROL ========================== }

const
{$EXTERNALSYM UPDOWN_CLASS}
  UPDOWN_CLASS                          = 'msctls_updown32';

type
  PUDAccel = ^TUDAccel;
{$EXTERNALSYM _UDACCEL}
  _UDACCEL = packed record
    nSec: UINT;
    nInc: UINT;
  end;
  TUDAccel = _UDACCEL;
{$EXTERNALSYM UDACCEL}
  UDACCEL = _UDACCEL;

const
{$EXTERNALSYM UD_MAXVAL}
  UD_MAXVAL                             = $7FFF;
{$EXTERNALSYM UD_MINVAL}
  UD_MINVAL                             = -UD_MAXVAL;

{$EXTERNALSYM UDS_WRAP}
  UDS_WRAP                              = $0001;
{$EXTERNALSYM UDS_SETBUDDYINT}
  UDS_SETBUDDYINT                       = $0002;
{$EXTERNALSYM UDS_ALIGNRIGHT}
  UDS_ALIGNRIGHT                        = $0004;
{$EXTERNALSYM UDS_ALIGNLEFT}
  UDS_ALIGNLEFT                         = $0008;
{$EXTERNALSYM UDS_AUTOBUDDY}
  UDS_AUTOBUDDY                         = $0010;
{$EXTERNALSYM UDS_ARROWKEYS}
  UDS_ARROWKEYS                         = $0020;
{$EXTERNALSYM UDS_HORZ}
  UDS_HORZ                              = $0040;
{$EXTERNALSYM UDS_NOTHOUSANDS}
  UDS_NOTHOUSANDS                       = $0080;
{$EXTERNALSYM UDS_HOTTRACK}
  UDS_HOTTRACK                          = $0100;

{$EXTERNALSYM UDM_SETRANGE}
  UDM_SETRANGE                          = WM_USER + 101;
{$EXTERNALSYM UDM_GETRANGE}
  UDM_GETRANGE                          = WM_USER + 102;
{$EXTERNALSYM UDM_SETPOS}
  UDM_SETPOS                            = WM_USER + 103;
{$EXTERNALSYM UDM_GETPOS}
  UDM_GETPOS                            = WM_USER + 104;
{$EXTERNALSYM UDM_SETBUDDY}
  UDM_SETBUDDY                          = WM_USER + 105;
{$EXTERNALSYM UDM_GETBUDDY}
  UDM_GETBUDDY                          = WM_USER + 106;
{$EXTERNALSYM UDM_SETACCEL}
  UDM_SETACCEL                          = WM_USER + 107;
{$EXTERNALSYM UDM_GETACCEL}
  UDM_GETACCEL                          = WM_USER + 108;
{$EXTERNALSYM UDM_SETBASE}
  UDM_SETBASE                           = WM_USER + 109;
{$EXTERNALSYM UDM_GETBASE}
  UDM_GETBASE                           = WM_USER + 110;
{$EXTERNALSYM UDM_SETRANGE32}
  UDM_SETRANGE32                        = WM_USER + 111;
{$EXTERNALSYM UDM_GETRANGE32}
  UDM_GETRANGE32                        = WM_USER + 112; // wParam & lParam are LPINT

type
  PNMUpDown = ^TNMUpDown;
{$EXTERNALSYM _NM_UPDOWN}
  _NM_UPDOWN = packed record
    hdr: TNMHDR;
    iPos: integer;
    iDelta: integer;
  end;
  TNMUpDown = _NM_UPDOWN;
{$EXTERNALSYM NM_UPDOWN}
  NM_UPDOWN = _NM_UPDOWN;

  (*������� �������*)
const
  HOTKEYF_SHIFT                         = $01;
  HOTKEYF_CONTROL                       = $02;
  HOTKEYF_ALT                           = $04;
  HOTKEYF_EXT                           = $08;

  HKCOMB_NONE                           = $0001;
  HKCOMB_S                              = $0002;
  HKCOMB_C                              = $0004;
  HKCOMB_A                              = $0008;
  HKCOMB_SC                             = $0010;
  HKCOMB_SA                             = $0020;
  HKCOMB_CA                             = $0040;
  HKCOMB_SCA                            = $0080;

  HKM_SETHOTKEY                         = WM_USER + 1;
  HKM_GETHOTKEY                         = WM_USER + 2;
  HKM_SETRULES                          = WM_USER + 3;

function AutoCQDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;


// the Auto-CQ settings dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowAutoCQ;

implementation
uses
  MainUnit,
  SysUtils,   // IntToStr
  uCFG;       // SetCFGCommandValue -- the one route to a [COMMANDS] value
var
  U                                     : _UDACCEL = (nSec: 1; nInc: 250);

function AutoCQDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1;
var
  lpTranslated                          : LongBool;
  code                                  : Word;
  TempByte                              : Byte;
//  VirtualKey                            : Byte;
begin
  Result := False;
  case Msg of

    WM_INITDIALOG:
      begin

        Windows.SetWindowTextA(hwnddlg, RC_AUTOCQ2);

        CreateStatic(RC_PRESSMKYWTR, 5, 5, 220, hwnddlg, 103);
        CreateStatic(RC_NUMBEROSOLT, 5, 45, 220, hwnddlg, 105);

        tWM_SETFONT(CreateWindowW('msctls_hotkey32', nil, WS_CHILD or WS_VISIBLE or WS_TABSTOP, 230, 5, 50, 21, hwnddlg, 107, hInstance, nil), MSSansSerifFont);
        // ES_NUMBER: the delay is an integer and the field used to accept
        // letters, which GetDlgItemInt then silently read as 0.  NY4I,
        // 2026-08-18.  When this dialog becomes an LCL form the style word
        // goes away and this is edtDelay.NumbersOnly := True.
        CreateEdit(ES_NUMBER, 230, 45, 50, 21, hwnddlg, 106);

        CreateOKCancelButtons(hwnddlg);

        SendDlgItemMessage(hwnddlg, 107, HKM_SETRULES, HKCOMB_CA or HKCOMB_S or HKCOMB_SA or HKCOMB_SC or HKCOMB_SCA or HKCOMB_NONE, 0);
        SendDlgItemMessage(hwnddlg, 107, HKM_SETHOTKEY, VK_F1, 0);

        CreateUpDownControl(WS_CHILD or WS_BORDER or WS_VISIBLE or UDS_NOTHOUSANDS or UDS_ARROWKEYS or UDS_ALIGNRIGHT or UDS_SETBUDDYINT, 0, 0, 0, 0, hwnddlg, 404, hInstance, GetDlgItem(hwnddlg, 106), 10000, 500, AutoCQDelayTime);
        SendDlgItemMessage(hwnddlg, 404, UDM_SETACCEL, 1, integer(@U));
        SendDlgItemMessage(hwnddlg, 106, EM_LIMITTEXT, 4, 0);
      end;

    WM_COMMAND:
      case wParam of
        2: goto 1;
        1:
          begin
//            VirtualKey := 0;
            code := LoWord(SendDlgItemMessage(hwnddlg, 107, HKM_GETHOTKEY, 0, 0));
            if code = 0 then Exit;
            TempByte := lobyte(code);
            if not (TempByte in [VK_F1..vk_f12]) then
               begin
               TempByte := VK_F1;
               end;
            if hibyte(code) = HOTKEYF_CONTROL then
               begin
               TempByte := TempByte + 12;
               end;
            if hibyte(code) = HOTKEYF_ALT then
               begin
               TempByte := TempByte + 24;
               end;
            AutoCQMemory := Char(TempByte);
            // THROUGH THE REGISTRY, NOT STRAIGHT AT THE INI.  This wrote the
            // file directly and assigned the global itself, which skipped
            // what CheckCommand does for this row: the crMin 500 / crMax 10000
            // bounds (uCFG.pas:469) and the row's crA hook.  A delay of 5 was
            // accepted here and then rejected at the next start as an invalid
            // statement.
            //
            // It is also the function uNet's receive side calls to apply an
            // inbound change, so a value now behaves identically whether it is
            // typed here or arrives from another position.  (It does NOT send:
            // crNetwork is read only by uOption.SendParameterToNetwork, which is
            // a separate explicit action -- checked, not assumed.)
            //
            // SetCFGCommandValue validates first and persists second, and it is
            // what assigns AutoCQDelayTime -- so the assignment that stood here
            // is gone rather than duplicated.
            SetCFGCommandValue('AUTO-CQ DELAY TIME',
                               IntToStr(GetDlgItemInt(hwnddlg, 106, lpTranslated, False)));
            RunAutoCQ;
            goto 1;
          end;
      end;

    WM_CLOSE: 1: EndDialog(hwnddlg, 0);
  end;
end;


procedure ShowAutoCQ;
begin
   CreateModalDialog(145, 60, tr4whandle, @AutoCQDlgProc, 0);
end;
end.

