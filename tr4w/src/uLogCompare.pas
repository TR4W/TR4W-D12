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
unit uLogCompare;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  VC,
  TF,
  uWin32Compat,   // IDI_WARNING -- the FPC gap list

  PostUnit,
  Windows,
  LogDupe,
  Messages
  ;

{
  THE LOG-COMPARISON SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uLogCompareForm.pas -- and this unit keeps the entry point and
  the two globals uNet reads.

  DELETED here, not wrapped (Phase 4b): LogCompareDlgProc, its CreateListView2
  and column/row construction, three CreateButtons, and two gotos.

  A LATENT BUG WENT WITH IT.  OpenGetServerLogDlg -- "the operator pressed
  Synchronize, so open the server-log dialog afterwards" -- was a LOCAL of the
  DlgProc, which lives for one message only.  It worked when Synchronize was
  pressed (its arm set the flag and jumped to the close arm in the same call)
  and read UNINITIALISED stack on any other close, where a non-zero value
  opened a dialog nobody asked for.  It is a field on the form now.
}

var
  TimeDifference                        : integer;

// the log-comparison dialog.  Two call sites in uNet pass the same shape.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowLogCompare(const aInitParam: lParam);

implementation

uses
  uLogCompareForm;

procedure ShowLogCompare(const aInitParam: lParam);
begin
   uLogCompareForm.ShowLogCompare(aInitParam);
end;

end.
