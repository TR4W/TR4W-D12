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
procedure InitLCLApplication;

{ Tell the operator that TR4W is already running, and say it VISIBLY.

  This was a raw MessageBoxW(0, ...) in tr4w.dpr with MB_SYSTEMMODAL.
  Application.Initialize has already run by this point, so the LCL owns the
  message pump such a dialog needs; going around it with a raw Win32 call was
  gratuitous.

  A NOTE ON WHAT THIS DID *NOT* FIX, because an earlier version of this comment
  claimed otherwise.  It was written believing the raw call created no window at
  all -- read off a probe that reported no top-level window for the process.
  That probe could not see ANY window, not even Notepad's, so it proved nothing;
  NY4I confirmed the dialog does appear on his desktop.  The real cause of the
  invisible, unkillable-looking TR4W was a HEADLESS EXPORT reaching this dialog,
  and that is fixed in tr4w.dpr by deciding batch mode before the
  single-instance check. }
procedure ReportAlreadyRunning(const aMessage: string);

{ Hand the program to the LCL and do not come back.

  Phase 3c: TR4W ran its own GetMessage loop until 2026-08-23, which is why the
  initialiser above used to be called InitLCLForHostedLoop -- the LCL was a
  guest inside TR4W's loop.  It is the other way round now.

  Application.Run is HERE rather than in tr4w.dpr for the same reason
  Application.Initialize is: this unit owns the whole LCL dependency, and
  tr4w.dpr does not link Forms. }
procedure RunLCLApplication;

// True once InitLCLApplication has run.  A form that creates itself before
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
   Forms,
   LCLType,      { MB_OK, MB_ICONWARNING }
   uAppStrings;  { SAlreadyRunningTitle }

var
   gInitialised: boolean = False;

procedure ReportAlreadyRunning(const aMessage: string);
begin
   // PAnsiChar, and this one IS a real byte boundary: TApplication.MessageBox
   // takes PChar meaning PAnsiChar, while this unit compiles with
   // {$MODESWITCH UnicodeStrings} so a bare PChar cast would hand it UTF-16 and
   // it would render the first letter and stop.
   Application.MessageBox(PAnsiChar(AnsiString(aMessage)),
                          PAnsiChar(AnsiString(SAlreadyRunningTitle)),
                          MB_OK or MB_ICONWARNING);
end;

procedure InitLCLApplication;
begin
   if gInitialised then
      begin
      Exit;
      end;

   // Registers the widgetset and the platform services an LCL form needs to
   // create its window.  It does not start a message loop; RunLCLApplication
   // does that, once TR4W has finished starting up.
   Application.Initialize;
   gInitialised := True;
end;

procedure RunLCLApplication;
begin
   // NOT SHOWN BY Run.  CreateMainWindow has already positioned and shown the
   // main form with geometry it can only compute once the editable log exists
   // and has been measured; letting Run show it again would flash it at its
   // designed size first.
   Application.ShowMainForm := False;

   // Does not return in normal use: TR4W exits through ExitProcess in
   // tr4w_ShutDown, reached from ExitProgram.  Nothing may be placed after the
   // call site that has to run.
   Application.Run;
end;

function LCLReadyForHostedForms: boolean;
begin
   Result := gInitialised;
end;

{$ENDIF}

end.
