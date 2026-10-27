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
      procedure Test_TheServersIndexFollowsItsLogFile;
      procedure Test_TheOldReaderOfTheBinaryLogIsGone;
   end;

implementation

uses
   SysUtils, utils_text, TF, uNet, uNetClient, uNetResend, uNetHello,
   uLogStore, uLogDatabase, uLogRepository, uContestRegistry, PostUnit,
   uServerQsoIndex;

const
   (* The station-id 2 every test peer announces itself as. *)
   PEER = 2;

type
   (* A WRITER WITH NO SOCKET. Records each packet it was asked to write, and can
     fail from the Nth write on or hold writes at a gate. Runs on the queue's
     writer thread. *)
   TStubLink = class
   private
      FLock: TCriticalSection;
      FWritten: TStringList;
      FLast: TNetQSOInformation;
      FAttempts: integer;
   public
      (* The 1-based number of the write from which writes fail; 0 never. *)
      FailFrom: integer;
      (* When assigned, a write waits here (5 s at most) before it does anything. *)
      Gate: TEvent;
      constructor Create;
      destructor Destroy; override;
      function Write(const aBytes: TBytes): boolean;
      function Attempts: integer;
      (* One text per packet written: Q, E, O or S, then the QSO's key. *)
      function WrittenText: string;
      function WrittenCount: integer;
      function CountOf(const aPrefix: string): integer;
      function Last: TNetQSOInformation;
   end;

var
   gNotices: TStringList;

procedure RecordNotice(const aText: string);
begin
   gNotices.Add(aText);
end;

constructor TStubLink.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FWritten := TStringList.Create;
end;

destructor TStubLink.Destroy;
begin
   FWritten.Free;
   FLock.Free;
   inherited Destroy;
end;

function TStubLink.Write(const aBytes: TBytes): boolean;
var
   id: Word;
   kind: string;
   pkt: NetQSOInformationPtr;
begin
   if Gate <> nil then
      begin
      Gate.WaitFor(5000);
      end;

   FLock.Enter;
   try
      Inc(FAttempts);
      Result := (FailFrom = 0) or (FAttempts < FailFrom);
      if not Result then
         begin
         Exit;
         end;

      id := Word(aBytes[0]) or (Word(aBytes[1]) shl 8);
      case id of
         NET_QSOINFO_ID:        kind := 'Q';
         NET_EDITEDQSO_ID:      kind := 'E';
         NET_OFFLINEQSO_ID:     kind := 'O';
         NET_SERVERMESSAGE_ID:  kind := 'S';
      else
         kind := 'X';
      end;

      if (kind = 'Q') or (kind = 'E') or (kind = 'O') then
         begin
         pkt := NetQSOInformationPtr(@aBytes[0]);
         FLast := pkt^;
         FWritten.Add(kind + IntToStr(pkt^.qiInformation.ceQSOID1) + '/' +
                      IntToStr(pkt^.qiInformation.ceQSOID2));
         end
      else
         begin
         FWritten.Add(kind);
         end;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.Attempts: integer;
begin
   FLock.Enter;
   try
      Result := FAttempts;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.WrittenText: string;
begin
   FLock.Enter;
   try
      Result := FWritten.CommaText;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.WrittenCount: integer;
begin
   FLock.Enter;
   try
      Result := FWritten.Count;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.CountOf(const aPrefix: string): integer;
var
   i: integer;
begin
   Result := 0;
   FLock.Enter;
   try
      for i := 0 to FWritten.Count - 1 do
         begin
         if Copy(FWritten[i], 1, Length(aPrefix)) = aPrefix then
            begin
            Inc(Result);
            end;
         end;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.Last: TNetQSOInformation;
begin
   FLock.Enter;
   try
      Result := FLast;
   finally
      FLock.Leave;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the scratch store and the link                                               *)
(* --------------------------------------------------------------------------- *)

(* Waits (5 s at most) until the stub has been asked to write aCount packets of
  any kind. A QSO packet's outcome is reported before the next write begins, so
  when the LAST packet is not a QSO or an edit this also means every outcome is
  in. *)
function WaitWrites(aLink: TStubLink; aCount: integer): boolean;
var
   started: QWord;
begin
   started := GetTickCount64;
   repeat
      Result := aLink.Attempts >= aCount;
      if not Result then
         begin
         Sleep(5);
         end;
   until Result or (GetTickCount64 - started > 5000);
end;

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

         CheckTrue(SendRecordToServer(NET_QSOINFO_ID, rec), 'the packet is posted');
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
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'posted');
         CheckTrue(WaitSettled(1), 'written');
         SettleServerProgress;

         CheckFalse(rec.ceSendToServer, 'the record is still unsent');
         CheckTrue(rec.ceNeedSendToServerAE, 'and still dirty');
         CheckTrue(link.Last.qiInformation.ceSendToServer, 'the packet says sent');
         CheckFalse(link.Last.qiInformation.ceNeedSendToServerAE, 'and not dirty');
         CheckTrue(link.Last.qiInformation.ceQSOID1 = 402, 'and carries the key');
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
         CheckTrue(SendRecordToServer(NET_QSOINFO_ID, rec), 'posted: the link was up');
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
         CheckEquals('Q403/1,S', next.WrittenText,
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
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'the first edit is posted');
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'and a second');
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
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'the first edit is posted');
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'and a second');
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

         CheckEquals('Q421/1,Q422/1,E423/1,Q424/1,E424/1,S', link.WrittenText,
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
         CheckEquals('Q436/1,Q437/1,Q438/1,Q439/1,Q440/1,S', second.WrittenText,
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
         Check(elapsed < 3000,
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

(* A QSO THAT ARRIVES TWICE IS LOGGED ONCE. The real QSOINFO arm is fed a packet
  whose key the log already holds (a station sending again what it had sent): the
  arm ignores it -- no LogContact, which a unit test could not survive anyway --
  and counts it. A QSO it does not hold is not "known". *)
procedure TNetResendTests.Test_AQsoThatArrivesTwiceIsLoggedOnce;
var
   pkt: NetQSOInformationPtr;
   desync: boolean;
   before, dupes: integer;
   known: ContestExchange;
   other: ContestExchange;
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

      other := Default(ContestExchange);
      other.ceQSOID1 := 441;
      other.ceQSOID2 := 2;
      CheckTrue(ReceivedQsoIsKnown(known), 'a stored key is known');
      CheckFalse(ReceivedQsoIsKnown(other), 'a key the log does not hold is not');
      other.ceQSOID1 := 0;
      other.ceQSOID2 := 0;
      CheckFalse(ReceivedQsoIsKnown(other), '(0, 0) is never known');
      CheckEquals(dupes + 1, NetDuplicateQsosIgnored,
                  'only the first was counted as a duplicate');

      pkt := NetQSOInformationPtr(@NetBuffer[1]);
      pkt^ := Default(TNetQSOInformation);
      pkt^.qiID := NET_QSOINFO_ID;
      pkt^.qiComputerID := 2;
      pkt^.qiSenderID := PEER;
      pkt^.qiInformation := known;
      pkt^.qiInformation.ceSendToServer := True;
      CheckEquals(SizeOf(TNetQSOInformation),
                  ConsumeNetBuffer(SizeOf(TNetQSOInformation), desync),
                  'the whole packet was consumed');
      CheckFalse(desync, 'and the stream stayed on a message boundary');
      CheckEquals(dupes + 2, NetDuplicateQsosIgnored, 'the arm turned the second copy away');
      CheckEquals(before, integer(repo.RecordCount), 'and the log did not grow');
   finally
      CloseScratchStore;
   end;
end;

(* THE IN-TREE SERVER'S SET OF HELD QSOs. It is built from the log file, treats
  the file as the authority (a different size means stale), is kept in step by
  the server's own appends, never holds the pair (0, 0), and forgets on a clear.
  The stream is a memory stream shaped like SERVERLOG.TRW: a header the size of
  one record, then records. *)
procedure TNetResendTests.Test_TheServersIndexFollowsItsLogFile;
var
   index: TServerQsoIndex;
   log: TMemoryStream;
   rec: ContestExchange;

   procedure AppendToLog(aId1, aId2: Cardinal);
   begin
      rec := Default(ContestExchange);
      rec.ceQSOID1 := aId1;
      rec.ceQSOID2 := aId2;
      log.Seek(0, soEnd);
      log.WriteBuffer(rec, SizeOf(ContestExchange));
   end;

begin
   BeginTest('the server''s index follows its log file');
   index := TServerQsoIndex.Create;
   log := TMemoryStream.Create;
   try
      rec := Default(ContestExchange);
      log.WriteBuffer(rec, SizeOf(ContestExchange));   (* the header slot *)
      AppendToLog(11, 1);
      AppendToLog(12, 1);
      AppendToLog(0, 0);                               (* an unnetworked record *)
      AppendToLog(13, $FFFFFFFF);

      CheckFalse(index.ReflectsLog(log.Size), 'a new index reflects no log');
      index.LoadFromLog(log, SizeOf(ContestExchange));
      CheckEquals(3, index.Count, 'three pairs; the (0, 0) record is not one');
      CheckTrue(index.Contains(11, 1) and index.Contains(12, 1), 'the stored pairs are held');
      CheckTrue(index.Contains(13, $FFFFFFFF), 'a high id is held whole');
      CheckFalse(index.Contains(11, 2), 'a pair that differs in one id is not');
      CheckFalse(index.Contains(0, 0), '(0, 0) is never held');
      CheckTrue(index.ReflectsLog(log.Size), 'and it reflects the log it was built from');

      (* THE SERVER'S OWN APPEND keeps it current. *)
      AppendToLog(14, 1);
      CheckFalse(index.ReflectsLog(log.Size), 'a log that grew behind its back is stale');
      index.Add(14, 1);
      index.NoteLogSize(log.Size);
      CheckTrue(index.ReflectsLog(log.Size) and index.Contains(14, 1),
                'told of the append, it is current again');
      index.Add(14, 1);
      CheckEquals(4, index.Count, 'a pair added twice is held once');

      (* THE FILE IS THE AUTHORITY: cleared or replaced, the set is rebuilt. *)
      log.Size := SizeOf(ContestExchange);
      CheckFalse(index.ReflectsLog(log.Size), 'a cleared log is not the one it reflects');
      index.LoadFromLog(log, SizeOf(ContestExchange));
      CheckEquals(0, index.Count, 'rebuilt from the cleared log it holds nothing');
      CheckFalse(index.Contains(11, 1), 'and forgets what was in it');

      index.NoteLogSize(log.Size);
      index.Clear;
      CheckFalse(index.ReflectsLog(log.Size), 'Clear forgets the size too');
   finally
      log.Free;
      index.Free;
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
   CheckEquals(0, Pos('rec.ceSendToServer :=',
                      BodyOf(net, 'function SendRecordToServer(RecordType: Word; const rec: ' +
                                  'ContestExchange): boolean;' + LineEnding + 'var')),
               'SendRecordToServer does not write the record''s flag');
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
   Test_TheServersIndexFollowsItsLogFile;
   Test_TheOldReaderOfTheBinaryLogIsGone;
end;

end.
