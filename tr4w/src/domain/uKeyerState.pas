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

{ WHAT THE WINKEYER IS, as state rather than as a widget write.

  Third state object, after uWSJTXState and uRadioState, same shape for the same
  reason -- docs\DISPLAY_STATE_MODEL_PLAN.md.

  WHAT THIS REPLACES, and it is THREE writers to one element, all of them on a
  thread:

    wkOpen             SetMainWindowText(mweWinKey, Format('WK%d v%d', ...))
                       -- started with tCreateThread (uProgramMain:1384)
    wkReadThreadProc   wkDispayState -> EnableElement(mweWinKey, wkActive)
    wkReadThreadProc1  the same

  So the panel's caption came from one thread and its enabled state from two
  others, with nothing coordinating them. That is the shape the plan describes:
  a worker naming a widget, safe only because Win32 marshalled it for us.

  TWO FACTS, NOT THREE PROPERTIES. Whether a keyer is answering, and what it
  said it was. Family and version move together -- they arrive in one reply from
  one device -- so they are set in one call and notify once. Two properties each
  firing a notification would repaint twice and could be seen half-updated.

  THE FORMAT STRING IS NOT HERE. 'WK%d v%d' is how the main window chooses to
  render a family and a version; another view might write it differently, and
  the domain must not care. src\ui\lcl\uStateBridge.pas owns it.

  NO LCL, NO WINDOWS, NO mwe* -- enforced by build\Lint-DomainPurity.ps1. }
unit uKeyerState;

{$I ..\tr4w.inc}

interface

uses
   uDomainState;

type
   TKeyerState = class(TDomainState)
   private
      FActive: boolean;
      FFamily: integer;
      FVersion: integer;
      function  GetActive: boolean;
      procedure SetActive(const aValue: boolean);
   public
      { Is the keyer answering? Set from the two WinKey read threads, which is
        why it is a locked property rather than a field. Setting it to what it
        already is notifies nobody -- the read threads call this on every pass
        through their loop. }
      property Active: boolean read GetActive write SetActive;

      { WHAT IT SAID IT WAS, set together in one call so the view never sees a
        family from one device and a version from the next. Zero for both means
        nothing has identified itself yet, which is the state at start-up and
        after a close. }
      procedure SetIdentity(const aFamily, aVersion: integer);
      procedure GetIdentity(out aFamily, aVersion: integer);
   end;

{ THE ONE INSTANCE, as with the other two. }
var
   KeyerState: TKeyerState = nil;

implementation

function TKeyerState.GetActive: boolean;
begin
   Lock;
   try
      Result := FActive;
   finally
      Unlock;
   end;
end;

procedure TKeyerState.SetActive(const aValue: boolean);
var
   changed: boolean;
begin
   Lock;
   try
      changed := FActive <> aValue;
      FActive := aValue;
   finally
      Unlock;
   end;

   if changed then
      begin
      NotifyChanged;   // OUTSIDE the lock -- see TDomainState.NotifyChanged
      end;
end;

procedure TKeyerState.SetIdentity(const aFamily, aVersion: integer);
var
   changed: boolean;
begin
   Lock;
   try
      changed := (FFamily <> aFamily) or (FVersion <> aVersion);
      FFamily := aFamily;
      FVersion := aVersion;
   finally
      Unlock;
   end;

   if changed then
      begin
      NotifyChanged;
      end;
end;

procedure TKeyerState.GetIdentity(out aFamily, aVersion: integer);
begin
   { BOTH UNDER ONE LOCK. Two separate reads could straddle a write and pair a
     new family with an old version -- the reason they are set together. }
   Lock;
   try
      aFamily := FFamily;
      aVersion := FVersion;
   finally
      Unlock;
   end;
end;

initialization
   KeyerState := TKeyerState.Create;

finalization
   KeyerState.Free;
   KeyerState := nil;

end.
