unit uMainThread;

(* RUNNING SOMETHING ON THE MAIN THREAD.

  A background thread that has finished -- a download, a parse, a socket read
  -- has to hand its result to the main thread before anything touches the UI
  or the program's globals. TR4W did that by POSTING A WINDOW MESSAGE to the
  main window and answering it in the window procedure, which meant every such
  handoff needed three things that have nothing to do with the work: a message
  id, an arm in a Win32 window procedure, and a window handle for the thread to
  post to.

  IT ALSO MEANT THE HANDOFF COULD FAIL SILENTLY. PostMessage returns False when
  the target queue is full or the window is gone, and a caller that did not
  check simply lost the result -- with a heap object leaked behind it wherever
  the lParam carried ownership.

  Application.QueueAsyncCall is the LCL's own answer and needs none of that: it
  runs the call on the main thread the next time the loop turns, it is safe to
  call from any thread, and it exists on every platform the LCL targets. There
  is no handle, no message id and nothing for a window procedure to claim.

  WHEN TO REACH FOR THIS, AND WHEN NOT TO -- THERE ARE THREE MECHANISMS.

  1. A THREAD THAT HAS FINISHED wants its result handled: give the thread a
     TYPED EVENT and raise it from TThread.OnTerminate, which the RTL already
     raises through Synchronize on the main thread
     (rtl/win/tthread.inc:46-50). No queue, no unit, nothing custom. That is
     what uPOTAParks, uCTYUpdate and uTRMasterUpdate do, and it is the first
     thing to try.

  2. A REPEATED REQUEST TO REDRAW SOMETHING, from a poll loop: uMainThreadWork,
     which runs a NAMED job and COALESCES -- two asks while one is pending run
     once. Right for a display refresh; wrong for a result, where two would
     have to be two.

  3. WHAT IS LEFT, AND WHY THIS UNIT EXISTS: a thread that is STILL RUNNING
     handing over one distinct datum, mid-life. uTCIServer is the case and
     currently the only one -- an Indy connection thread queues an apply and
     carries on serving the connection. OnTerminate is no use (the thread is
     not ending), Synchronize would block the connection against
     TTCIServer.Stop, and TThread.Queue would purge the callback if that
     thread exited first.

  IF THIS UNIT EVER HAS NO CALLERS, DELETE IT rather than finding it a use.

  OWNERSHIP. aData is passed through untouched, so a caller may hand over a
  pointer -- a TStringList of parsed parks, a command object -- exactly as it
  handed one through an lParam. The callback owns it on arrival. The difference
  is that the handoff cannot now fail after the caller has released it. *)

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

interface

type
   (* A PLAIN PROCEDURE, not a method, because every caller here is a thread's
     Execute handing over a result rather than an object with a lifetime. *)
   TMainThreadCallback = procedure(aData: PtrInt);

(* Runs aCallback(aData) on the main thread, soon, and returns immediately.

  SAFE FROM ANY THREAD, including the main one -- from the main thread the call
  is still deferred to the next turn of the loop rather than run inline, which
  is what makes the timing the same wherever it is called from. *)
procedure RunOnMainThread(const aCallback: TMainThreadCallback;
                          const aData: PtrInt);

implementation

uses
   Forms;   (* Application.QueueAsyncCall *)

type
   (* ONE PENDING CALL. QueueAsyncCall carries a single PtrInt, and a handoff
     needs two things -- which routine, and its datum -- so the pair is
     allocated and the pointer to it is what travels. Freed by the dispatcher
     whether or not the callback raises. *)
   PPendingCall = ^TPendingCall;
   TPendingCall = record
      Callback: TMainThreadCallback;
      Data:     PtrInt;
   end;

   (* QueueAsyncCall takes a METHOD (TDataEvent), so there has to be an object
     for it to be a method of. One instance, created in initialization -- NOT
     on first use. This is called FROM BACKGROUND THREADS, so building it
     on first use is a race: two threads finishing
     together can both see nil, both construct, and one instance is leaked
     while a queued call may hold a pointer to the object the other replaced.
     Unit initialization runs once, on the main thread, before any of those
     threads exist. *)
   TMainThreadDispatcher = class
      procedure Dispatch(aData: PtrInt);
   end;

var
   GDispatcher: TMainThreadDispatcher = nil;

procedure TMainThreadDispatcher.Dispatch(aData: PtrInt);
var
   call: PPendingCall;
begin
   call := PPendingCall(aData);
   if call = nil then
      begin
      Exit;
      end;

   try
      if Assigned(call^.Callback) then
         begin
         call^.Callback(call^.Data);
         end;
   finally
      (* THE RECORD IS FREED EVEN IF THE CALLBACK RAISES. What the callback
        does with call^.Data is its own business -- this owns the pair, not
        the datum. *)
      Dispose(call);
   end;
end;

procedure RunOnMainThread(const aCallback: TMainThreadCallback;
                          const aData: PtrInt);
var
   call: PPendingCall;
begin
   if not Assigned(aCallback) then
      begin
      Exit;
      end;

   New(call);
   call^.Callback := aCallback;
   call^.Data     := aData;

   Application.QueueAsyncCall(GDispatcher.Dispatch, PtrInt(call));
end;

initialization
   GDispatcher := TMainThreadDispatcher.Create;

finalization
   (* Not freed while calls could still be queued: Application has already
     stopped turning by the time finalization runs, so anything still in the
     queue will never be dispatched, and freeing the dispatcher underneath a
     queued reference buys nothing. The instance is one object for the life of
     the process. *)

end.
