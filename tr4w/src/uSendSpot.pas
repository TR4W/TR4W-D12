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
unit uSendSpot;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  uNet,
  Windows,
  LogStuff,
  LogK1EA,
  LogWind,
  LogRadio,
  LogEdit,
  WinSock2,
  PostUnit,
  Messages;

{
  THE SEND-SPOT SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uSendSpotForm.pas -- and this unit is the entry point only.

  DELETED here, not wrapped (Phase 4a): SendSpotDlgProc, its CreateStatic /
  CreateEdit loop, the BN_CLICKED arm that mirrored the tick into the comment
  field, and the pointer-built spot string.  A LANG_RUS-only help arm went with
  them: it answered control id 110, which no arm of this dialog ever created.
}

// the Send Spot dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4a, 2026-08-18: that is exactly what happened, and no call site moved.
procedure ShowSendSpot;

implementation

uses
  uSendSpotForm;

procedure ShowSendSpot;
begin
   uSendSpotForm.ShowSendSpot;
end;

end.
