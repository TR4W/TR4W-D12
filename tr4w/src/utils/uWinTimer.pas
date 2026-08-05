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
unit uWinTimer;

{
  A WM_TIMER timer with the surface of VCL's TTimer, and no VCL.

  WHY.  TR4W has no VCL user interface -- every window is raw Win32 -- but the
  project still linked the VCL packages for exactly four things, and the deepest
  was `uses ExtCtrls` in LOGRADIO for one TTimer: tmrCWByCAT, the CW-by-CAT busy
  window.  ExtCtrls drags in Vcl.Controls, Vcl.Forms, Vcl.Graphics and the rest,
  so a single timer was the reason the whole framework was in the binary.  That
  matters now because FMX is coming and one executable should carry ONE
  framework.

  WHAT IT IS.  SetTimer/KillTimer against a hidden message-only window from
  System.Classes.AllocateHWnd -- which is RTL, not VCL.  VCL's own TTimer is
  implemented exactly this way; this is the same mechanism with the framework
  peeled off.

  WHY NOT FMX.Types.TTimer, WHICH IS WHERE THIS PROJECT IS HEADED.  It is, and
  NY4I's stated direction is that TR4W moves to FMX and away from the Win32 API
  entirely (2026-08-05).  This unit is a STEPPING STONE, not a destination, and
  the reason is sequencing: FMX's Windows timer runs through FMX.Platform.Win
  and needs the platform services that the coexistence spike is about to test.
  Putting the CW-by-CAT busy window -- contest-critical timing -- on that
  framework BEFORE the spike answers whether FMX works under TR4W's foreign
  message loop would be betting the CW path on the unknown.

  So: revisit this once the spike passes.  The surface is TTimer's, so switching
  to FMX.Types.TTimer is a `uses` change and a type name, and
  test/unit/uTestWinTimer.pas carries over unchanged as the safety net for it.

  BEHAVIOUR IS TTimer's, deliberately, including the part that surprises people:

    * Setting Interval while the timer is RUNNING kills and recreates it, so the
      countdown RESTARTS at the new value.  It does not add to the time
      remaining.  LOGRADIO.AddTimeToCWByCATTimer depends on this -- it sets
      Interval := Interval + ms to lengthen the CW busy window, and the restart
      is why the comment there says updating a running timer "does not work
      properly".  Keeping the quirk keeps the CW timing identical; changing it
      would silently alter how long TR4W believes a message takes to key.
    * Interval = 0 stops the timer, as it does in the VCL.
    * OnTimer receives the timer object as Sender, so `TWinTimer(Sender).Enabled
      := False` in a handler works the way `TTimer(Sender)` did.

  ONE DELIBERATE DIFFERENCE.  VCL's TTimer is born Enabled with Interval 1000,
  so constructing one starts a real timer you then have to switch off.  This one
  starts DISABLED.  Every TR4W call site assigns Enabled := False immediately
  after Create, so nothing changes for them, and a timer that does nothing until
  asked is the safer default.

  THREAD AFFINITY, unchanged from the VCL: the hidden window belongs to the
  thread that constructs the timer, and WM_TIMER is delivered to that thread's
  message loop.  TR4W's radio objects are built on the main thread, which is the
  thread running the loop in tr4w.dpr -- the same condition TTimer already
  relied on.
}

interface

uses
   Winapi.Windows,
   Winapi.Messages,
   System.Classes;

type
   TWinTimer = class(TComponent)
   private
      FWindowHandle: HWND;
      FInterval: Cardinal;
      FEnabled: boolean;
      FOnTimer: TNotifyEvent;
      FTimerActive: boolean;
      procedure WndProc(var Msg: TMessage);
      procedure UpdateTimer;
      procedure SetEnabled(Value: boolean);
      procedure SetInterval(Value: Cardinal);
      procedure SetOnTimer(Value: TNotifyEvent);
   public
      // AOwner is accepted and ignored, so `TWinTimer.Create(nil)` reads the
      // same as the TTimer call it replaces.  Nothing in TR4W owns its timer
      // through a component hierarchy; every one is freed explicitly.
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;

      property Enabled: boolean read FEnabled write SetEnabled;
      property Interval: Cardinal read FInterval write SetInterval;
      property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
   end;

implementation

const
   // Any non-zero id will do: the timer is identified by (window, id) and this
   // window has exactly one timer.
   WINTIMER_ID = 1;

constructor TWinTimer.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FEnabled  := False;
   FInterval := 1000;   // TTimer's default, for anyone who reads Interval first
   FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TWinTimer.Destroy;
begin
   FEnabled := False;
   UpdateTimer;                      // kills the timer if one is running
   DeallocateHWnd(FWindowHandle);
   inherited Destroy;
end;

procedure TWinTimer.WndProc(var Msg: TMessage);
begin
   if (Msg.Msg = WM_TIMER) and (TWMTimer(Msg).TimerID = WINTIMER_ID) then
      begin
      // Sender is the timer, matching TNotifyEvent from a TTimer.  A handler
      // that disables the timer from inside itself -- which TR4W's does, to get
      // one-shot behaviour -- is safe: SetEnabled only calls KillTimer.
      if Assigned(FOnTimer) then
         begin
         FOnTimer(Self);
         end;
      end
   else
      begin
      Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
      end;
end;

procedure TWinTimer.UpdateTimer;
begin
   if FTimerActive then
      begin
      KillTimer(FWindowHandle, WINTIMER_ID);
      FTimerActive := False;
      end;

   // Interval 0 means "no timer", as in the VCL.
   if FEnabled and (FInterval > 0) then
      begin
      FTimerActive := SetTimer(FWindowHandle, WINTIMER_ID, FInterval, nil) <> 0;
      end;
end;

procedure TWinTimer.SetEnabled(Value: boolean);
begin
   if Value <> FEnabled then
      begin
      FEnabled := Value;
      UpdateTimer;
      end;
end;

procedure TWinTimer.SetInterval(Value: Cardinal);
begin
   if Value <> FInterval then
      begin
      FInterval := Value;
      // Restarts a running timer at the new interval -- see the header.
      UpdateTimer;
      end;
end;

procedure TWinTimer.SetOnTimer(Value: TNotifyEvent);
begin
   FOnTimer := Value;
end;

end.
