(*
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
 *)

(* THE WSJT-X CQ DECODE IS EVALUATED ON THE MAIN THREAD -- 2026-10-14.

  uWSJTX sets ThreadedEvent, so its read handler runs on Indy's listener thread.
  The CQ-decode branch used to call VisibleLog.CallIsADupe, DetermineIfNewMult
  and LOGEDIT.DoingAnyMults (which reaches ActiveContest, and that can free and
  rebuild the contest object) right there. These tests pin the hand-off:

    * A decode posted from another thread is QUEUED, not evaluated.
    * The evaluation itself refuses to run on any thread but the main one, so
      a future caller that bypasses the hand-off is stopped and logged.
    * A queued decode never evaluates after its server has stopped -- the
      lifetime half. The queue is drained with ProcessMessages, which runs the
      detached job and finds nothing to evaluate; nothing here frees a server
      with a decode still queued and then drains for the crash.

  WHAT THIS CANNOT SHOW: that the colourisation still works. That needs a live
  WSJT-X session -- docs/BENCH_QUEUE.md. *)
unit uTestWSJTXThreading;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TWSJTXThreadingTests = class(TTestCase)
   private
      procedure Drain;
      procedure Test_AListenerThreadDecodeIsQueuedNotEvaluated;
      procedure Test_EvaluationRefusesAnyThreadButTheMainOne;
      procedure Test_AQueuedDecodeIsDroppedOnceTheServerStops;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, Forms,
   uCrashLog,   (* InstallCrashLog -- records the MAIN THREAD, without which
                  OnMainThread is False everywhere *)
   uWSJTX;

type
   (* What the UDP listener does with a CQ decode, from a thread of our own. *)
   TDecodePosterThread = class(TThread)
   private
      FServer: TWSJTXServer;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TWSJTXServer);
   end;

   (* A caller that bypasses the hand-off and evaluates directly. *)
   TDirectEvaluatorThread = class(TThread)
   private
      FServer: TWSJTXServer;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TWSJTXServer);
   end;

constructor TDecodePosterThread.Create(aServer: TWSJTXServer);
begin
   FServer := aServer;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TDecodePosterThread.Execute;
begin
   FServer.PostCQDecode('K1ABC', 'FN42', 'WSJT-X', 14074000);
end;

constructor TDirectEvaluatorThread.Create(aServer: TWSJTXServer);
begin
   FServer := aServer;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TDirectEvaluatorThread.Execute;
begin
   FServer.EvaluateCQDecode('K1ABC', 'FN42', 'WSJT-X', 14074000);
end;

procedure TWSJTXThreadingTests.Drain;
begin
   if Application <> nil then
      begin
      Application.ProcessMessages;
      end;
end;

procedure TWSJTXThreadingTests.Test_AListenerThreadDecodeIsQueuedNotEvaluated;
var
   server: TWSJTXServer;
   poster: TDecodePosterThread;
begin
   InstallCrashLog;
   server := TWSJTXServer.Create;
   try
      poster := TDecodePosterThread.Create(server);
      try
         poster.WaitFor;
      finally
         poster.Free;
      end;

      CheckEquals(1, PendingCQDecodeCount,
                  'the decode is waiting for the main thread');
      CheckEquals(0, server.DecodesEvaluated,
                  'and the listener thread did NOT evaluate it -- the dupe '
                  + 'sheet and ActiveContest are the main thread''s');

      server.Stop;     (* detaches it, so the drain below evaluates nothing *)
      Drain;
      CheckEquals(0, PendingCQDecodeCount, 'the queue is empty again');
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.Test_EvaluationRefusesAnyThreadButTheMainOne;
var
   server: TWSJTXServer;
   evaluator: TDirectEvaluatorThread;
begin
   InstallCrashLog;
   server := TWSJTXServer.Create;
   try
      evaluator := TDirectEvaluatorThread.Create(server);
      try
         evaluator.WaitFor;
      finally
         evaluator.Free;
      end;

      CheckEquals(0, server.DecodesEvaluated,
                  'EvaluateCQDecode refuses to run off the main thread');
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.Test_AQueuedDecodeIsDroppedOnceTheServerStops;
var
   server: TWSJTXServer;
   poster: TDecodePosterThread;
begin
   InstallCrashLog;
   server := TWSJTXServer.Create;
   try
      poster := TDecodePosterThread.Create(server);
      try
         poster.WaitFor;
      finally
         poster.Free;
      end;
      CheckEquals(1, PendingCQDecodeCount, 'queued');

      (* Destroy stops the server, which detaches the job. The server is then
        gone and the queue is drained: the job is popped and DROPPED, not run
        against freed memory. *)
      server.Free;
      server := nil;
      Drain;

      CheckEquals(0, PendingCQDecodeCount,
                  'the orphaned decode was popped and discarded');
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.RunAllTests;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   Test_AListenerThreadDecodeIsQueuedNotEvaluated;
   Test_EvaluationRefusesAnyThreadButTheMainOne;
   Test_AQueuedDecodeIsDroppedOnceTheServerStops;
end;

end.
