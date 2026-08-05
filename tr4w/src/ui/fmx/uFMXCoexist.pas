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
unit uFMXCoexist;

{
  Lets an FMX window live inside TR4W's own Win32 message loop.

  THE PROBLEM.  TR4W does not use a framework -- tr4w.dpr owns a hand-written
  GetMessage loop that inspects nearly every message before dispatching it.  It
  runs the accelerator table, it routes WM_CHAR into the callsign window, it
  treats function keys as CW memories and the numeric keypad as memories too.
  That is right for the contest UI and catastrophic for a text box in another
  window: type 'K4' into an FMX edit and the characters land in the Call window
  instead, and F1 sends CQ rather than doing nothing.

  Note the loop cannot simply "check if a control has focus", because focus is
  not the thing being tested -- the loop sees messages for EVERY window in the
  process, and TR4W's own windows are not FMX windows.

  THE FIX, in one place.  An FMX form registers its window handle while it is
  open.  The loop asks, as its FIRST question: is this message destined for one
  of those windows?  If so it does a plain Translate + Dispatch and skips
  everything else -- accelerators included.  FMX then handles the keystroke the
  way any FMX application would.

  WHY GetAncestor(..., GA_ROOT).  A message arrives addressed to the specific
  child window under the cursor or with focus, not to the top-level form.  FMX
  puts its controls on ONE window and draws them, so in the common case the
  handle already IS the form -- but menus, drop-downs and combo lists get their
  own top-level windows, and a message for a drop-down whose ROOT is not the
  registered form would fall through to the contest loop.  GA_ROOT walks up to
  the owning top level, which is the form, so the whole widget tree is covered
  by one registration.

  WHY A LIST RATHER THAN A SINGLE HANDLE.  A modeless preferences window plus a
  modal child is two windows at once, and the spike is expected to open a second
  form.  The list is tiny and linear-scanned on purpose: it is consulted for
  every message in the loop, and a hash lookup for an array that will hold one
  or two entries would cost more than it saves.

  THREAD AFFINITY.  Registration is only ever done from the thread that owns the
  message loop -- forms register in OnShow and unregister in OnClose, both of
  which run there.  No lock, for the same reason the loop needs none.
}

interface

uses
   Winapi.Windows,
   Winapi.Messages;

// Called by a form as it is shown / as it closes.  Registering the same handle
// twice is harmless; unregistering one that was never registered is too.
procedure RegisterFMXFormHandle(const aHandle: HWND);
procedure UnregisterFMXFormHandle(const aHandle: HWND);

// True when this message belongs to a registered FMX window (or to any child
// of one).  The main loop's first question.
function MessageIsForFMXWindow(const aMsg: TMsg): boolean;

// True when any FMX window is currently open.  Cheap enough to guard work that
// only matters while one is up.
function AnyFMXWindowOpen: boolean;

implementation

var
   // Deliberately a plain array: it holds one or two handles, and it is
   // consulted once per message.
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

procedure RegisterFMXFormHandle(const aHandle: HWND);
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

procedure UnregisterFMXFormHandle(const aHandle: HWND);
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

function AnyFMXWindowOpen: boolean;
begin
   Result := Length(gHandles) > 0;
end;

function MessageIsForFMXWindow(const aMsg: TMsg): boolean;
var
   root: HWND;
begin
   Result := False;

   // The overwhelmingly common case, and the one that must stay cheap: no FMX
   // window is open at all, so every message in a contest goes through one
   // length test.
   if Length(gHandles) = 0 then
      begin
      Exit;
      end;

   if aMsg.hwnd = 0 then
      begin
      // A thread message (PostThreadMessage) belongs to no window.  It is not
      // FMX's, and asking GetAncestor about a null handle would answer 0 --
      // which could match an empty slot if the list ever held one.
      Exit;
      end;

   if IndexOfHandle(aMsg.hwnd) >= 0 then
      begin
      Result := True;
      Exit;
      end;

   // Walk up to the owning top-level window: the message is addressed to the
   // child with focus, and everything under a registered form counts as FMX's.
   root := GetAncestor(aMsg.hwnd, GA_ROOT);
   Result := (root <> 0) and (IndexOfHandle(root) >= 0);
end;

end.
