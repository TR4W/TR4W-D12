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
  (* uAnsiStr was here for StrLen over a PAnsiChar -- itself a
    replacement for Windows.lstrlenA -- and the parser it served now
    indexes a string, so neither is needed. *)
  TF;

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
function GetInsertableCommand(const src: string): String;

var
  LastSelectedCommand                   : String;


// the list of program messages, as a picker.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
function ShowMessagesList: integer;

implementation

uses
  uMessagesListForm;

function GetInsertableCommand(const src: string): String;
var
   startPos, eqPos, endPos, i: integer;
begin
   (* INDEXES, NOT POINTERS (2026-09-14).

     This walked the line with four PAnsiChars -- start, p, eqStart and the
     p[-1] look-behind -- and its only caller already had a string and was
     casting it with PAnsiChar(s) to get in here.

     ONE THING THE POINTER VERSION DID THAT THIS CANNOT: the separator scan
     tested p[0], p[1] and p[2] while only p^ was known to be inside the
     string, so on a line ending in a space it read ONE BYTE PAST the
     terminator. Harmless in practice and not expressible now -- the loop
     stops at Length(src) - 2, which is where a three-character ' = ' can
     still fit.

     Verified equivalent against the old body on 20 inputs before the swap,
     including the "  = = BT" case the comment below is about. The unit
     cannot be linked into tr4w_unit_tests (its implementation uses
     uMessagesListForm, which drags in the LCL), so that was a standalone
     probe running both implementations side by side. *)
   Result := '';

   // Skip leading spaces
   startPos := 1;
   while (startPos <= Length(src)) and (src[startPos] = ' ') do
      begin
      Inc(startPos);
      end;
   if startPos > Length(src) then
      begin
      Exit;
      end;

   // Look for ' = ' separator beginning one character past startPos
   // so that a command that IS '=' (e.g. "  = = BT") is not treated
   // as a separator itself.
   eqPos := 0;
   for i := startPos + 1 to Length(src) - 2 do
      begin
      if (src[i] = ' ') and (src[i + 1] = '=') and (src[i + 2] = ' ') then
         begin
         eqPos := i;
         Break;
         end;
      end;

   if eqPos > 0 then
      begin
      endPos := eqPos - 1;
      end
   else
      begin
      endPos := Length(src);
      end;

   // Trim the spaces before the separator (or before the end of the line).
   while (endPos >= startPos) and (src[endPos] = ' ') do
      begin
      Dec(endPos);
      end;

   if endPos >= startPos then
      begin
      Result := Copy(src, startPos, endPos - startPos + 1);
      end;
end;

// Fetch the text of the currently selected listbox item (ID 90) and store
// the extracted command in LastSelectedCommand. Returns True if an item was
// selected. We go through LB_GETTEXT rather than indexing sCommandsArray
// because the listbox is created with LBS_SORT — its visible index order
// does not match the array's insertion order.

function ShowMessagesList: integer;
begin
   // RETURNS the dialog result -- uEditMessage tests it for 1 to decide
   // whether to paste the chosen command. A procedure here would silently
   // drop that.
   Result := uMessagesListForm.ShowMessagesList;
end;

end.
