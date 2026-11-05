unit uTestIcomTxHistory;
{$I ..\..\src\tr4w.inc}

(*
  The Icom LAN transport's TX history: the last ICOM_BUFSIZE tracked packets
  of one socket, kept so the radio's retransmit requests can be answered.

  Pointer audit item 2.8 (2026-11-05). These tests were written against the
  history as it stood -- a TList of New'd records, moved unchanged into
  TIcomTxHistory -- and passed there before its internals changed.

  The last test is the one the old internals could fail: the history is
  written by whichever thread sends a tracked packet (the CI-V send queue,
  the timer thread, a reader thread answering a login) and read by the Indy
  listener thread answering a retransmit request. Nothing locked it, so an
  eviction could Dispose the entry a reader was copying from.

  No socket and no radio: the class owns no transport.
*)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uIcomNetworkTypes, uIcomNetworkTransport;

type
   TIcomTxHistoryTests = class(TTestCase)
   protected
      procedure Test_UnknownSeqIsEmpty;
      procedure Test_DataRoundTripsByteExact;
      procedure Test_DuplicateSeqAnswersTheNewest;
      procedure Test_OldestIsEvictedPastBufSize;
      procedure Test_ClearEmptiesIt;
      procedure Test_ReaderAndWriterThreads;
   public
      procedure RunAllTests; override;
   end;

implementation

(* A packet whose bytes say which sequence number it was stored under, so a
   reader can tell a right answer from a torn or freed one. Carries #0 and
   $FF on purpose: the history holds wire bytes, not text. *)
function PacketFor(Seq: Word): AnsiString;
var
   i: Integer;
begin
   SetLength(Result, 64);
   for i := 1 to Length(Result) do
      begin
      Result[i] := AnsiChar((Seq + i) and $FF);
      end;
   Result[1] := AnsiChar(Seq and $FF);
   Result[2] := AnsiChar(Seq shr 8);
   Result[3] := #0;
   Result[4] := #$FF;
end;

procedure TIcomTxHistoryTests.Test_UnknownSeqIsEmpty;
var
   h: TIcomTxHistory;
begin
   BeginTest('an unknown sequence number answers empty');
   h := TIcomTxHistory.Create;
   try
      CheckEquals('', string(h.Find(7)), 'a new history holds nothing');
      h.Add(1, PacketFor(1));
      CheckEquals('', string(h.Find(7)), 'a seq never stored answers empty');
      CheckEquals(1, h.Count, 'one entry stored');
   finally
      h.Free;
   end;
end;

procedure TIcomTxHistoryTests.Test_DataRoundTripsByteExact;
var
   h: TIcomTxHistory;
   p: AnsiString;
begin
   BeginTest('a stored packet comes back byte for byte, #0 and $FF included');
   h := TIcomTxHistory.Create;
   try
      h.Add(300, PacketFor(300));
      p := h.Find(300);
      CheckEquals(64, Length(p), 'length kept past the #0');
      Check(p = PacketFor(300), 'every byte kept');
   finally
      h.Free;
   end;
end;

procedure TIcomTxHistoryTests.Test_DuplicateSeqAnswersTheNewest;
var
   h: TIcomTxHistory;
begin
   (* A sequence counter wraps at $FFFF, so a seq can be stored twice; the
      radio is asking about the packet it saw last. *)
   BeginTest('a sequence number stored twice answers the newer packet');
   h := TIcomTxHistory.Create;
   try
      h.Add(5, 'old');
      h.Add(6, 'other');
      h.Add(5, 'new');
      CheckEquals('new', string(h.Find(5)), 'the newer packet for seq 5');
      CheckEquals('other', string(h.Find(6)), 'seq 6 untouched');
   finally
      h.Free;
   end;
end;

procedure TIcomTxHistoryTests.Test_OldestIsEvictedPastBufSize;
const
   EXTRA = 10;
var
   h: TIcomTxHistory;
   i: Integer;
begin
   BeginTest('past ICOM_BUFSIZE the oldest packets are forgotten, the rest kept');
   h := TIcomTxHistory.Create;
   try
      for i := 0 to ICOM_BUFSIZE + EXTRA - 1 do
         begin
         h.Add(Word(i), PacketFor(Word(i)));
         end;
      CheckEquals(ICOM_BUFSIZE, h.Count, 'capped at ICOM_BUFSIZE');
      for i := 0 to EXTRA - 1 do
         begin
         CheckEquals('', string(h.Find(Word(i))), Format('seq %d was evicted', [i]));
         end;
      Check(h.Find(EXTRA) = PacketFor(EXTRA), 'the oldest kept packet is still there');
      Check(h.Find(ICOM_BUFSIZE + EXTRA - 1) = PacketFor(ICOM_BUFSIZE + EXTRA - 1),
            'the newest packet is there');
   finally
      h.Free;
   end;
end;

procedure TIcomTxHistoryTests.Test_ClearEmptiesIt;
var
   h: TIcomTxHistory;
begin
   BeginTest('Clear forgets every packet and the history is usable after');
   h := TIcomTxHistory.Create;
   try
      h.Add(1, 'one');
      h.Add(2, 'two');
      h.Clear;
      CheckEquals(0, h.Count, 'empty after Clear');
      CheckEquals('', string(h.Find(1)), 'seq 1 gone');
      h.Add(1, 'again');
      CheckEquals('again', string(h.Find(1)), 'a packet stored after Clear is found');
      h.Clear;
      h.Clear;
      CheckEquals(0, h.Count, 'Clear twice is harmless');
   finally
      h.Free;
   end;
end;

type
   (* Stores packets as fast as it can, wrapping the sequence counter -- the
      sender's side. *)
   THistoryWriter = class(TThread)
   private
      FHistory: TIcomTxHistory;
      FAdds: Integer;
   protected
      procedure Execute; override;
   public
      constructor Create(aHistory: TIcomTxHistory; aAdds: Integer);
   end;

constructor THistoryWriter.Create(aHistory: TIcomTxHistory; aAdds: Integer);
begin
   FHistory := aHistory;
   FAdds := aAdds;
   inherited Create(False);
end;

procedure THistoryWriter.Execute;
var
   i: Integer;
begin
   for i := 0 to FAdds - 1 do
      begin
      FHistory.Add(Word(i), PacketFor(Word(i)));
      if (i mod 5000) = 4999 then
         begin
         FHistory.Clear;   // a sequence reset, as SendTrackedPacket does at seq 0
         end;
      end;
end;

procedure TIcomTxHistoryTests.Test_ReaderAndWriterThreads;
const
   ADDS = 200000;
var
   h: TIcomTxHistory;
   writer: THistoryWriter;
   seq: Word;
   p: AnsiString;
   reads, wrong: Integer;
begin
   (* The retransmit reader runs on an Indy listener thread while a sender
      stores and evicts. Every answer must be empty or exactly the packet
      stored under that seq -- never a torn or freed one. *)
   BeginTest('a reader thread beside a writer thread only ever sees whole packets');
   h := TIcomTxHistory.Create;
   try
      writer := THistoryWriter.Create(h, ADDS);
      try
         reads := 0;
         wrong := 0;
         seq := 0;
         while not writer.Finished do
            begin
            p := h.Find(seq);
            if (p <> '') and (p <> PacketFor(seq)) then
               begin
               Inc(wrong);
               end;
            Inc(reads);
            seq := Word(seq + 37);
            end;
         writer.WaitFor;
      finally
         writer.Free;
      end;
      CheckEquals(0, wrong, Format('torn or wrong answers in %d reads', [reads]));
      Check(reads > 0, 'the reader ran while the writer did');
   finally
      h.Free;
   end;
end;

procedure TIcomTxHistoryTests.RunAllTests;
begin
   Test_UnknownSeqIsEmpty;
   Test_DataRoundTripsByteExact;
   Test_DuplicateSeqAnswersTheNewest;
   Test_OldestIsEvictedPastBufSize;
   Test_ClearEmptiesIt;
   Test_ReaderAndWriterThreads;
end;

initialization
   RegisterSuite(TIcomTxHistoryTests.Create('IcomTxHistory'));

end.
