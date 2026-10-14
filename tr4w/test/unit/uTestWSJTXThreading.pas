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

(* WHAT THE WSJT-X UDP LISTENER MAY DO ITSELF -- 2026-10-14.

  uWSJTX sets ThreadedEvent, so its read handler runs on Indy's listener thread.
  It used to evaluate CQ decodes, status messages, clears and LOGGED QSOs right
  there: the dupe sheet, ActiveContest, the entry fields and the log store all
  touched from a thread that is not the main one. Each of the four is now a job
  (PostCQDecode and its siblings) that the main thread evaluates
  (EvaluateCQDecode and its siblings). These tests pin that for
  ALL FOUR kinds, named by the letter PendingMessageOrder uses:

    C  CQ decode      S  status      X  clear      L  logged ADIF

    * A message posted from another thread is QUEUED, not evaluated.
    * The evaluation refuses to run on any thread but the main one.
    * The four kinds share ONE queue and keep arrival order -- a QSO's L and
      the S / C messages around it must not be reordered.
    * A queued message never evaluates after its server has stopped or been
      freed -- EXCEPT a LOGGED one, which Stop evaluates (a logged QSO is never
      dropped; the status, clear and decode messages around it are). The queue
      is drained with ProcessMessages, which pops the detached jobs and finds
      nothing to run; nothing here frees a server with a message queued and
      then drains for the crash.

  WHAT THIS CANNOT SHOW, and says so rather than pretending: that a WSJT-X QSO
  is LOGGED correctly. LogContact needs a booted contest -- the sheet, the log
  store, the entry fields -- and this binary does not boot one. That, and the
  colourisation, need a live WSJT-X session: docs/BENCH_QUEUE.md. *)
unit uTestWSJTXThreading;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TWSJTXThreadingTests = class(TTestCase)
   private
      FSeen: string;       (* the ADIF the seam received, '|' between *)
      procedure Drain;
      procedure RecordADIF(const aAdif: string);
      procedure Test_EveryListenerMessageIsQueuedNotEvaluated;
      procedure Test_EvaluationRefusesAnyThreadButTheMainOne;
      procedure Test_TheKindsShareOneQueueInArrivalOrder;
      procedure Test_AQueuedMessageIsDroppedOnceTheServerIsFreed;
      procedure Test_StopLogsAQueuedQSOInsteadOfDroppingIt;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Forms,
   uCrashLog,   (* InstallCrashLog -- records the MAIN THREAD, without which
                  OnMainThread is False everywhere *)
   uWSJTX;

type
   (* Does, from a thread of its own, what the UDP listener does: one Post* per
     letter of the script, in order -- or, with aEvaluate, calls the matching
     Evaluate* directly the way a caller that bypassed the hand-off would. *)
   TListenerThread = class(TThread)
   private
      FServer: TWSJTXServer;
      FScript: string;
      FEvaluate: boolean;
   protected
      procedure Execute; override;
   public
      constructor Create(aServer: TWSJTXServer; const aScript: string;
                         aEvaluate: boolean);
   end;

constructor TListenerThread.Create(aServer: TWSJTXServer;
                                   const aScript: string;
                                   aEvaluate: boolean);
begin
   FServer := aServer;
   FScript := aScript;
   FEvaluate := aEvaluate;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TListenerThread.Execute;
var
   i: integer;
begin
   for i := 1 to Length(FScript) do
      begin
      case FScript[i] of
        'C':
           begin
           if FEvaluate then
              begin
              FServer.EvaluateCQDecode('K1ABC', 'FN42', 'WSJT-X', 14074000);
              end
           else
              begin
              FServer.PostCQDecode('K1ABC', 'FN42', 'WSJT-X', 14074000);
              end;
           end;

        'S':
           begin
           if FEvaluate then
              begin
              FServer.EvaluateStatus(14074000, 'K1ABC', 'FN42', True);
              end
           else
              begin
              FServer.PostStatus(14074000, 'K1ABC', 'FN42', True);
              end;
           end;

        'X':
           begin
           if FEvaluate then
              begin
              FServer.EvaluateClear;
              end
           else
              begin
              FServer.PostClear;
              end;
           end;

        'L':
           begin
           if FEvaluate then
              begin
              FServer.EvaluateLoggedADIF('<call:5>K1ABC<eor>');
              end
           else
              begin
              FServer.PostLoggedADIF('<call:5>K1ABC<eor>');
              end;
           end;

        (* A second, different logged record, so order among LOGGED is visible. *)
        'M':
           begin
           FServer.PostLoggedADIF('<call:5>K2XYZ<eor>');
           end;
      end;
      end;
end;

procedure RunListener(aServer: TWSJTXServer; const aScript: string;
                      aEvaluate: boolean);
var
   th: TListenerThread;
begin
   th := TListenerThread.Create(aServer, aScript, aEvaluate);
   try
      th.WaitFor;
   finally
      th.Free;
   end;
end;

procedure TWSJTXThreadingTests.RecordADIF(const aAdif: string);
begin
   if FSeen <> '' then
      begin
      FSeen := FSeen + '|';
      end;
   FSeen := FSeen + aAdif;
end;

procedure TWSJTXThreadingTests.Drain;
begin
   if Application <> nil then
      begin
      Application.ProcessMessages;
      end;
end;

procedure TWSJTXThreadingTests.Test_EveryListenerMessageIsQueuedNotEvaluated;
const
   KINDS = 'CSXL';
var
   server: TWSJTXServer;
   k: integer;
begin
   InstallCrashLog;
   FSeen := '';
   for k := 1 to Length(KINDS) do
      begin
      server := TWSJTXServer.Create;
      server.LoggedADIFHook := RecordADIF;
      try
         RunListener(server, KINDS[k], False);

         CheckEquals(1, PendingMessageCount,
                     KINDS[k] + ': the message is waiting for the main thread');
         CheckEquals(string(KINDS[k]), PendingMessageOrder,
                     KINDS[k] + ': and it is the kind that was posted');
         CheckEquals(0, server.MessagesEvaluated,
                     KINDS[k] + ': the listener thread did NOT evaluate it -- '
                     + 'the sheet, ActiveContest, the entry fields and the log '
                     + 'store are the main thread''s');

         server.Stop;
         Drain;
         CheckEquals(0, PendingMessageCount,
                     KINDS[k] + ': the queue is empty again');
         if KINDS[k] = 'L' then
            begin
            CheckEquals(1, server.MessagesEvaluated,
                        'L: Stop LOGS a queued QSO rather than dropping it');
            end
         else
            begin
            CheckEquals(0, server.MessagesEvaluated,
                        KINDS[k] + ': Stop drops a transient message unevaluated');
            end;
      finally
         server.Free;
      end;
      end;
end;

procedure TWSJTXThreadingTests.Test_EvaluationRefusesAnyThreadButTheMainOne;
const
   KINDS = 'CSXL';
var
   server: TWSJTXServer;
   k: integer;
begin
   InstallCrashLog;
   server := TWSJTXServer.Create;
   try
      for k := 1 to Length(KINDS) do
         begin
         RunListener(server, KINDS[k], True);
         CheckEquals(0, server.MessagesEvaluated,
                     KINDS[k] + ': Evaluate* refuses to run off the main '
                     + 'thread -- EvaluateLoggedADIF is the one that logs a QSO');
         end;
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.Test_TheKindsShareOneQueueInArrivalOrder;
var
   server: TWSJTXServer;
begin
   InstallCrashLog;
   server := TWSJTXServer.Create;
   try
      (* A status, the QSO's logged message, WSJT-X's clear, a decode, and the
        next QSO's status. *)
      RunListener(server, 'SLXCS', False);

      CheckEquals('SLXCS', PendingMessageOrder,
                  'one FIFO for all four kinds: nothing is reordered, and the '
                  + 'logged message sits between the messages around it');
      CheckEquals(0, server.MessagesEvaluated,
                  'none evaluated off the main thread');

      server.Stop;
      Drain;
      CheckEquals('', PendingMessageOrder, 'and the queue empties');
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.Test_AQueuedMessageIsDroppedOnceTheServerIsFreed;
var
   server: TWSJTXServer;
begin
   InstallCrashLog;
   FSeen := '';
   server := TWSJTXServer.Create;
   server.LoggedADIFHook := RecordADIF;
   try
      RunListener(server, 'CSXL', False);
      CheckEquals(4, PendingMessageCount, 'queued');

      (* Destroy stops the server, which detaches every job. The server is then
        gone and the queue is drained: the jobs are popped and DROPPED, not run
        against freed memory. *)
      server.Free;
      server := nil;
      Drain;

      CheckEquals(0, PendingMessageCount,
                  'the orphaned messages were popped and discarded');
      CheckEquals('<call:5>K1ABC<eor>', FSeen,
                  'and the logged one was LOGGED by the destructor''s Stop');
   finally
      server.Free;
   end;
end;

procedure TWSJTXThreadingTests.Test_StopLogsAQueuedQSOInsteadOfDroppingIt;
var
   server: TWSJTXServer;
begin
   InstallCrashLog;
   FSeen := '';
   server := TWSJTXServer.Create;
   server.LoggedADIFHook := RecordADIF;
   try
      (* status, QSO 1, clear, QSO 2, decode -- two LOGGED among transient ones *)
      RunListener(server, 'SLXMC', False);
      CheckEquals('SLXLC', PendingMessageOrder, 'queued in arrival order');
      CheckEquals(0, server.MessagesEvaluated, 'nothing evaluated off the main thread');

      server.Stop;

      CheckEquals(2, server.MessagesEvaluated,
                  'Stop evaluated both LOGGED jobs and nothing else: the '
                  + 'status, clear and decode are transient and were dropped');
      CheckEquals('<call:5>K2XYZ<eor>', Copy(FSeen, Pos('|', FSeen) + 1, MaxInt),
                  'the second QSO was logged second');
      CheckEquals('<call:5>K1ABC<eor>', Copy(FSeen, 1, Pos('|', FSeen) - 1),
                  'FIFO: the first QSO was logged first');

      Drain;
      CheckEquals(0, PendingMessageCount, 'the rest was detached and dropped');
      CheckEquals(2, server.MessagesEvaluated, 'and the drain evaluated nothing more');
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

   Test_EveryListenerMessageIsQueuedNotEvaluated;
   Test_EvaluationRefusesAnyThreadButTheMainOne;
   Test_TheKindsShareOneQueueInArrivalOrder;
   Test_AQueuedMessageIsDroppedOnceTheServerIsFreed;
   Test_StopLogsAQueuedQSOInsteadOfDroppingIt;
end;

end.
