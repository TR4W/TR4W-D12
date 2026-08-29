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
  TR4W's LCL dependency, in one unit.

  HISTORICAL, AND NO LONGER TRUE OF THE FIRST LINE: this unit was called into
  being to host LCL forms inside TR4W's OWN GetMessage / TranslateMessage /
  DispatchMessage loop, and its header said "Application.Run is never called".
  That stopped being true on 2026-08-23 (Phase 3c).  RunLCLApplication below IS
  that call, and tr4w.lpr no longer has a loop of its own.

  What survives from the old arrangement, because it is still the reason this
  unit exists: tr4w.lpr does not link Forms, so every reference to Application
  lives here.

  THIS UNIT IS DELIBERATELY ALMOST EMPTY, and the reason is worth stating
  because its FMX counterpart is not.

  uFMXCoexist carried TellFMXTheApplicationIsRunning, a shim installed because
  FMX asks "is the application running?" before it will activate a form, and on
  Windows that answer came from TPlatformWin.FRunning -- set by Application.Run,
  which this architecture did not then call.  Every hosted FMX form therefore
  stayed Active=False for its whole life, and the only visible symptom was that
  an edit accepted keystrokes but SHOWED NO CARET (bench, 2026-08-05).

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

  WHICH WINDOWS ARE OURS was in uHostedFormWindows -- pure Win32, naming no
  toolkit, shared with the FMX side.  A form registered its handle as it showed
  and unregistered as it closed, and tr4w.lpr's loop asked that unit whether a
  message belonged to a hosted window before applying its own CW-memory and
  accelerator handling.  With the loop gone nothing asks any more: the registry
  is still written by eighteen forms and read by nobody, and should be retired.
}

interface


// Call ONCE, early in startup, before any LCL form is created.  Idempotent:
// calling it twice is harmless, which matters because the call site is a
// startup path that has grown conditional branches over the years.
//
// It does NOT start the message loop; RunLCLApplication does, once TR4W has
// finished starting up.
procedure InitLCLApplication;

{ Tell the operator that TR4W is already running, and say it VISIBLY.

  This was a raw MessageBoxW(0, ...) in tr4w.lpr with MB_SYSTEMMODAL.
  Application.Initialize has already run by this point, so the LCL owns the
  message pump such a dialog needs; going around it with a raw Win32 call was
  gratuitous.

  A NOTE ON WHAT THIS DID *NOT* FIX, because an earlier version of this comment
  claimed otherwise.  It was written believing the raw call created no window at
  all -- read off a probe that reported no top-level window for the process.
  That probe could not see ANY window, not even Notepad's, so it proved nothing;
  NY4I confirmed the dialog does appear on his desktop.  The real cause of the
  invisible, unkillable-looking TR4W was a HEADLESS EXPORT reaching this dialog,
  and that is fixed in tr4w.lpr by deciding batch mode before the
  single-instance check. }
procedure ReportAlreadyRunning(const aMessage: string);

{ Hand the program to the LCL and do not come back.

  Phase 3c: TR4W ran its own GetMessage loop until 2026-08-23, which is why the
  initialiser above used to be called InitLCLForHostedLoop -- the LCL was a
  guest inside TR4W's loop.  It is the other way round now.

  Application.Run is HERE rather than in tr4w.lpr for the same reason
  Application.Initialize is: this unit owns the whole LCL dependency, and
  tr4w.lpr does not link Forms. }
procedure RunLCLApplication;

// True once InitLCLApplication has run.  A form that creates itself before
// the widgetset is initialised fails in ways that do not name the cause, so
// the form units assert on this rather than discovering it at random.
function LCLReadyForHostedForms: boolean;


implementation


uses
   // Interfaces FIRST, and it is not optional.  It is what links the win32
   // widgetset, which supplies every WSRegisterXxx symbol the LCL's controls
   // reference.  Without it the link fails with a wall of
   //     Undefined symbol: WSRegisterControl, WSRegisterMenu, ...
   // that names no unit and does not suggest its own cause.  Listing it here
   // rather than in tr4w.lpr keeps the whole LCL dependency in one place, and
   // the uses order guarantees it initialises before Forms.
   Interfaces,
   Forms,
   LCLType,      { MB_OK, MB_ICONWARNING }
   uAppStrings,
  uAnsiStr;  { SAlreadyRunningTitle }

var
   gInitialised: boolean = False;

procedure ReportAlreadyRunning(const aMessage: string);
begin
   // PAnsiChar, and this one IS a real byte boundary: TApplication.MessageBox
   // takes PChar meaning PAnsiChar, while this unit compiles with
   // {$MODESWITCH UnicodeStrings} so a bare PChar cast would hand it UTF-16 and
   // it would render the first letter and stop.
   Application.MessageBox(PAnsiChar(WinAnsi(aMessage)),
                          PAnsiChar(WinAnsi(SAlreadyRunningTitle)),
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


end.
