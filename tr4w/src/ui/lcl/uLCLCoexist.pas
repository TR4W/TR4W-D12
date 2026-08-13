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
unit uLCLCoexist;
{$I ..\..\tr4w.inc}

{
  Hosting LCL forms inside TR4W's own message loop.

  `program tr4w;` owns its GetMessage / TranslateMessage / DispatchMessage loop
  and builds its windows with CreateWindow.  There is no MainForm and
  Application.Run is never called.  Any toolkit here has to tolerate that.

  THIS UNIT IS DELIBERATELY ALMOST EMPTY, and the reason is worth stating
  because its FMX counterpart is not.

  uFMXCoexist carries TellFMXTheApplicationIsRunning, a shim installed because
  FMX asks "is the application running?" before it will activate a form, and on
  Windows that answer comes from TPlatformWin.FRunning -- set by
  Application.Run, the one call this architecture never makes.  Every hosted FMX
  form therefore stayed Active=False for its whole life, and the only visible
  symptom was that an edit accepted keystrokes but SHOWED NO CARET (diagnosed on
  the bench 2026-08-05).

  The LCL was asked the same question directly rather than assumed to differ
  (spike\lclprobe, 2026-08-13).  With Application.Initialize called and
  Application.Run never called, inside a hand-rolled loop:

      form Active      : TRUE
      form Visible     : TRUE
      handle allocated : TRUE
      edit Focused     : TRUE

  So there is nothing to mirror.  The LCL activates and focuses a hosted form
  without being told anything, which is why this unit holds an initialiser and
  no shim.

  WHICH WINDOWS ARE OURS is NOT here either: that lives in uHostedFormWindows,
  which is pure Win32, names no toolkit, and is shared with the FMX side.  A
  form registers its handle there as it shows and unregisters as it closes, and
  tr4w.dpr's loop asks that unit whether a message belongs to a hosted window
  before applying its own CW-memory and accelerator handling.
}

interface

{$IFDEF FPC}

// Call ONCE, early in startup, before any LCL form is created.  Idempotent:
// calling it twice is harmless, which matters because the call site is a
// startup path that has grown conditional branches over the years.
//
// It does NOT call Application.Run and never will -- see the unit header.
procedure InitLCLForHostedLoop;

// True once InitLCLForHostedLoop has run.  A form that creates itself before
// the widgetset is initialised fails in ways that do not name the cause, so
// the form units assert on this rather than discovering it at random.
function LCLReadyForHostedForms: boolean;

{$ENDIF}

implementation

{$IFDEF FPC}

uses
   // Interfaces FIRST, and it is not optional.  It is what links the win32
   // widgetset, which supplies every WSRegisterXxx symbol the LCL's controls
   // reference.  Without it the link fails with a wall of
   //     Undefined symbol: WSRegisterControl, WSRegisterMenu, ...
   // that names no unit and does not suggest its own cause.  Listing it here
   // rather than in tr4w.dpr keeps the whole LCL dependency in one place, and
   // the uses order guarantees it initialises before Forms.
   Interfaces,
   Forms;

var
   gInitialised: boolean = False;

procedure InitLCLForHostedLoop;
begin
   if gInitialised then
      begin
      Exit;
      end;

   // Registers the widgetset and the platform services an LCL form needs to
   // create its window.  It does not start a message loop and does not create
   // a main form -- the loop below it stays TR4W's own.
   Application.Initialize;
   gInitialised := True;
end;

function LCLReadyForHostedForms: boolean;
begin
   Result := gInitialised;
end;

{$ENDIF}

end.
