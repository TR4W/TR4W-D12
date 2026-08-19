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
unit LPT;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  uCFG,
  TF,
  VC,
  CFGCMD,
  LogK1EA,
  uIO,
  LogWind,
  LogCfg,
  LogRadio,
  Tree,
  Windows,
  Messages;

var
LPTBaseAddressArray                   : array[Parallel1..Parallel3] of Cardinal = ($378, $278, $3BC);  
{
  THE LPT SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uLPTForm.pas -- and this unit keeps the entry point and
  LPTBaseAddressArray.

  DELETED here, not wrapped (Phase 4b): LPTDlgProc, its two loops building nine
  static/edit and static/combo pairs, the three gotos, and three arms that
  could never run -- control 50 (an Apply button that is enabled and disabled
  but never created) and the wParam 51 and 52 handlers, which no control could
  send because no control with those ids exists.
}

// the LPT port dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowLPTDialog;

implementation

uses
  uLPTForm;

procedure ShowLPTDialog;
begin
   uLPTForm.ShowLPTDialog;
end;

end.
