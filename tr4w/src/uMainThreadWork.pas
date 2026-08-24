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
unit uMainThreadWork;
{$I tr4w.inc}

{
  RUN A NAMED PIECE OF WORK ON THE MAIN THREAD, ONCE, HOWEVER OFTEN IT IS ASKED
  FOR.

  WHAT THIS IS FOR.  The radio polling thread does UI work directly.  Not
  theoretically -- ProcessFilteredStatus switches the operating mode, moves the
  focus and refreshes six displays, all from the reading thread of whichever
  radio happened to report.  That was safe only BY ACCIDENT: every one of those
  calls bottomed out in a Win32 API that marshals across threads for you.
  InvalidateRect posts, a cross-thread SetFocus fails harmlessly, a cross-thread
  SendMessage blocks but works.  The LCL equivalents are none of those things,
  and until the calls arrive on the main thread the controls underneath them
  cannot become ordinary LCL property access.

  WHY NOT THE MECHANISMS ALREADY REJECTED.  uPanelUpdate settled this for the
  radio panels on 2026-08-14 and the reasoning still holds:

    * TThread.Queue stamps each entry with the CALLING thread's id even when the
      thread argument is nil, and TThread.Destroy purges by that id -- so a
      thread that queues and then exits DELETES ITS OWN PENDING CALLBACK.  Radio
      threads are torn down on every reconnect, which is exactly when an update
      matters most.
    * TThread.Synchronize blocks the worker until the main thread runs it.  A
      radio poll must not be held hostage to a busy UI.

  WHY NOT A POSTED MESSAGE EITHER, WHICH IS THE PART THAT CHANGED.  uPanelUpdate
  chose PostMessage because the alternatives were worse AND because TR4W ran a
  hand-rolled GetMessage loop -- its header says as much, and calls that "a
  mechanism Phase 3/7 deletes".  Phase 3/7 has now happened: the program runs
  Application.Run.  So Application.QueueAsyncCall is available, and it answers
  all three objections at once -- it does not block the sender, it is tied to no
  thread's lifetime, and it is drained by the LCL's own loop with no
  CheckSynchronize and no WakeMainThread reliance.  It is also not Win32, which
  is the direction of travel.  MEASURED, NOT ASSUMED: QueueAsyncCall enters
  FAsyncCall.CritSec (lcl/include/application.inc:2327), so it really is safe
  from a worker thread.

  AND IT COALESCES, which is the half that is not about threads.  A job already
  waiting is not queued twice, and the request costs a compare-and-swap.  That
  matters because these are asked for from a poll loop -- the bandmap's lesson,
  which uPanelUpdate records too: set a flag, do the work once, never marshal
  per event.

  Compare-and-swap rather than a lock, because requests arrive from several
  radio threads at once and the entire point is that asking is cheaper than
  doing.

  THE BIT IS CLEARED BEFORE THE JOB RUNS, NOT AFTER, AND THAT IS DELIBERATE.  A
  change arriving while the job executes must queue another pass rather than be
  swallowed by the pass that is already past the point of reading it.  Being
  wrong in this direction costs one redundant refresh; being wrong in the other
  leaves a display silently stale until the operator happens to move something.

  THE JOBS THEMSELVES LIVE WITH THEIR SUBJECT.  This unit knows nothing about
  radios, bands or windows: callers register a procedure against a job id from
  their own initialization.  Moving the bodies here would put radio logic in a
  threading unit and drag MainUnit in behind it, and the seam is worth more than
  the saved indirection.
}

interface

type
   { One value per marshalled operation.  Add a member, register a procedure for
     it, and the coalescing comes for free. }
   TMainThreadJob = (
      { The two radio rows' alert colour.  A radio connecting or dropping
        changes a COLOUR and nothing else, so no text is written and nothing
        else would push it -- the Win32 version got away with an InvalidateRect
        from the polling thread because DrawWindows re-evaluated the rule while
        painting.  An LCL control paints from a property, so the property has to
        be recomputed, and that has to happen on the main thread. }
      mtRadioAlertColors,
      { AUTO S&P: the operator tuned the dial far enough to leave CQ mode.  A
        SEQUENCE -- clear the dupe info, clear Alt-D, reinitialise the QSO, take
        the focus -- which is why it is one job and not four. }
      mtSwitchToSearchAndPounce,

      { The active radio changed band or mode: refresh everything that shows
        either.  Pure repaint, and already behind a change test. }
      mtBandModeDisplay
   );

   TMainThreadProc = procedure;

{ Say what to run for a job.  Call once, from the owning unit's initialization.
  Registering over an existing entry replaces it. }
procedure RegisterMainThreadJob(const aJob: TMainThreadJob;
                                const aProc: TMainThreadProc);

{ Ask for a job to run on the main thread.  Safe from ANY thread, never blocks,
  and asking for one already pending costs a compare-and-swap and returns. }
procedure RequestMainThreadJob(const aJob: TMainThreadJob);

{ True while at least one job is waiting.  Diagnostics only. }
function MainThreadWorkPending: boolean;

implementation

uses
   SysUtils,
   Forms,       // Application.QueueAsyncCall
   uCrashLog;   // LogCaughtException -- a job must not kill the message loop

type
   { QueueAsyncCall wants a method, so one object owns it. }
   TJobRunner = class(TObject)
   public
      procedure RunOne(Data: PtrInt);
   end;

var
   { One bit per job.  LongInt because that is what the Interlocked family
     takes. }
   gPending: LongInt = 0;
   gProcs: array[TMainThreadJob] of TMainThreadProc;
   gRunner: TJobRunner = nil;

function BitOf(const aJob: TMainThreadJob): LongInt;
begin
   Result := LongInt(1) shl Ord(aJob);
end;

procedure RegisterMainThreadJob(const aJob: TMainThreadJob;
                                const aProc: TMainThreadProc);
begin
   gProcs[aJob] := aProc;
end;

function MainThreadWorkPending: boolean;
begin
   Result := gPending <> 0;
end;

procedure ReleaseBit(const aBit: LongInt);
var
   prev: LongInt;
begin
   repeat
      prev := gPending;
   until InterlockedCompareExchange(gPending, prev and (not aBit), prev) = prev;
end;

procedure TJobRunner.RunOne(Data: PtrInt);
var
   job: TMainThreadJob;
   proc: TMainThreadProc;
begin
   job := TMainThreadJob(Data);

   // CLEAR FIRST -- see the header.  A request arriving while this runs must
   // queue another pass rather than be lost inside this one.
   ReleaseBit(BitOf(job));

   proc := gProcs[job];
   if not Assigned(proc) then
      begin
      Exit;
      end;

   try
      proc();
   except
      on E: TObject do
         begin
         // This runs INSIDE the LCL's async-call drain, which runs inside the
         // message loop.  An escaping exception would take out the loop over a
         // refresh that failed -- report it and keep the program up.
         LogCaughtException('main-thread job ' + IntToStr(Ord(job)), E);
         end;
   end;
end;

procedure RequestMainThreadJob(const aJob: TMainThreadJob);
var
   bit, prev: LongInt;
begin
   bit := BitOf(aJob);

   // Claim the bit, or find that somebody already has.  A loop, because another
   // radio thread may be claiming a DIFFERENT bit in the same word.
   repeat
      prev := gPending;
      if (prev and bit) <> 0 then
         begin
         // Already waiting.  Nothing to do -- that is the coalescing.
         Exit;
         end;
   until InterlockedCompareExchange(gPending, prev or bit, prev) = prev;

   try
      Application.QueueAsyncCall(gRunner.RunOne, PtrInt(Ord(aJob)));
   except
      on E: TObject do
         begin
         // QueueAsyncCall RAISES once the queue is shut down, and a radio thread
         // polls until its object is torn down -- so this is reached on an
         // ordinary exit, not only on a fault.  Release the bit so nothing
         // believes a job is pending forever, and say so rather than swallow it.
         ReleaseBit(bit);
         LogCaughtException('RequestMainThreadJob ' + IntToStr(Ord(aJob)), E);
         end;
   end;
end;

initialization
   gRunner := TJobRunner.Create;

finalization
   // Anything still queued is dropped by the LCL at shutdown; freeing the runner
   // while a drain could still be in flight would be the worse race.
   FreeAndNil(gRunner);

end.
