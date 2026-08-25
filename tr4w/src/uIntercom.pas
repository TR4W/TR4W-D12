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
unit uIntercom;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Tree,
  uGradient,
  utils_file,
  Windows,
  LogEdit,
  LogWind,
  LogStuff,
  Messages;

procedure AddMessageToIntercomWindow(mes: PAnsiChar; Sender: AnsiChar);
procedure FlashIntercomListBox;
procedure EnumINTERCOMTXT(FileString: PShortString);

{ THE BACKLOG FROM INTERCOM.TXT.

  Ran inside WM_INITDIALOG, so it happened exactly once per opening of the
  window.  The form calls it from OnCreate, which is also once -- the form
  object is reused across opens, so loading on every OnShow would append the
  whole file again each time. }
procedure LoadIntercomHistory;

var
  { IntercomListBoxHandle is gone with the dialog: the list box is a TListBox on
    uIntercomForm and there is no raw handle to keep. }
  LastItemInIntercomListBox        : integer;

implementation
uses MainUnit,
  uFlasher,    { the intercom flash is a timer now }
  uIntercomForm,   { the window is a form -- the list box lives there }
   uConfigValues;

procedure AddMessageToIntercomWindow(mes: PAnsiChar; Sender: AnsiChar);
var
  stored                           : integer;
  h                                : HWND;
  lpThreadId                       : DWORD;
begin
  if tr4w_WindowsArray[tw_INTERCOMWINDOW_INDEX].WndHandle = 0 then
     begin
     ProcessMenu(menu_windows_intercom);
     end;

  // Issue #997: manual cdecl varargs push -> TF.Format (itself wsprintfA, so
  // identical marshalling). The asm pushes were right-to-left, so the format
  // arg order is: GetTimeString (%s), Sender (%C), mes (%s). Sender is pushed
  // zero-extended (xor eax,eax; mov al,Sender) -> Ord(Sender). This binds the
  // (PChar, integer, PChar) overload.
  stored := TF.Format(wsprintfBuffer, '%s %C :   %s', GetTimeString, Ord(Sender), mes);

  if Config.IntercomFileEnable then
     begin
     h := CreateFileA(TR4W_INTERCOM_FILENAME, GENERIC_WRITE or GENERIC_READ, FILE_SHARE_WRITE or FILE_SHARE_READ, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_ARCHIVE, 0);
     if h <> INVALID_HANDLE_VALUE then
        begin
        SetFilePointer(h, 0, nil, FILE_END);
        sWriteFile(h, wsprintfBuffer, stored);
        sWriteFileFromString(h, #13#10);
        CloseHandle(h);
        end;
     end;
  // THROUGH THE FORM.  The window is an LCL form (uIntercomForm) and the raw
  // HWND the list box used to be is gone; TopIndex scrolls to the end, which is
  // what the WM_VSCROLL/SB_BOTTOM did.
  if TR4WIntercomForm = nil then
     begin
     Exit;
     end;
  with TR4WIntercomForm.lstMessages do
     begin
     LastItemInIntercomListBox := Items.Add(string(AnsiString(PAnsiChar(@wsprintfBuffer))));
     TopIndex := Items.Count - 1;
     end;
  FlashIntercomListBox;
end;


{ Lazily created, so the headless /EXPORT path -- which boots the contest,
  writes the files and halts before any GUI -- never constructs a timer it
  cannot run. }
var
  gIntercomFlasher: TFlasher = nil;

function IntercomFlasher: TFlasher;
begin
  if gIntercomFlasher = nil then
     begin
     gIntercomFlasher := TFlasher.Create;
     end;
  Result := gIntercomFlasher;
end;

{ One phase of the intercom flash.  Was a thread that ran 49 x Sleep(150) --
  SEVEN AND A HALF SECONDS it could not be told to stop.  See uFlasher.

  STILL FLASHES BY TOGGLING SELECTION, which is a state and not a highlight.
  That was excused before by the list box being a raw Win32 window with nothing
  else to set; it is a TListBox now, so the excuse is gone even though the
  behaviour is unchanged.  Left alone deliberately: changing what the flash
  LOOKS like is a visual decision for NY4I, not a side effect of a conversion. }
procedure IntercomFlashPhase(const aOn: boolean);
begin
  if TR4WIntercomForm = nil then
     begin
     Exit;
     end;
  if (LastItemInIntercomListBox < 0) or
     (LastItemInIntercomListBox >= TR4WIntercomForm.lstMessages.Items.Count) then
     begin
     Exit;
     end;
  TR4WIntercomForm.lstMessages.Selected[LastItemInIntercomListBox] := aOn;
end;

procedure FlashIntercomListBox;
begin
  if TR4WIntercomForm = nil then
     begin
     Exit;
     end;

  // Clear any existing selection first, as the loop did before its first pass.
  TR4WIntercomForm.lstMessages.ClearSelection;

  // 49 phases at 150 ms -- the same flash, now cancellable and off no thread.
  IntercomFlasher.Start(@IntercomFlashPhase, 49, 150);
end;

procedure LoadIntercomHistory;
begin
  EnumerateLinesInFile('INTERCOM.TXT', EnumINTERCOMTXT, false);
end;

procedure EnumINTERCOMTXT(FileString: PShortString);
begin
  if TR4WIntercomForm <> nil then
     begin
     TR4WIntercomForm.lstMessages.Items.Add(string(FileString^));
     end;
end;

end.

