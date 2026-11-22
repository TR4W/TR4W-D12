program bench_post_cost;

(* WHAT DOES POSTING A QSO TO THE NETWORK COST THE MAIN THREAD?
  (issue 300 / 341, NY4I 2026-11-22: "multi-network should not add any time
  whatsoever to the qso log process. I think that is the way it is today but
  wanted to check.")

  Today, after the commit, MainUnit.AddRecordToLogAndSendToNetwork calls
  uNet.SendRecordToServer -> PostQsoPacket -> SendToNet -> NetClient.Send ->
  TNetSendQueue.Post, ALL ON THE CALLER'S (MAIN) THREAD. The socket write is
  on the queue's writer thread. This bench times what the caller does:

    - copy the 376-byte record into the 384-byte packet global (PostQsoPacket)
    - SetLength + Move into a TBytes                              (TNetClient.Send)
    - TNetSendQueue.Post: allocate the item, copy the bytes AGAIN, take the
      lock, append, set the events                                (the REAL class)

  NOT TIMED, and said so: OutboundPacketIsWellFormed (a table lookup),
  NetPacketKind (returns a constant) and NetIsConnected (two reads). They are a
  few nanoseconds each and live in uNet, which drags in the whole program.

  THREE LINKS, because the answer that matters is "does a SLOW link slow the
  caller":
    fast    the writer returns at once
    slow    the writer takes 5 ms a packet (a poor link)
    stalled the writer takes 250 ms a packet (the SlowMs threshold; the queue
            grows, the caller must not notice)
  Each is run PACED (one packet every 3 ms, so the writer keeps up where it
  can) and as a BURST (back to back, the worst case for the queue's lock).
  A station's real rate is about one QSO every 3 SECONDS.

  Usage:  bench_post_cost [iterations]     default 3000 *)

{$I ..\..\src\tr4w.inc}

uses
   SysUtils,
   Classes,
   Math,
{$IFDEF WINDOWS}
   Windows,   (* QueryPerformanceCounter *)
{$ENDIF}
   Log4D,
   uNetSendQueue;

const
   PACKET_SIZE = 384;   (* TNetQSOInformation: the 376-byte record + 8 *)

type
   TFakeLink = class(TObject)
   public
      DelayMs: integer;
      function Write(const aBytes: TBytes): boolean;
   end;

var
   gFreq: Int64 = 0;
   gSource: array[0..PACKET_SIZE - 1] of byte;   (* the record being logged *)
   gPacket: array[0..PACKET_SIZE - 1] of byte;   (* uNet.NetQSOInfoToSend *)

function TFakeLink.Write(const aBytes: TBytes): boolean;
begin
   if DelayMs > 0 then
      begin
      Sleep(DelayMs);
      end;
   Result := True;
end;

function Now_: Int64;
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(Result);
{$ELSE}
   Result := Int64(GetTickCount64);
{$ENDIF}
end;

function Micros(aFrom, aTo: Int64): double;
begin
{$IFDEF WINDOWS}
   Result := (aTo - aFrom) * 1000000.0 / gFreq;
{$ELSE}
   Result := (aTo - aFrom) * 1000.0;
{$ENDIF}
end;

(* The caller-thread work, as PostQsoPacket + TNetClient.Send do it. *)
function PostOne(aQueue: TNetSendQueue; aTag: Int64): boolean;
var
   bytes: TBytes;
begin
   Move(gSource[0], gPacket[0], PACKET_SIZE);
   SetLength(bytes, PACKET_SIZE);
   Move(gPacket[0], bytes[0], PACKET_SIZE);
   Result := aQueue.Post('QSOINFO', bytes, aTag);
end;

procedure Report(const aName: string; var aMicros: array of double; aCount: integer);
var
   i, j, k: integer;
   t: double;
   function P(aFrac: double): double;
   var
      k: integer;
   begin
      k := Ceil(aFrac * aCount) - 1;
      if k < 0 then
         begin
         k := 0;
         end;
      if k > aCount - 1 then
         begin
         k := aCount - 1;
         end;
      Result := aMicros[k];
   end;
begin
   (* a shell sort: thousands of samples, and no dependency for one sort *)
   j := aCount div 2;
   while j > 0 do
      begin
      for i := j to aCount - 1 do
         begin
         t := aMicros[i];
         k := i;
         while (k >= j) and (aMicros[k - j] > t) do
            begin
            aMicros[k] := aMicros[k - j];
            k := k - j;
            end;
         aMicros[k] := t;
         end;
      j := j div 2;
      end;
   WriteLn(Format('%-28s n=%5d  p50 %7.2f  p95 %7.2f  p99 %7.2f  max %8.2f  (us per Post)',
      [aName, aCount, P(0.50), P(0.95), P(0.99), aMicros[aCount - 1]]));
end;

procedure RunCase(const aName: string; aDelayMs: integer; aPaced: boolean; aIterations: integer);
var
   link: TFakeLink;
   queue: TNetSendQueue;
   times: array of double;
   i: integer;
   t0, t1: Int64;
begin
   link := TFakeLink.Create;
   link.DelayMs := aDelayMs;
   queue := TNetSendQueue.Create(link.Write);
   SetLength(times, aIterations);
   try
      (* warm-up: the first Post starts the worker thread *)
      for i := 1 to 50 do
         begin
         PostOne(queue, i);
         end;
      queue.WaitIdle(60000);
      for i := 0 to aIterations - 1 do
         begin
         t0 := Now_;
         PostOne(queue, i);
         t1 := Now_;
         times[i] := Micros(t0, t1);
         if aPaced then
            begin
            Sleep(3);
            end;
         end;
      Report(aName, times, aIterations);
      WriteLn(Format('%-28s queued at the end: %d (posted %d, written %d)',
         ['', queue.QueueDepth, queue.Posted, queue.Written]));
   finally
      queue.Shutdown(5000);
      queue.Free;
      link.Free;
   end;
end;

var
   iterations, i: integer;
begin
{$IFDEF WINDOWS}
   QueryPerformanceFrequency(gFreq);
{$ENDIF}
   iterations := 3000;
   if ParamCount >= 1 then
      begin
      iterations := StrToIntDef(ParamStr(1), 3000);
      end;
   for i := 0 to PACKET_SIZE - 1 do
      begin
      gSource[i] := i and $FF;
      end;

   WriteLn('bench_post_cost: ', iterations, ' posts per case; the real TNetSendQueue');
   WriteLn;
   RunCase('fast link, paced', 0, True, iterations);
   RunCase('fast link, burst', 0, False, iterations);
   RunCase('slow link (5 ms), paced', 5, True, iterations);
   RunCase('slow link (5 ms), burst', 5, False, iterations);
   RunCase('stalled (250 ms), paced', 250, True, 300);
   RunCase('stalled (250 ms), burst', 250, False, 300);
end.
