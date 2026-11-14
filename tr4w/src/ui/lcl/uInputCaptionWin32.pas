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

(* THE WIN32 WIDGET-SET CLASS FOR TInputCaption (issue 278). WINDOWS ONLY.

  A widget-set class is the LCL's own extension point for "this control
  behaves differently on Win32": registered by the control's WSRegisterClass
  (uInputCaption), exactly as components/opengl does for
  TCustomOpenGLControl. It descends from TWin32WSCustomStaticText, so the
  window is the LCL's own STATIC with the LCL's own window procedure and
  window info; the only difference is that, once the LCL has made it, the
  window is handed to uStaticDialogCodeWindows to answer WM_GETDLGCODE as a
  static, which is what lets UI Automation name the input after it. That
  unit holds every raw Win32 call and says why each is needed.

  THE HWND HERE IS THE LCL'S SIGNATURE, NOT OURS: TWin32WSCustomStaticText.
  CreateHandle returns one, and an override must match it. *)
unit uInputCaptionWin32;

{$MODE Delphi}

interface

{$IFDEF WINDOWS}
uses
   Controls,
   LCLType,
   Win32WSStdCtrls;

type
   TWin32WSInputCaption = class(TWin32WSCustomStaticText)
   published
      (* PUBLISHED, like every widget-set method: the LCL builds the run-time
        class from the published method table (wslclclasses.pp, CreateVClass). *)
      class function CreateHandle(const AWinControl: TWinControl;
         const AParams: TCreateParams): HWND; override;
   end;
{$ENDIF}

implementation

{$IFDEF WINDOWS}
uses
   LazLoggerBase,
   uStaticDialogCodeWindows;

class function TWin32WSInputCaption.CreateHandle(const AWinControl: TWinControl;
   const AParams: TCreateParams): HWND;
begin
   Result := inherited CreateHandle(AWinControl, AParams);
   if Result = 0 then
      begin
      Exit;
      end;
   if not TStaticDialogCode.AnswerAsStatic(Result) then
      begin
      (* The caption then works as a plain TStaticText and is unnamed to UI
        Automation, which uTestPrefsPlacement's DLGC_STATIC check reports. *)
      DebugLn(['[uInputCaptionWin32] ', AWinControl.Name,
               ': unexpected window procedure; not answering as a static']);
      end;
end;
{$ENDIF}

end.
