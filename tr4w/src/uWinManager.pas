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
unit uWinManager;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Windows,
  Messages;

{
  THE WINDOW-CONTROL SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uWinManagerForm.pas -- and this unit keeps the entry point and
  ManageWindow, which is where the caller reads the chosen window.

  DELETED here, not wrapped (Phase 4b): WindowsManagerDlgProc, its
  Enumtr4wWindowsProc callback and CreateListBox, and the FIVE gotos -- three
  labels (FlashWind, SelectItem, ExitAndClose) that existed only because a
  DlgProc is one procedure handling every message with no other way to share an
  exit path.  A form has Close.
}

var
  ManageWindow                          : HWND;

// the Window control dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowWindowsManager;

implementation

uses
  uWinManagerForm;

procedure ShowWindowsManager;
begin
   uWinManagerForm.ShowWindowsManager;
end;

end.
