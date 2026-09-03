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
unit uEditMessage;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
//
uses
  uMessagesList,
  CFGCMD,
  TF,
  VC,
  utils_file,
  Windows,
  Messages,
  MMSystem,
  Tree,
  LogWind

  ;

{
  THE PROGRAM-MESSAGE-EDITOR SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uEditMessageForm.pas -- and this unit keeps the entry point and
  DeleteEscapeChars, which the form still calls on the way to the .cfg.

  DELETED here, not wrapped (Phase 4b): EditMessageDlgProc and NewMsgEditProc --
  a whole window procedure subclassed onto the message edit so it could see
  Ctrl+letter -- along with the MsgEditHWND / OldMsgEditProc / EditMessageWnd /
  AllowEscapes / SelPos globals that existed only to let those two talk to each
  other.  3f65889d had already removed the dead hint popup; between them the
  unit goes from 531 lines to this.
}

// DeleteEscapeChars is NOT dialog code: it turns the editor's control
// characters back into the on-disk escape spelling, and the form calls it.
procedure DeleteEscapeChars(var s: ShortString);

// the single-message editor.  Parent and message index both come from the
// caller (uAltP passes its own window and the selected message).
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);

implementation

uses
  uEditMessageForm;

procedure DeleteEscapeChars(var s: ShortString);
const
  HexChars                              : array[0..$F] of AnsiChar = '0123456789ABCDEF';
var
  TempString                            : ShortString;
  i                                     : integer;
  l                                     : integer;
begin
  l := 0;
  for i := 1 to length(s) do
     begin
     inc(l);
     if s[i] > CHR(31) then
        begin
        TempString[l] := s[i];
        end
     else
        begin
        TempString[l] := '<';
        TempString[l + 1] := HexChars[Ord(s[i]) shr $4];
        TempString[l + 2] := HexChars[Ord(s[i]) and $F];
        TempString[l + 3] := '>';
        inc(l, 3);
        end;
     end;
  TempString[0] := AnsiChar(l);
  s := TempString;
  s[l + 1] := #0;
end;

procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);
begin
   uEditMessageForm.ShowEditMessage(aParent, aMessage);
end;

end.
