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

{ THE ONE PLACE THE DOMAIN CROSSES INTO THE UI, AND THE ONE PLACE THAT
  MARSHALS.

  A domain state object notifies on whatever thread changed it and knows nothing
  about a main thread -- that is the point of it.  This unit subscribes, hops to
  the main thread once, and then decides what the state LOOKS like.

  WHY THAT SPLIT IS THE WHOLE EXERCISE.  Before this, a UDP listener thread
  called SetMainWindowText(mweWSJTX, 'WSJTX') and ShowElement(mweWSJTX, True):
  a network thread naming a widget, choosing a caption, and choosing whether it
  was visible.  The caption and the visibility are decisions about APPEARANCE
  and they live here.  uWSJTX now sets a boolean.

  MARSHALLING: one hop, Application.QueueAsyncCall, and NOT TThread.Queue.  That
  is measured, not stylistic -- TThread.Queue stamps entries with the CALLING
  thread's id and TThread.Destroy purges by it, so a thread that queues and then
  exits deletes its own callback.  Radio threads are torn down on every
  reconnect.  See uPanelUpdate's header, and DOMAIN_LAYER_SEQUENCE.md.

  WHAT THIS UNIT WILL GROW INTO: one Apply per state object.  When radio state,
  keyer state and contest state follow, they subscribe here and nothing else in
  the program learns that mwe* identifiers exist. }
unit uStateBridge;

{$I ..\..\tr4w.inc}

interface

{ Call once, after the main form exists.  Idempotent. }
procedure InstallStateBridge;

implementation

uses
   SysUtils, Forms,
   VC,             // TMainWindowElement, tr4wColorsArray -- the APPEARANCE side
   TF,             // SetMainWindowText
   uCrashLog,      // OnMainThread, LogCaughtException
   uMainForm,      // ShowElement
   uWSJTXState;

type
   { QueueAsyncCall wants a method, so one object owns the hop. }
   TStateBridge = class(TObject)
   public
      procedure WSJTXChanged;             // subscriber -- ANY thread
      procedure ApplyWSJTX(Data: PtrInt); // main thread only
   end;

var
   GBridge: TStateBridge = nil;

{ ------------------------------------------------------------- WSJT-X ------ }

procedure TStateBridge.ApplyWSJTX(Data: PtrInt);
begin
   // THE APPEARANCE DECISIONS, all three of them, in the layer that owns them:
   // a live link is captioned, a dead one is blank, and the indicator is hidden
   // when there is nothing to say.  The COLOUR is decided by
   // RefreshMainWindowElementColors, which reads the same state.
   if WSJTXState.Connected then
      begin
      SetMainWindowText(mweWSJTX, 'WSJTX');
      ShowElement(mweWSJTX, True);
      end
   else
      begin
      SetMainWindowText(mweWSJTX, '');
      ShowElement(mweWSJTX, False);
      end;
end;

procedure TStateBridge.WSJTXChanged;
begin
   // Called from the UDP listener thread.  One hop, and only when we are not
   // already where we need to be.
   if OnMainThread then
      begin
      ApplyWSJTX(0);
      Exit;
      end;

   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GBridge.ApplyWSJTX, 0);
end;

{ ------------------------------------------------------------- install ----- }

procedure InstallStateBridge;
begin
   if GBridge <> nil then
      begin
      Exit;
      end;
   GBridge := TStateBridge.Create;

   WSJTXState.Subscribe(GBridge.WSJTXChanged);

   // The state may already be set -- WSJT-X can heartbeat before the main form
   // is up -- so the view is brought into line once at install rather than
   // waiting for the next change.
   GBridge.WSJTXChanged;
end;

finalization
   FreeAndNil(GBridge);

end.
