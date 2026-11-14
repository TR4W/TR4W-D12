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

(* A CAPTION THAT NAMES ITS INPUT TO WINDOWS UI AUTOMATION (issue 278).

  A TLabel has no window, so a screen reader sees nothing beside an edit and
  reports it unnamed. A TStaticText is a window, and Windows names an edit
  from the window immediately before it in z-order -- but ONLY when that
  window says it is a static, by answering WM_GETDLGCODE with DLGC_STATIC.

  THE LCL WIN32 WIDGET SET ANSWERS DLGC_WANTALLKEYS (4) FOR EVERY WINDOW it
  owns, a TStaticText's STATIC included, and answers it ITSELF: the message
  never reaches the control (win32callback.inc, WM_GETDLGCODE). Measured
  2026-11-13 by the gui-test probe (docs/gui-test/bench-20261113-uia278/):
  the Station page's statics answered 4 and every box was unnamed; a static
  answering $104 named its edit.

  SO THE DIFFERENCE IS A WIDGET-SET CLASS, the LCL's own way to make a control
  behave differently on one platform: TInputCaption registers
  TWin32WSInputCaption (uInputCaptionWin32, which says what it does and why)
  from WSRegisterClass, the pattern components/opengl uses for
  TCustomOpenGLControl. This unit holds no handle and sends no message.

  OFF WINDOWS THIS IS A PLAIN TStaticText: nothing is registered and the
  inherited widget-set class serves it. How the gtk2 and cocoa accessibility
  layers name a field is unmeasured.

  USE IT FOR A CAPTION THAT NAMES AN INPUT: FocusControl set, and streamed
  AFTER its input in the .lfm (the LCL's child list is the reverse of window
  z-order -- see uPrefsForm's Station block). uLCLFormHelpers.CaptionFocusControl
  pairs it with its input because it IS a TStaticText.

  NEAR-LEAF ON PURPOSE: build/lintlfm and build/lfmload link this unit to
  resolve the class, and they link the LCL and nothing else. Its one other
  dependency, uInputCaptionWin32, uses only the LCL's win32 interface. *)
unit uInputCaption;

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

interface

uses
   Classes, StdCtrls;

type
   TInputCaption = class(TStaticText)
{$IFDEF WINDOWS}
   protected
      class procedure WSRegisterClass; override;
{$ENDIF}
   end;

implementation

{$IFDEF WINDOWS}
uses
   WSLCLClasses,
   uInputCaptionWin32;

var
   GRegistered: boolean = False;   (* main thread only, as all form creation is *)

(* CALLED BY THE LCL before the first TInputCaption gets its widget-set class
  (TLCLComponent.NewInstance -> GetWSComponentClass), so the registration is
  in place before any node for this class exists. inherited first: it
  registers TCustomStaticText's own Win32 class, the parent this one's
  run-time class is built against (wslclclasses.pp, CreateVClass). *)
class procedure TInputCaption.WSRegisterClass;
begin
   if GRegistered then
      begin
      Exit;
      end;
   inherited WSRegisterClass;
   RegisterWSComponent(TInputCaption, TWin32WSInputCaption);
   GRegistered := True;
end;
{$ENDIF}

initialization
   (* THE STREAMING LOADER RESOLVES A CLASS BY NAME. uPrefsForm's fields give
     it the class today, but a form that adds one without a published field
     would otherwise fail to load at the first of them. *)
   RegisterClass(TInputCaption);

end.
