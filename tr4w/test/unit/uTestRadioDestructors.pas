unit uTestRadioDestructors;
{$I ..\..\src\tr4w.inc}

(*
  PINS THAT A FACTORY RADIO'S DESTRUCTOR RUNS, AND THAT RUNNING IT IS SAFE.

  THE DEFECT.  TFactoryRadioBase declared `Destructor Destroy; overload;
  Virtual;`.  That is a NEW virtual slot, and it HID TObject.Destroy (the
  compiler warned on every build).  Free and FreeAndNil call TObject's slot, so
  for the whole life of the factory NO radio destructor ever ran -- not the
  base's (socket, IOHandler, VFOs, serial port, lock), not TK4Radio's spectrum
  thread stop, not the Icom family's transport teardown, not HamLib's or
  TCI's.  The memory was released; nothing inside it was.

  THE FIX made the base destructor `override` and gave the base a
  BeforeDestruction that stops its reading thread while the object is whole.
  Code that has never run is new code, so these tests run it:

  - Test_FreeThroughBaseReferenceRunsTheDestructor -- the pin.  A probe whose
    destructor sets a flag, freed through a TFactoryRadioBase variable.  On the
    old declaration the probe's `override` overrode the base's private slot,
    Free went to TObject.Destroy, and the flag stays False.
  - Test_EveryRegisteredRadioFreesCleanly -- every registry entry, on every
    link it claims, built and freed.  Nothing may raise.
  - Test_EveryRegisteredRadioFreesAfterDisconnect -- the same after
    Disconnect, which is the production order (ShutDownRadioInterface,
    ExitProgram): every teardown step must be idempotent.
  - Test_ConnectedNetworkRadioWithReaderFrees -- a real TK4Radio connected to a
    loopback server, with its reading thread parked in a ReadLn that has no
    timeout.  Free must return, which needs the socket closed BEFORE the
    reader is joined -- the order the old, never-run body had backwards.  The
    Free runs on a helper thread under a watchdog, so a regression FAILS
    rather than hanging the run.

  NO TRANSPORT EXCEPT LOOPBACK.  Constructing a radio opens nothing (the
  existing uTestFlexRegistry test builds every one the same way); only the
  last test makes a connection, to 127.0.0.1 on an ephemeral port.

  TWO OTHER THREADS THAT MUST BE STOPPED BEFORE WHAT THEY USE IS FREED:

  - Test_FreeRunningCIVSendThread (issue #105) -- the Icom CI-V send queue
    thread, freed while RUNNING with no Stop or WaitFor first.  Its destructor
    used to free its event, lock and queues and only THEN join, so the
    running thread woke from its 50 ms wait into freed objects.  The probe
    subclass catches what Execute raises; under the checked build heaptrc
    fills freed memory with $F0, so the freed lock's VMT is $F0F0F0F0 and the
    old order raises an access violation there every time.
  - Test_ShutDown* (issue #104) -- RadioObject.ShutDownRadioInterface against
    a REAL polling thread (uRadioPolling.BeginPolling) whose first call on the
    radio blocks.  The shutdown used to wait 3 s, ignore the answer and free
    the radio under the thread.  One radio is unblocked by closing its link
    (InterruptLink), and must be freed only after its thread has exited; the
    other is not (a wedged serial write), and must be LEAKED, not freed, with
    its thread leaving on its own once the call returns.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal,
   uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4,
   uRadioIcomBase,   // TCIVSendThread -- issue #105
   LogRadio,         // RadioObject, ShutDownRadioInterface -- issue #104
   VC,               // Serial1 -- placing a radio on a serial link
   Log4D, uTestLogCapture;   // the stop walk's ERROR capture -- issue #99

type
   (* Sets a flag from its destructor.  Nothing else. *)
   TDestructorFlagProbe = class(TFactoryRadioBase)
   public
      destructor Destroy; override;
   end;

   (* A real TK4Radio, connected through the SHIPPED path with OnConnected left
     in place -- so, unlike uTestRadioSocketNoRead's probe, it starts its
     reading thread. *)
   TConnectedK4Probe = class(TK4Radio)
   public
      procedure ConnectWithReader(const AHost: string; APort: Integer);
   end;

   (* Frees one object on its own thread and says when it is done, so the test
     thread can wait with a timeout instead of for ever. *)
   TBackgroundFree = class(TThread)
   private
      FTarget: TObject;
      FDone: TEvent;
      FError: string;
   protected
      procedure Execute; override;
   public
      constructor Create(ATarget: TObject);
      destructor Destroy; override;
      function WaitDone(AMs: Cardinal): Boolean;
      property Error: string read FError;
   end;

   (* The shipped TCIVSendThread, with Execute wrapped so an exception it
     raises is RECORDED instead of vanishing into TThread.FatalException --
     which Free discards.  Nothing else is changed. *)
   TCIVSendThreadProbe = class(TCIVSendThread)
   public
      procedure Execute; override;
   end;

   (* A radio whose FIRST call from the polling thread -- IsConnected, the top
     of every pass in pFactoryRadio -- blocks until it is released.  Released
     by its own link being interrupted, or not, per the constructor: the
     second is a call that closing the link cannot reach, such as a serial
     write to an adapter that was just unplugged.  Its destructor records
     whether the polling thread was still running when it was freed. *)
   TBlockingPollProbe = class(TFactoryRadioBase)
   private
      FBlockedOnce: Boolean;
      FInterruptReleases: Boolean;
   protected
      function GetIsConnected: boolean; override;
   public
      constructor CreateProbe(AHandler: TProcessMsgRef; AInterruptReleases: Boolean);
      procedure InterruptLink; override;
      destructor Destroy; override;
   end;

   (* What the registry walk does to each radio between building and freeing it. *)
   TRadioWalkStep = (rwNothing, rwDisconnect, rwStopAndUnkey);

   (* Reaches a radio's protected logger, through the door any descendant has.
     Never constructed: the walk casts a built radio to it. *)
   TRadioLoggerAccess = class(TFactoryRadioBase)
   public
      function RadioLogger: TLogLogger;
   end;

   TRadioDestructorTests = class(TTestCase)
   private
      FServer: TIdTCPServer;
      procedure HandleMessage(sMessage: string);
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  FreeEveryRadio(disconnectFirst: Boolean; out checked: Integer): string;
      function  WalkEveryRadio(aStep: TRadioWalkStep; out checked: Integer): string;
      function  StartBlockedPoller(AInterruptReleases: Boolean): TBlockingPollProbe;
      function  WaitPollerGone(AMs: Integer): Boolean;
   protected
      procedure Test_FreeThroughBaseReferenceRunsTheDestructor;
      procedure Test_EveryRegisteredRadioFreesCleanly;
      procedure Test_EveryRegisteredRadioFreesAfterDisconnect;
      procedure Test_ConnectedNetworkRadioWithReaderFrees;
      procedure Test_EveryRegisteredRadio_StopAndUnkeyWithNoLink_LogNoError;
      procedure Test_FreeRunningCIVSendThread;
      procedure Test_FreeNeverStartedCIVSendThread;
      procedure Test_ShutDownFreesTheRadioOnlyAfterThePollerStops;
      procedure Test_ShutDownLeaksARadioWhosePollerWillNotStop;
   public
      procedure RunAllTests; override;
   end;

implementation

var
   gProbeDestroyed: Boolean = False;

   (* What TCIVSendThreadProbe.Execute caught, '' for nothing.  Written on the
     probe's thread, read on the test thread after the join. *)
   gCIVThreadFault: string = '';

   (* THE SLOT the shutdown tests run on.  A unit global and not Radio1/Radio2,
     so the tests never touch the radios the rest of the program uses; a
     global, so it starts zeroed with no FillChar. *)
   gPollRig: RadioObject;
   gPollBlocked: TEvent;             // the probe's call has started blocking
   gPollRelease: TEvent;             // lets the blocked call return
   gPollProbeFreed: Boolean = False;
   gPollerRunningAtFree: Boolean = False;

const
   (* Bounds on waits that a correct run finishes in milliseconds.  A failure
     must REPORT rather than hang the run. *)
   POLL_BLOCK_WAIT_MS   = 5000;
   POLL_RELEASE_MAX_MS  = 30000;

(* ---- probes ----------------------------------------------------------------- *)

function TRadioLoggerAccess.RadioLogger: TLogLogger;
begin
   Result := logger;
end;

(* A captured log line with its control and non-ASCII bytes shown as '.'.  The
  logged command can be a binary frame or end in a CR -- the Orion's does --
  and a raw CR in a failure message cut the report off at that radio. *)
function Printable(const s: string): string;
var
   i: Integer;
begin
   Result := Trim(s);
   for i := 1 to Length(Result) do
      begin
      if (Ord(Result[i]) < 32) or (Ord(Result[i]) > 126) then
         begin
         Result[i] := '.';
         end;
      end;
end;

function LinkName(link: TRadioLink): string;
begin
   if link = rlSerial then
      begin
      Result := 'serial';
      end
   else
      begin
      Result := 'network';
      end;
end;

procedure TCIVSendThreadProbe.Execute;
begin
   try
      inherited Execute;
   except
      on E: Exception do
         begin
         gCIVThreadFault := E.ClassName + ': ' + E.Message;
         end;
   end;
end;

constructor TBlockingPollProbe.CreateProbe(AHandler: TProcessMsgRef; AInterruptReleases: Boolean);
begin
   inherited Create(AHandler);
   FBlockedOnce := False;
   FInterruptReleases := AInterruptReleases;
end;

function TBlockingPollProbe.GetIsConnected: boolean;
begin
   if not FBlockedOnce then
      begin
      FBlockedOnce := True;
      gPollBlocked.SetEvent;
      (* Bounded only so a broken run cannot hang the suite for ever. *)
      gPollRelease.WaitFor(POLL_RELEASE_MAX_MS);
      end;
   Result := False;
end;

procedure TBlockingPollProbe.InterruptLink;
begin
   if FInterruptReleases then
      begin
      gPollRelease.SetEvent;
      end;
   inherited InterruptLink;
end;

destructor TBlockingPollProbe.Destroy;
begin
   gPollProbeFreed := True;
   gPollerRunningAtFree := gPollRig.PollingThreadRunning;
   inherited Destroy;
end;

destructor TDestructorFlagProbe.Destroy;
begin
   gProbeDestroyed := True;
   inherited Destroy;
end;

procedure TConnectedK4Probe.ConnectWithReader(const AHost: string; APort: Integer);
begin
   radioAddress := AHost;
   radioPort := APort;
   Connect;
end;

constructor TBackgroundFree.Create(ATarget: TObject);
begin
   FTarget := ATarget;
   FDone := TEvent.Create(nil, True, False, '');
   FError := '';
   FreeOnTerminate := False;
   (* Suspended, then Start: the fields are set before Execute can run. *)
   inherited Create(True);
   Start;
end;

destructor TBackgroundFree.Destroy;
begin
   inherited Destroy;      // joins Execute first
   FreeAndNil(FDone);
end;

procedure TBackgroundFree.Execute;
begin
   try
      FTarget.Free;
   except
      on E: Exception do
         begin
         FError := E.ClassName + ': ' + E.Message;
         end;
   end;
   FTarget := nil;
   FDone.SetEvent;
end;

function TBackgroundFree.WaitDone(AMs: Cardinal): Boolean;
begin
   Result := FDone.WaitFor(AMs) = wrSignaled;
end;

(* ---- fixture ---------------------------------------------------------------- *)

procedure TRadioDestructorTests.HandleMessage(sMessage: string);
begin
   (* Nothing arrives: the probe opens no transport. *)
end;

(* Swallows whatever the radio sends and never answers, so the radio's reading
  thread stays parked in ReadLn -- the state that has to be broken out of. *)
procedure TRadioDestructorTests.ServerExecute(AContext: TIdContext);
begin
   AContext.Connection.IOHandler.ReadLn(';', 100, -1, IndyTextEncoding_8Bit);
end;

function TRadioDestructorTests.StartServer: Word;
begin
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;

   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;          // ephemeral: never collides with a real service
      end;

   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TRadioDestructorTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* Build every registered radio on every link it claims and free it, catching
  anything that escapes.  Returns the failures, one per entry; checked counts
  what was built, so a loop that silently built nothing cannot pass. *)
function TRadioDestructorTests.FreeEveryRadio(disconnectFirst: Boolean;
                                              out checked: Integer): string;
begin
   if disconnectFirst then
      begin
      Result := WalkEveryRadio(rwDisconnect, checked);
      end
   else
      begin
      Result := WalkEveryRadio(rwNothing, checked);
      end;
end;

(* THE ONE REGISTRY WALK: every registered radio -- enum and string-id alike,
  RegisteredIds holds both -- on every link it claims, built, put through
  aStep, and freed.  Anything that escapes is reported against the stage it
  escaped from.

  rwStopAndUnkey PLACES the radio on its link first (a serial port, or an
  address and port) WITHOUT connecting, because several drivers choose their
  transport from that -- the Icom sends a network radio's frames to its UDP
  transport, which does not exist until Connect.  It then calls StopCW and
  Receive with the radio's own logger capturing at ERROR, and any line
  captured is a failure: with no link there is nothing to stop (issue #99). *)
function TRadioDestructorTests.WalkEveryRadio(aStep: TRadioWalkStep;
                                              out checked: Integer): string;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   link: TRadioLink;
   stage: string;
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
begin
   Result := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;
   for id in ids do
      begin
      for link := Low(TRadioLink) to High(TRadioLink) do
         begin
         if ((link = rlSerial) and not uRadioRegistry.SupportsSerialId(id)) or
            ((link = rlNetwork) and not uRadioRegistry.SupportsNetworkId(id)) then
            begin
            Continue;
            end;

         stage := 'create';
         r := nil;
         try
            r := uRadioRegistry.CreateInstanceForLinkId(id, link);
            if r = nil then
               begin
               Result := Result + id + '(nil) ';
               Continue;
               end;
            Inc(checked);

            case aStep of
               rwDisconnect:
                  begin
                  stage := 'disconnect';
                  r.Disconnect;
                  end;
               rwStopAndUnkey:
                  begin
                  stage := 'place on link';
                  if link = rlSerial then
                     begin
                     r.serialPort := Serial1;
                     end
                  else
                     begin
                     r.radioAddress := '127.0.0.1';
                     r.radioPort := 9;      // never connected to; any non-zero port
                     end;

                  capture := TCaptureAppender.Create('stop-capture');
                  keep := capture;
                  lg := TRadioLoggerAccess(r).RadioLogger;
                  savedLevel := lg.Level;
                  lg.Level := Log4D.Error;
                  lg.AddAppender(keep);
                  try
                     stage := 'StopCW';
                     r.StopCW;
                     stage := 'Receive';
                     r.Receive;
                  finally
                     lg.RemoveAppender(keep);
                     lg.Level := savedLevel;
                  end;
                  if capture.Lines.Count > 0 then
                     begin
                     Result := Result + Format('%s[%s] logged: %s; ',
                                               [id, LinkName(link), Printable(capture.Lines[0])]);
                     end;
                  keep := nil;
                  end;
               end;

            stage := 'free';
            FreeAndNil(r);
         except
            on E: Exception do
               begin
               Result := Result + Format('%s[%s %s] %s: %s; ',
                                         [id, LinkName(link), stage, E.ClassName, E.Message]);
               end;
         end;
         end;
      end;
end;

(* ---- tests ------------------------------------------------------------------ *)

procedure TRadioDestructorTests.Test_FreeThroughBaseReferenceRunsTheDestructor;
var
   handler: TProcessMsgRef;
   r: TFactoryRadioBase;
begin
   BeginTest('Free on a TFactoryRadioBase reference runs the radio''s destructor');
   (* A typed local and no @ -- see uTestRadioSocketProbe.MakeRadio. *)
   handler := HandleMessage;
   gProbeDestroyed := False;

   r := TDestructorFlagProbe.Create(handler);
   CheckTrue(r.BaseConstructorRan, 'precondition: the base constructor ran');
   (* Free, exactly as ShutDownRadioInterface and ExitProgram do it. *)
   r.Free;

   CheckTrue(gProbeDestroyed,
             'Free did not reach the radio''s destructor -- TFactoryRadioBase.Destroy ' +
             'must be `override`; `overload; Virtual;` hides TObject.Destroy and Free ' +
             'then runs no radio destructor at all');
end;

procedure TRadioDestructorTests.Test_EveryRegisteredRadioFreesCleanly;
var
   bad: string;
   checked: Integer;
begin
   BeginTest('every registered radio, on every link, frees without raising');
   bad := FreeEveryRadio(False, checked);
   CheckTrue(checked > 50, Format('expected to build many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose Free raised: ' + bad);
end;

procedure TRadioDestructorTests.Test_EveryRegisteredRadioFreesAfterDisconnect;
var
   bad: string;
   checked: Integer;
begin
   BeginTest('every registered radio frees cleanly after Disconnect (the production order)');
   bad := FreeEveryRadio(True, checked);
   CheckTrue(checked > 50, Format('expected to build many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose Disconnect-then-Free raised: ' + bad);
end;

procedure TRadioDestructorTests.Test_ConnectedNetworkRadioWithReaderFrees;
var
   probe: TConnectedK4Probe;
   freer: TBackgroundFree;
   finished: Boolean;
begin
   BeginTest('a connected network radio with a live reading thread frees, and promptly');

   probe := TConnectedK4Probe.Create;
   freer := nil;
   finished := False;
   try
      probe.ConnectWithReader('127.0.0.1', StartServer);
      CheckTrue(probe.IsConnected, 'precondition: the loopback connect succeeded');

      (* The reading thread is now parked in ReadLn: the server never answers.
        Free must close the socket before joining it.  The reader's own worst
        sleep is 1000 ms, so 5 s is generous; a hang is the failure. *)
      freer := TBackgroundFree.Create(probe);
      probe := nil;   // owned by the freer from here
      finished := freer.WaitDone(5000);

      CheckTrue(finished,
                'Free of a connected network radio did not return in 5 s -- the ' +
                'reading thread was joined while still blocked in ReadLn (the ' +
                'socket must be closed first)');
      if finished then
         begin
         CheckEquals('', freer.Error, 'Free raised');
         end;
   finally
      if finished then
         begin
         FreeAndNil(freer);
         end;
      (* else: the freer and the radio are deliberately LEAKED.  Freeing the
        freer would join a thread that is stuck, and the run would hang
        instead of reporting. *)
      if probe <> nil then
         begin
         FreeAndNil(probe);   // the connect raised before the hand-over
         end;
      StopServer;
   end;
end;

(* ---- issue #99: a stop or unkey with no link, on EVERY radio --------------- *)

procedure TRadioDestructorTests.Test_EveryRegisteredRadio_StopAndUnkeyWithNoLink_LogNoError;
var
   bad: string;
   checked: Integer;
begin
   BeginTest('every registered radio, on every link, stops CW and unkeys with no link: no exception, no ERROR');
   (* The rule is "there is nothing to stop", and it holds for every radio, so
     it is asserted over the registry rather than driver by driver: a driver
     added later that sends its stop unconditionally fails here by name. *)
   bad := WalkEveryRadio(rwStopAndUnkey, checked);
   CheckTrue(checked > 50, Format('expected to build many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose StopCW/Receive with no link raised or logged an ERROR: ' + bad);
end;

(* ---- issue #105: the CI-V send thread -------------------------------------- *)

procedure TRadioDestructorTests.Test_FreeRunningCIVSendThread;
var
   t: TCIVSendThreadProbe;
   freer: TBackgroundFree;
   finished: Boolean;
   pass: Integer;
begin
   BeginTest('a RUNNING CI-V send thread freed with no Stop or WaitFor first is joined before its objects go');

   (* Three rounds, because the old order fails when the thread wakes into
     freed objects, and one pass could in principle land between its frees
     and its join.  No owner: an idle queue never reaches FOwner. *)
   for pass := 1 to 3 do
      begin
      gCIVThreadFault := '';
      t := TCIVSendThreadProbe.Create(nil);
      t.Start;
      Sleep(120);    // well inside Execute's 50 ms WaitFor loop

      freer := TBackgroundFree.Create(t);
      finished := freer.WaitDone(5000);
      CheckTrue(finished, Format('pass %d: Free of a running CI-V send thread did not return in 5 s', [pass]));
      if not finished then
         begin
         (* Leaked deliberately: freeing the freer would join a stuck thread. *)
         Exit;
         end;
      CheckEquals('', freer.Error, Format('pass %d: Free raised', [pass]));
      FreeAndNil(freer);

      CheckEquals('', gCIVThreadFault,
                  Format('pass %d: the CI-V send thread ran on freed objects -- its ' +
                         'destructor must stop and join it BEFORE freeing FHasWork, ' +
                         'FLock and the queues (issue #105)', [pass]));
      end;
end;

procedure TRadioDestructorTests.Test_FreeNeverStartedCIVSendThread;
var
   t: TCIVSendThreadProbe;
   freer: TBackgroundFree;
   finished: Boolean;
begin
   BeginTest('a CI-V send thread that was never started frees, and promptly');

   (* Created suspended, as TIcomRadio.Connect creates it, and never resumed.
     A destructor that simply WaitFor'd would wait on a thread that never runs;
     TThread.Destroy starts it with Terminated set so it can finish. *)
   gCIVThreadFault := '';
   t := TCIVSendThreadProbe.Create(nil);
   freer := TBackgroundFree.Create(t);
   finished := freer.WaitDone(5000);
   CheckTrue(finished, 'Free of a never-started CI-V send thread did not return in 5 s');
   if finished then
      begin
      CheckEquals('', freer.Error, 'Free raised');
      FreeAndNil(freer);
      end;
   CheckEquals('', gCIVThreadFault, 'Execute raised: ' + gCIVThreadFault);
end;

(* ---- issue #104: the polling thread and ShutDownRadioInterface ------------- *)

(* Put a blocking probe in gPollRig's slot, start the SHIPPED polling thread
  on it, and wait until its first call has blocked.  nil if it never did. *)
function TRadioDestructorTests.StartBlockedPoller(AInterruptReleases: Boolean): TBlockingPollProbe;
var
   handler: TProcessMsgRef;
begin
   handler := HandleMessage;
   gPollBlocked.ResetEvent;
   gPollRelease.ResetEvent;
   gPollProbeFreed := False;
   gPollerRunningAtFree := False;
   gPollRig.PollingStopRequested := False;

   Result := TBlockingPollProbe.CreateProbe(handler, AInterruptReleases);
   gPollRig.tFactoryObject := Result;
   gPollRig.StartPollingThread;

   if gPollBlocked.WaitFor(POLL_BLOCK_WAIT_MS) <> wrSignaled then
      begin
      Result := nil;
      end;
end;

(* BeginPolling clears PollingThreadRunning in its finally, as the thread
  leaves.  Polled, because on the leak path the slot's handle is already
  closed. *)
function TRadioDestructorTests.WaitPollerGone(AMs: Integer): Boolean;
var
   waited: Integer;
begin
   waited := 0;
   while gPollRig.PollingThreadRunning and (waited < AMs) do
      begin
      Sleep(20);
      Inc(waited, 20);
      end;
   Result := not gPollRig.PollingThreadRunning;
end;

procedure TRadioDestructorTests.Test_ShutDownFreesTheRadioOnlyAfterThePollerStops;
var
   probe: TBlockingPollProbe;
begin
   BeginTest('ShutDownRadioInterface closes the link, then frees the radio only once its poller has exited');

   probe := StartBlockedPoller(True);
   CheckTrue(probe <> nil, 'precondition: the polling thread is blocked in a call on the radio');
   if probe = nil then
      begin
      Exit;
      end;

   gPollRig.ShutDownRadioInterface;

   CheckTrue(gPollProbeFreed, 'the radio was freed');
   CheckFalse(gPollerRunningAtFree,
              'the radio was freed while its polling thread was still running -- the ' +
              'shutdown must interrupt the link and know the thread stopped before Free (issue #104)');
   CheckTrue(gPollRig.tFactoryObject = nil, 'the slot is empty');
   CheckFalse(gPollRig.PollingThreadRunning, 'the polling thread has exited');

   if not gPollProbeFreed then
      begin
      (* Leaked by a failing shutdown: let its thread go, then free it here. *)
      gPollRelease.SetEvent;
      if WaitPollerGone(POLL_RELEASE_MAX_MS) then
         begin
         probe.Free;
         end;
      end;
end;

procedure TRadioDestructorTests.Test_ShutDownLeaksARadioWhosePollerWillNotStop;
var
   probe: TBlockingPollProbe;
   gone: Boolean;
begin
   BeginTest('a poller that will not stop: the radio is LEAKED, not freed, and the thread leaves when released');

   (* Closing the link does NOT release this one -- the wedged-serial-write
     case.  The shutdown's bounded wait expires (about 6 s). *)
   probe := StartBlockedPoller(False);
   CheckTrue(probe <> nil, 'precondition: the polling thread is blocked in a call on the radio');
   if probe = nil then
      begin
      Exit;
      end;

   gPollRig.ShutDownRadioInterface;

   CheckFalse(gPollProbeFreed,
              'the radio was freed while its polling thread was still inside a call on it -- ' +
              'a timed-out shutdown must leak it instead (issue #104)');
   CheckTrue(gPollRig.tFactoryObject = nil, 'the slot let go of the radio');
   CheckFalse(gPollRig.PollingStopRequested, 'the stop request is withdrawn for the next radio');

   (* Now the wedged call returns.  With the stop request withdrawn, only the
     slot no longer holding this radio tells the thread to leave -- otherwise
     it would go on polling a leaked radio for ever. *)
   gPollRelease.SetEvent;
   gone := WaitPollerGone(10000);
   CheckTrue(gone,
             'the leaked radio''s polling thread kept running after its call returned -- ' +
             'pFactoryRadio must leave once the slot no longer holds its radio');

   if gone and (not gPollProbeFreed) then
      begin
      (* The test owns the leaked radio; nothing else will free it. *)
      probe.Free;
      CheckFalse(gPollerRunningAtFree, 'freed here only after the thread left');
      end;
end;

procedure TRadioDestructorTests.RunAllTests;
begin
   Test_FreeThroughBaseReferenceRunsTheDestructor;
   Test_EveryRegisteredRadioFreesCleanly;
   Test_EveryRegisteredRadioFreesAfterDisconnect;
   Test_ConnectedNetworkRadioWithReaderFrees;
   Test_EveryRegisteredRadio_StopAndUnkeyWithNoLink_LogNoError;
   Test_FreeRunningCIVSendThread;
   Test_FreeNeverStartedCIVSendThread;

   gPollBlocked := TEvent.Create(nil, True, False, '');
   gPollRelease := TEvent.Create(nil, True, False, '');
   try
      Test_ShutDownFreesTheRadioOnlyAfterThePollerStops;
      Test_ShutDownLeaksARadioWhosePollerWillNotStop;
   finally
      (* A thread still blocked holds gPollRelease: release it, and leak the
        two events rather than free them under it if it has not left. *)
      gPollRelease.SetEvent;
      if WaitPollerGone(POLL_RELEASE_MAX_MS) then
         begin
         FreeAndNil(gPollBlocked);
         FreeAndNil(gPollRelease);
         end;
   end;
end;

end.
