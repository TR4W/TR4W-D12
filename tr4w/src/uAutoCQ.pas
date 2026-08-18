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
  Windows;   // HWND, for nothing but the seam's shape

{
  THE AUTO-CQ SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uAutoCQForm.pas -- and this unit is the entry point only.

  DELETED here, not wrapped (Phase 4a): AutoCQDlgProc, the msctls_hotkey32
  capture control and its HKM_* messages, the updown buddy and its UDM_*
  messages, and the ~90 lines of UPDOWN_CLASS / HOTKEYF_ / UDM_ / HKM_ constant
  and record declarations this unit carried purely to talk to those two
  controls.  A read-only TEdit with OnKeyDown replaces the first; a TSpinEdit
  replaces the second.
}

// the Auto-CQ settings dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4a, 2026-08-18: that is exactly what happened, and no call site moved.
procedure ShowAutoCQ;

implementation

uses
  uAutoCQForm;

procedure ShowAutoCQ;
begin
   uAutoCQForm.ShowAutoCQ;
end;

end.
