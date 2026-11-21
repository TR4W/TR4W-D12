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
unit uAltDragMove;
{$I tr4w.inc}

(*
  ALT + LEFT-BUTTON DRAG MOVES A TOOL WINDOW THAT NO CAPTION LEFT WITHOUT A FRAME.

  NO CAPTION (Settings.MainWindow.NoCaption) makes every tool window
  BorderStyle = bsNone in MainUnit.OpenTR4WWindow. With no title bar there
  was nothing to grab, so the window could not be moved at all -- D7 had the
  same gap. Holding Alt and dragging anywhere inside such a window moves it
  now. Alt is required so that a plain click in a grid, an edit or a button
  is never taken from the control.

  WHY TControl.WindowProc, AND NOT AN APPLICATION HANDLER.

  - Application.OnUserInput / AddOnUserInputHandler is handed the message
    NUMBER by value, so it cannot consume anything; the cocoa widget set
    raises it for keys only; and in this tree one such handler was measured
    never to fire (see the note in uAppInputHooks).
  - Chaining OnMouseDown / OnMouseMove / OnMouseUp is too late: a TCustomGrid
    changes its selection in MouseDown BEFORE it raises OnMouseDown, so the
    event cannot stop the click.
  - WindowProc is the LCL's own dispatch point. Every widget set delivers a
    mouse message through DeliverMessage, which calls the control's
    WindowProc before the control's WndProc and its MouseDown. Not calling
    the previous WindowProc is therefore a real veto, on every platform.

  ONLY TWinControls ARE HOOKED. A TGraphicControl (a TLabel on the radio
  panel) gets its mouse messages from its parent's WndProc
  (TWinControl.IsControlMouseMsg), so the parent's hook sees them first. A
  child added at run time is hooked when its parent's WindowProc receives
  CM_CONTROLLISTCHANGE, which TWinControl.InsertControl sends before the
  insert.

  WHAT THIS CANNOT STOP, ON WIN32: a NATIVE control (TEdit, TMemo, a
  TListView) still gets the button press from its own window procedure after
  the LCL has seen it -- the win32 widget set passes a mouse message on to
  the native procedure whatever the LCL answered. So an Alt+click on the
  Network list can still select a row. The drag itself does not depend on
  which window holds the capture: every move is computed from Mouse.CursorPos,
  in SCREEN coordinates, and any hooked control that receives a move while a
  drag is running carries it on.

  LIFETIME. One hook object for the program, created on first use. Each
  hooked control is registered with FreeNotification, and the Notification
  handler puts the control's own WindowProc back BEFORE the entry is freed,
  so a message sent during the rest of the control's destruction reaches the
  control's real procedure. Unit finalization runs before the Application
  frees the forms, so the finalization puts every surviving WindowProc back
  and removes the free notifications before it frees the hook; without that
  every form destroyed later would call a freed object.

  WHERE THE POSITION IS SAVED: nowhere new. MainUnit's 5-second layout
  autosave (FindAndSaveRectOfAllWindows) and ExitProgram's SaveTR4WPOSFILE
  read each open tool window's BoundsRect, so moving the form is all a drag
  has to do.

  THE DECISIONS ARE PURE FUNCTIONS (AltDragShiftStarts, FormMovesByAltDrag,
  AltDragTopLeft, KeepStripOnAMonitor), pinned by uTestAltDragMove without a
  GUI.
*)

interface

uses
   Types, Classes, Controls, Forms;

const
   (* How much of a dragged window must stay on some monitor, in pixels, in
     each direction. The same margin MainUnit.EnsureRectOnScreen keeps. *)
   ALT_DRAG_VISIBLE_STRIP = 40;

(* Does this shift state start a drag? Alt without Ctrl: AltGr on a European
  keyboard arrives as Ctrl+Alt, and it types characters, so it never moves a
  window. *)
function AltDragShiftStarts(const aShift: TShiftState): boolean;

(* Is this window one an Alt-drag may move? Only a TOOL window (one of
  tr4w_WindowsArray[...].WndForm, never the main window) that NO CAPTION made
  borderless, and never while it is shown modally. *)
function FormMovesByAltDrag(aBorderStyle: TFormBorderStyle;
                            aIsToolWindow: boolean;
                            aIsMainForm: boolean;
                            aIsModal: boolean): boolean;

(* The same question about a real form: aForm must have been registered by
  EnableAltDragMove, and it must not be Application.MainForm. *)
function FormIsAltDragMovable(aForm: TCustomForm): boolean;

(* Where the window's top-left goes: where it started, plus how far the
  pointer has moved since. All three points are in SCREEN coordinates; a
  child-relative position would move with the window and feed back. *)
function AltDragTopLeft(const aStartTopLeft: TPoint;
                        const aStartCursor: TPoint;
                        const aCursor: TPoint): TPoint;

(* The top-left that keeps at least aStrip pixels (or the whole window, when
  it is smaller than that) on some monitor. aMonitors are the monitors' work
  areas, in screen coordinates, so a monitor left of or above the primary has
  negative coordinates. A window already showing the strip on ANY monitor is
  not moved; otherwise it is pulled onto the nearest one. No monitors: no
  change. *)
function KeepStripOnAMonitor(const aBounds: TRect;
                             const aMonitors: array of TRect;
                             aStrip: integer): TPoint;

(* Let Alt + left-button drag move aForm. Called by MainUnit.OpenTR4WWindow
  for a tool window it has just made borderless. Calling it again for the
  same form does nothing new; aForm = nil or Application.MainForm is
  refused. *)
procedure EnableAltDragMove(aForm: TCustomForm);

(* How many controls are hooked now. For tests: a freed form must take its
  controls out of the count. *)
function AltDragHookedControlCount: integer;

implementation

uses
   SysUtils, Math, LCLType, LMessages;

type
   TAltDragHook = class;

   (* One hooked control: the control, the WindowProc it had before, and the
     method that now stands in for it. A TWndMethod carries no argument
     naming the control, so each control needs an object of its own. *)
   THookedControl = class
   private
      FHook: TAltDragHook;
      FControl: TWinControl;
      FPrevious: TWndMethod;
   public
      constructor Create(aHook: TAltDragHook; aControl: TWinControl);
      procedure WndProc(var aMessage: TLMessage);
      (* Put the control's own WindowProc back, if ours is still the one
        installed; a later hook chained over ours is left alone. *)
      procedure Unhook;
   end;

   TAltDragHook = class(TComponent)
   private
      FControls: TFPList;      (* of THookedControl *)
      FForms: TFPList;         (* of TCustomForm: the registered tool windows *)
      FDragForm: TCustomForm;  (* nil when no drag is running *)
      FStartTopLeft: TPoint;
      FStartCursor: TPoint;
      function IndexOfControl(aControl: TControl): integer;
      procedure HookTree(aControl: TWinControl);
      procedure StartDrag(aForm: TCustomForm);
      procedure MoveDrag;
      procedure EndDrag;
   protected
      procedure Notification(aComponent: TComponent; aOperation: TOperation); override;
   public
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
      procedure RegisterForm(aForm: TCustomForm);
      function IsRegistered(aForm: TCustomForm): boolean;
      function HookedCount: integer;
      (* True when the message was consumed and must not reach the control. *)
      function Intercepts(aControl: TWinControl; var aMessage: TLMessage): boolean;
   end;

var
   GHook: TAltDragHook = nil;

(* ---------------------------------------------------------------- the pure part *)

function AltDragShiftStarts(const aShift: TShiftState): boolean;
begin
   Result := (ssAlt in aShift) and (not (ssCtrl in aShift));
end;

function FormMovesByAltDrag(aBorderStyle: TFormBorderStyle;
                            aIsToolWindow: boolean;
                            aIsMainForm: boolean;
                            aIsModal: boolean): boolean;
begin
   Result := (aBorderStyle = bsNone) and
             aIsToolWindow           and
             (not aIsMainForm)       and
             (not aIsModal);
end;

function FormIsAltDragMovable(aForm: TCustomForm): boolean;
begin
   if aForm = nil then
      begin
      Result := False;
      Exit;
      end;
   Result := FormMovesByAltDrag(aForm.BorderStyle,
                                (GHook <> nil) and GHook.IsRegistered(aForm),
                                aForm = Application.MainForm,
                                fsModal in aForm.FormState);
end;

function AltDragTopLeft(const aStartTopLeft: TPoint;
                        const aStartCursor: TPoint;
                        const aCursor: TPoint): TPoint;
begin
   Result.X := aStartTopLeft.X + (aCursor.X - aStartCursor.X);
   Result.Y := aStartTopLeft.Y + (aCursor.Y - aStartCursor.Y);
end;

function KeepStripOnAMonitor(const aBounds: TRect;
                             const aMonitors: array of TRect;
                             aStrip: integer): TPoint;
var
   w: integer;
   h: integer;
   stripW: integer;
   stripH: integer;
   i: integer;
   best: integer;
   bestDistance: Int64;
   dx: Int64;
   dy: Int64;
   distance: Int64;
   m: TRect;
begin
   Result := aBounds.TopLeft;
   if Length(aMonitors) = 0 then
      begin
      Exit;
      end;

   w := aBounds.Right - aBounds.Left;
   h := aBounds.Bottom - aBounds.Top;
   stripW := Min(aStrip, w);
   stripH := Min(aStrip, h);

   (* ALREADY REACHABLE: some one monitor shows the strip both ways. Asked of
     each monitor alone, because a strip split across two monitors is still
     a whole strip only if neither half is under a bezel or a gap. *)
   for i := Low(aMonitors) to High(aMonitors) do
      begin
      m := aMonitors[i];
      if (Min(aBounds.Right, m.Right) - Max(aBounds.Left, m.Left) >= stripW) and
         (Min(aBounds.Bottom, m.Bottom) - Max(aBounds.Top, m.Top) >= stripH) then
         begin
         Exit;
         end;
      end;

   (* Otherwise the NEAREST monitor: the smallest gap between the window and
     the monitor, zero for one it still touches. The first wins a tie. *)
   best := Low(aMonitors);
   bestDistance := High(Int64);
   for i := Low(aMonitors) to High(aMonitors) do
      begin
      m := aMonitors[i];
      dx := Max(0, Max(m.Left - aBounds.Right, aBounds.Left - m.Right));
      dy := Max(0, Max(m.Top - aBounds.Bottom, aBounds.Top - m.Bottom));
      distance := dx * dx + dy * dy;
      if distance < bestDistance then
         begin
         bestDistance := distance;
         best := i;
         end;
      end;

   m := aMonitors[best];
   Result.X := EnsureRange(aBounds.Left, m.Left - w + stripW, m.Right - stripW);
   Result.Y := EnsureRange(aBounds.Top, m.Top - h + stripH, m.Bottom - stripH);
end;

(* ---------------------------------------------------------------- the hook *)

constructor THookedControl.Create(aHook: TAltDragHook; aControl: TWinControl);
begin
   inherited Create;
   FHook := aHook;
   FControl := aControl;
   FPrevious := aControl.WindowProc;
   aControl.WindowProc := WndProc;
end;

procedure THookedControl.WndProc(var aMessage: TLMessage);
begin
   if FHook.Intercepts(FControl, aMessage) then
      begin
      Exit;
      end;
   (* Nothing of Self is touched after this call: the message may destroy
     the control, and the free notification then frees this object. *)
   FPrevious(aMessage);
end;

procedure THookedControl.Unhook;
var
   current: TWndMethod;
   ours: TWndMethod;
begin
   current := FControl.WindowProc;
   ours := WndProc;
   if (TMethod(current).Code = TMethod(ours).Code) and
      (TMethod(current).Data = TMethod(ours).Data) then
      begin
      FControl.WindowProc := FPrevious;
      end;
end;

constructor TAltDragHook.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);
   FControls := TFPList.Create;
   FForms := TFPList.Create;
end;

destructor TAltDragHook.Destroy;
var
   i: integer;
   entry: THookedControl;
begin
   for i := FControls.Count - 1 downto 0 do
      begin
      entry := THookedControl(FControls[i]);
      entry.Unhook;
      entry.FControl.RemoveFreeNotification(Self);
      entry.Free;
      end;
   for i := FForms.Count - 1 downto 0 do
      begin
      TCustomForm(FForms[i]).RemoveFreeNotification(Self);
      end;
   FreeAndNil(FControls);
   FreeAndNil(FForms);
   inherited Destroy;
end;

function TAltDragHook.IndexOfControl(aControl: TControl): integer;
var
   i: integer;
begin
   for i := 0 to FControls.Count - 1 do
      begin
      if THookedControl(FControls[i]).FControl = aControl then
         begin
         Result := i;
         Exit;
         end;
      end;
   Result := -1;
end;

procedure TAltDragHook.HookTree(aControl: TWinControl);
var
   i: integer;
begin
   if IndexOfControl(aControl) < 0 then
      begin
      FControls.Add(THookedControl.Create(Self, aControl));
      aControl.FreeNotification(Self);
      end;
   for i := 0 to aControl.ControlCount - 1 do
      begin
      if aControl.Controls[i] is TWinControl then
         begin
         HookTree(TWinControl(aControl.Controls[i]));
         end;
      end;
end;

procedure TAltDragHook.RegisterForm(aForm: TCustomForm);
begin
   if FForms.IndexOf(aForm) < 0 then
      begin
      FForms.Add(aForm);
      aForm.FreeNotification(Self);
      end;
   HookTree(aForm);
end;

function TAltDragHook.IsRegistered(aForm: TCustomForm): boolean;
begin
   Result := FForms.IndexOf(aForm) >= 0;
end;

function TAltDragHook.HookedCount: integer;
begin
   Result := FControls.Count;
end;

procedure TAltDragHook.Notification(aComponent: TComponent; aOperation: TOperation);
var
   i: integer;
   entry: THookedControl;
begin
   inherited Notification(aComponent, aOperation);
   if aOperation <> opRemove then
      begin
      Exit;
      end;

   if aComponent = FDragForm then
      begin
      FDragForm := nil;
      end;
   FForms.Remove(aComponent);

   i := IndexOfControl(TControl(aComponent));
   if i >= 0 then
      begin
      entry := THookedControl(FControls[i]);
      FControls.Delete(i);
      (* BACK BEFORE IT IS FREED: the control is still being destroyed and
        may yet be sent a message. *)
      entry.Unhook;
      entry.Free;
      end;
end;

procedure TAltDragHook.StartDrag(aForm: TCustomForm);
begin
   FDragForm := aForm;
   FStartCursor := Mouse.CursorPos;
   FStartTopLeft := Point(aForm.Left, aForm.Top);
   (* THE FORM TAKES THE MOUSE, so the moves arrive while the pointer is over
     any part of it, or briefly outside it. A native control may take the
     capture back from its own button-press handling; the moves then reach
     that control's hook, which carries the drag on just the same. *)
   SetCaptureControl(aForm);
end;

procedure TAltDragHook.MoveDrag;
var
   target: TPoint;
   monitors: array of TRect;
   i: integer;
   bounds: TRect;
begin
   target := AltDragTopLeft(FStartTopLeft, FStartCursor, Mouse.CursorPos);

   SetLength(monitors, Screen.MonitorCount);
   for i := 0 to Screen.MonitorCount - 1 do
      begin
      monitors[i] := Screen.Monitors[i].WorkareaRect;
      end;
   bounds := Rect(target.X, target.Y,
                  target.X + FDragForm.Width, target.Y + FDragForm.Height);
   target := KeepStripOnAMonitor(bounds, monitors, ALT_DRAG_VISIBLE_STRIP);

   if (target.X <> FDragForm.Left) or
      (target.Y <> FDragForm.Top) then
      begin
      FDragForm.SetBounds(target.X, target.Y, FDragForm.Width, FDragForm.Height);
      end;
end;

procedure TAltDragHook.EndDrag;
var
   form: TCustomForm;
begin
   form := FDragForm;
   FDragForm := nil;
   if (form <> nil) and (GetCaptureControl = form) then
      begin
      SetCaptureControl(nil);
      end;
end;

function TAltDragHook.Intercepts(aControl: TWinControl; var aMessage: TLMessage): boolean;
var
   form: TCustomForm;
begin
   Result := False;
   case aMessage.Msg of
      CM_CONTROLLISTCHANGE:
         begin
         (* A CHILD BEING INSERTED: hook it and anything already inside it.
           Never consumed -- the control's own handler still has to see it. *)
         if (aMessage.LParam <> 0) and
            (TObject(aMessage.WParam) is TWinControl) then
            begin
            HookTree(TWinControl(aMessage.WParam));
            end;
         end;

      LM_LBUTTONDOWN, LM_LBUTTONDBLCLK:
         begin
         (* A PRESS DURING A DRAG MEANS THE RELEASE WAS LOST -- to another
           program after an Alt+Tab, say, since the left button cannot be
           pressed while it is still held. The old drag is over, and this
           press is judged on its own, never swallowed for a stale one. *)
         if FDragForm <> nil then
            begin
            EndDrag;
            end;
         if AltDragShiftStarts(GetKeyShiftState) then
            begin
            form := GetParentForm(aControl);
            if FormIsAltDragMovable(form) then
               begin
               StartDrag(form);
               Result := True;
               end;
            end;
         end;

      LM_MOUSEMOVE:
         begin
         if FDragForm <> nil then
            begin
            (* THE BUTTON OR ALT LET GO: the drag is over. The release itself
              may have gone to another program, or to a native control that
              took the capture, so a move without them is the signal. *)
            if ((TLMMouseMove(aMessage).Keys and MK_LBUTTON) = 0) or
               (not AltDragShiftStarts(GetKeyShiftState)) then
               begin
               EndDrag;
               end
            else
               begin
               MoveDrag;
               end;
            Result := True;
            end;
         end;

      LM_LBUTTONUP:
         begin
         if FDragForm <> nil then
            begin
            EndDrag;
            Result := True;
            end;
         end;

      LM_CANCELMODE:
         begin
         if FDragForm <> nil then
            begin
            EndDrag;
            end;
         end;
   end;
end;

(* ---------------------------------------------------------------- the entry points *)

procedure EnableAltDragMove(aForm: TCustomForm);
begin
   if (aForm = nil) or (aForm = Application.MainForm) then
      begin
      Exit;
      end;
   if GHook = nil then
      begin
      GHook := TAltDragHook.Create(nil);
      end;
   GHook.RegisterForm(aForm);
end;

function AltDragHookedControlCount: integer;
begin
   if GHook = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := GHook.HookedCount;
      end;
end;

initialization

finalization
   (* BEFORE THE FORMS GO: Application frees them after this, and each one
     still pointing at a freed hook would fault as it is destroyed. The
     destructor puts every WindowProc back first. *)
   FreeAndNil(GHook);

end.
