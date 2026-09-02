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
unit uLogEdit;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
   TF,
   VC,
   uEditQSO,
   Windows,
   LogDupe,
   Tree,
   uCommctrl,
   PostUnit,
   Messages,
  uTR4WStrings;

   function LogEditDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;

   procedure EditFullLog;
   var LogEditListView                  : HWND;
       FullLogEditHandle                : HWND;
       FullLogEditIndex                 : integer;


// the View/Edit log window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowLogEdit;

implementation

uses MainUnit, uLogSource;

function LogEditDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
   1, 2;
var
   i : integer;

   begin
   Result := False;
   case Msg of
      WM_INITDIALOG:
         begin
            FullLogEditHandle := hwnddlg;
            Windows.SetWindowTextW(hwnddlg, PWideChar(UnicodeString(RC_VIEWEDITLOG2)));
            LogEditListView := CreateEditableLog(hwnddlg, 0, 0, 790, 420, True);
            i := 0;
            if not LogSourceOpen then
               begin
               Exit;
               end;
            LogSourceRewind;
            2:
            if LogSourceNext( TempRXData ) then
               begin
               tAddContestExchangeToLog(TempRXData, LogEditListView, i);
               goto 2;
               end;
            LogSourceClose;
            EnsureListViewColumnVisible(LogEditListView);
            Windows.SetFocus(LogEditListView);
            ListView_SetItemState( LogEditListView
                                  ,0
                                  ,LVIS_FOCUSED or LVIS_SELECTED
                                  ,LVIS_FOCUSED or LVIS_SELECTED
                                 );

         end;
      WM_COMMAND:
         begin
         if lParam = 0 then
            begin
            if LoWord(wParam) = 1 then
               begin
               EditFullLog;
               end;
            end;
         case wParam of
            2: goto 1;
            end;
         end;
      WM_CLOSE: 1:
         begin
         FullLogEditHandle := 0;
         EndDialog(hwnddlg, 0);
         end;
      WM_NOTIFY:
         begin
         with PNMHdr(lParam)^ do
            begin
            case code of
               NM_DBLCLK: EditFullLog;
            end;
            end;
         end;
  end;
end;
procedure EditFullLog;
   begin
   FullLogEditIndex := ListView_GetNextItem(LogEditListView, -1, LVNI_SELECTED);
   if FullLogEditIndex = -1 then
      begin
      Exit;
      end;
   (* This window lists the WHOLE log, so its row number is the record index.
      It used to be multiplied back into a byte offset here. *)
   IndexOfItemInLogForEdit := FullLogEditIndex;
   OpenEditQSOWindow(FullLogEditHandle);
   end;

procedure ShowLogEdit;
begin
   CreateModalDialog(396, 212, tr4whandle, @LogEditDlgProc, 0);
end;
end.
