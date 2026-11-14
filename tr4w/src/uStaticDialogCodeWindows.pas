(*
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
 *)

(* MAKE AN LCL STATIC WINDOW ANSWER WINDOWS AS A STATIC (issue 278).
  WINDOWS ONLY: off Windows this unit is empty.

  Windows UI Automation names an edit from the window immediately before it
  in z-order, but only when that window answers WM_GETDLGCODE with
  DLGC_STATIC ($100). The LCL win32 widget set answers that message ITSELF
  for every window it owns (win32callback.inc, WM_GETDLGCODE: Result :=
  DLGC_WANTALLKEYS, WinProcess := False) and never delivers LM_GETDLGCODE to
  the control, so nothing on the control can change the answer. Measured
  2026-11-13 by the gui-test probe (docs/gui-test/bench-20261113-uia278/):
  the LCL's STATICs answered $4 and every Station box was unnamed; a real
  window procedure answering $104 named its edit.

  THIS IS THE ONE RAW WIN32 STEP, AND WHY IT IS RAW. The window procedure the
  LCL installed is chained: every message goes to it first and unchanged,
  and only the WM_GETDLGCODE answer gains DLGC_STATIC. The LCL has no
  property or method that sets a window's dialog code, and its own
  subclassing hook (TCreateWindowExParams.SubClassWndProc) would REPLACE the
  static text's procedure (StaticTextWndProc, private to win32wsstdctrls)
  rather than chain it, losing its themed border and disabled painting.
  Checked against the LCL source (Lazarus 4.x, lcl/interfaces/win32): the
  window info lives in a window PROPERTY (AllocWindowInfo /
  GetWin32WindowInfo), the class procedure the LCL calls for default
  handling is WindowInfo^.DefWndProc, and nothing in the win32 interface
  reads or rewrites GWL_WNDPROC after creation (the one exception,
  RedirectDestroyMessages, is a debug define that is off).

  A HELPER KEPT OUT OF THE UI FILES ON PURPOSE (NY4I, 2026-11-13: the raw
  Win32 an LCL control needs lives in a helper under IFDEF WINDOWS, not in
  src/ui). Its one caller is the widget-set class uInputCaptionWin32, which
  hands it the handle the LCL has just created. It depends on the RTL's
  Windows unit and nothing else, so build/lintlfm and build/lfmload can link
  it. *)
unit uStaticDialogCodeWindows;

{$MODE Delphi}

interface

{$IFDEF WINDOWS}
uses
   LCLType;   (* TLCLHandle -- the handle as the LCL hands it over *)

type
   TStaticDialogCode = class
   public
      (* Chain aWindow's window procedure so its WM_GETDLGCODE answer also
        carries DLGC_STATIC. aWindow must be a window the LCL made for a
        TCustomStaticText (so its procedure is the one every such window
        has); call it once per window, straight after the window is made,
        on the main thread. Returns False, and leaves the window as it was,
        if its procedure is not the one the first chained window had. *)
      class function AnswerAsStatic(const aWindow: TLCLHandle): boolean;
   end;
{$ENDIF}

implementation

{$IFDEF WINDOWS}
uses
   Windows;

var
   (* THE LCL'S STATIC TEXT WINDOW PROCEDURE, as found on the first window
     chained. One routine for every TCustomStaticText window, so one variable
     serves them all; AnswerAsStatic refuses a window whose procedure turns
     out to be a different one. Main thread only, where every window is made.
     Held as the value SetWindowLongPtrW returns, so it is compared as a
     number, not called. *)
   GStaticTextWndProc: LONG_PTR = 0;

function StaticDialogCodeWndProc(Window: HWND; Msg: UINT; WParam: Windows.WPARAM;
   LParam: Windows.LPARAM): LRESULT; stdcall;
begin
   (* W, not A: the LCL made the window with CreateWindowExW, and an A call
     would have Windows thunk every message's text. *)
   Result := CallWindowProcW(Windows.WNDPROC(GStaticTextWndProc), Window, Msg,
                             WParam, LParam);
   if Msg = WM_GETDLGCODE then
      begin
      (* Keep what the LCL answered (DLGC_WANTALLKEYS) and add the static bit:
        $104, the answer the probe measured naming its edit. *)
      Result := Result or DLGC_STATIC;
      end;
end;

class function TStaticDialogCode.AnswerAsStatic(const aWindow: TLCLHandle): boolean;
var
   previous: LONG_PTR;
begin
   previous := SetWindowLongPtrW(aWindow, GWL_WNDPROC,
                                 LONG_PTR(@StaticDialogCodeWndProc));
   if GStaticTextWndProc = 0 then
      begin
      GStaticTextWndProc := previous;
      end;

   Result := (previous = GStaticTextWndProc);
   if not Result then
      begin
      (* Not the procedure the others chain to: put it back rather than
        forward this window's messages to the wrong routine. *)
      SetWindowLongPtrW(aWindow, GWL_WNDPROC, previous);
      end;
end;
{$ENDIF}

end.
