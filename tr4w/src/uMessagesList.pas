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
unit uMessagesList;
{$I tr4w.inc}

interface

uses
  VC,
  TF,
  Windows,
  Messages;

{
  THE LIST-OF-COMMANDS SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uMessagesListForm.pas -- and this unit keeps the entry point, the
  chosen command, and the parser that extracts it.

  DELETED here, not wrapped (Phase 4b): MessagesListDlgProc, its CreateListBox +
  tLB_ADDSTRING fill loop, and TryCaptureSelectedCommand -- which existed only
  to reach the listbox through LB_GETCURSEL / LB_GETTEXTLEN / LB_GETTEXT.  A
  TListBox answers ItemIndex and Items[] directly.

  GetInsertableCommand STAYS: it is a string parser, not dialog code, and the
  form calls it.
}

// Extracts the insertable token from a caCommand display string.  Kept here
// rather than moved into the form: it is pure parsing, and it is the piece most
// worth having somewhere testable.
function GetInsertableCommand(src: PAnsiChar): String;

var
  LastSelectedCommand                   : String;


// the list of program messages, as a picker.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
function ShowMessagesList(const aParent: HWND): integer;

implementation

uses
  uMessagesListForm;

function GetInsertableCommand(src: PAnsiChar): String;
var
  start, p, eqStart: PAnsiChar;
  len: Integer;
begin
  Result := '';

  // Skip leading spaces
  start := src;
  while start^ = ' ' do
     begin
     Inc(start);
     end;
  if start^ = #0 then
     begin
     Exit;
     end;

  // Look for ' = ' separator beginning one character past start
  // so that a command that IS '=' (e.g. "  = = BT") is not treated
  // as a separator itself.
  eqStart := nil;
  p := start + 1;
  while p^ <> #0 do
     begin
     if (p[0] = ' ') and (p[1] = '=') and (p[2] = ' ') then
        begin
        eqStart := p;
        Break;
        end;
     Inc(p);
     end;

  if eqStart <> nil then
     begin
     p := eqStart;
     while (p > start) and (p[-1] = ' ') do
        begin
        Dec(p);
        end;
     len := p - start;
     end
  else
     begin
     p := start + Windows.lstrlenA(start);
     while (p > start) and (p[-1] = ' ') do
        begin
        Dec(p);
        end;
     len := p - start;
     end;

  if len > 0 then
     begin
     SetString(Result, start, len);
     end;
end;

// Fetch the text of the currently selected listbox item (ID 90) and store
// the extracted command in LastSelectedCommand. Returns True if an item was
// selected. We go through LB_GETTEXT rather than indexing sCommandsArray
// because the listbox is created with LBS_SORT — its visible index order
// does not match the array's insertion order.

function ShowMessagesList(const aParent: HWND): integer;
begin
   // RETURNS the dialog result -- uEditMessage tests it for 1 to decide
   // whether to paste the chosen command. A procedure here would silently
   // drop that.
   Result := uMessagesListForm.ShowMessagesList(aParent);
end;

end.
