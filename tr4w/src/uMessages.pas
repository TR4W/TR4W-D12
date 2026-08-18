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
unit uMessages;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  uAltP,
  TF,
  VC,
  Windows,
  Messages,
  Tree;

function MESDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
var
  MessagesKeys                          : array[1..12] of HWND;
  MessagesValues                        : array[1..12] of HWND;


// the program-message box (Tools -> Program message).
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowProgramMessage;

implementation
uses uRadioPolling,
  MainUnit;

function MESDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
var
  i                                     : integer;
const
  LineHeight                            = 15;
  ceoa                                  : array[1..3] of PAnsiChar = (RC_PRESS_C, RC_PRESS_E, RC_PRESS_O);
label
  1;

begin
  Result := False;
  case Msg of

    WM_INITDIALOG:
      begin

        Windows.SetWindowTextA(hwnddlg, RC_MEMPROGFUNC);

        for i := 1 to 3 do
           begin
           CreateButton(BS_LEFT, ceoa[i], 30, -10 + i * 30, 350, hwnddlg, i + 100);
           end;

      end;

    WM_COMMAND:
      begin
        if wParam = 2 then
           begin
           goto 1;
           end;
        if HiWord(wParam) = BN_CLICKED then
           begin
           MesWindow := CQMsgWin;
           if LoWord(wParam) = 102 then
              begin
              MesWindow := ExMsgWin;
              end;
           if LoWord(wParam) = 103 then
              begin
              MesWindow := OtherMsgWin;
              end;
           EndDialog(hwnddlg, 0);
           OpenListOfMessages;
           end;

      end;

    WM_CLOSE: 1: EndDialog(hwnddlg, 0);

  end;
end;


procedure ShowProgramMessage;
begin
   CreateModalDialog(205, 70, tr4whandle, @MESDlgProc, 0);
end;
end.

