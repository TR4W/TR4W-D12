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

{ WHAT THE RADIO IS DOING, as state rather than as a widget write.

  The second concrete state object, after uWSJTXState, and the same shape for
  the same reason -- docs\DISPLAY_STATE_MODEL_PLAN.md.

  WHAT THIS REPLACES. uRadioPolling.PTTStatusChanged ended with

      SetMainWindowText(mwePTTStatus, PTTStatusString[ActiveRadioPtr.tPTTStatus]);

  and it is reached from ProcessFilteredStatus, which runs on the RADIO POLLING
  THREAD. So a serial reader was naming a control and assigning its caption.
  Under Win32 that was accidentally safe -- SetWindowTextW is a kernel call and
  Windows marshals it to the window's own thread -- and the LCL offers no such
  guarantee, which is why the ElementOnMainThread guard exists. A guard that
  makes wrong code work is weaker than a structure in which it cannot be
  written.

  WHY THIS IS A BOOLEAN AND NOT PTTStatusType. The domain records the FACT; the
  view decides what it looks like. PTTStatusType lives in VC.pas and its
  rendering is PTTStatusString in tree.pas -- 'OFF' and 'ON ', trailing space and
  all. Neither belongs here: this layer must not know that the answer is painted
  as text, and it must not reach VC, which pulls in Windows and would fail
  Lint-DomainPurity. The bridge in src\ui\lcl\uStateBridge.pas turns the boolean
  back into whatever the main window should show.

  NO LCL, NO WINDOWS, NO mwe* -- enforced by build\Lint-DomainPurity.ps1. }
unit uRadioState;

{$I ..\tr4w.inc}

interface

uses
   uDomainState;

type
   TRadioState = class(TDomainState)
   private
      FPTTOn: boolean;
      function  GetPTTOn: boolean;
      procedure SetPTTOn(const aValue: boolean);
   public
      { Set from the radio polling thread; read from the main thread. Both go
        through the lock, and setting it to what it already is notifies nobody --
        the poller re-reads status continuously and must not repaint on every
        pass. That coalescing is free here and was hand-built in uPanelUpdate
        precisely because the transport had to do it. }
      property PTTOn: boolean read GetPTTOn write SetPTTOn;
   end;

{ THE ONE INSTANCE. A global, as uWSJTXState is, and for the same reason: making
  it an injected dependency would be a second change inside a commit that is
  moving one call off a worker thread. }
var
   RadioState: TRadioState = nil;

implementation

function TRadioState.GetPTTOn: boolean;
begin
   Lock;
   try
      Result := FPTTOn;
   finally
      Unlock;
   end;
end;

procedure TRadioState.SetPTTOn(const aValue: boolean);
var
   changed: boolean;
begin
   Lock;
   try
      changed := FPTTOn <> aValue;
      FPTTOn := aValue;
   finally
      Unlock;
   end;

   // OUTSIDE THE LOCK. See TDomainState.NotifyChanged -- a subscriber that
   // called back into the state while the lock was held would deadlock.
   if changed then
      begin
      NotifyChanged;
      end;
end;

initialization
   RadioState := TRadioState.Create;

finalization
   RadioState.Free;
   RadioState := nil;

end.
