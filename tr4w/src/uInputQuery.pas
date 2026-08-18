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
unit uInputQuery;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  TF,
  Windows,
  Messages;

var
  IQresult                              : ShortString;
  IQMaxInputLength                      : integer;

{
  THE INPUT-QUERY SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uInputQueryForm.pas -- and this unit keeps the caller's contract
  and nothing else: IQresult and IQMaxInputLength, which LOGWIND writes and
  reads around the call.

  DELETED here, not wrapped (Phase 4a): IQDlgProc, its control construction, the
  SetWindowLong(GWL_STYLE) that poked ES_NUMBER/ES_UPPERCASE into an edit AFTER
  creating it, the EM_SETPASSWORDCHAR, the EM_LIMITTEXT, and the icon-ordinal
  arithmetic that had already needed one D12 repair because PChar stride doubled
  under PWideChar. Every one of those is a control property in the LCL.
}

// the one-line input query.  Parent is explicit: LOGWIND picks between the
// active window and tr4whandle before calling.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
//
// Phase 4a, 2026-08-18: that is exactly what happened, and no call site moved.
procedure ShowInputQuery(const aParent: HWND);

implementation

uses
  uInputQueryForm;

procedure ShowInputQuery(const aParent: HWND);
begin
   uInputQueryForm.ShowInputQuery(aParent);
end;

end.
