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

(* A SERVER THAT LOST ITS LOG IS RESTOCKED FROM THE STATIONS (2026-10-28).

  NY4I moved the server to another machine with no log. His station held 83
  QSOs, all already marked sent to the old server, and nothing sent them again:
  the resend only sends rows still owed, and the catch-up only asks what the
  SERVER has that this log lacks. The push plan (uNetCatchUp.TPushPlan) asks the
  converse, from the image the catch-up already downloads.

  THE PLAN, over a REAL SQLite log in a scratch directory (uGetServerLog.
  MakePushPlan): NY4I's own case (83 sent rows, three imports, two owed rows,
  an empty server) pushes exactly the 83 and counts the imports and the owed;
  a server that holds them all gets none; one that holds some gets the rest in
  log order; a QSO this station received from ANOTHER station is pushed too; a
  second plan made after the push is empty; and a row the resend posted on this
  link is counted as owed, not pushed again.

  THE DECISION (SyncOnConnect): one question for both directions, none when the
  setting is on, nothing at all when both sides are complete.

  THE POSTING, through the real uNet over a writer with no socket: every packet
  is an OFFLINEQSO (not QSOINFO), no row's flag is written, nothing is queued
  for the main thread to settle, and a link that is not usable is refused.

  THE WINDOW: the Send button's states, and its layout read from the .lfm.

  WHAT IT CANNOT REACH: a real server's sync port and what it does with an
  OFFLINEQSO (tools/netprobe's `restock` case, against both servers), and two
  stations. Those are BENCH_QUEUE. *)
unit uTestNetRestock;

{$I ..\..\src\tr4w.inc}

interface

uses
   SysUtils, Classes, VC, uTR4WTestFramework, uTestNetSupport, uNetCatchUp;

type
   TNetRestockTests = class(TNetStoreTestCase)
   public
      procedure RunAllTests; override;

   private
      (* NY4I's log: 83 networked rows already sent, three imports, two rows still
        owed. Server key of row n of the 83 is (7000, n). *)
      procedure SeedTheEightyThreeLog;
      function ServerRec(aId1, aId2: Cardinal): ContestExchange;
      function MakePlan(aImage: TServerLogImage): TPushPlan;
      function SourceOf(const aRelative: string): string;
      (* aCount networked rows (STATION_START, aFirst .. aFirst + aCount - 1), all
        sent and clean, in ONE transaction -- the way a long log is made. *)
      procedure SeedBulk(aFirst, aCount: integer);
      (* A server image holding exactly those keys. *)
      function BulkImage(aFirst, aCount: integer): TServerLogImage;

      procedure Test_TheEightyThreeAreTheOnlyOnesPushed;
      procedure Test_AServerThatHoldsThemAllGetsNone;
      procedure Test_AServerThatHoldsSomeGetsOnlyTheRest;
      procedure Test_AQsoReceivedFromAnotherStationIsPushedToo;
      procedure Test_ASecondPlanAfterThePushIsEmpty;
      procedure Test_ARowTheResendPostedOnThisLinkIsOwedNotPushed;
      procedure Test_ADeletedQsoAndARepeatedPairAreHandled;
      procedure Test_TheDecisionIsOneQuestionOrNone;
      procedure Test_AnUpToDateLogIsPlannedQuickly;
      procedure Test_APushOfFiveThousandIsFastAndSmall;
      procedure Test_TheRestockPostsOfflineQsoAndWritesNoFlag;
      procedure Test_ARestockOnAnUnusableLinkSendsNothing;
      procedure Test_TheWindowOffersSendOnlyWhenThereIsSomething;
      procedure Test_TheWindowsControlsFitInsideIt;
      procedure Test_TheWiringIsWhatTheDesignSays;
   end;

implementation

uses
   PostUnit, uNet, uNetClient, uNetLink, uLogStore, uLogRepository, uQsoMyFacts,
   uGetServerLog, uAppStrings, uServerLogForm;

const
   (* The first half of the network key of every row of NY4I's log. *)
   STATION_START = 7000;

(* --------------------------------------------------------------------------- *)
(* builders                                                                     *)
(* --------------------------------------------------------------------------- *)

function TNetRestockTests.ServerRec(aId1, aId2: Cardinal): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := Contest;
   Result.Callsign := ShortString('S' + IntToStr(aId2));
   Result.ceQSOID1 := aId1;
   Result.ceQSOID2 := aId2;
   Result.ceSendToServer := True;
   Result.Band := Band20;
   Result.Mode := CW;
   Result.Frequency := 14025000;
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 6;
   Result.tSysTime.qtDay := 1;
   Result.tSysTime.qtHour := 12;
   Result.tSysTime.qtMinute := 30;
   Result.tSysTime.qtSecond := 15;
end;

procedure TNetRestockTests.SeedTheEightyThreeLog;
var
   i: integer;
begin
   for i := 1 to 83 do
      begin
      AppendRow('K' + IntToStr(i), STATION_START, i, True, False);
      end;
   (* IMPORTS: no network identity. *)
   AppendRow('IMP1', 0, 0, False, False);
   AppendRow('IMP2', 0, 0, True, False);
   AppendRow('IMP3', 0, 0, False, False);
   (* OWED: never sent, and sent but edited since. *)
   AppendRow('OWE1', STATION_START, 901, False, False);
   AppendRow('OWE2', STATION_START, 902, True, True);
end;

(* The plan for the log as it is now, against an image. The caller frees it. *)
function TNetRestockTests.MakePlan(aImage: TServerLogImage): TPushPlan;
begin
   Result := nil;
   CheckTrue(MakePushPlan(aImage, Result), 'the log was read');
   CheckTrue(Result <> nil, 'and a plan was made');
end;

function TNetRestockTests.SourceOf(const aRelative: string): string;
var
   lines: TStringList;
begin
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(
         ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
         'src' + PathDelim + aRelative)));
      Result := lines.Text;
   finally
      lines.Free;
   end;
end;

procedure TNetRestockTests.SeedBulk(aFirst, aCount: integer);
var
   appends: TLogQsoAppends;
   facts: TQsoMyFacts;
   i, failedIndex: integer;
   failure: string;
begin
   facts := LogStoreCurrentMyFacts;
   facts.Source := mfsAssumed;
   appends := TLogQsoAppends.Create;
   try
      for i := aFirst to aFirst + aCount - 1 do
         begin
         appends.Add(ServerRec(STATION_START, i), facts, '');
         end;
      CheckTrue(LogStoreAppendQSOs(appends, failedIndex, failure),
                'the bulk rows are stored: ' + failure);
   finally
      appends.Free;
   end;
end;

function TNetRestockTests.BulkImage(aFirst, aCount: integer): TServerLogImage;
var
   header: TBytes;
   i: integer;
   rec: ContestExchange;
   why: string;
begin
   Result := TServerLogImage.Create;
   SetLength(header, SizeOfTLogHeader);
   Result.Data.WriteBuffer(header[0], SizeOfTLogHeader);
   for i := aFirst to aFirst + aCount - 1 do
      begin
      rec := ServerRec(STATION_START, i);
      Result.Data.WriteBuffer(rec, SizeOf(ContestExchange));
      end;
   CheckTrue(Result.Accept(Result.Data.Size, why), 'the bulk image is whole: ' + why);
end;

(* --------------------------------------------------------------------------- *)
(* the plan                                                                     *)
(* --------------------------------------------------------------------------- *)

(* NY4I'S CASE, exactly: an empty server, 83 rows already sent, imports and owed
  rows beside them. *)
procedure TNetRestockTests.Test_TheEightyThreeAreTheOnlyOnesPushed;
var
   image: TServerLogImage;
   plan: TPushPlan;
   rec: ContestExchange;
   i: integer;
begin
   BeginTest('an empty server, 83 sent rows, 3 imports and 2 owed: exactly the 83 are pushed');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedTheEightyThreeLog;
      CheckEquals(88, LogRowCount, 'the log holds 88 rows');

      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(83, plan.Count, 'the 83 are pushed');
            for i := 0 to plan.Count - 1 do
               begin
               rec := plan.Row(i);
               CheckEquals(STATION_START, integer(rec.ceQSOID1), 'row ' + IntToStr(i) + ' is this station''s');
               CheckEquals(i + 1, integer(rec.ceQSOID2), 'in log order');
               end;
            CheckEquals(3, plan.Verdicts(pvNoIdentity), 'three imports are left out and counted');
            CheckEquals(2, plan.Verdicts(pvOwed), 'two owed rows are left out and counted');
            CheckEquals(0, plan.Verdicts(pvRepeated), 'nothing repeated');
            CheckTrue(Pos('83 to send', PushSummary(plan)) = 1, 'the summary leads with the count: ' + PushSummary(plan));
            CheckTrue(Pos('3 imported', PushSummary(plan)) > 0, 'and names the imports: ' + PushSummary(plan));
            CheckTrue(Pos('2 still owed', PushSummary(plan)) > 0, 'and the owed: ' + PushSummary(plan));
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;

      (* THE LOG IS ONLY READ. *)
      CheckEquals(88, LogRowCount, 'no row was added');
      CheckTrue(RowSent(STATION_START, 1), 'and no flag was written');
      CheckFalse(RowSent(STATION_START, 901), 'the owed row is still owed');
   finally
      CloseScratchStore;
   end;
end;

procedure TNetRestockTests.Test_AServerThatHoldsThemAllGetsNone;
var
   held: array of ContestExchange;
   image: TServerLogImage;
   plan: TPushPlan;
   i: integer;
begin
   BeginTest('a server that already holds them all gets none (idempotence)');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedTheEightyThreeLog;
      SetLength(held, 83);
      for i := 1 to 83 do
         begin
         held[i - 1] := ServerRec(STATION_START, i);
         end;

      image := NewImage(held);
      try
         plan := MakePlan(image);
         try
            CheckEquals(0, plan.Count, 'nothing to send');
            CheckEquals(3, plan.Verdicts(pvNoIdentity), 'the imports are still not judged sendable');
            CheckEquals(2, plan.Verdicts(pvOwed), 'and the owed rows are still the resend''s');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

procedure TNetRestockTests.Test_AServerThatHoldsSomeGetsOnlyTheRest;
var
   held: array of ContestExchange;
   image: TServerLogImage;
   plan: TPushPlan;
   rec: ContestExchange;
   i: integer;
begin
   BeginTest('a server that holds 30 of the 83 gets the other 53, in order');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedTheEightyThreeLog;
      SetLength(held, 30);
      for i := 1 to 30 do
         begin
         held[i - 1] := ServerRec(STATION_START, i);
         end;

      image := NewImage(held);
      try
         plan := MakePlan(image);
         try
            CheckEquals(53, plan.Count, 'the rest');
            rec := plan.Row(0);
            CheckEquals(31, integer(rec.ceQSOID2), 'starting where the server stopped');
            rec := plan.Row(52);
            CheckEquals(83, integer(rec.ceQSOID2), 'and ending at the last');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* ANY STATION CAN RESTOCK THE SERVER: the key is the pair, not the author. *)
procedure TNetRestockTests.Test_AQsoReceivedFromAnotherStationIsPushedToo;
var
   image: TServerLogImage;
   plan: TPushPlan;
   rec: ContestExchange;
   i: integer;
   foreign: integer;
begin
   BeginTest('a QSO this station received from another station is pushed too');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      FRowAuthor := 'B';
      for i := 1 to 4 do
         begin
         AppendRow('W9R' + IntToStr(i), 9100, i, True, False);
         end;
      FRowAuthor := #0;
      AppendRow('K1OWN', STATION_START, 1, True, False);

      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(5, plan.Count, 'its own and the four received');
            foreign := 0;
            for i := 0 to plan.Count - 1 do
               begin
               rec := plan.Row(i);
               if rec.ceComputerID = 'B' then
                  begin
                  Inc(foreign);
                  end;
               end;
            CheckEquals(4, foreign, 'the four from station B are among them');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

procedure TNetRestockTests.Test_ASecondPlanAfterThePushIsEmpty;
var
   image, after: TServerLogImage;
   plan, second: TPushPlan;
   restocked: array of ContestExchange;
   i: integer;
begin
   BeginTest('a second plan made after the push, from the updated image, is empty');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedTheEightyThreeLog;
      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            SetLength(restocked, plan.Count);
            for i := 0 to plan.Count - 1 do
               begin
               restocked[i] := plan.Row(i);
               end;
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
      CheckEquals(83, Length(restocked), 'the first plan was 83');

      after := NewImage(restocked);
      try
         second := MakePlan(after);
         try
            CheckEquals(0, second.Count, 'the server holds them now: nothing is pushed again');
         finally
            second.Free;
         end;
      finally
         after.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* THE FETCH RUNS ON ITS OWN CONNECTION. A row the resend posted on this link may
  not be in the image, and the writer may already have marked it sent: it must
  not be counted as a row the server lacks. *)
procedure TNetRestockTests.Test_ARowTheResendPostedOnThisLinkIsOwedNotPushed;
var
   image: TServerLogImage;
   plan: TPushPlan;
begin
   BeginTest('a row the resend posted on this link is counted as owed, not pushed');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedTheEightyThreeLog;
      NetResentThisLink.Add(STATION_START, 5);
      NetResentThisLink.Add(STATION_START, 6);

      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(81, plan.Count, 'the two the resend just posted are not pushed');
            CheckEquals(4, plan.Verdicts(pvOwed), 'they are counted with the owed');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;

      (* A NEW LINK FORGETS THEM. *)
      NetBeginLinkSession;
      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(83, plan.Count, 'on the next link they are ordinary rows again');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* A deleted QSO is a QSO the server held, so it goes like the others (the catch-up
  carries deleted records too); a pair held twice in the LOG is pushed once. *)
procedure TNetRestockTests.Test_ADeletedQsoAndARepeatedPairAreHandled;
var
   image: TServerLogImage;
   plan: TPushPlan;
   deleted: ContestExchange;
begin
   BeginTest('a deleted QSO is pushed, and a pair held twice in the log is pushed once');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      deleted := ServerRec(STATION_START, 1);
      deleted.ceQSO_Deleted := True;
      deleted.Frequency := 14025000;
      CheckTrue(LogStoreAppendQSO(deleted), 'a deleted row is stored');
      AppendRow('K2', STATION_START, 2, True, False);
      AppendRow('K2AGAIN', STATION_START, 2, True, False);

      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(2, plan.Count, 'the deleted one and one of the pair');
            CheckEquals(1, plan.Verdicts(pvRepeated), 'the second copy is counted and left');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the decision                                                                 *)
(* --------------------------------------------------------------------------- *)

procedure TNetRestockTests.Test_TheDecisionIsOneQuestionOrNone;
begin
   BeginTest('on connect: one question for both directions, none when the setting is on');

   (* THE SETTING OFF: ask, once. *)
   CheckTrue(SyncOnConnect(0, 0, False) = socNothing, 'both complete: nothing');
   CheckTrue(SyncOnConnect(5, 0, False) = socAskPull, 'only the server has something: the pull question');
   CheckTrue(SyncOnConnect(0, 83, False) = socAskPush, 'only this log has something: the push question');
   CheckTrue(SyncOnConnect(5, 83, False) = socAskBoth, 'both: ONE question covering both');

   (* THE SETTING ON: it just happens. *)
   CheckTrue(SyncOnConnect(0, 0, True) = socNothing, 'both complete: nothing even with the setting on');
   CheckTrue(SyncOnConnect(5, 0, True) = socDoNow, 'pull on its own');
   CheckTrue(SyncOnConnect(0, 83, True) = socDoNow, 'push on its own');
   CheckTrue(SyncOnConnect(5, 83, True) = socDoNow, 'both on their own');

   (* A damaged count never asks about nothing. *)
   CheckTrue(SyncOnConnect(-1, 0, False) = socNothing, 'a negative count is nothing');
end;

(* THE COMMON CASE, MEASURED: every link-up plans a restock, and nearly always the
  server already holds everything. The plan runs on the main thread, so it has to
  be cheap when there is nothing to do. The numbers are printed; the limit is only
  there to catch an order-of-magnitude regression. *)
procedure TNetRestockTests.Test_AnUpToDateLogIsPlannedQuickly;
var
   image: TServerLogImage;
   plan: TPushPlan;
   started: QWord;
   took10, took20: QWord;
begin
   BeginTest('a log the server already holds is planned quickly (10,000 and 20,000 rows)');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      SeedBulk(1, 10000);
      image := BulkImage(1, 10000);
      try
         started := GetTickCount64;
         plan := MakePlan(image);
         took10 := GetTickCount64 - started;
         try
            CheckEquals(0, plan.Count, 'nothing to send at 10,000');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;

      SeedBulk(10001, 10000);
      image := BulkImage(1, 20000);
      try
         started := GetTickCount64;
         plan := MakePlan(image);
         took20 := GetTickCount64 - started;
         try
            CheckEquals(0, plan.Count, 'nothing to send at 20,000');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;

      WriteLn('[MEASURE] restock plan, server holds all: 10,000 rows ', took10,
              ' ms, 20,000 rows ', took20, ' ms (image index included)');
      CheckTrue(took20 < 20000, 'the plan over 20,000 rows is not a main-thread stall: ' +
                IntToStr(took20) + ' ms');
   finally
      CloseScratchStore;
   end;
end;

procedure TNetRestockTests.Test_APushOfFiveThousandIsFastAndSmall;
var
   link: TStubLink;
   image: TServerLogImage;
   plan: TPushPlan;
   started: QWord;
   tookPlan, tookPost, tookWrite: QWord;
   heapBefore, heapPlan: PtrUInt;
   posted: integer;
begin
   BeginTest('a push of 5,000 QSOs: planned, posted and written, and what it holds');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         SeedBulk(1, 5000);
         image := NewImage([]);
         try
            heapBefore := GetFPCHeapStatus.CurrHeapUsed;
            started := GetTickCount64;
            plan := MakePlan(image);
            tookPlan := GetTickCount64 - started;
            heapPlan := GetFPCHeapStatus.CurrHeapUsed;
            try
               CheckEquals(5000, plan.Count, 'five thousand to send');

               started := GetTickCount64;
               CheckTrue(RestockServer(plan, posted), 'all posted');
               tookPost := GetTickCount64 - started;
               CheckEquals(5000, posted, 'five thousand');
               started := GetTickCount64;
               CheckTrue(WaitWrites(link, 5000), 'and written');
               tookWrite := GetTickCount64 - started;
            finally
               plan.Free;
            end;
         finally
            image.Free;
         end;
         CheckEquals(5000, link.CountOf('O'), 'every one an OFFLINEQSO');
         CheckEquals(0, NetDeliveryLedger.Unsettled, 'nothing waiting to be settled');

         WriteLn('[MEASURE] restock of 5,000: plan ', tookPlan, ' ms (retained heap ',
                 (heapPlan - heapBefore) div 1024, ' KB), post ', tookPost,
                 ' ms, drained by the writer ', tookWrite, ' ms');
         CheckTrue(tookPlan + tookPost < 20000, 'planning and posting 5,000 is not a stall');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the posting                                                                  *)
(* --------------------------------------------------------------------------- *)

procedure TNetRestockTests.Test_TheRestockPostsOfflineQsoAndWritesNoFlag;
var
   link: TStubLink;
   image: TServerLogImage;
   plan: TPushPlan;
   posted, i: integer;
begin
   BeginTest('the restock posts OFFLINEQSO only, writes no flag and queues nothing to settle');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         for i := 1 to 60 do
            begin
            AppendRow('K' + IntToStr(i), STATION_START, i, True, False);
            end;

         image := NewImage([]);
         try
            plan := MakePlan(image);
            try
               CheckEquals(60, plan.Count, 'sixty to send');
               CheckTrue(RestockServer(plan, posted), 'the whole plan was posted');
               CheckEquals(60, posted, 'sixty');
            finally
               plan.Free;
            end;
         finally
            image.Free;
         end;

         CheckTrue(WaitWrites(link, 60), 'the writer wrote them all');
         CheckEquals(60, link.CountOf('O'), 'every packet is an OFFLINEQSO');
         CheckEquals(0, link.CountOf('Q'), 'none is a QSOINFO (which the server would relay)');
         CheckEquals(0, link.CountOf('E'), 'and none an edit');
         CheckEquals('O7000/1', Copy(link.WrittenText, 1, 7), 'in log order, starting with the first');

         (* NO FLAG, NO LEDGER. *)
         CheckEquals(0, NetDeliveryLedger.Unsettled, 'nothing is waiting for the main thread to settle');
         SettleServerProgress;
         CheckEquals(60, LogRowCount, 'no row was added');
         for i := 1 to 60 do
            begin
            CheckTrue(RowSent(STATION_START, i), 'row ' + IntToStr(i) + ' is as it was');
            CheckFalse(RowDirty(STATION_START, i), 'and clean');
            end;
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

procedure TNetRestockTests.Test_ARestockOnAnUnusableLinkSendsNothing;
var
   link: TStubLink;
   image: TServerLogImage;
   plan: TPushPlan;
   posted: integer;
begin
   BeginTest('a restock with no link, or before the server''s HELLO, sends nothing');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      AppendRow('K1', STATION_START, 1, True, False);
      NetBeginLinkSession;
      image := NewImage([]);
      try
         plan := MakePlan(image);
         try
            CheckEquals(1, plan.Count, 'one to send');

            NetClient := nil;
            CheckFalse(RestockServer(plan, posted), 'no link: refused');
            CheckEquals(0, posted, 'and nothing posted');

            NetClient := TNetClient.CreateWithWriter(link.Write);
            AttachNetClient(NetClient);
            try
               NetBeginLinkSession;
               CheckFalse(RestockServer(plan, posted),
                          'a link whose server has not said HELLO is not trusted yet');
               CheckEquals(0, posted, 'nothing posted');
               Sleep(50);
               CheckEquals(0, link.WrittenCount, 'and nothing written');

               FeedHello(0, '');
               CheckTrue(RestockServer(plan, posted), 'after the HELLO it goes');
               CheckEquals(1, posted, 'one');
               CheckTrue(WaitWrites(link, 1), 'and is written');
            finally
               NetClient.Free;
               NetClient := nil;
            end;
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the window                                                                   *)
(* --------------------------------------------------------------------------- *)

procedure TNetRestockTests.Test_TheWindowOffersSendOnlyWhenThereIsSomething;
var
   form: TfrmServerLog;
   link: TStubLink;
   before: integer;
begin
   BeginTest('the window: Send needs a count AND a usable link, follows the link, Add is independent');
   link := TStubLink.Create;
   form := TfrmServerLog.Create(nil);
   try
      NetClient := nil;
      NetBeginLinkSession;
      before := NetLinkObservers.Count;
      form.HandleShow(nil);
      try
         CheckEquals(before + 1, NetLinkObservers.Count, 'shown: it follows the link');
         CheckEquals(SServerLogTitle, form.Caption, 'the title says both directions');
         CheckFalse(form.btnSendMissing.Enabled, 'nothing fetched yet: Send is off');
         CheckEquals(SServerLogSend, form.btnSendMissing.Caption, 'with its plain caption');

         (* A COUNT, BUT NO LINK. *)
         form.ApplySyncProgress(SYNC_FIELD_ENABLE_SEND, 83);
         CheckEquals(SysUtils.Format(SServerLogSendCount, [83]), form.btnSendMissing.Caption,
                     'the count is shown');
         CheckFalse(form.btnSendMissing.Enabled, 'but with no link Send is off');

         (* THE LINK COMES UP while the window is open. *)
         NetClient := TNetClient.CreateWithWriter(link.Write);
         AttachNetClient(NetClient);
         try
            NetBeginLinkSession;
            form.LinkChanged(nil);
            CheckFalse(form.btnSendMissing.Enabled, 'connected, but the server has not said HELLO');
            FeedHello(0, '');
            form.LinkChanged(nil);
            CheckTrue(form.btnSendMissing.Enabled, 'a count and a usable link: Send is on');
            CheckEquals(SysUtils.Format(SServerLogSendCount, [83]), form.btnSendMissing.Caption,
                        'and shows it');
         finally
            NetClient.Free;
            NetClient := nil;
         end;

         (* AND GOES DOWN. *)
         form.LinkChanged(nil);
         CheckFalse(form.btnSendMissing.Enabled, 'the link dropped: Send is off again');
         CheckEquals(SysUtils.Format(SServerLogSendCount, [83]), form.btnSendMissing.Caption,
                     'the count stays, for when it is back');

         (* NOTHING TO SEND: off whatever the link. *)
         form.ApplySyncProgress(SYNC_FIELD_ENABLE_SEND, 0);
         CheckEquals(SServerLogSend, form.btnSendMissing.Caption, 'a zero count is the plain caption');
         CheckFalse(form.btnSendMissing.Enabled, 'and off');
         CheckFalse(form.btnAddMissing.Enabled, 'the Add button is not enabled by it');

         form.ApplySyncProgress(SYNC_FIELD_ENABLE_REPLACE, 5);
         CheckTrue(form.btnAddMissing.Enabled, 'Add has its own count');
         CheckEquals(SysUtils.Format(SServerLogAddMissing, [5]), form.btnAddMissing.Caption,
                     'and shows it');
         CheckFalse(form.btnSendMissing.Enabled, 'Send is untouched by it');
      finally
         SyncProgressHandler := nil;
         NetLinkObservers.Remove(form.LinkChanged);
      end;
      CheckEquals(before, NetLinkObservers.Count, 'closed: it no longer follows the link');
   finally
      form.Free;
      link.Free;
   end;
   CheckEquals(before, NetLinkObservers.Count, 'and a destroyed window leaves nothing behind');
end;

(* THE LAYOUT, READ FROM THE .lfm -- the form cannot be shown in a test. Each
  control must sit inside the form, and no two buttons or check boxes may
  overlap (issue 142: the gtk2 font is wider, so the widths carry room). *)
procedure TNetRestockTests.Test_TheWindowsControlsFitInsideIt;
type
   TBox = record
      Name: string;
      Left, Top, Width, Height: integer;
   end;
var
   lines: TStringList;
   boxes: array of TBox;
   i, j, n, clientW, clientH, depth: integer;
   line, value: string;
   cur: integer;

   function IntAfter(const aText, aKey: string; var aValue: integer): boolean;
   begin
      Result := Pos(aKey + ' = ', Trim(aText)) = 1;
      if Result then
         begin
         aValue := StrToIntDef(Trim(Copy(Trim(aText), Length(aKey) + 4, MaxInt)), 0);
         end;
   end;

   function Overlap(const a, b: TBox): boolean;
   begin
      Result := (a.Left < b.Left + b.Width) and (b.Left < a.Left + a.Width) and
                (a.Top < b.Top + b.Height) and (b.Top < a.Top + a.Height);
   end;

   function BoxOf(const aName: string): integer;
   var
      k: integer;
   begin
      Result := -1;
      for k := 0 to High(boxes) do
         begin
         if boxes[k].Name = aName then
            begin
            Result := k;
            end;
      end;
   end;

begin
   BeginTest('the window: every control fits inside it and no two buttons overlap');
   lines := TStringList.Create;
   try
      lines.Text := SourceOf('ui' + PathDelim + 'lcl' + PathDelim + 'uServerLogForm.lfm');
      clientW := 0;
      clientH := 0;
      cur := -1;
      n := 0;
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         depth := Length(line) - Length(TrimLeft(line));
         if (depth = 2) and (Pos('object ', Trim(line)) = 1) then
            begin
            SetLength(boxes, n + 1);
            boxes[n].Name := Trim(Copy(Trim(line), 8, Pos(':', Trim(line)) - 8));
            cur := n;
            Inc(n);
            Continue;
            end;
         if depth = 2 then
            begin
            IntAfter(line, 'ClientWidth', clientW);
            IntAfter(line, 'ClientHeight', clientH);
            end;
         if (depth = 4) and (cur >= 0) then
            begin
            if IntAfter(line, 'Left', j) then
               begin
               boxes[cur].Left := j;
               end;
            if IntAfter(line, 'Top', j) then
               begin
               boxes[cur].Top := j;
               end;
            if IntAfter(line, 'Width', j) then
               begin
               boxes[cur].Width := j;
               end;
            if IntAfter(line, 'Height', j) then
               begin
               boxes[cur].Height := j;
               end;
            end;
         end;

      CheckTrue(clientW > 0, 'the form''s client width was read');
      CheckTrue(clientH > 0, 'and its client height');
      CheckTrue(BoxOf('btnSendMissing') >= 0, 'the Send button is in the .lfm');

      for i := 0 to High(boxes) do
         begin
         CheckTrue(boxes[i].Left >= 0, boxes[i].Name + ' starts inside on the left');
         CheckTrue(boxes[i].Top >= 0, boxes[i].Name + ' starts inside at the top');
         CheckTrue(boxes[i].Left + boxes[i].Width <= clientW,
                   boxes[i].Name + ' ends inside on the right');
         CheckTrue(boxes[i].Top + boxes[i].Height <= clientH,
                   boxes[i].Name + ' ends inside at the bottom');
         end;

      for i := 0 to High(boxes) do
         begin
         for j := i + 1 to High(boxes) do
            begin
            if ((Copy(boxes[i].Name, 1, 3) = 'btn') or (Copy(boxes[i].Name, 1, 3) = 'chk')) and
               ((Copy(boxes[j].Name, 1, 3) = 'btn') or (Copy(boxes[j].Name, 1, 3) = 'chk')) then
               begin
               CheckFalse(Overlap(boxes[i], boxes[j]),
                          boxes[i].Name + ' and ' + boxes[j].Name + ' do not overlap');
               end;
            end;
         end;

      value := lines.Text;
      CheckTrue(Pos('OnClick = btnSendMissingClick', value) > 0, 'Send is wired in the .lfm');
      CheckTrue(Pos('Caption = ''' + SServerLogSend + '''', value) > 0,
                'the .lfm placeholder is the resourcestring''s English');
      CheckTrue(Pos('Caption = ''' + SServerLogTitle + '''', value) > 0,
                'and so is the title''s');
   finally
      lines.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the wiring, by source                                                        *)
(* --------------------------------------------------------------------------- *)

procedure TNetRestockTests.Test_TheWiringIsWhatTheDesignSays;
var
   net, sync, form, strings, catchUp, restockBody, canBody: string;

   (* From a routine's header to the next "end;" at the start of a line. *)
   function BodyOf(const aText, aHeader: string): string;
   var
      p, q: integer;
   begin
      p := Pos(aHeader, aText);
      CheckTrue(p > 0, aHeader + ' is there');
      Result := Copy(aText, p, Length(aText));
      q := Pos(LineEnding + 'end;', Result);
      if q > 0 then
         begin
         Result := Copy(Result, 1, q);
         end;
   end;

   function Occurrences(const aText, aPart: string): integer;
   var
      p: integer;
   begin
      Result := 0;
      p := Pos(aPart, aText);
      while p > 0 do
         begin
         Inc(Result);
         p := Pos(aPart, aText, p + Length(aPart));
         end;
   end;

begin
   BeginTest('the restock is wired as designed: OFFLINEQSO, no tag, the guards, one question');
   net := SourceOf('uNet.pas');
   restockBody := BodyOf(net, 'function RestockServer(aPlan: TPushPlan; out aPosted: integer): ' +
                              'boolean;' + LineEnding + 'var');
   sync := SourceOf('uGetServerLog.pas');
   form := SourceOf('ui' + PathDelim + 'lcl' + PathDelim + 'uServerLogForm.pas');
   strings := SourceOf('uAppStrings.pas');
   catchUp := SourceOf('uNetCatchUp.pas');

   (* WHAT GOES: OFFLINEQSO, UNTAGGED, through the one packet builder. *)
   CheckTrue(Pos('NET_OFFLINEQSO_ID', restockBody) > 0,
             'the restock sends OFFLINEQSO');
   CheckEquals(0, Pos('NET_QSOINFO_ID', restockBody),
               'never QSOINFO: the server would relay it to every station');
   CheckTrue(Pos('PostQsoPacket(NET_OFFLINEQSO_ID, aPlan.Row(i), 0)',
                 restockBody) > 0,
             'through the one packet builder, with no tag');
   CheckEquals(0, Pos('IOHandler', restockBody),
               'and never the socket directly');
   CheckEquals(0, Pos('LogStoreMark', restockBody + BodyOf(sync, 'function SendLogToServer(aImage: ' +
                      'TServerLogImage; out aSent: integer): boolean;' + LineEnding + 'var')),
               'no flag is written by the restock path');
   CheckTrue(Pos('NetCanRestock', restockBody) > 0,
             'the guards are checked at send time');
   canBody := BodyOf(net, 'function NetCanRestock: boolean;' + LineEnding + 'begin');
   CheckTrue(Pos('NetIsConnected', canBody) > 0, 'the link is up');
   CheckTrue(Pos('FServerHelloSeen', canBody) > 0, 'the server has said HELLO');
   CheckTrue(Pos('FRefusedComputerID', canBody) > 0, 'and has not refused this station''s id');
   CheckTrue(Pos('NetCanRestock', BodyOf(sync, 'procedure DecideOnConnect(')) > 0,
             'the on-connect question is only asked about a send that can go');
   CheckTrue(Pos('NetCanRestock', BodyOf(form, 'procedure TfrmServerLog.UpdateSendButton;')) > 0,
             'and the window enables Send by it');
   CheckTrue(Pos('NetLinkObservers.Add(LinkChanged)', BodyOf(form, 'procedure TfrmServerLog.HandleShow(')) > 0,
             'the window follows the link while it is open');
   CheckTrue(Pos('NetLinkObservers.Remove(LinkChanged)', BodyOf(form, 'procedure TfrmServerLog.HandleClose(')) > 0,
             'and lets go when it closes');
   CheckTrue(Pos('NetLinkObservers.Remove(LinkChanged)', BodyOf(form, 'destructor TfrmServerLog.Destroy;')) > 0,
             'and in its destructor');

   (* THE RESEND IS UNCHANGED: it still sends QSOINFO and remembers what it posted. *)
   CheckTrue(Pos('SendRecordToServer(NET_QSOINFO_ID, rec)',
                 BodyOf(net, 'function ResendOfflineWork: TResendResult;' + LineEnding + 'var')) > 0,
             'the resend still sends QSOINFO');
   CheckTrue(Pos('GResentKeys.Add', BodyOf(net, 'function ResendOfflineWork: TResendResult;' + LineEnding + 'var')) > 0,
             'and remembers its keys for the plan');
   CheckTrue(Pos('GResentKeys.Clear', BodyOf(net, 'procedure NetBeginLinkSession;' + LineEnding + 'begin')) > 0,
             'forgotten when a link comes up');

   (* ONE QUESTION. *)
   CheckTrue(Pos('SyncOnConnect(', BodyOf(sync, 'procedure DecideOnConnect(')) > 0,
             'the on-connect decision is the one function');
   CheckEquals(1, Occurrences(BodyOf(sync, 'procedure DecideOnConnect('), 'YesOrNo('),
               'ONE dialog on connect, never two');
   CheckTrue(Pos('SSyncAskBoth', BodyOf(sync, 'procedure DecideOnConnect(')) > 0,
             'covering both directions');

   (* THE WINDOW: a fresh download starts Send over; the click sends at once. *)
   CheckTrue(Pos('FPushCount := 0', BodyOf(form, 'procedure TfrmServerLog.btnGetLogClick(')) > 0,
             'Get server log clears the count: Send is off until the new image says otherwise');
   CheckTrue(Pos('SendLogToServer(', BodyOf(form, 'procedure TfrmServerLog.btnSendMissingClick(')) > 0,
             'the Send button sends');
   CheckEquals(0, Pos('Close', BodyOf(form, 'procedure TfrmServerLog.btnSendMissingClick(')),
               'without closing the window');
   CheckTrue(Pos('SendLogToServer', BodyOf(sync, 'function SendLogToServer(aImage: TServerLogImage; out aSent: integer): ' +
                       'boolean;' + LineEnding + 'var')) > 0,
             'and the plan is made again at click time');

   (* THE ENGLISH. *)
   CheckTrue(Pos('SNetMenuServerLog = ''Synchronize with the server...''', strings) > 0,
             'the menu row says both directions');
   CheckTrue(Pos('SServerLogTitle   = ''Synchronize with the server''', strings) > 0,
             'and so does the title');
   CheckTrue(Pos('SNetPushedToServer =' + LineEnding +
                 '      ''Sent to the server: %d QSO(s) it did not have.''', strings) > 0,
             'the notice is NY4I''s wording');

   (* THE PLAN IS THE LEAF'S. *)
   CheckTrue(Pos('ResendNeedsOf(aRec)', BodyOf(catchUp, 'function TPushPlan.Consider(')) > 0,
             'owed is judged by the resend''s own rule');
   CheckTrue(Pos('QsoHasNetworkIdentity(aRec)', BodyOf(catchUp, 'function TPushPlan.Consider(')) > 0,
             'and identity by its own');
end;

procedure TNetRestockTests.RunAllTests;
begin
   Test_TheEightyThreeAreTheOnlyOnesPushed;
   Test_AServerThatHoldsThemAllGetsNone;
   Test_AServerThatHoldsSomeGetsOnlyTheRest;
   Test_AQsoReceivedFromAnotherStationIsPushedToo;
   Test_ASecondPlanAfterThePushIsEmpty;
   Test_ARowTheResendPostedOnThisLinkIsOwedNotPushed;
   Test_ADeletedQsoAndARepeatedPairAreHandled;
   Test_TheDecisionIsOneQuestionOrNone;
   Test_AnUpToDateLogIsPlannedQuickly;
   Test_APushOfFiveThousandIsFastAndSmall;
   Test_TheRestockPostsOfflineQsoAndWritesNoFlag;
   Test_ARestockOnAnUnusableLinkSendsNothing;
   Test_TheWindowOffersSendOnlyWhenThereIsSomething;
   Test_TheWindowsControlsFitInsideIt;
   Test_TheWiringIsWhatTheDesignSays;
end;

end.
