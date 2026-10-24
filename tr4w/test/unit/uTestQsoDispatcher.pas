unit uTestQsoDispatcher;
{$I ..\..\src\tr4w.inc}

(*
  THE QSO DISPATCHER: the one thread that delivers to every program outside
  TR4W.  Everything here runs against recording stub sinks -- no socket.

  The defect it exists for is measured, not hypothetical: on 2026-10-24, in a
  contest, two QSOs froze the main thread for 2702 ms and 2680 ms because the
  UDP broadcast resolved a host name on the thread that had pressed Enter.
  Before the dispatcher existed, the equivalent of Test_PostReturnsWhileASinkBlocks
  failed with "Send returned after 1500 ms".
*)

interface

uses
   SysUtils,
   Classes,
   SyncObjs,
   uTR4WTestFramework,
   uUDPBroadcastConfig,
   uQsoDispatcher;

type
   TQsoDispatcherTests = class(TTestCase)
   private
      procedure Test_PostReturnsWhileASinkBlocks;
      procedure Test_EverySinkReceivesEveryMessageInOrder;
      procedure Test_ADisabledSinkReceivesNothingAndASwapAppliesToTheNextMessage;
      procedure Test_OneSinkRaisingDoesNotStopTheOthers;
      procedure Test_TheMessageCarriesTheValuesFromPostTime;
      procedure Test_TheQueueIsBoundedAndDropsAreReportedOncePerEpisode;
      procedure Test_AQsoMessageOutlivesDroppableOnes;
      procedure Test_ThousandsOfQsoMessagesAreNeverDropped;
      procedure Test_ShutdownWithABlockedSinkIsBounded;
      procedure Test_ShutdownDeliversWhatIsQueued;
      procedure Test_ASlowSinkIsCounted;
      procedure Test_PostAfterShutdownIsDiscarded;
      procedure Test_SynchronousModeDeliversInline;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   (* A recording sink.  Its behaviour is set before the first Post and its
     Enabled flag is flipped from the test thread, so Enabled is under a lock
     exactly as a real sink's configuration is. *)
   TStubSink = class(TQsoSink)
   private
      FName: string;
      FLock: TCriticalSection;
      FEnabled: boolean;
   public
      SleepMs: integer;
      Raises: boolean;
      Block: TEvent;      // when set, Deliver waits for it
      Entered: TEvent;    // signalled when Deliver starts
      constructor Create(const aName: string);
      destructor Destroy; override;
      function Name: string; override;
      function Wants(const aMessage: TQsoMessage): boolean; override;
      procedure Deliver(const aMessage: TQsoMessage); override;
      procedure SetEnabled(const aValue: boolean);
   end;

var
   gLog: TStringList;
   gLogLock: TCriticalSection;

constructor TStubSink.Create(const aName: string);
begin
   inherited Create;
   FName := aName;
   FLock := TCriticalSection.Create;
   FEnabled := True;
   Block := nil;
   Entered := TEvent.Create(nil, True, False, '');
end;

destructor TStubSink.Destroy;
begin
   Entered.Free;
   FLock.Free;
   inherited Destroy;
end;

function TStubSink.Name: string;
begin
   Result := FName;
end;

procedure TStubSink.SetEnabled(const aValue: boolean);
begin
   FLock.Enter;
   try
      FEnabled := aValue;
   finally
      FLock.Leave;
   end;
end;

function TStubSink.Wants(const aMessage: TQsoMessage): boolean;
begin
   FLock.Enter;
   try
      Result := FEnabled;
   finally
      FLock.Leave;
   end;
end;

procedure TStubSink.Deliver(const aMessage: TQsoMessage);
begin
   Entered.SetEvent;
   if Block <> nil then
      begin
      Block.WaitFor(High(Cardinal));
      end;
   if SleepMs > 0 then
      begin
      Sleep(SleepMs);
      end;
   if Raises then
      begin
      raise Exception.Create('stub sink failure');
      end;
   gLogLock.Enter;
   try
      gLog.Add(FName + ':' + aMessage.Description + ':' + string(aMessage.HamBody));
   finally
      gLogLock.Leave;
   end;
end;

function Logged: string;
begin
   gLogLock.Enter;
   try
      Result := gLog.CommaText;
   finally
      gLogLock.Leave;
   end;
end;

procedure ResetLog;
begin
   gLogLock.Enter;
   try
      gLog.Clear;
   finally
      gLogLock.Leave;
   end;
end;

function NewMessage(const aName: string): TQsoMessage;
begin
   Result := TQsoMessage.Create(qmNew, aName);
end;

procedure TQsoDispatcherTests.Test_PostReturnsWhileASinkBlocks;
var
   d: TQsoDispatcher;
   s: TStubSink;
   started: QWord;
   elapsed: QWord;
begin
   BeginTest('Post returns at once while a sink is blocked for 1.5 s');
   d := TQsoDispatcher.Create;
   s := TStubSink.Create('slow');
   try
      s.SleepMs := 1500;       // the host-name stall of 2026-10-24
      d.AddSink(s);
      ResetLog;

      started := GetTickCount64;
      d.Post(NewMessage('CR6K'));
      d.Post(NewMessage('V47T'));
      elapsed := GetTickCount64 - started;
      Check(elapsed < 300,
            Format('two Posts took %d ms; they must not wait for the network', [elapsed]));
      CheckFalse(d.WaitIdle(0), 'the work is still going on behind the Post');
      CheckTrue(d.WaitIdle(8000), 'and it does finish');
      CheckEquals('slow:CR6K:,slow:V47T:', Logged, 'both messages, in order');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_EverySinkReceivesEveryMessageInOrder;
var
   d: TQsoDispatcher;
   expected: string;
   i: integer;
begin
   BeginTest('every enabled sink receives every message, sink order within a message');
   d := TQsoDispatcher.Create;
   try
      d.AddSink(TStubSink.Create('A'));
      d.AddSink(TStubSink.Create('B'));
      ResetLog;
      expected := '';
      for i := 0 to 19 do
         begin
         d.Post(NewMessage(Format('m%.2d', [i])));
         if expected <> '' then
            begin
            expected := expected + ',';
            end;
         expected := expected + Format('A:m%.2d:,B:m%.2d:', [i, i]);
         end;
      CheckTrue(d.WaitIdle(5000), 'delivered');
      CheckEquals(expected, Logged, 'A then B for each message, messages in posting order');
      CheckEquals(40, d.Delivered, 'forty deliveries');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_ADisabledSinkReceivesNothingAndASwapAppliesToTheNextMessage;
var
   d: TQsoDispatcher;
   b: TStubSink;
begin
   // The configuration swap is the sink's own (a Preferences change); the
   // dispatcher reads it per message, so it lands on the next one.
   BeginTest('a disabled sink gets nothing; enabling it applies to the next message');
   d := TQsoDispatcher.Create;
   try
      d.AddSink(TStubSink.Create('A'));
      b := TStubSink.Create('B');
      b.SetEnabled(False);
      d.AddSink(b);
      ResetLog;

      d.Post(NewMessage('m0'));
      CheckTrue(d.WaitIdle(3000), 'm0 delivered');
      CheckEquals('A:m0:', Logged, 'B was off for m0');

      b.SetEnabled(True);
      d.Post(NewMessage('m1'));
      CheckTrue(d.WaitIdle(3000), 'm1 delivered');
      CheckEquals('A:m0:,A:m1:,B:m1:', Logged, 'B received m1, and only m1');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_OneSinkRaisingDoesNotStopTheOthers;
var
   d: TQsoDispatcher;
   a: TStubSink;
begin
   BeginTest('a sink that raises is counted and the next sink still receives the message');
   d := TQsoDispatcher.Create;
   try
      a := TStubSink.Create('A');
      a.Raises := True;
      d.AddSink(a);
      d.AddSink(TStubSink.Create('B'));
      ResetLog;

      d.Post(NewMessage('m0'));
      d.Post(NewMessage('m1'));
      CheckTrue(d.WaitIdle(3000), 'delivered');
      CheckEquals('B:m0:,B:m1:', Logged, 'B got both despite A failing both');
      CheckEquals(2, d.Failures, 'and the two failures are counted');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_TheMessageCarriesTheValuesFromPostTime;
var
   d: TQsoDispatcher;
   s: TStubSink;
   gate: TEvent;
   liveFact: string;
   m: TQsoMessage;
begin
   // The builder reads live state (MY CALL, the radio, the contest) and stores
   // the ANSWER in the message.  Delivery happens later, after the operator may
   // have changed the setting; the old value is the one that was logged.
   BeginTest('the message holds the values from Post time, not from delivery time');
   d := TQsoDispatcher.Create;
   gate := TEvent.Create(nil, True, False, '');
   s := TStubSink.Create('A');
   try
      s.Block := gate;
      d.AddSink(s);
      ResetLog;

      d.Post(NewMessage('first'));
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'the sink is busy with the first message');

      liveFact := 'W1AW';
      m := NewMessage('second');
      m.HamBody := AnsiString(liveFact);          // captured at log time
      d.Post(m);
      liveFact := 'N0CALL';                        // the setting changes afterwards

      gate.SetEvent;
      CheckTrue(d.WaitIdle(3000), 'delivered');
      CheckEquals('A:first:,A:second:W1AW', Logged,
                  'the value that arrived is the one captured when it was posted');
      CheckEquals('N0CALL', liveFact, 'while the live value had moved on');
   finally
      gate.SetEvent;
      d.Free;
      gate.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_TheQueueIsBoundedAndDropsAreReportedOncePerEpisode;
var
   d: TQsoDispatcher;
   s: TStubSink;
   gate: TEvent;
   i: integer;
begin
   BeginTest('the queue is bounded; drops are counted and an episode is reported once');
   d := TQsoDispatcher.Create;
   gate := TEvent.Create(nil, True, False, '');
   s := TStubSink.Create('A');
   try
      s.Block := gate;
      d.AddSink(s);
      d.QueueLimit := 3;

      d.PostUDP(usRadio, 'x', 'busy');
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'the sink is stuck on the first packet');

      for i := 1 to 10 do
         begin
         d.PostUDP(usRadio, 'x', Format('p%d', [i]));
         end;
      CheckEquals(3, d.QueueDepth, 'the queue stopped at its limit');
      CheckEquals(7, d.Dropped, 'seven of the ten were dropped');
      CheckEquals(1, d.DropEpisodes, 'and that is ONE episode, not seven reports');

      gate.SetEvent;
      CheckTrue(d.WaitIdle(3000), 'the survivors are delivered');
      CheckEquals(1, d.DropEpisodes, 'recovery does not add an episode');

      // A second overflow after the queue emptied is a new episode.
      gate.ResetEvent;
      s.Entered.ResetEvent;
      d.PostUDP(usRadio, 'x', 'busy2');
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'stuck again');
      for i := 1 to 5 do
         begin
         d.PostUDP(usRadio, 'x', Format('q%d', [i]));
         end;
      CheckEquals(2, d.DropEpisodes, 'a later overflow is a second episode');
   finally
      gate.SetEvent;
      d.Free;
      gate.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_AQsoMessageOutlivesDroppableOnes;
var
   d: TQsoDispatcher;
   s: TStubSink;
   gate: TEvent;
begin
   // A QSO is never what is sacrificed while something stale is available.
   BeginTest('when full, the oldest DROPPABLE message goes and the QSO stays');
   d := TQsoDispatcher.Create;
   gate := TEvent.Create(nil, True, False, '');
   s := TStubSink.Create('A');
   try
      s.Block := gate;
      d.AddSink(s);
      d.QueueLimit := 3;      // the limit counts droppable messages only
      ResetLog;

      d.PostUDP(usRadio, 'x', 'busy');
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'stuck');
      d.Post(NewMessage('QSO'));
      d.PostUDP(usRadio, 'x', 'd1');
      d.PostUDP(usRadio, 'x', 'd2');
      d.PostUDP(usRadio, 'x', 'd3');
      d.PostUDP(usRadio, 'x', 'd4');          // queue was full: d1 goes, not QSO

      gate.SetEvent;
      CheckTrue(d.WaitIdle(3000), 'delivered');
      CheckEquals('A:busy:,A:QSO:,A:d2:,A:d3:,A:d4:', Logged,
                  'the QSO survived, d1 was the victim, order held');
   finally
      gate.SetEvent;
      d.Free;
      gate.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_ThousandsOfQsoMessagesAreNeverDropped;
var
   d: TQsoDispatcher;
   s: TStubSink;
   gate: TEvent;
   i: integer;
   expected: TStringList;
   actual: TStringList;
begin
   // "Resend the whole log to UDP" and the HamScore resync post one message per
   // QSO.  The bound must not touch them, however small QueueLimit is.
   BeginTest('5000 QSO messages behind a blocked sink all arrive, in order, none dropped');
   d := TQsoDispatcher.Create;
   gate := TEvent.Create(nil, True, False, '');
   s := TStubSink.Create('A');
   expected := TStringList.Create;
   actual := TStringList.Create;
   try
      s.Block := gate;
      d.AddSink(s);
      d.QueueLimit := 3;
      ResetLog;

      d.Post(NewMessage('q00000'));
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'the sink is blocked on the first');
      expected.Add('A:q00000:');
      for i := 1 to 4999 do
         begin
         d.Post(NewMessage(Format('q%.5d', [i])));
         expected.Add(Format('A:q%.5d:', [i]));
         end;
      CheckEquals(4999, d.QueueDepth, 'every one is queued; Post never refused or blocked');
      CheckEquals(0, d.Dropped, 'none dropped');

      gate.SetEvent;
      CheckTrue(d.WaitIdle(30000), 'all delivered');
      gLogLock.Enter;
      try
         actual.Assign(gLog);
      finally
         gLogLock.Leave;
      end;
      CheckEquals(5000, actual.Count, 'all 5000 arrived');
      CheckTrue(actual.Text = expected.Text, 'in posting order');
      CheckEquals(0, d.DropEpisodes, 'and no drop episode was ever opened');
   finally
      gate.SetEvent;
      actual.Free;
      expected.Free;
      d.Free;
      gate.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_ShutdownWithABlockedSinkIsBounded;
var
   d: TQsoDispatcher;
   s: TStubSink;
   gate: TEvent;
   started: QWord;
   elapsed: QWord;
begin
   BeginTest('Shutdown returns False within its bound when a sink is blocked');
   d := TQsoDispatcher.Create;
   gate := TEvent.Create(nil, True, False, '');
   s := TStubSink.Create('A');
   try
      s.Block := gate;
      d.AddSink(s);
      d.Post(NewMessage('stuck'));
      CheckTrue(s.Entered.WaitFor(3000) = wrSignaled, 'the sink is blocked');

      started := GetTickCount64;
      CheckFalse(d.Shutdown(200), 'a thread stuck in a sink is reported, not waited for');
      elapsed := GetTickCount64 - started;
      Check(elapsed < 1500, Format('Shutdown took %d ms for a 200 ms bound', [elapsed]));

      gate.SetEvent;
      CheckTrue(d.Shutdown(1000), 'once the sink lets go the thread stops');
   finally
      gate.SetEvent;
      d.Free;
      gate.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_ShutdownDeliversWhatIsQueued;
var
   d: TQsoDispatcher;
   s: TStubSink;
   i: integer;
begin
   BeginTest('Shutdown drains the queue before it stops the thread');
   d := TQsoDispatcher.Create;
   s := TStubSink.Create('A');
   try
      s.SleepMs := 20;
      d.AddSink(s);
      ResetLog;
      for i := 1 to 5 do
         begin
         d.Post(NewMessage(Format('m%d', [i])));
         end;
      CheckTrue(d.Shutdown(3000), 'stopped');
      CheckEquals('A:m1:,A:m2:,A:m3:,A:m4:,A:m5:', Logged, 'all five went out first');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_ASlowSinkIsCounted;
var
   d: TQsoDispatcher;
   s: TStubSink;
begin
   BeginTest('a sink slower than SlowSinkMs is counted (and logged by name)');
   d := TQsoDispatcher.Create;
   s := TStubSink.Create('slow');
   try
      s.SleepMs := 80;
      d.AddSink(s);
      d.SlowSinkMs := 20;
      d.Post(NewMessage('m0'));
      CheckTrue(d.WaitIdle(3000), 'delivered');
      CheckEquals(1, d.SlowDeliveries, 'the 80 ms delivery is over the 20 ms threshold');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_PostAfterShutdownIsDiscarded;
var
   d: TQsoDispatcher;
begin
   BeginTest('a message posted after Shutdown is discarded, not queued for ever');
   d := TQsoDispatcher.Create;
   try
      d.AddSink(TStubSink.Create('A'));
      ResetLog;
      CheckTrue(d.Shutdown(500), 'stopped');
      d.Post(NewMessage('late'));
      CheckEquals(0, d.QueueDepth, 'nothing queued');
      CheckEquals('', Logged, 'and nothing delivered');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.Test_SynchronousModeDeliversInline;
var
   d: TQsoDispatcher;
begin
   BeginTest('Synchronous mode delivers on the calling thread, before Post returns');
   d := TQsoDispatcher.Create;
   try
      d.AddSink(TStubSink.Create('A'));
      d.Synchronous := True;
      ResetLog;
      d.Post(NewMessage('m0'));
      CheckEquals('A:m0:', Logged, 'already delivered');
   finally
      d.Free;
   end;
end;

procedure TQsoDispatcherTests.RunAllTests;
begin
   gLog := TStringList.Create;
   gLogLock := TCriticalSection.Create;
   try
      Test_PostReturnsWhileASinkBlocks;
      Test_EverySinkReceivesEveryMessageInOrder;
      Test_ADisabledSinkReceivesNothingAndASwapAppliesToTheNextMessage;
      Test_OneSinkRaisingDoesNotStopTheOthers;
      Test_TheMessageCarriesTheValuesFromPostTime;
      Test_TheQueueIsBoundedAndDropsAreReportedOncePerEpisode;
      Test_AQsoMessageOutlivesDroppableOnes;
      Test_ThousandsOfQsoMessagesAreNeverDropped;
      Test_ShutdownWithABlockedSinkIsBounded;
      Test_ShutdownDeliversWhatIsQueued;
      Test_ASlowSinkIsCounted;
      Test_PostAfterShutdownIsDiscarded;
      Test_SynchronousModeDeliversInline;
   finally
      FreeAndNil(gLogLock);
      FreeAndNil(gLog);
   end;
end;

end.
