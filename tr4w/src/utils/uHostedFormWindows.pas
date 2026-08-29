{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uHostedFormWindows;
{$I ..\tr4w.inc}

{
  Which top-level windows belong to a GUI TOOLKIT hosted inside TR4W's own
  message loop -- and therefore must be left alone by it.

  WHY THIS IS ITS OWN UNIT.  `program tr4w;` owns its GetMessage /
  TranslateMessage / DispatchMessage loop (tr4w.lpr) and routes WM_CHAR into the
  callsign window, treats F-keys and the numeric keypad as CW memories, and runs
  an accelerator table.  Every one of those would steal keystrokes from a text
  box in a toolkit-owned window.  So the loop's FIRST question is "is this
  message someone else's?", and this unit answers it.

  IT IS PURE WIN32 AND NAMES NO TOOLKIT.  That is the point: it was extracted
  from uFMXCoexist when the LCL port started, because the answer -- a handle
  registry plus a GetAncestor walk -- is identical whether the window belongs to
  FMX or to the LCL, and TWO COPIES OF IT WOULD DRIFT.  This tree has paid for
  that shape before (LOGRADIO's per-model dispatch duplicated in
  uRadioPolling).  What stays framework-specific is only the toolkit's own
  "the application is running" hook, which lives beside that toolkit.

  Registering the same handle twice is harmless; unregistering one that was
  never registered is too.  Both are called from form show/close paths where
  the exact pairing is not worth asserting.
}

interface

uses
   Windows,
   Messages;

procedure RegisterHostedFormHandle(const aHandle: HWND);
procedure UnregisterHostedFormHandle(const aHandle: HWND);

// True when this message belongs to a registered window, or to any child of
// one.  The main loop's first question.
function MessageIsForHostedWindow(const aMsg: TMsg): boolean;

// True when any hosted window is currently open.  Cheap enough to guard work
// that only matters while one is up.
function AnyHostedWindowOpen: boolean;

implementation

var
   // Deliberately a plain array: it holds one or two handles, and it is read
   // on every message in the loop.
   gHandles: array of HWND;

function IndexOfHandle(const aHandle: HWND): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(gHandles) do
      begin
      if gHandles[i] = aHandle then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure RegisterHostedFormHandle(const aHandle: HWND);
var
   n: integer;
begin
   if aHandle = 0 then
      begin
      Exit;
      end;
   if IndexOfHandle(aHandle) >= 0 then
      begin
      Exit;
      end;

   n := Length(gHandles);
   SetLength(gHandles, n + 1);
   gHandles[n] := aHandle;
end;

procedure UnregisterHostedFormHandle(const aHandle: HWND);
var
   idx, i: integer;
begin
   idx := IndexOfHandle(aHandle);
   if idx < 0 then
      begin
      Exit;
      end;

   for i := idx to High(gHandles) - 1 do
      begin
      gHandles[i] := gHandles[i + 1];
      end;
   SetLength(gHandles, Length(gHandles) - 1);
end;

function AnyHostedWindowOpen: boolean;
begin
   Result := Length(gHandles) > 0;
end;

function MessageIsForHostedWindow(const aMsg: TMsg): boolean;
var
   root: HWND;
begin
   Result := False;

   // The overwhelmingly common case, and the one that must stay cheap: no
   // hosted window is open at all, so every message in a contest goes through
   // one length test.
   if Length(gHandles) = 0 then
      begin
      Exit;
      end;

   if aMsg.hwnd = 0 then
      begin
      // A thread message (PostThreadMessage) belongs to no window.  It is not
      // the toolkit's, and asking GetAncestor about a null handle would answer
      // 0 -- which could match an empty slot if the list ever held one.
      Exit;
      end;

   if IndexOfHandle(aMsg.hwnd) >= 0 then
      begin
      Result := True;
      Exit;
      end;

   // Walk up to the owning top-level window: the message is addressed to the
   // child with focus, and everything under a registered form belongs to it.
   root := GetAncestor(aMsg.hwnd, GA_ROOT);
   Result := (root <> 0) and (IndexOfHandle(root) >= 0);
end;

end.
