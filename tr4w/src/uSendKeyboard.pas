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
unit uSendKeyboard;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

interface

uses
  uConfigValues,
  uMMTTY,
  uTelnet,
  VC,
  TF,
  Windows,
  Tree,
  LOGSend,
  LogCW,
  uCWKeyerBase,   // KeyerCPU -- CPU-keyer-only flush (B3)
  LogWind,
  LogK1EA,
  Messages
  ;

{
  THE SEND-KEYBOARD-CW SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uSendKeyboardForm.pas -- and this unit is the entry point and
  the two exported helpers, all three forwarding.

  DELETED here, not wrapped (Phase 4a): SendKeyboardCWDlgProc and
  NewSendKeyboardEditProc -- a whole window procedure subclassed onto the edit
  to catch Enter, PageUp/PageDown and F10 -- plus the EN_CHANGE arm that keyed
  each character as it was typed, and the SendKeyboardWindow HWND that served
  as the open/closed flag.  A form knows whether it is visible.

  It was DEFERRED in f75eb405 because its parent can be a QTC window and LCL
  ShowModal disables LCL forms only; ShowModalOverWin32Parent (d2aff49a)
  removed that blocker.
}

// the send-CW-from-keyboard box.  Takes its parent EXPLICITLY: the caller
// passes tCardinal, not tr4whandle, and that is a real difference rather
// than an oversight -- do not quietly normalise it here.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
//
// Phase 4a, 2026-08-18: that is exactly what happened, and no call site moved.
procedure ShowSendKeyboardCW(const aParent: HWND);
procedure CloseSendKeyboardInputDialog(StopSending: boolean);
function SendKeyboardInputDialogOpen: boolean;

implementation

uses
  uSendKeyboardForm;

procedure ShowSendKeyboardCW(const aParent: HWND);
begin
   uSendKeyboardForm.ShowSendKeyboardCW(aParent);
end;

procedure CloseSendKeyboardInputDialog(StopSending: boolean);
begin
   uSendKeyboardForm.CloseSendKeyboardInputDialog(StopSending);
end;

function SendKeyboardInputDialogOpen: boolean;
begin
   Result := uSendKeyboardForm.SendKeyboardInputDialogOpen;
end;

end.
