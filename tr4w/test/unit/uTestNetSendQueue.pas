unit uTestNetSendQueue;
{$I ..\..\src\tr4w.inc}

(*
  THE MULTI-OP SEND QUEUE: the one writer that keeps the main thread off the
  network.  Everything here runs against a stub writer -- no socket.

  The defect it exists for: TNetClient.Send used to call Indy's IOHandler.Write
  on the caller's thread, with no write timeout, so a server that stopped
  reading froze logging.  Test_PostReturnsWhileTheWriterIsBlocked is written so
  the old synchronous send FAILS it: the stub writer blocks (for at most 5 s, so
  a regression fails rather than hangs) and the test asserts that Post returned
  long before that.
*)

interface

uses
   SysUtils,
   Classes,
   SyncObjs,
   uTR4WTestFramework,
   uNetSendQueue;

type
   TNetSendQueueTests = class(TTestCase)
   private
      procedure Test_PostReturnsWhileTheWriterIsBlocked;
      procedure Test_FifoOrderIsPreservedOverManyPackets;
      procedure Test_NoPacketIsDroppedWhileTheWriterIsBlocked;
      procedure Test_ShutdownWithABlockedWriterIsBounded;
      procedure Test_ShutdownDrainsWhatIsQueued;
      procedure Test_AFailedWriteIsLostAndReportedAndTheRestFollow;
      procedure Test_ASlowWriteIsCountedAndTheStallIsMeasured;
      procedure Test_PostAfterShutdownIsRefused;
      procedure Test_TheTagComesBackWithTheOutcome;
      procedure Test_TheClientNoLongerWritesOnTheCallersThread;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   (* A recording writer.  Block, when set, holds every write until the test
     releases it (or 5 s pass); FailKind makes writes of that kind fail. *)
   TStubWriter = class
   private
      FLock: TCriticalSection;
      FIds: TList;
   public
      Block: TEvent;
      Entered: TEvent;
      SleepMs: integer;
      FailOn: integer;      // packet number whose write returns False, or -1
      constructor Create;
      destructor Destroy; override;
      function Write(const aBytes: TBytes): boolean;
      function Count: integer;
      function IdAt(const aIndex: integer): integer;
   end;

var
   gLostKinds: TStringList;
   (* 'W<tag>' for a packet written, 'L<tag>' for one lost, in the order the
     writer thread reported them. *)
   gLostTags: TStringList;
   gLostLock: TCriticalSection;

constructor TStubWriter.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FIds := TList.Create;
   Block := nil;
   Entered := TEvent.Create(nil, True, False, '');
   FailOn := -1;
end;

destructor TStubWriter.Destroy;
begin
   Entered.Free;
   FIds.Free;
   FLock.Free;
   inherited Destroy;
end;

function TStubWriter.Write(const aBytes: TBytes): boolean;
var
   id: integer;
begin
   Entered.SetEvent;
   if Block <> nil then
      begin
      Block.WaitFor(5000);
      end;
   if SleepMs > 0 then
      begin
      Sleep(SleepMs);
      end;
   id := 0;
   if Length(aBytes) >= SizeOf(integer) then
      begin
      id := aBytes[0] or (aBytes[1] shl 8) or (aBytes[2] shl 16) or (aBytes[3] shl 24);
      end;
   Result := id <> FailOn;
   if Result then
      begin
      FLock.Enter;
      try
         FIds.Add(Pointer(PtrInt(id)));
      finally
         FLock.Leave;
      end;
      end;
end;

function TStubWriter.Count: integer;
begin
   FLock.Enter;
   try
      Result := FIds.Count;
   finally
      FLock.Leave;
   end;
end;

function TStubWriter.IdAt(const aIndex: integer): integer;
begin
   FLock.Enter;
   try
      Result := integer(PtrInt(FIds[aIndex]));
   finally
      FLock.Leave;
   end;
end;

procedure OnLostStub(const aKind: string; const aTag: Int64);
begin
   gLostLock.Enter;
   try
      gLostKinds.Add(aKind);
      gLostTags.Add('L' + IntToStr(aTag));
   finally
      gLostLock.Leave;
   end;
end;

procedure OnWrittenStub(const aKind: string; const aTag: Int64);
begin
   gLostLock.Enter;
   try
      gLostTags.Add('W' + IntToStr(aTag));
   finally
      gLostLock.Leave;
   end;
end;

function Packet(const aId: integer): TBytes;
begin
   SetLength(Result, SizeOf(integer));
   Result[0] := Byte(aId);
   Result[1] := Byte(aId shr 8);
   Result[2] := Byte(aId shr 16);
   Result[3] := Byte(aId shr 24);
end;

procedure TNetSendQueueTests.Test_PostReturnsWhileTheWriterIsBlocked;
var
   w: TStubWriter;
   q: TNetSendQueue;
   release: TEvent;
   started: QWord;
   elapsed: QWord;
   i: integer;
begin
   BeginTest('Post returns at once while the writer is blocked (the old synchronous send hangs here)');
   w := TStubWriter.Create;
   release := TEvent.Create(nil, True, False, '');
   w.Block := release;
   q := TNetSendQueue.Create(w.Write);
   try
      started := GetTickCount64;
      for i := 1 to 3 do
         begin
         CheckTrue(q.Post('QSOINFO', Packet(i)), 'accepted');
         end;
      elapsed := GetTickCount64 - started;
      Check(elapsed < 300,
            Format('three Posts took %d ms; they must not wait for the network', [Integer(elapsed)]));
      CheckTrue(w.Entered.WaitFor(2000) = wrSignaled, 'the writer did start on the first packet');
      CheckFalse(q.WaitIdle(0), 'the work is still pending behind the Post');
      CheckEquals(0, w.Count, 'nothing has been written yet');

      release.SetEvent;
      CheckTrue(q.WaitIdle(5000), 'and it does finish once the link recovers');
      CheckEquals(3, w.Count, 'all three arrived');
   finally
      release.SetEvent;
      q.Free;
      w.Free;
      release.Free;
   end;
end;

procedure TNetSendQueueTests.Test_FifoOrderIsPreservedOverManyPackets;
var
   w: TStubWriter;
   q: TNetSendQueue;
   i: integer;
   inOrder: boolean;
begin
   BeginTest('packets are written in exactly the order they were posted');
   w := TStubWriter.Create;
   q := TNetSendQueue.Create(w.Write);
   try
      for i := 1 to 2000 do
         begin
         q.Post('STATIONSTATUS', Packet(i));
         end;
      CheckTrue(q.WaitIdle(10000), 'drained');
      CheckEquals(2000, w.Count, 'every packet written');
      inOrder := True;
      for i := 1 to 2000 do
         begin
         if w.IdAt(i - 1) <> i then
            begin
            inOrder := False;
            end;
         end;
      CheckTrue(inOrder, 'the sequence 1..2000 is intact');
   finally
      q.Free;
      w.Free;
   end;
end;

procedure TNetSendQueueTests.Test_NoPacketIsDroppedWhileTheWriterIsBlocked;
var
   w: TStubWriter;
   q: TNetSendQueue;
   release: TEvent;
   i: integer;
   inOrder: boolean;
begin
   BeginTest('a stalled link drops nothing: 5000 queued packets all arrive, in order');
   w := TStubWriter.Create;
   release := TEvent.Create(nil, True, False, '');
   w.Block := release;
   q := TNetSendQueue.Create(w.Write);
   try
      for i := 1 to 5000 do
         begin
         q.Post('QSOINFO', Packet(i));
         end;
      CheckTrue(q.QueueDepth >= 4999, 'they are waiting, not discarded');
      release.SetEvent;
      CheckTrue(q.WaitIdle(15000), 'drained after recovery');
      CheckEquals(5000, w.Count, 'none dropped');
      CheckEquals(0, q.LostCount, 'none lost');
      inOrder := True;
      for i := 1 to 5000 do
         begin
         if w.IdAt(i - 1) <> i then
            begin
            inOrder := False;
            end;
         end;
      CheckTrue(inOrder, 'and in order');
   finally
      release.SetEvent;
      q.Free;
      w.Free;
      release.Free;
   end;
end;

procedure TNetSendQueueTests.Test_ShutdownWithABlockedWriterIsBounded;
var
   w: TStubWriter;
   q: TNetSendQueue;
   release: TEvent;
   started: QWord;
   elapsed: QWord;
   stopped: boolean;
begin
   BeginTest('Shutdown with the writer stuck in a write returns False within its bound');
   w := TStubWriter.Create;
   release := TEvent.Create(nil, True, False, '');
   w.Block := release;
   q := TNetSendQueue.Create(w.Write);
   try
      q.Post('QSOINFO', Packet(1));
      q.Post('QSOINFO', Packet(2));
      CheckTrue(w.Entered.WaitFor(2000) = wrSignaled, 'the writer is inside the write');

      started := GetTickCount64;
      stopped := q.Shutdown(200);
      elapsed := GetTickCount64 - started;
      CheckFalse(stopped, 'it reports the thread is stuck');
      Check(elapsed < 1500,
            Format('Shutdown took %d ms for a 200 ms bound plus the grace', [Integer(elapsed)]));

      release.SetEvent;
      CheckTrue(q.Shutdown(100), 'once the write returns, a second Shutdown completes');
   finally
      release.SetEvent;
      q.Free;
      w.Free;
      release.Free;
   end;
end;

procedure TNetSendQueueTests.Test_ShutdownDrainsWhatIsQueued;
var
   w: TStubWriter;
   q: TNetSendQueue;
   i: integer;
begin
   BeginTest('Shutdown lets a healthy queue go out before it stops');
   w := TStubWriter.Create;
   w.SleepMs := 2;
   q := TNetSendQueue.Create(w.Write);
   try
      for i := 1 to 50 do
         begin
         q.Post('TIMESYNC', Packet(i));
         end;
      CheckTrue(q.Shutdown(5000), 'stopped');
      CheckEquals(50, w.Count, 'everything posted was written first');
   finally
      q.Free;
      w.Free;
   end;
end;

procedure TNetSendQueueTests.Test_AFailedWriteIsLostAndReportedAndTheRestFollow;
var
   w: TStubWriter;
   q: TNetSendQueue;
begin
   BeginTest('a packet whose write fails is counted lost and reported by kind; later packets still go');
   gLostKinds.Clear;
   w := TStubWriter.Create;
   w.FailOn := 2;
   q := TNetSendQueue.Create(w.Write);
   try
      q.OnLost := OnLostStub;
      q.Post('STATIONSTATUS', Packet(1));
      q.Post('QSOINFO', Packet(2));
      q.Post('STATIONSTATUS', Packet(3));
      CheckTrue(q.WaitIdle(5000), 'drained');
      CheckEquals(2, w.Count, 'packets 1 and 3 were written');
      CheckEquals(1, w.IdAt(0), 'first');
      CheckEquals(3, w.IdAt(1), 'then the one after the failure');
      CheckEquals(1, q.LostCount, 'one lost');
      CheckEquals('QSOINFO', gLostKinds.CommaText, 'and it is named');
   finally
      q.Free;
      w.Free;
   end;
end;

procedure TNetSendQueueTests.Test_ASlowWriteIsCountedAndTheStallIsMeasured;
var
   w: TStubWriter;
   q: TNetSendQueue;
   release: TEvent;
   stalled: QWord;
begin
   BeginTest('a write over SlowMs is counted; WriteStalledMs grows while one is in flight');
   w := TStubWriter.Create;
   release := TEvent.Create(nil, True, False, '');
   w.Block := release;
   q := TNetSendQueue.Create(w.Write);
   try
      q.SlowMs := 100;
      CheckEquals(0, Integer(q.WriteStalledMs), 'no write in flight');
      q.Post('INTERCOM', Packet(1));
      CheckTrue(w.Entered.WaitFor(2000) = wrSignaled, 'writer inside the write');
      Sleep(200);
      stalled := q.WriteStalledMs;
      Check(stalled >= 150, Format('stalled for %d ms', [Integer(stalled)]));
      release.SetEvent;
      CheckTrue(q.WaitIdle(5000), 'done');
      CheckEquals(1, q.SlowCount, 'counted as slow');
      CheckEquals(0, Integer(q.WriteStalledMs), 'nothing in flight again');
   finally
      release.SetEvent;
      q.Free;
      w.Free;
      release.Free;
   end;
end;

procedure TNetSendQueueTests.Test_PostAfterShutdownIsRefused;
var
   w: TStubWriter;
   q: TNetSendQueue;
begin
   BeginTest('Post after Shutdown is refused, not queued for a thread that is gone');
   w := TStubWriter.Create;
   q := TNetSendQueue.Create(w.Write);
   try
      CheckTrue(q.Post('QSOINFO', Packet(1)), 'accepted before');
      CheckTrue(q.Shutdown(2000), 'stopped');
      CheckFalse(q.Post('QSOINFO', Packet(2)), 'refused after');
      CheckEquals(1, w.Count, 'only the first was written');
   finally
      q.Free;
      w.Free;
   end;
end;

(* THE TAG A POSTER ATTACHES COMES BACK WITH THE OUTCOME (Phase 1, C5): written
  or lost, in the order the packets were written, and a packet posted with no
  tag comes back as 0. This is how a QSO's row is found when its write
  finishes. *)
procedure TNetSendQueueTests.Test_TheTagComesBackWithTheOutcome;
var
   w: TStubWriter;
   q: TNetSendQueue;
begin
   BeginTest('a packet''s tag comes back through OnWritten or OnLost');
   gLostTags.Clear;
   w := TStubWriter.Create;
   w.FailOn := 2;
   q := TNetSendQueue.Create(w.Write);
   try
      q.OnLost := OnLostStub;
      q.OnWritten := OnWrittenStub;
      q.Post('QSOINFO', Packet(1), 111);
      q.Post('EDITEDQSO', Packet(2), 222);
      q.Post('QSOINFO', Packet(3), 333);
      q.Post('STATIONSTATUS', Packet(4));
      CheckTrue(q.WaitIdle(5000), 'drained');
      (* WaitIdle fires when the last write returns; its OnWritten runs just
        after, on the same thread. *)
      Sleep(100);
      CheckEquals('W111,L222,W333,W0', gLostTags.CommaText,
                  'each outcome carries its own tag, in order');
   finally
      q.Free;
      w.Free;
   end;
end;

(* A SOURCE READ.  The behavioural tests above prove the queue; this proves the
  client USES it: after the handshake the only IOHandler.Write is in
  WriteToSocket, and Send contains none.  Without it someone could put the
  synchronous write back and every test here would stay green. *)
procedure TNetSendQueueTests.Test_TheClientNoLongerWritesOnTheCallersThread;
var
   src: TStringList;
   path, text, sendBody: string;
   p, n: integer;
begin
   BeginTest('uNetClient: Send posts to the queue and does not touch IOHandler');
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                          PathDelim + 'src' + PathDelim + 'uNetClient.pas');
   CheckTrue(FileExists(path), 'uNetClient.pas is beside the tests: ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;
   src := TStringList.Create;
   try
      src.LoadFromFile(AnsiString(path));
      text := UpperCase(src.Text);
      p := Pos('FUNCTION TNETCLIENT.SEND(', text);
      CheckTrue(p > 0, 'Send is there');
      (* Send is the last method in the unit, so its body runs to the end of
        the file. *)
      sendBody := Copy(text, p, Length(text));
      CheckEquals(0, Pos('IOHANDLER', sendBody), 'Send does not write to the socket');
      CheckTrue(Pos('FSENDQUEUE.POST', sendBody) > 0, 'Send posts to the queue');

      n := 0;
      p := Pos('IOHANDLER.WRITE(', text);
      while p > 0 do
         begin
         Inc(n);
         Delete(text, 1, p + 15);
         p := Pos('IOHANDLER.WRITE(', text);
         end;
      CheckEquals(2, n, 'two writes: the handshake password and WriteToSocket');
   finally
      src.Free;
   end;
end;

procedure TNetSendQueueTests.RunAllTests;
begin
   gLostKinds := TStringList.Create;
   gLostTags := TStringList.Create;
   gLostLock := TCriticalSection.Create;
   try
      Test_PostReturnsWhileTheWriterIsBlocked;
      Test_FifoOrderIsPreservedOverManyPackets;
      Test_NoPacketIsDroppedWhileTheWriterIsBlocked;
      Test_ShutdownWithABlockedWriterIsBounded;
      Test_ShutdownDrainsWhatIsQueued;
      Test_AFailedWriteIsLostAndReportedAndTheRestFollow;
      Test_ASlowWriteIsCountedAndTheStallIsMeasured;
      Test_PostAfterShutdownIsRefused;
      Test_TheTagComesBackWithTheOutcome;
      Test_TheClientNoLongerWritesOnTheCallersThread;
   finally
      FreeAndNil(gLostLock);
      FreeAndNil(gLostTags);
      FreeAndNil(gLostKinds);
   end;
end;

end.
