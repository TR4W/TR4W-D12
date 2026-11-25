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

{ WHETHER WSJT-X IS TALKING TO US.  The first real domain state, and chosen as
  the first deliberately: it is ONE boolean, ONE writer and ONE indicator, so it
  proves the whole path -- state, notification, bridge, view -- with almost
  nothing to get wrong.

  IT IS ALSO THE ONE NY4I ASKED ABOUT.  "How does WSJT-X sending UDP data turn
  the wsjtx indication green?"  The answer used to be: an Indy UDP listener
  thread calls SetMainWindowText(mweWSJTX, 'WSJTX') and ShowElement, i.e. a
  network thread names a widget.  Now it sets Connected here and stops caring
  what that looks like.

  WHAT IS DELIBERATELY ABSENT: the caption 'WSJTX', the colour green, and the
  element mweWSJTX.  Deciding that a live link looks like a green panel is the
  view's job -- src\ui\lcl\uStateBridge.pas. }
unit uWSJTXState;

{$I ..\tr4w.inc}

interface

uses
   uDomainState;

const
   (* How long after a STATUS that says WSJT-X may transmit it counts as running
     the QSO.  Longer than a cycle pair (FT8 15 s, FT4 7.5 s, FT8 TX 13 s) and the
     return of a shifted dial after the last transmission. *)
   WSJTX_DRIVING_WINDOW_MS = 60000;

type
   TWSJTXState = class(TDomainState)
   private
      FConnected: boolean;
      FDrivingTick: QWord;
      function  GetConnected: boolean;
      procedure SetConnected(const aValue: boolean);
   public
      (* WSJT-X IS RUNNING A QSO: its STATUS says it may transmit or is
        transmitting.  Stamped by the UDP listener on every such STATUS and
        asked by the radio polling thread, so a dial the program is moved to
        make room for the transmission (WSJT-X's Fake It / split) is not taken
        for the operator tuning away.  Both threads go through the lock. *)
      procedure NoteDriving;
      function  Driving(aWindowMs: QWord): boolean;

      { Set from the UDP listener thread; read from the main thread.  Both go
        through the lock, and setting it to what it already is notifies nobody
        -- a heartbeat arrives every few seconds and must not repaint on each
        one. }
      property Connected: boolean read GetConnected write SetConnected;
   end;

{ THE ONE INSTANCE.  A global, like everything else this program keeps, and for
  now that is the honest shape: making it an injected dependency would be a
  second change in a commit that is establishing a layer. }
var
   WSJTXState: TWSJTXState = nil;

implementation

uses
   SysUtils;   // GetTickCount64

function TWSJTXState.GetConnected: boolean;
begin
   Lock;
   try
      Result := FConnected;
   finally
      Unlock;
   end;
end;

procedure TWSJTXState.NoteDriving;
begin
   Lock;
   try
      FDrivingTick := GetTickCount64;
   finally
      Unlock;
   end;
end;

function TWSJTXState.Driving(aWindowMs: QWord): boolean;
begin
   Lock;
   try
      Result := (FDrivingTick <> 0) and
                (GetTickCount64 - FDrivingTick <= aWindowMs);
   finally
      Unlock;
   end;
end;

procedure TWSJTXState.SetConnected(const aValue: boolean);
var
   changed: boolean;
begin
   Lock;
   try
      changed := FConnected <> aValue;
      FConnected := aValue;
   finally
      Unlock;
   end;

   // OUTSIDE THE LOCK.  See TDomainState.NotifyChanged.
   if changed then
      begin
      NotifyChanged;
      end;
end;

initialization
   WSJTXState := TWSJTXState.Create;

finalization
   WSJTXState.Free;
   WSJTXState := nil;

end.
