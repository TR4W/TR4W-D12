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

(* A STATION THAT LOST THE LINK CATCHES UP WHEN IT COMES BACK -- Phase 1, C5,
  2026-10-27.

  THREE LAYERS, each one only as real as a unit test can make it.

  uNetResend, ALONE: a QSO's tag, what each row owes the server, the sequence
  that keeps two QSOs made in one clock step apart, and the ledger that decides
  when a flag may change (written is sent, posted is not; an edit is done only
  when every edit packet for it was written).

  THE REAL uNet OVER A WRITER WITH NO SOCKET: a TNetClient.CreateWithWriter,
  whose packets go through the same queue and the same writer thread a real link
  uses, to a stub that can fail, block or record. The store is a real SQLite log
  in a scratch directory. So what is proven here is the chain a bench would
  watch: a row is stored unsent, the packet is POSTED, the row is still unsent,
  the packet is WRITTEN, the row is sent; a write that fails leaves the row
  unsent and the next link sends it; a burst cut in half is finished by the next
  link without repeating what went; the server's HELLO releases the catch-up,
  once per link; an import is never sent; and a QSO that arrives twice is logged
  once.

  WHAT IT CANNOT REACH: a real server, a real cable pulled mid-write, and the two
  stations seeing each other's QSOs. Those are tools/netprobe's `resend` case
  (both servers) and BENCH_QUEUE. *)
unit uTestNetResend;

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, SyncObjs, VC, uTR4WTestFramework, uTestNetSupport;

type
   TNetResendTests = class(TNetStoreTestCase)
   public
      procedure RunAllTests; override;

   private
      (* The link. *)
      function WaitSettled(aCount: integer): boolean;

      (* uNetResend alone. *)
      procedure Test_ATagCarriesBothIdsAndZeroMeansNone;
      procedure Test_ARowOwesWhatItsFlagsSayAndNothingWithoutAnIdentity;
      procedure Test_TheSequenceNeverRepeatsInOneClockStep;
      procedure Test_TheSequenceFollowsAClockThatMovesOnAndWraps;
      procedure Test_AWrittenQsoIsSentAndAFailedOneIsNot;
      procedure Test_AnEditIsDoneOnlyWhenEveryEditPostedForItWasWritten;
      procedure Test_AFailedEditIsNeverDoneByTheOnesAroundIt;

      (* The real uNet, a stub writer, a scratch store. *)
      procedure Test_PostedIsNotSentUntilTheWriterHasWrittenIt;
      procedure Test_ThePacketSaysSentButTheRecordIsLeftAlone;
      procedure Test_AWriteThatFailsLeavesTheRowUnsentAndTheNextLinkSendsIt;
      procedure Test_AnEditIsCleanedOnlyOnceBothPacketsWereWritten;
      procedure Test_AnEditWhoseWriteFailedStaysDirty;
      procedure Test_TheServersHelloReleasesTheCatchUpOncePerLink;
      procedure Test_TheCatchUpSendsExactlyWhatIsOwedAndAnImportIsNeverSent;
      procedure Test_ALinkThatFallsMidBurstLeavesTheRestForTheNextOne;
      procedure Test_ABurstOfTwoHundredIsPostedWhole;
      procedure Test_AQsoThatArrivesTwiceIsLoggedOnce;
      procedure Test_AGuidSetHoldsGuidsOnceAndNeverTheEmptyOne;
      procedure Test_TheOldReaderOfTheBinaryLogIsGone;
   end;

implementation

uses
   SysUtils, utils_text, TF, uNet, uNetClient, uNetResend, uNetHello,
   uLogStore, uLogDatabase, uLogRepository, uContestRegistry, PostUnit,
   uGuidSet, uWireQso, uQsoColumns, uNetFraming;

const
   (* The station-id 2 every test peer announces itself as. *)
   PEER = 2;

var
   gNotices: TStringList;

procedure RecordNotice(const aText: string);
begin
   gNotices.Add(aText);
end;

(* --------------------------------------------------------------------------- *)
(* the scratch store and the link                                               *)
(* --------------------------------------------------------------------------- *)

(* Waits (5 s at most) until the writer thread has reported aCount QSO or edit
  packets, written or lost. The reports arrive just after the write returns. *)
function TNetResendTests.WaitSettled(aCount: integer): boolean;
var
   started: QWord;
begin
   started := GetTickCount64;
   repeat
      Result := NetDeliveryLedger.Unsettled >= aCount;
      if not Result then
         begin
         Sleep(5);
         end;
   until Result or (GetTickCount64 - started > 5000);
end;

(* --------------------------------------------------------------------------- *)
(* uNetResend alone                                                             *)
(* --------------------------------------------------------------------------- *)

procedure TNetResendTests.Test_ATagCarriesBothIdsAndZeroMeansNone;
var
   tag: Int64;
   a, b: Cardinal;
begin
   BeginTest('a QSO''s tag carries both ids, and no ids is tag 0');
   CheckTrue(NetQsoTag(0, 0) = 0, '(0, 0) is no tag');
   CheckTrue(NetQsoTag(5, 0) <> 0, 'a half-zero pair is a tag');
   CheckTrue(NetQsoTag(0, 5) <> 0, 'in either half');

   tag := NetQsoTag($FFFFFFFF, $80000001);
   NetTagIds(tag, a, b);
   CheckTrue(a = $FFFFFFFF, 'ceQSOID1 comes back whole, high bit and all');
   CheckTrue(b = $80000001, 'ceQSOID2 too');
   CheckTrue(tag <> 0, 'and the tag is not the "none" value');
   CheckTrue(NetQsoTag(1, 2) <> NetQsoTag(2, 1), 'the halves are not interchangeable');
end;

procedure TNetResendTests.Test_ARowOwesWhatItsFlagsSayAndNothingWithoutAnIdentity;
var
   rec: ContestExchange;
   needs: TResendNeeds;

   procedure Make(aId1, aId2: Cardinal; aSent, aDirty: boolean);
   begin
      rec := Default(ContestExchange);
      rec.ceQSOID1 := aId1;
      rec.ceQSOID2 := aId2;
      rec.ceSendToServer := aSent;
      rec.ceNeedSendToServerAE := aDirty;
      needs := ResendNeedsOf(rec);
   end;

begin
   BeginTest('a row owes the packets its flags say, and nothing without an identity');
   Make(1, 1, True, False);
   CheckFalse(needs.NeedsQso or needs.NeedsEdit, 'sent and current owes nothing');
   Make(1, 1, False, False);
   CheckTrue(needs.NeedsQso and (not needs.NeedsEdit), 'never sent owes the QSO');
   Make(1, 1, True, True);
   CheckTrue((not needs.NeedsQso) and needs.NeedsEdit, 'edited since owes the edit');
   Make(1, 1, False, True);
   CheckTrue(needs.NeedsQso and needs.NeedsEdit, 'both owes both');
   Make(0, 0, False, True);
   CheckFalse(needs.NeedsQso or needs.NeedsEdit,
              'an import (both ids 0) owes nothing, whatever its flags');
   Make(0, 7, False, False);
   CheckTrue(needs.NeedsQso, 'one id is enough of an identity');
   CheckTrue(QsoHasNetworkIdentity(rec), 'and says so');
end;

procedure TNetResendTests.Test_TheSequenceNeverRepeatsInOneClockStep;
begin
   BeginTest('two QSOs made inside one clock step get different ceQSOID2');
   ResetQsoSequence;
   CheckTrue(NextQsoSequence(1000) = 1000, 'the first is the tick');
   CheckTrue(NextQsoSequence(1000) = 1001, 'the same tick again is one more');
   CheckTrue(NextQsoSequence(1000) = 1002, 'and again');
   CheckTrue(NextQsoSequence(900) = 1003, 'a clock that stepped back does not repeat');
   CheckTrue(NextQsoSequence(1001) = 1004, 'nor one that has not caught up');
   ResetQsoSequence;
end;

procedure TNetResendTests.Test_TheSequenceFollowsAClockThatMovesOnAndWraps;
begin
   BeginTest('the sequence follows a clock that moves on, across the 32-bit wrap');
   ResetQsoSequence;
   CheckTrue(NextQsoSequence(1000) = 1000, 'start');
   CheckTrue(NextQsoSequence(5000) = 5000, 'a later tick is used as it is');
   ResetQsoSequence;
   CheckTrue(NextQsoSequence($FFFFFFFE) = $FFFFFFFE, 'just before the wrap');
   CheckTrue(NextQsoSequence(1) = 1, 'a tick past the wrap is later, not earlier');
   CheckTrue(NextQsoSequence(1) = 2, 'and the sequence carries on from it');
   ResetQsoSequence;
end;

procedure TNetResendTests.Test_AWrittenQsoIsSentAndAFailedOneIsNot;
var
   d: TNetDelivery;
   sent, done: TNetTags;
   lost: integer;
begin
   BeginTest('a QSO whose packet was written is sent, one whose write failed is not');
   d := TNetDelivery.Create;
   try
      CheckTrue(d.Report(NET_KIND_QSOINFO, 10, True),
                'the first report asks for a settle');
      CheckFalse(d.Report(NET_KIND_QSOINFO, 11, False),
                 'the next, with one already asked for, does not');
      CheckFalse(d.Report(NET_KIND_OFFLINEQSO, 12, True), 'nor does a third');
      CheckEquals(3, d.Unsettled, 'three are waiting');

      d.Settle(sent, done, lost);
      CheckEquals(2, Length(sent), 'two QSOs are sent');
      CheckTrue((sent[0] = 10) and (sent[1] = 12), 'the written ones, in order');
      CheckEquals(0, Length(done), 'no edit is done');
      CheckEquals(1, lost, 'one packet was lost');
      CheckEquals(0, d.Unsettled, 'nothing is left waiting');
      CheckTrue(d.Report(NET_KIND_QSOINFO, 13, True),
                'after a settle the next report asks again');
      d.Settle(sent, done, lost);
      CheckEquals(1, Length(sent), 'and is settled in its turn');

      d.Report(NET_KIND_QSOINFO, 0, True);
      d.Settle(sent, done, lost);
      CheckEquals(0, Length(sent), 'a packet with tag 0 is tied to no row');
   finally
      d.Free;
   end;
end;

procedure TNetResendTests.Test_AnEditIsDoneOnlyWhenEveryEditPostedForItWasWritten;
var
   d: TNetDelivery;
   sent, done: TNetTags;
   lost: integer;
begin
   BeginTest('an edit is done only when every edit posted for that QSO was written');
   d := TNetDelivery.Create;
   try
      d.EditPosted(7);
      d.EditPosted(7);
      CheckEquals(2, d.EditsInFlight, 'two edits are in flight for one QSO');

      d.Report(NET_KIND_EDITEDQSO, 7, True);
      d.Settle(sent, done, lost);
      CheckEquals(0, Length(done), 'the first one written does not clear the flag');
      CheckEquals(1, d.EditsInFlight, 'one is still in flight');

      d.Report(NET_KIND_EDITEDQSO, 7, True);
      d.Settle(sent, done, lost);
      CheckEquals(1, Length(done), 'the second does');
      CheckTrue(done[0] = 7, 'for that QSO');
      CheckEquals(0, d.EditsInFlight, 'and nothing is in flight');

      (* One settle holding both is the same. *)
      d.EditPosted(8);
      d.EditPosted(8);
      d.Report(NET_KIND_EDITEDQSO, 8, True);
      d.Report(NET_KIND_EDITEDQSO, 8, True);
      d.Settle(sent, done, lost);
      CheckEquals(1, Length(done), 'both in one settle: done once');

      (* An edit nobody posted through the ledger, written, is done; a tagless
        one is tied to no row. *)
      d.Report(NET_KIND_EDITEDQSO, 9, True);
      d.Report(NET_KIND_EDITEDQSO, 0, True);
      d.Settle(sent, done, lost);
      CheckEquals(1, Length(done), 'an untracked written edit is done');
      CheckTrue(done[0] = 9, 'that one');
   finally
      d.Free;
   end;
end;

procedure TNetResendTests.Test_AFailedEditIsNeverDoneByTheOnesAroundIt;
var
   d: TNetDelivery;
   sent, done: TNetTags;
   lost: integer;
begin
   BeginTest('a failed edit keeps the flag for good, whatever else was written');
   d := TNetDelivery.Create;
   try
      (* The second of two edits fails: the first one written must not
        clear a flag whose later edit never reached the server. *)
      d.EditPosted(7);
      d.EditPosted(7);
      d.Report(NET_KIND_EDITEDQSO, 7, True);
      d.Report(NET_KIND_EDITEDQSO, 7, False);
      d.Settle(sent, done, lost);
      CheckEquals(0, Length(done), 'not done');
      CheckEquals(1, lost, 'one lost');
      CheckEquals(0, d.EditsInFlight, 'and the ledger is clear for the next edit');

      d.EditPosted(7);
      d.Report(NET_KIND_EDITEDQSO, 7, True);
      d.Settle(sent, done, lost);
      CheckEquals(1, Length(done),
                  'a later edit, written, carries the whole record and is done');

      (* The first fails, the second is written: same answer. *)
      d.EditPosted(8);
      d.EditPosted(8);
      d.Report(NET_KIND_EDITEDQSO, 8, False);
      d.Report(NET_KIND_EDITEDQSO, 8, True);
      d.Settle(sent, done, lost);
      CheckEquals(0, Length(done), 'a failure anywhere in the group means not done');
   finally
      d.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the real uNet over a writer with no socket                                   *)
(* --------------------------------------------------------------------------- *)

(* THE POINT OF CHOOSING "WRITTEN": a packet that is only posted leaves its row
  unsent. The writer is held at a gate; the packet is posted (SendRecordToServer
  says True), the main thread settles, and the row is STILL unsent -- a link
  that died here would lose the QSO, and the log still says so. Released, the
  writer writes, the main thread settles, and now it is sent. *)
procedure TNetResendTests.Test_PostedIsNotSentUntilTheWriterHasWrittenIt;
var
   link: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('a posted QSO is not sent until the writer has written it');
   OpenScratchStore;
   link := TStubLink.Create;
   link.Gate := TEvent.Create(nil, True, False, '');
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         rec := AppendRow('K1POST', 401, 1, False, False);

         CheckTrue(SendRecordToServer(NET_WIRE_QSO_ID, rec), 'the packet is posted');
         SettleServerProgress;
         CheckFalse(RowSent(401, 1),
                    'POSTED, NOT WRITTEN: the row is still unsent');

         link.Gate.SetEvent;
         CheckTrue(WaitSettled(1), 'the writer wrote it and reported');
         SettleServerProgress;
         CheckTrue(RowSent(401, 1), 'WRITTEN: now the row is sent');
         CheckEquals(0, integer(tUSQ), 'and nothing is counted as unsent');
      finally
         link.Gate.SetEvent;
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Gate.Free;
      link.Free;
      CloseScratchStore;
   end;
end;

(* WHAT GOES ON THE WIRE AND WHAT GOES IN THE LOG ARE DIFFERENT THINGS. The
  packet tells the server (and every other station) the QSO is sent and clean,
  so nobody sends it back; the record the caller keeps, and stores, is exactly
  as the caller made it. *)
procedure TNetResendTests.Test_ThePacketSaysSentButTheRecordIsLeftAlone;
var
   link: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('the packet says sent and clean; the caller''s record is not touched');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         rec := AppendRow('K1WIRE', 402, 1, False, True);
         CheckTrue(SendRecordToServer(NET_WIRE_EDIT_ID, rec), 'posted');
         CheckTrue(WaitSettled(1), 'written');
         SettleServerProgress;

         CheckFalse(rec.ceSendToServer, 'the record is still unsent');
         CheckTrue(rec.ceNeedSendToServerAE, 'and still dirty');
         (* PROTOCOL 5: the message is the stored row's ON-WIRE columns. The
           sent and dirty flags are this database's own and are not among them
           (before, the packet said "sent, not dirty"); the guid is the key. *)
         CheckTrue(QsoWireColumns.IndexOfName('sent_to_server') < 0,
                   'the wire has no sent flag');
         CheckTrue(QsoWireColumns.IndexOfName('server_dirty') < 0,
                   'and no dirty flag');
         CheckEquals('K1WIRE', link.LastValue('callsign'), 'the message carries the row');
         CheckEquals(RowGuid(402, 1), link.LastValue('guid'),
                     'and its guid, the identity every station shares');
         CheckTrue(RowGuid(402, 1) <> '', 'the row has a guid');
         CheckEquals(integer(Ord(WireComputerID)), integer(link.LastSender),
                     'and this station''s id as the sender');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

(* A WRITE THAT DOES NOT COMPLETE LEAVES THE ROW OWING, and the next link sends
  it: nothing in the log said it was sent, so nothing was lost. *)
procedure TNetResendTests.Test_AWriteThatFailsLeavesTheRowUnsentAndTheNextLinkSendsIt;
var
   link, next: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('a write that fails leaves the row unsent, and the next link sends it');
   OpenScratchStore;
   gNotices := TStringList.Create;
   ResendNoticeSink := RecordNotice;
   link := TStubLink.Create;
   next := TStubLink.Create;
   try
      link.FailFrom := 1;
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         rec := AppendRow('K1LOST', 403, 1, False, False);
         CheckTrue(SendRecordToServer(NET_WIRE_QSO_ID, rec), 'posted: the link was up');
         CheckTrue(WaitSettled(1), 'the writer reported');
         SettleServerProgress;
         CheckFalse(RowSent(403, 1), 'the write failed: the row stays unsent');
         CheckEquals(1, integer(tUSQ), 'and is counted as unsent');
         CheckEquals(0, link.WrittenCount, 'nothing was written');
      finally
         NetClient.Free;
         NetClient := nil;
      end;

      (* THE NEXT LINK. *)
      NetClient := TNetClient.CreateWithWriter(next.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         NetServiceResend;
         CheckTrue(WaitWrites(next, 2), 'the catch-up was written');
         SettleServerProgress;
         CheckEquals('QK1LOST,S', next.WrittenText,
                     'the QSO, then the note that a batch arrived');
         CheckTrue(RowSent(403, 1), 'now it is sent');
         CheckEquals(0, integer(tUSQ), 'and nothing is counted as unsent');
         CheckEquals(1, gNotices.Count, 'the operator was told once');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      next.Free;
      link.Free;
      ResendNoticeSink := nil;
      FreeAndNil(gNotices);
      CloseScratchStore;
   end;
end;

procedure TNetResendTests.Test_AnEditIsCleanedOnlyOnceBothPacketsWereWritten;
var
   link: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('an edit is cleaned once both edit packets were written');
   OpenScratchStore;
   link := TStubLink.Create;
   link.Gate := TEvent.Create(nil, True, False, '');
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         rec := AppendRow('K1EDIT', 404, 1, True, True);
         CheckTrue(SendRecordToServer(NET_WIRE_EDIT_ID, rec), 'the first edit is posted');
         CheckTrue(SendRecordToServer(NET_WIRE_EDIT_ID, rec), 'and a second');
         CheckEquals(2, NetDeliveryLedger.EditsInFlight, 'both are in flight');
         link.Gate.SetEvent;
         CheckTrue(WaitSettled(2), 'both were written');
         SettleServerProgress;
         CheckFalse(RowDirty(404, 1), 'the row is clean');
         CheckTrue(RowSent(404, 1), 'and was sent all along');
         CheckEquals(0, integer(tUSQE), 'nothing is counted as edited');
      finally
         link.Gate.SetEvent;
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Gate.Free;
      link.Free;
      CloseScratchStore;
   end;
end;

procedure TNetResendTests.Test_AnEditWhoseWriteFailedStaysDirty;
var
   link: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('an edit whose write failed stays dirty');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      (* The first edit is written, the second fails: the log must still say the
        server holds an older version. *)
      link.FailFrom := 2;
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         rec := AppendRow('K1EFAIL', 405, 1, True, True);
         CheckTrue(SendRecordToServer(NET_WIRE_EDIT_ID, rec), 'the first edit is posted');
         CheckTrue(SendRecordToServer(NET_WIRE_EDIT_ID, rec), 'and a second');
         CheckTrue(WaitSettled(2), 'both finished');
         SettleServerProgress;
         CheckTrue(RowDirty(405, 1), 'the row is still dirty');
         CheckEquals(1, integer(tUSQE), 'and counted as edited');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

(* THE SERVER'S HELLO IS WHAT RELEASES THE CATCH-UP. A link that is merely up
  proves nothing: nothing is posted before it, and after it exactly once. *)
procedure TNetResendTests.Test_TheServersHelloReleasesTheCatchUpOncePerLink;
var
   link: TStubLink;
   res: TResendResult;
begin
   BeginTest('the server''s HELLO releases the catch-up, once per link');
   OpenScratchStore;
   gNotices := TStringList.Create;
   ResendNoticeSink := RecordNotice;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         AppendRow('K1ONE', 411, 1, False, False);
         AppendRow('K1TWO', 412, 1, False, False);

         NetServiceResend;
         res := ResendOfflineWork;
         CheckEquals(0, res.Qsos + res.Edits, 'before the HELLO nothing is sent');
         Sleep(50);
         CheckEquals(0, link.Attempts, 'and nothing reached the writer');

         FeedHello(0, '');
         Sleep(50);
         CheckEquals(0, link.Attempts,
                     'the HELLO itself posts nothing: it waits for the end of the drain');
         NetServiceResend;
         CheckTrue(WaitWrites(link, 3), 'now the two QSOs go, and the note');
         SettleServerProgress;
         CheckEquals(2, link.CountOf('Q'), 'two QSO packets');
         CheckEquals(1, gNotices.Count, 'one notice');
         CheckTrue(Pos('2 QSO(s)', gNotices[0]) > 0, 'that names the count: ' + gNotices[0]);

         (* ANOTHER HELLO ON THE SAME LINK, another service: nothing more. *)
         AppendRow('K1THREE', 413, 1, False, False);
         FeedHello(0, '');
         NetServiceResend;
         res := ResendOfflineWork;
         CheckEquals(0, res.Qsos + res.Edits, 'once per link: nothing is sent twice');
         Sleep(50);
         CheckEquals(2, link.CountOf('Q'), 'and nothing more was written');
         CheckEquals(1, gNotices.Count, 'nor said');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      ResendNoticeSink := nil;
      FreeAndNil(gNotices);
      CloseScratchStore;
   end;
end;

(* EXACTLY WHAT IS OWED. Six rows: three never sent, one sent and edited, one
  both, one with no identity at all (an import), one up to date. The catch-up
  posts a QSO packet for the three never-sent ones and an edit packet for the two
  edited ones, in log order, and never touches the import or the clean one. When
  they have been written every flag is clear and the counts are zero. *)
procedure TNetResendTests.Test_TheCatchUpSendsExactlyWhatIsOwedAndAnImportIsNeverSent;
var
   link: TStubLink;
   res: TResendResult;
   sent, dirty: boolean;
begin
   BeginTest('the catch-up sends exactly what is owed and an import is never sent');
   OpenScratchStore;
   gNotices := TStringList.Create;
   ResendNoticeSink := RecordNotice;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         AppendRow('K1A', 421, 1, False, False);   (* never sent *)
         AppendRow('K1B', 422, 1, False, False);   (* never sent *)
         AppendRow('K1C', 423, 1, True,  True);    (* sent, then edited *)
         AppendRow('K1D', 424, 1, False, True);    (* never sent, and edited *)
         AppendRow('K1E', 0,   0, False, False);   (* an import *)
         AppendRow('K1F', 425, 1, True,  False);   (* up to date *)

         FeedHello(0, '');
         NetServiceResend;
         CheckTrue(WaitWrites(link, 6), 'five QSO or edit packets and the note were written');
         SettleServerProgress;

         CheckEquals('QK1A,QK1B,EK1C,QK1D,EK1D,S', link.WrittenText,
                     'a QSO for each never sent, an edit for each edited, in log order');

         ReadFlags(421, 1, sent, dirty);
         CheckTrue(sent and (not dirty), 'A is sent');
         ReadFlags(422, 1, sent, dirty);
         CheckTrue(sent and (not dirty), 'B is sent');
         ReadFlags(423, 1, sent, dirty);
         CheckTrue(sent and (not dirty), 'C is clean');
         ReadFlags(424, 1, sent, dirty);
         CheckTrue(sent and (not dirty), 'D is sent and clean');
         ReadFlags(0, 0, sent, dirty);
         CheckFalse(sent, 'the import is as it was: never sent, and never owed');
         ReadFlags(425, 1, sent, dirty);
         CheckTrue(sent and (not dirty), 'F is untouched');

         CheckEquals(0, integer(tUSQ), 'no QSO is counted as unsent');
         CheckEquals(0, integer(tUSQE), 'no edit is counted as pending');
         CheckEquals(1, gNotices.Count, 'one notice');
         CheckTrue((Pos('3 QSO(s)', gNotices[0]) > 0) and (Pos('2 edit(s)', gNotices[0]) > 0),
                   'it names 3 QSOs and 2 edits: ' + gNotices[0]);

         res := ResendOfflineWork;
         CheckEquals(0, res.Qsos + res.Edits, 'and a second call finds nothing to do');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      ResendNoticeSink := nil;
      FreeAndNil(gNotices);
      CloseScratchStore;
   end;
end;

(* A LINK THAT FALLS HALFWAY. Ten QSOs are owed; the link takes five and then
  every write fails. The five are marked, the five are not, and the next link
  sends exactly those five -- each QSO reaches a server once between the two. *)
procedure TNetResendTests.Test_ALinkThatFallsMidBurstLeavesTheRestForTheNextOne;
var
   first, second: TStubLink;
   i: integer;
begin
   BeginTest('a link that falls mid-burst leaves the rest for the next one');
   OpenScratchStore;
   gNotices := TStringList.Create;
   ResendNoticeSink := RecordNotice;
   first := TStubLink.Create;
   second := TStubLink.Create;
   try
      for i := 1 to 10 do
         begin
         AppendRow('K1B' + IntToStr(i), 430 + i, 1, False, False);
         end;

      first.FailFrom := 6;   (* writes 1..5 go, the rest fail *)
      NetClient := TNetClient.CreateWithWriter(first.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         NetServiceResend;
         CheckTrue(WaitWrites(first, 11), 'all ten and the note were attempted');
         SettleServerProgress;
         CheckEquals(5, first.CountOf('Q'), 'five went');
         CheckEquals(5, integer(tUSQ), 'five are still owed');
         for i := 1 to 5 do
            begin
            CheckTrue(RowSent(430 + i, 1), 'row ' + IntToStr(i) + ' went and is marked');
            end;
         for i := 6 to 10 do
            begin
            CheckFalse(RowSent(430 + i, 1), 'row ' + IntToStr(i) + ' did not and is not');
            end;
      finally
         NetClient.Free;
         NetClient := nil;
      end;

      NetClient := TNetClient.CreateWithWriter(second.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         NetServiceResend;
         CheckTrue(WaitWrites(second, 6), 'the five and the note were written');
         SettleServerProgress;
         CheckEquals('QK1B6,QK1B7,QK1B8,QK1B9,QK1B10,S', second.WrittenText,
                     'exactly the five that had not gone, and none of the five that had');
         CheckEquals(0, integer(tUSQ), 'and none is owed now');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      second.Free;
      first.Free;
      ResendNoticeSink := nil;
      FreeAndNil(gNotices);
      CloseScratchStore;
   end;
end;

(* A LONG OUTAGE IS HUNDREDS OF QSOS. Two hundred are owed; all two hundred are
  posted by one call on the main thread (no wait per record), written in order,
  and marked. *)
procedure TNetResendTests.Test_ABurstOfTwoHundredIsPostedWhole;
const
   BURST = 200;
var
   link: TStubLink;
   i: integer;
   started: QWord;
   elapsed: QWord;
   res: TResendResult;
begin
   BeginTest('a burst of two hundred owed QSOs is posted whole, with no wait per record');
   OpenScratchStore;
   gNotices := TStringList.Create;
   ResendNoticeSink := RecordNotice;
   link := TStubLink.Create;
   try
      for i := 1 to BURST do
         begin
         AppendRow('K1N' + IntToStr(i), 5000 + i, 1, False, False);
         end;

      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(0, '');
         started := GetTickCount64;
         res := ResendOfflineWork;
         elapsed := GetTickCount64 - started;
         CheckEquals(BURST, res.Qsos, 'all two hundred were posted');
         (* 10 SECONDS, NOT 3: each record is now read from its committed row and
           built as a wire row (a SQLite read, JSON and a CRC), and the CHECKED
           run (heaptrc, -gt) is about twelve times slower than a normal one; it
           took 3.2 s there against a few hundred ms normally. The guard is the
           old one-second wait per record, 200 s, which 10 s is still far under. *)
         Check(elapsed < 10000,
               'in well under the 200 seconds the old one-second wait per record cost: ' +
               IntToStr(Integer(elapsed)) + ' ms');
         CheckTrue(WaitWrites(link, BURST + 1), 'and all were written, with the note');
         SettleServerProgress;
         CheckEquals(BURST, link.CountOf('Q'), 'two hundred QSO packets');
         CheckEquals(0, integer(tUSQ), 'none is owed any more');
         CheckTrue(RowSent(5000 + BURST, 1), 'the last is marked');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      ResendNoticeSink := nil;
      FreeAndNil(gNotices);
      CloseScratchStore;
   end;
end;

(* A QSO THAT ARRIVES TWICE IS LOGGED ONCE (protocol 5: judged by GUID). The real
  wire QSO arm is fed a message whose guid the log already holds (a station
  sending again what it had sent): the arm ignores it and counts it, and the log
  does not grow. A guid the log does not hold is not "known", and the empty guid
  is never known. *)
procedure TNetResendTests.Test_AQsoThatArrivesTwiceIsLoggedOnce;
var
   desync: boolean;
   before, dupes: integer;
   known: ContestExchange;
   values: TWireValues;
   repo: TLogRepository;
begin
   BeginTest('a QSO that arrives twice is logged once');
   OpenScratchStore;
   try
      NetBeginLinkSession;
      FeedHello(PEER, ContestId(Contest));
      known := AppendRow('K1HAVE', 441, 1, True, False);
      repo := LogStoreRepository;
      before := integer(repo.RecordCount);
      dupes := NetDuplicateQsosIgnored;

      CheckTrue(RowWire(441, 1, values), 'the stored row reads as wire values');
      CheckTrue(ReceivedGuidIsKnown(WireValue(values, 'guid')), 'a stored guid is known');
      CheckFalse(ReceivedGuidIsKnown('not-a-guid-this-log-holds'), 'a guid the log does not hold is not');
      CheckFalse(ReceivedGuidIsKnown(''), 'the empty guid is never known');
      CheckEquals(dupes + 1, NetDuplicateQsosIgnored,
                  'only the first was counted as a duplicate');

      CheckEquals(Length(BuildWireMessage(NET_WIRE_QSO_ID, PEER, QsoWireColumns, values)),
                  FeedWireMessage(NET_WIRE_QSO_ID, PEER, values, desync),
                  'the whole message was consumed');
      CheckFalse(desync, 'and the stream stayed on a message boundary');
      CheckTrue(NetDuplicateQsosIgnored >= dupes + 2, 'the arm turned the copies away');
      CheckEquals(before, integer(repo.RecordCount), 'and the log did not grow');
      CheckTrue(known.ceQSOID1 = 441, 'the row is the one that was stored');
   finally
      CloseScratchStore;
   end;
end;

(* THE GUID SET. What the resend and the catch-up ask "is this guid held?" with:
  a guid is held once however often it is added, and the empty guid is never
  held (it names nothing -- the old pair (0, 0)). *)
procedure TNetResendTests.Test_AGuidSetHoldsGuidsOnceAndNeverTheEmptyOne;
var
   s: TGuidSet;
begin
   BeginTest('a guid set holds a guid once and never the empty one');
   s := TGuidSet.Create;
   try
      s.Add('11111111-1111-1111-1111-111111111111');
      s.Add('22222222-2222-2222-2222-222222222222');
      s.Add('11111111-1111-1111-1111-111111111111');
      s.Add('');
      CheckEquals(2, s.Count, 'two guids, one added twice, and the empty one refused');
      CheckTrue(s.Contains('22222222-2222-2222-2222-222222222222'), 'a held guid is found');
      CheckFalse(s.Contains('22222222-2222-2222-2222-222222222223'), 'one that differs by a digit is not');
      CheckFalse(s.Contains(UpperCase('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
                 'a guid never added is not held');
      s.Add('abcdef00-0000-0000-0000-000000000000');
      CheckFalse(s.Contains(UpperCase('abcdef00-0000-0000-0000-000000000000')),
                 'the compare is exact: case matters');
      CheckFalse(s.Contains(''), 'the empty guid is never held');
      s.Clear;
      CheckEquals(0, s.Count, 'Clear forgets everything');
   finally
      s.Free;
   end;
end;

(* THE .TRW READER IS GONE FROM THE NETWORK UNIT, and the sync worker no longer
  starts the resend: it ran on a thread that must not touch the log, from a call
  nothing reaches. A source read -- the alternative is a test that passes
  whether or not the dead path came back. *)
procedure TNetResendTests.Test_TheOldReaderOfTheBinaryLogIsGone;
var
   root, net, sync: string;

   function Slurp(const aRelative: string): string;
   var
      lines: TStringList;
   begin
      lines := TStringList.Create;
      try
         lines.LoadFromFile(AnsiString(ExpandFileName(root + aRelative)));
         Result := lines.Text;
      finally
         lines.Free;
      end;
   end;

   (* The body of a routine, from its implementation header to the next
     top-level "end;" at the start of a line. *)
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

begin
   BeginTest('the old .TRW reader of the resend is gone');
   root := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim;
   net := Slurp('uNet.pas');
   sync := Slurp('uGetServerLog.pas');

   CheckEquals(0, Pos('procedure CommitChangesInLocalLog', net),
               'uNet declares no CommitChangesInLocalLog');
   CheckEquals(0, Pos(LineEnding + '  CommitChangesInLocalLog;', sync),
               'the sync unit does not call it');
   (* The implementation, not the declaration: its header is followed by the
     routine's var block. *)
   (* The message is built in PostWireRow (protocol 5), from the stored row. *)
   CheckEquals(0, Pos('rec.ceSendToServer :=',
                      BodyOf(net, 'function PostWireRow(')),
               'PostWireRow (what SendRecordToServer posts through) does not ' +
               'write the record''s flag');
   CheckTrue(Pos('NetServiceResend;', BodyOf(net, 'procedure TNetDrainer.Drain(')) > 0,
             'the drain services the catch-up after the buffer is handled');
   CheckTrue(Pos('GResendDue := True', BodyOf(net, 'procedure HandleHelloReceived(')) > 0,
             'the server''s HELLO is what makes it due');
end;

procedure TNetResendTests.RunAllTests;
begin
   Test_ATagCarriesBothIdsAndZeroMeansNone;
   Test_ARowOwesWhatItsFlagsSayAndNothingWithoutAnIdentity;
   Test_TheSequenceNeverRepeatsInOneClockStep;
   Test_TheSequenceFollowsAClockThatMovesOnAndWraps;
   Test_AWrittenQsoIsSentAndAFailedOneIsNot;
   Test_AnEditIsDoneOnlyWhenEveryEditPostedForItWasWritten;
   Test_AFailedEditIsNeverDoneByTheOnesAroundIt;

   Test_PostedIsNotSentUntilTheWriterHasWrittenIt;
   Test_ThePacketSaysSentButTheRecordIsLeftAlone;
   Test_AWriteThatFailsLeavesTheRowUnsentAndTheNextLinkSendsIt;
   Test_AnEditIsCleanedOnlyOnceBothPacketsWereWritten;
   Test_AnEditWhoseWriteFailedStaysDirty;
   Test_TheServersHelloReleasesTheCatchUpOncePerLink;
   Test_TheCatchUpSendsExactlyWhatIsOwedAndAnImportIsNeverSent;
   Test_ALinkThatFallsMidBurstLeavesTheRestForTheNextOne;
   Test_ABurstOfTwoHundredIsPostedWhole;
   Test_AQsoThatArrivesTwiceIsLoggedOnce;
   Test_AGuidSetHoldsGuidsOnceAndNeverTheEmptyOne;
   Test_TheOldReaderOfTheBinaryLogIsGone;
end;

end.
