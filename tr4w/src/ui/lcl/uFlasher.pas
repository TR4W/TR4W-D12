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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uFlasher;
{$I ..\..\tr4w.inc}

{
  FLASHING SOMETHING, WITHOUT A THREAD AND WITHOUT Sleep.

  TR4W flashed things by starting an OS thread whose entire life was a loop of
  Sleep and a UI call:

    FlashQickDisplay    six  x Sleep(100) toggling EnableWindow   (LOGWIND:3825)
    FlashIntercomListBox 49  x Sleep(150) toggling LB_SETSEL      (uIntercom:130)

  A thread that only sleeps is not concurrency, it is a timer with extra failure
  modes.  It costs a stack, it does UI from a worker thread -- safe only by the
  Win32 accident this migration is removing -- and it CANNOT BE CANCELLED.  The
  intercom one is the clearest case: 49 x 150 ms is SEVEN AND A HALF SECONDS
  during which the operator can dismiss the window, work a station and move on
  while a thread keeps toggling selection on a listbox behind them.

  A TIMER IS THE WHOLE ANSWER.  It runs on the main thread, it costs nothing
  while idle, Stop is one assignment, and restarting is not a special case.  It
  is also not a new pattern here -- it is the bandmap's, which is the cheapest
  UI in the program precisely because it schedules rather than blocks.  Timers
  became dependable when the program moved to Application.Run.

  WHAT IS SHARED IS THE SCHEDULING, NOT THE PAINTING, and that split is the
  point of the class.  The four flashers were four hand-rolled copies of the
  same countdown; that duplication is what this removes.  What each one DRAWS
  stays at the call site, because the targets are genuinely different widgets.

  ON THE FACT THAT THEY FLASH BY TOGGLING ENABLED AND SELECTED.  That is wrong
  and this unit does not fix it: EnableWindow means "this control cannot be
  used" and LB_SETSEL means "this row is selected", and flashing with them
  borrows a side effect of how those states happen to paint.  It is the same
  confusion that left RIT/XIT stuck yellow on the bench (see uPanelUpdate's note
  on ForgetPanel).  The honest reason it stays for now: both targets are still
  raw Win32 windows, not LCL controls, and you cannot set .Color on an HWND.
  When the quick-command window and the intercom listbox become LCL controls,
  the phase handler becomes a colour assignment and nothing here changes.

  IT ALWAYS LANDS ON THE RESTING STATE.  Stop -- whether the count ran out or a
  caller cancelled -- calls the phase handler one last time with True.  A
  flasher that can leave a control disabled because it was interrupted is worse
  than no flasher.
}

interface

uses
   ExtCtrls;   // TTimer -- an LCL unit that says so

type
   { Called once per phase, on the main thread.  aOn is the resting/"normal"
     state; the flash is the alternation between the two. }
   TFlashPhaseProc = procedure(const aOn: boolean);

type
   TFlasher = class(TObject)
   private
      FTimer: TTimer;
      FPhase: TFlashPhaseProc;
      FPhasesLeft: integer;
      FPhaseIndex: integer;
      procedure Tick(Sender: TObject);
   public
      constructor Create;
      destructor Destroy; override;

      { Begin flashing.  Calling Start while already running RESTARTS it rather
        than stacking, which is what every caller's hand-rolled guard flag was
        trying to express. }
      procedure Start(const aPhase: TFlashPhaseProc;
                      const aPhases, aIntervalMs: integer);

      { Stop early.  Lands on the resting state.  Harmless when not running. }
      procedure Stop;

      function Running: boolean;
   end;

implementation

uses
   SysUtils;

constructor TFlasher.Create;
begin
   inherited Create;
   FTimer := TTimer.Create(nil);
   FTimer.Enabled := False;
   FTimer.OnTimer := Tick;
end;

destructor TFlasher.Destroy;
begin
   if FTimer <> nil then
      begin
      FTimer.Enabled := False;
      FreeAndNil(FTimer);
      end;
   inherited Destroy;
end;

function TFlasher.Running: boolean;
begin
   Result := (FTimer <> nil) and FTimer.Enabled;
end;

procedure TFlasher.Start(const aPhase: TFlashPhaseProc;
                         const aPhases, aIntervalMs: integer);
begin
   if (not Assigned(aPhase)) or (aPhases <= 0) or (aIntervalMs <= 0) then
      begin
      Exit;
      end;

   FPhase := aPhase;
   FPhasesLeft := aPhases;
   FPhaseIndex := 0;

   FTimer.Enabled := False;
   FTimer.Interval := aIntervalMs;
   FTimer.Enabled := True;

   // The first phase immediately, not one interval from now.  The threaded
   // originals acted before their first Sleep, and waiting would make a short
   // flash look like a delay.
   Tick(nil);
end;

procedure TFlasher.Stop;
begin
   if FTimer <> nil then
      begin
      FTimer.Enabled := False;
      end;

   // ALWAYS LAND NORMAL -- see the header.
   if Assigned(FPhase) then
      begin
      FPhase(True);
      end;
end;

procedure TFlasher.Tick(Sender: TObject);
begin
   if FPhasesLeft <= 0 then
      begin
      Stop;
      Exit;
      end;

   // Odd phases are the resting state, which makes an even phase count end on
   // it naturally as well as via Stop.
   FPhase(Odd(FPhaseIndex));

   Inc(FPhaseIndex);
   Dec(FPhasesLeft);

   if FPhasesLeft <= 0 then
      begin
      Stop;
      end;
end;

end.
