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
unit uCT1BOH;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
  Windows
  ;
{
  THE CT1BOH SEAM.  The report itself is now an LCL form --
  src\ui\lcl\uCT1BOHForm.pas -- and this unit is the entry point only.

  DELETED here, not wrapped (Phase 4b): ct1bohDlgProc, its CreateListView2 and
  the ListView_InsertColumn / InsertItem / SetItem calls, CT1BOHInfoString
  (which returned a pointer into the shared wsprintfBuffer), and one goto.

  A WHOLE CLASS OF PROBLEM WENT WITH IT.  This unit carried two long comments
  about uCommctrl versus FPC's own commctrl -- the same type names declared in
  both, binding differently by uses-clause order and surfacing as "Call by var
  has to match exactly: got tagLVCOLUMNA expected LV_COLUMN" -- and a
  function-scoped AnsiString existing only to keep pszText alive across
  ListView_SetItem.  A TListView takes strings; none of that exists any more,
  which is why uCommctrl has left the uses clause entirely.
}

// the CT1BOH information box.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowCT1BOHInfo;

implementation

uses
  uCT1BOHForm;

procedure ShowCT1BOHInfo;
begin
   uCT1BOHForm.ShowCT1BOHInfo;
end;

end.
