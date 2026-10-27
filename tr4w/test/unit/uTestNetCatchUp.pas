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

(* A STATION THAT COMES UP IN THE MIDDLE OF A CONTEST CATCHES UP FROM THE SERVER
  -- Phase 1, C6, 2026-10-27.

  TWO LAYERS.

  uNetCatchUp, ALONE: the server's log as bytes (whole or refused), the judge of
  which contest a record belongs to (by what its author announced, by its byte,
  by neither), and the plan -- what a catch-up would add and why it leaves each
  of the others. No store, no socket.

  THE MERGE, over a REAL SQLite log in a scratch directory (uGetServerLog.
  MergeServerLog): absent rows go in and present rows are not touched, even when
  the server's copy differs; (0, 0) is skipped; the contest is this station's
  whatever byte the record carried; what is added is sent and clean and marked as
  assumed; a verified backup is taken first and without one nothing is written;
  a record that will not go in leaves the log as it was; and doing it twice adds
  nothing the second time.

  THE DOWNLOAD (uGetServerLog.FetchServerLog) is run against a REAL socket: an
  in-process TIdTCPServer on loopback that plays the server's sync port -- reads
  the password, writes a four-byte size and the bytes -- so what is pinned is
  the client's side of the protocol: ten password bytes, a native-order size,
  exactly that many bytes, and a clear report of a server that stops short.

  WHAT IT CANNOT REACH: a real server's sync port (tools/netprobe's `catchup`
  case, against both servers), the thread and the question asked of the
  operator, and two stations. Those are BENCH_QUEUE. *)
unit uTestNetCatchUp;

{$I ..\..\src\tr4w.inc}

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, VC, uTR4WTestFramework,
   uTestNetSupport, uNetCatchUp, uNetHello;

type
   TNetCatchUpTests = class(TNetStoreTestCase)
   public
      procedure RunAllTests; override;

   private
      (* THE FIXTURE SYNC PORT. What the server writes after the password: a size,
        then FPayload cut short at FSendOnly bytes when that is >= 0. *)
      FServer: TIdTCPServer;
      FPayload: TBytes;
      FDeclared: Int64;
      FSendOnly: integer;
      FPasswordSeen: TBytes;
      FLock: TCriticalSection;
      procedure ServerExecute(AContext: TIdContext);
      function StartServer: Word;
      procedure StopServer;
      function PayloadOf(aRecords: integer): TBytes;
      (* A server log image: a header, then these records. *)
      function NewImage(const aRecords: array of ContestExchange): TServerLogImage;
      (* A QSO as the server holds it, by author, with flags that are NOT the
        ones a caught-up row ends with, so the stamping is seen. *)
      function Rec(const aCall: string; aId1, aId2: Cardinal;
                   aAuthor: AnsiChar; aContest: TContestHandle): ContestExchange;
      procedure Announce(aPeers: TNetPeers; aOrdinal: Byte; const aContestId: string);
      function LegacyContext(aPeers: TNetPeers): TCatchUpContext;
      function ByIdContext(aPeers: TNetPeers): TCatchUpContext;
      function BackupFolder: string;
      function PeerLetter: AnsiChar;

      (* uNetCatchUp alone. *)
      procedure Test_AnImageIsWholeOrRefused;
      procedure Test_ALegacyContestIsJudgedByItsByteAndItsAuthor;
      procedure Test_AContestByIdIsJudgedByItsAuthorThenItsByte;
      procedure Test_ThePlanAddsOnlyWhatTheLogLacks;
      procedure Test_ACaughtUpRecordIsOursSentAndClean;
      procedure Test_APlanOverALargeLogIsFast;

      (* The download, against a fixture sync port. *)
      procedure Test_TheDownloadIsExactlyWhatTheServerSent;
      procedure Test_TheDownloadSendsTenPasswordBytes;
      procedure Test_AServerThatStopsShortIsReportedAndTheImageRefusesIt;
      procedure Test_AnImpossibleSizeIsRefusedBeforeAnyByteIsRead;
      procedure Test_NothingListeningIsReportedByName;

      (* The merge, over a scratch log. *)
      procedure Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
      procedure Test_WhatIsAddedIsSentCleanAssumedAndOfThisContest;
      procedure Test_AVerifiedBackupIsTakenFirst;
      procedure Test_TheDatedNamesAreOneRuleWithAPurpose;
      procedure Test_WithoutABackupNothingIsWritten;
      procedure Test_DoingItTwiceAddsNothingTheSecondTime;
      procedure Test_ARecordThatWillNotGoInLeavesTheLogAsItWas;
      procedure Test_ARecordTheLogReceivedLiveMeanwhileIsNotAddedTwice;
      procedure Test_AnEmptyServerLogChangesNothing;

      (* The wiring, by source. *)
      procedure Test_TheWiringIsWhatTheDesignSays;
   end;

implementation

uses
   StrUtils, TF, uNet, uNetClient, uComputerID, uContestRegistry, PostUnit,
   uLogStore, uServerQsoIndex, uGetServerLog;

const
   (* The station-id every test peer announces itself as. *)
   PEER = 2;
   OTHER_PEER = 3;

(* --------------------------------------------------------------------------- *)
(* builders                                                                     *)
(* --------------------------------------------------------------------------- *)

function TNetCatchUpTests.PeerLetter: AnsiChar;
begin
   Result := ComputerIDLetter(AnsiChar(PEER));
end;

function TNetCatchUpTests.NewImage(const aRecords: array of ContestExchange): TServerLogImage;
var
   header: TBytes;
   i: integer;
   why: string;
begin
   Result := TServerLogImage.Create;
   SetLength(header, SizeOfTLogHeader);
   Result.Data.WriteBuffer(header[0], SizeOfTLogHeader);
   for i := Low(aRecords) to High(aRecords) do
      begin
      Result.Data.WriteBuffer(aRecords[i], SizeOf(ContestExchange));
      end;
   CheckTrue(Result.Accept(Result.Data.Size, why), 'the image is whole: ' + why);
end;

function TNetCatchUpTests.Rec(const aCall: string; aId1, aId2: Cardinal;
                              aAuthor: AnsiChar; aContest: TContestHandle): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := aContest;
   Result.Callsign := ShortString(aCall);
   Result.ceQSOID1 := aId1;
   Result.ceQSOID2 := aId2;
   Result.ceComputerID := aAuthor;
   Result.ceSendToServer := False;
   Result.ceNeedSendToServerAE := True;
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

procedure TNetCatchUpTests.Announce(aPeers: TNetPeers; aOrdinal: Byte;
                                    const aContestId: string);
var
   hello: THelloMessage;
begin
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, aOrdinal, '5.0.99', aContestId, hello),
             'the hello can be built');
   CheckTrue(aPeers.Announce(hello), 'and is accepted');
end;

function TNetCatchUpTests.LegacyContext(aPeers: TNetPeers): TCatchUpContext;
begin
   Result.Peers := aPeers;
   Result.OurHandle := ContestHandleOf(ARRLDXCW);
   Result.OurContestId := ContestId(Result.OurHandle);
   Result.OurIsLegacy := True;
end;

function TNetCatchUpTests.ByIdContext(aPeers: TNetPeers): TCatchUpContext;
begin
   Result.Peers := aPeers;
   (* A handle above every legacy number: what a contest registered by id holds.
     The judge never asks the registry, only the id's text. *)
   Result.OurHandle := TContestHandle.FromByte(200);
   Result.OurContestId := 'TEST-BY-ID-QP';
   Result.OurIsLegacy := False;
end;

function TNetCatchUpTests.BackupFolder: string;
begin
   Result := IncludeTrailingPathDelimiter(FDir) + 'backup';
end;

(* --------------------------------------------------------------------------- *)
(* uNetCatchUp alone                                                            *)
(* --------------------------------------------------------------------------- *)

procedure TNetCatchUpTests.Test_AnImageIsWholeOrRefused;
var
   image: TServerLogImage;
   why: string;
   first, back: ContestExchange;
   header: TBytes;
   deleted: ContestExchange;
begin
   BeginTest('a server log image is whole or refused');
   first := Rec('K1ONE', 1, 1, 'B', ContestHandleOf(ARRLDXCW));
   deleted := Rec('K1DEL', 1, 2, 'B', ContestHandleOf(ARRLDXCW));
   deleted.ceQSO_Deleted := True;

   image := NewImage([first, deleted]);
   try
      CheckEquals(2, image.Count, 'two records after the header');
      CheckEquals(1, image.QsoCount, 'and one counts: a deleted QSO does not');
      CheckTrue(image.Row(1, back), 'a record can be read back');
      CheckEquals('K1DEL', string(back.Callsign), 'by position');
      CheckFalse(image.Row(2, back), 'one past the end is refused');
      CheckFalse(image.Row(-1, back), 'and so is before the start');
   finally
      image.Free;
   end;

   (* The size the server stated must be the size that arrived. *)
   image := NewImage([first]);
   try
      CheckFalse(image.Accept(image.Data.Size + 1, why), 'a short transfer is refused');
      CheckTrue(Pos('arrived', why) > 0, 'and says what arrived: ' + why);
      CheckEquals(0, image.Count, 'and holds no records');
   finally
      image.Free;
   end;

   (* A whole number of records after the header, or nothing. *)
   image := TServerLogImage.Create;
   try
      SetLength(header, SizeOfTLogHeader + 100);
      image.Data.WriteBuffer(header[0], Length(header));
      CheckFalse(image.Accept(image.Data.Size, why), 'a torn record is refused');
      CheckTrue(Pos('whole number', why) > 0, 'and says so: ' + why);
   finally
      image.Free;
   end;

   image := TServerLogImage.Create;
   try
      SetLength(header, 40);
      image.Data.WriteBuffer(header[0], Length(header));
      CheckFalse(image.Accept(image.Data.Size, why), 'less than a header is refused');
   finally
      image.Free;
   end;

   (* An empty log is whole: no bytes, or a header and nothing after it. *)
   image := TServerLogImage.Create;
   try
      CheckTrue(image.Accept(0, why), 'no bytes at all is an empty log');
      CheckEquals(0, image.Count, 'with no records');
   finally
      image.Free;
   end;

   image := NewImage([]);
   try
      CheckEquals(0, image.Count, 'a header alone is an empty log too');
   finally
      image.Free;
   end;
end;

procedure TNetCatchUpTests.Test_ALegacyContestIsJudgedByItsByteAndItsAuthor;
var
   peers: TNetPeers;
   ctx: TCatchUpContext;
   ours, other: TContestHandle;
begin
   BeginTest('a legacy contest: the byte is definitive, the author''s word decides the rest');
   peers := TNetPeers.Create;
   try
      ctx := LegacyContext(peers);
      ours := ctx.OurHandle;
      other := ContestHandleOf(CQWWCW);

      (* The author said it is on our contest. *)
      Announce(peers, PEER, ctx.OurContestId);
      Announce(peers, OTHER_PEER, ContestId(other));

      CheckTrue(JudgeServerRecord(Rec('A', 1, 1, PeerLetter, ours), ctx) = cvAccept,
                'our byte, an author on our contest: accepted');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 2, ComputerIDLetter(AnsiChar(OTHER_PEER)), ours), ctx) = cvOtherContest,
                'our byte, but the author is on another contest now: not ours');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 3, PeerLetter, other), ctx) = cvOtherContest,
                'ANOTHER LEGACY BYTE IS ANOTHER CONTEST whatever its author says now');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 4, 'Z', ours), ctx) = cvAccept,
                'our byte, an author who is not here: accepted');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 5, 'Z', other), ctx) = cvOtherContest,
                'another byte, an author who is not here: another contest');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 6, #0, ours), ctx) = cvAccept,
                'our byte, no author at all (a single-op log): accepted');
   finally
      peers.Free;
   end;
end;

procedure TNetCatchUpTests.Test_AContestByIdIsJudgedByItsAuthorThenItsByte;
var
   peers: TNetPeers;
   ctx: TCatchUpContext;
   ours, foreign: TContestHandle;
begin
   BeginTest('a contest registered by id: its author''s word first, its byte only when the author is gone');
   peers := TNetPeers.Create;
   try
      ctx := ByIdContext(peers);
      ours := ctx.OurHandle;
      foreign := TContestHandle.FromByte(77);

      Announce(peers, PEER, ctx.OurContestId);
      Announce(peers, OTHER_PEER, 'SOME-OTHER-QP');

      CheckTrue(JudgeServerRecord(Rec('A', 1, 1, PeerLetter, foreign), ctx) = cvAccept,
                'THE BYTE IS NOT READ when the author is here and says it is ours: a '
                + 'by-id handle differs between builds');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 2, ComputerIDLetter(AnsiChar(OTHER_PEER)), ours), ctx) = cvOtherContest,
                'an author on another contest: not ours, whatever the byte');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 3, 'Z', ours), ctx) = cvAccept,
                'an author who has gone, our byte: accepted (same build)');
      CheckTrue(JudgeServerRecord(Rec('A', 1, 4, 'Z', foreign), ctx) = cvUnknownContest,
                'an author who has gone, another byte: NOT JUDGED, and counted as such');
   finally
      peers.Free;
   end;
end;

procedure TNetCatchUpTests.Test_ThePlanAddsOnlyWhatTheLogLacks;
var
   peers: TNetPeers;
   ctx: TCatchUpContext;
   held: TServerQsoIndex;
   image: TServerLogImage;
   plan: TCatchUpPlan;
   ours, other: TContestHandle;
begin
   BeginTest('the plan adds only what the log lacks, each once, and says why it left the rest');
   peers := TNetPeers.Create;
   held := TServerQsoIndex.Create;
   try
      ctx := LegacyContext(peers);
      ours := ctx.OurHandle;
      other := ContestHandleOf(CQWWCW);
      Announce(peers, PEER, ctx.OurContestId);

      held.Add(10, 1);
      held.Add(10, 2);

      image := NewImage([
         Rec('K1HELD', 10, 1, PeerLetter, ours),      (* 0: the log has it *)
         Rec('W1NEW', 10, 3, PeerLetter, ours),       (* 1: added *)
         Rec('W2NEW', 10, 4, PeerLetter, ours),       (* 2: added *)
         Rec('N0ID', 0, 0, PeerLetter, ours),         (* 3: names nothing *)
         Rec('W1NEW', 10, 3, PeerLetter, ours),       (* 4: the same pair again *)
         Rec('AA1OTH', 10, 5, PeerLetter, other),     (* 5: another contest *)
         Rec('W3NEW', 10, 6, 'Z', ours),              (* 6: added: its author is gone, its byte is ours *)
         Rec('K1HELD', 10, 2, PeerLetter, ours)]);    (* 7: the log has it *)
      try
         plan := BuildCatchUpPlan(image, held, ctx);
         try
            CheckEquals(3, plan.Count, 'three are added');
            CheckEquals(1, plan.RowIndex(0), 'in the server''s order: first');
            CheckEquals(2, plan.RowIndex(1), 'second');
            CheckEquals(6, plan.RowIndex(2), 'third');
            CheckEquals(2, plan.Skipped(cusAlreadyHeld), 'two the log has');
            CheckEquals(1, plan.Skipped(cusNoIdentity), '(0, 0) names nothing');
            CheckEquals(1, plan.Skipped(cusRepeated), 'a pair twice in the file is added once');
            CheckEquals(1, plan.Skipped(cusOtherContest), 'one for another contest');
            CheckEquals(0, plan.Skipped(cusUnknownContest), 'none unjudged');
            CheckEquals('AA1OTH', plan.FirstCallSkipped(cusOtherContest),
                        'and the log can name the first');
            CheckEquals(5, plan.SkippedTotal, 'five left');
            CheckTrue(Pos('3 to add', CatchUpSummary(plan)) = 1, 'the summary leads with the count');
            CheckTrue(Pos('for another contest (first: AA1OTH)', CatchUpSummary(plan)) > 0,
                      'and says why the others were left: ' + CatchUpSummary(plan));
            CheckFalse(held.Contains(10, 3), 'the held set is only read');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      held.Free;
      peers.Free;
   end;
end;

procedure TNetCatchUpTests.Test_ACaughtUpRecordIsOursSentAndClean;
var
   r: ContestExchange;
   ours: TContestHandle;
begin
   BeginTest('a caught-up record carries this station''s contest, and is sent and clean');
   ours := ContestHandleOf(ARRLDXCW);
   r := Rec('W1NEW', 5, 5, 'B', TContestHandle.FromByte(99));
   CheckFalse(r.ceSendToServer, 'it starts unsent');
   CheckTrue(r.ceNeedSendToServerAE, 'and dirty');

   StampCaughtUp(r, ours);
   CheckTrue(r.ceContest = ours, 'the sender''s byte is replaced by ours');
   CheckTrue(r.ceSendToServer, 'it came from the server: sent');
   CheckFalse(r.ceNeedSendToServerAE, 'and clean');
   CheckEquals('W1NEW', string(r.Callsign), 'nothing else is touched');
   CheckTrue((r.ceQSOID1 = 5) and (r.ceQSOID2 = 5), 'least of all its network key');
end;

(* THE COST IS NOT A GUESS: a large multi-op log, planned in memory. The bound is
  loose on purpose (a slow build machine must not fail it); the figure printed
  is the measurement. *)
procedure TNetCatchUpTests.Test_APlanOverALargeLogIsFast;
const
   RECORD_COUNT = 20000;
   HELD_COUNT = 10000;
var
   peers: TNetPeers;
   ctx: TCatchUpContext;
   held: TServerQsoIndex;
   image: TServerLogImage;
   plan: TCatchUpPlan;
   header: TBytes;
   r: ContestExchange;
   i: integer;
   why: string;
   started, buildMs, planMs: QWord;
begin
   BeginTest('a plan over ' + IntToStr(RECORD_COUNT) + ' server records is fast');
   peers := TNetPeers.Create;
   held := TServerQsoIndex.Create;
   image := TServerLogImage.Create;
   try
      ctx := LegacyContext(peers);
      SetLength(header, SizeOfTLogHeader);
      image.Data.WriteBuffer(header[0], SizeOfTLogHeader);
      for i := 1 to RECORD_COUNT do
         begin
         r := Rec('K' + IntToStr(i), 700, i, 'Z', ctx.OurHandle);
         image.Data.WriteBuffer(r, SizeOf(ContestExchange));
         end;

      started := GetTickCount64;
      CheckTrue(image.Accept(image.Data.Size, why), 'the image is whole');
      buildMs := GetTickCount64 - started;

      for i := 1 to HELD_COUNT do
         begin
         held.Add(700, i);
         end;

      started := GetTickCount64;
      plan := BuildCatchUpPlan(image, held, ctx);
      planMs := GetTickCount64 - started;
      try
         CheckEquals(RECORD_COUNT - HELD_COUNT, plan.Count, 'half of them are missing');
         CheckEquals(HELD_COUNT, plan.Skipped(cusAlreadyHeld), 'half are held');
         WriteLn('[info] ', RECORD_COUNT, ' records (', image.Data.Size, ' bytes): accepted in ',
                 buildMs, ' ms, planned against ', HELD_COUNT, ' held in ', planMs, ' ms');
         CheckTrue(planMs < 10000, 'the plan took ' + IntToStr(planMs) + ' ms');
      finally
         plan.Free;
      end;
   finally
      image.Free;
      held.Free;
      peers.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the download, against a fixture sync port                                    *)
(* --------------------------------------------------------------------------- *)

(* THE SERVER'S SYNC PORT, AS D7 AND BOTH OUR SERVERS PLAY IT: read what the
  client writes as its password (up to 50 bytes, whatever has arrived), write the
  file's size as four bytes in native order, then the file, then close. The test
  decides what the size says and how much of the file is actually sent. *)
procedure TNetCatchUpTests.ServerExecute(AContext: TIdContext);
var
   raw: TIdBytes;
   got, sendCount, i: integer;
   size32: LongInt;
begin
   AContext.Connection.IOHandler.CheckForDataOnSource(3000);
   got := AContext.Connection.IOHandler.InputBuffer.Size;
   if got > 50 then
      begin
      got := 50;
      end;
   SetLength(raw, 0);
   if got > 0 then
      begin
      AContext.Connection.IOHandler.ReadBytes(raw, got, False);
      end;

   FLock.Enter;
   try
      SetLength(FPasswordSeen, Length(raw));
      for i := 0 to High(raw) do
         begin
         FPasswordSeen[i] := raw[i];
         end;
   finally
      FLock.Leave;
   end;

   size32 := LongInt(FDeclared);
   AContext.Connection.IOHandler.Write(size32, False);   (* native order *)

   sendCount := Length(FPayload);
   if (FSendOnly >= 0) and (FSendOnly < sendCount) then
      begin
      sendCount := FSendOnly;
      end;
   if sendCount > 0 then
      begin
      AContext.Connection.IOHandler.Write(RawToBytes(FPayload[0], sendCount));
      end;
   AContext.Connection.Disconnect;
end;

function TNetCatchUpTests.StartServer: Word;
begin
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;
   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;          (* ephemeral: never collides with a real service *)
      end;
   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TNetCatchUpTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* A server log file: a header slot, then aRecords records, each with its own
  callsign and key so a misplaced byte shows. *)
function TNetCatchUpTests.PayloadOf(aRecords: integer): TBytes;
var
   image: TServerLogImage;
   header: TBytes;
   one: ContestExchange;
   i: integer;
begin
   image := TServerLogImage.Create;
   try
      SetLength(header, SizeOfTLogHeader);
      image.Data.WriteBuffer(header[0], SizeOfTLogHeader);
      for i := 1 to aRecords do
         begin
         one := Rec('K' + IntToStr(i), 900, i, 'B', ContestHandleOf(ARRLDXCW));
         image.Data.WriteBuffer(one, SizeOf(ContestExchange));
         end;
      SetLength(Result, image.Data.Size);
      if image.Data.Size > 0 then
         begin
         image.Data.Position := 0;
         image.Data.ReadBuffer(Result[0], image.Data.Size);
         end;
   finally
      image.Free;
   end;
end;

procedure TNetCatchUpTests.Test_TheDownloadIsExactlyWhatTheServerSent;
var
   stream: TMemoryStream;
   image: TServerLogImage;
   declared: Int64;
   why: string;
   port: Word;
   same: boolean;
   last: ContestExchange;
begin
   BeginTest('the download is exactly what the server sent, and then reads as a log');
   FLock := TCriticalSection.Create;
   stream := TMemoryStream.Create;
   try
      (* 300 records is 112,800 bytes: more than one chunk, so the loop that
        reads a size's worth in pieces is the thing being run. *)
      FPayload := PayloadOf(300);
      FDeclared := Length(FPayload);
      FSendOnly := -1;
      port := StartServer;
      try
         CheckTrue(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                  stream, declared, why), 'the download succeeds: ' + why);
      finally
         StopServer;
      end;

      CheckTrue(declared = Length(FPayload), 'the size is the one the server stated');
      CheckEquals(Length(FPayload), integer(stream.Size), 'and that many bytes arrived');
      same := (stream.Size = Length(FPayload)) and
              CompareMem(stream.Memory, @FPayload[0], Length(FPayload));
      CheckTrue(same, 'every byte is the byte sent');

      (* And it is a log: the image takes it, and reads a record back. *)
      image := TServerLogImage.Create;
      try
         image.Data.CopyFrom(stream, 0);
         CheckTrue(image.Accept(declared, why), 'the image is whole: ' + why);
         CheckEquals(300, image.Count, 'with the 300 records');
         CheckTrue(image.Row(299, last), 'the last can be read');
         CheckEquals('K300', string(last.Callsign), 'and is the last sent');
      finally
         image.Free;
      end;
   finally
      stream.Free;
      FreeAndNil(FLock);
   end;
end;

(* THE PASSWORD IS TEN BYTES, NUL PADDED -- what D7's client wrote with
  send(buf, 10). The in-tree server's sync port once waited for fifty. *)
procedure TNetCatchUpTests.Test_TheDownloadSendsTenPasswordBytes;
var
   stream: TMemoryStream;
   declared: Int64;
   why: string;
   port: Word;
   seen: TBytes;
begin
   BeginTest('the download writes the password as ten bytes, NUL padded');
   FLock := TCriticalSection.Create;
   stream := TMemoryStream.Create;
   try
      FPayload := PayloadOf(1);
      FDeclared := Length(FPayload);
      FSendOnly := -1;
      port := StartServer;
      try
         CheckTrue(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('PW'),
                                  stream, declared, why), 'the download succeeds: ' + why);
      finally
         StopServer;
      end;

      FLock.Enter;
      try
         seen := Copy(FPasswordSeen, 0, Length(FPasswordSeen));
      finally
         FLock.Leave;
      end;
      CheckEquals(10, Length(seen), 'ten bytes reached the server');
      CheckTrue((seen[0] = Ord('P')) and (seen[1] = Ord('W')) and (seen[2] = 0) and
                (seen[9] = 0), 'the password, then NULs');
   finally
      stream.Free;
      FreeAndNil(FLock);
   end;
end;

(* A SERVER THAT STOPS SHORT -- a link cut mid-transfer -- is a failed download
  that says how far it got, and what did arrive is not a log: the image refuses
  it, so nothing downstream sees half a file. *)
procedure TNetCatchUpTests.Test_AServerThatStopsShortIsReportedAndTheImageRefusesIt;
var
   stream: TMemoryStream;
   image: TServerLogImage;
   declared: Int64;
   why, imageWhy: string;
   port: Word;
begin
   BeginTest('a server that stops short is reported, and the partial file is refused');
   FLock := TCriticalSection.Create;
   stream := TMemoryStream.Create;
   try
      FPayload := PayloadOf(10);
      FDeclared := Length(FPayload);
      FSendOnly := 1000;
      port := StartServer;
      try
         CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                   stream, declared, why), 'the download fails');
      finally
         StopServer;
      end;
      CheckTrue(Pos('1000 of ' + IntToStr(Length(FPayload)), why) > 0,
                'and says how far it got: ' + why);

      image := TServerLogImage.Create;
      try
         image.Data.CopyFrom(stream, 0);
         CheckFalse(image.Accept(declared, imageWhy), 'what arrived is not a log');
         CheckEquals(0, image.Count, 'and holds no records');
      finally
         image.Free;
      end;
   finally
      stream.Free;
      FreeAndNil(FLock);
   end;
end;

procedure TNetCatchUpTests.Test_AnImpossibleSizeIsRefusedBeforeAnyByteIsRead;
var
   stream: TMemoryStream;
   declared: Int64;
   why: string;
   port: Word;
begin
   BeginTest('an impossible size is refused before any byte is read');
   FLock := TCriticalSection.Create;
   stream := TMemoryStream.Create;
   try
      FPayload := PayloadOf(1);
      FSendOnly := -1;

      FDeclared := -5;
      port := StartServer;
      try
         CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                   stream, declared, why), 'a negative size fails');
      finally
         StopServer;
      end;
      CheckTrue(Pos('impossible', why) > 0, 'and says so: ' + why);

      FDeclared := SERVER_LOG_MAX_BYTES + 1;
      port := StartServer;
      try
         CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                   stream, declared, why), 'a size past the limit fails');
      finally
         StopServer;
      end;
      CheckEquals(0, integer(stream.Size), 'and nothing was written either time');
   finally
      stream.Free;
      FreeAndNil(FLock);
   end;
end;

procedure TNetCatchUpTests.Test_NothingListeningIsReportedByName;
var
   stream: TMemoryStream;
   declared: Int64;
   why: string;
   port: Word;
begin
   BeginTest('a server that is not there is reported with its address');
   FLock := TCriticalSection.Create;
   stream := TMemoryStream.Create;
   try
      FPayload := PayloadOf(1);
      FDeclared := Length(FPayload);
      FSendOnly := -1;
      (* A port that was listening a moment ago and is not now. *)
      port := StartServer;
      StopServer;

      CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                stream, declared, why), 'the download fails');
      CheckTrue(Pos('could not connect to 127.0.0.1:' + IntToStr(port), why) > 0,
                'and names where it tried: ' + why);
   finally
      stream.Free;
      FreeAndNil(FLock);
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the merge, over a scratch log                                                *)
(* --------------------------------------------------------------------------- *)

(* THE POINT OF INSERT-ONLY: the log keeps what it has. A row the server holds
  under the same key, with a DIFFERENT callsign, is not applied; a row the
  station has not yet sent keeps its flags; and every absent row is added once.
  (0, 0), another contest and a repeated pair are left, and counted. *)
procedure TNetCatchUpTests.Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
   ours, other: TContestHandle;
   row: ContestExchange;
   sent, dirty: boolean;
begin
   BeginTest('the merge adds what is absent and never touches what is present');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      ours := Contest;
      other := ContestHandleOf(CQWWCW);
      FeedHello(PEER, ContestId(Contest));

      AppendRow('K1HELD', 601, 1, True, False);
      AppendRow('K1MINE', 601, 9, False, True);

      image := NewImage([
         Rec('K1DIFF', 601, 1, PeerLetter, ours),     (* held, but the server's copy differs *)
         Rec('W1NEW', 601, 2, PeerLetter, ours),
         Rec('W2NEW', 601, 3, PeerLetter, ours),
         Rec('W3NEW', 601, 4, PeerLetter, ours),
         Rec('N0ID', 0, 0, PeerLetter, ours),
         Rec('AA1OTH', 601, 5, PeerLetter, other),
         Rec('W1NEW', 601, 2, PeerLetter, ours)]);
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why),
                   'the merge succeeds: ' + why);
         CheckEquals(3, added, 'three QSOs were added');
         CheckEquals(1, skipped, 'one was for another contest');
         CheckEquals(5, LogRowCount, 'the log holds the two it had and the three');

         CheckTrue(ReadRow(601, 1, row), 'the held row is still there');
         CheckEquals('K1HELD', string(row.Callsign),
                     'and is NOT OVERWRITTEN by the server''s differing copy');
         CheckTrue(ReadFlags(601, 9, sent, dirty), 'the unsent row is still there');
         CheckFalse(sent, 'it is still unsent');
         CheckTrue(dirty, 'and still dirty: the resend will take it up');

         CheckTrue(ReadRow(601, 2, row) and ReadRow(601, 3, row) and ReadRow(601, 4, row),
                   'the three new rows are in');
         CheckFalse(ReadRow(601, 5, row), 'the other contest''s is not');
         CheckFalse(ReadRow(0, 0, row), 'and neither is the one that names nothing');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* WHAT AN ADDED ROW IS: this station's contest whatever byte it carried, sent
  and clean so the resend never sends it back, a deleted QSO still deleted, and
  our station marked ASSUMED -- the packet carries no station of its own. *)
procedure TNetCatchUpTests.Test_WhatIsAddedIsSentCleanAssumedAndOfThisContest;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
   row, deleted: ContestExchange;
   sent, dirty: boolean;
   unsent, dirtyCount: integer;
begin
   BeginTest('an added row is sent, clean, assumed and of this contest');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      (* The author is not here and its byte is OURS: accepted, and stamped. A
        deleted QSO is a QSO the server still holds. *)
      deleted := Rec('W9DEL', 611, 2, 'Z', Contest);
      deleted.ceQSO_Deleted := True;
      image := NewImage([
         Rec('W1NEW', 611, 1, PeerLetter, Contest),
         deleted]);
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why),
                   'the merge succeeds: ' + why);
         CheckEquals(2, added, 'both were added');

         CheckTrue(ReadFlags(611, 1, sent, dirty), 'the row is in');
         CheckTrue(sent, 'sent: it came from the server');
         CheckFalse(dirty, 'clean');
         CheckTrue(ReadRow(611, 1, row), 'read back');
         CheckTrue(row.ceContest = Contest, 'of this contest');
         CheckEquals(PeerLetter, row.ceComputerID, 'its author is kept');
         CheckTrue(ReadRow(611, 2, row), 'the deleted one is in');
         CheckTrue(row.ceQSO_Deleted, 'and still deleted');

         CheckEquals(2, integer(ScalarOfLogFile(FDb,
                     'SELECT COUNT(*) FROM qso WHERE my_source = ''assumed''')),
                     'OUR STATION is marked assumed on both: the packet carries none');
         CheckEquals(0, integer(ScalarOfLogFile(FDb,
                     'SELECT COUNT(*) FROM qso WHERE exchange_sent IS NOT NULL')),
                     'and no sent exchange is invented');

         CheckTrue(LogStoreCountUnsentToServer(unsent, dirtyCount), 'the owed count reads');
         CheckEquals(0, unsent, 'NOTHING IS OWED to the server for them');
         CheckEquals(0, dirtyCount, 'no edit either');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* A BACKUP FIRST: the verified snapshot of the log, taken before the first row
  goes in, so it holds the log as it was. It is a DATED backup ("<log> before
  catch-up <stamp>Z.db"), never the periodic slot: a periodic backup the operator
  already has is not rotated into .bak, and is not touched at all. *)
procedure TNetCatchUpTests.Test_AVerifiedBackupIsTakenFirst;
var
   image: TServerLogImage;
   added, skipped: integer;
   why, backup, periodic, seed: string;
   found: TSearchRec;
   stamps: integer;
   f: TextFile;
begin
   BeginTest('a dated backup of the log is taken before anything is added, and the periodic one is left alone');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      AppendRow('K1HELD', 621, 1, True, False);

      (* An operator's last periodic backup, which must come through untouched. *)
      periodic := LogStorePeriodicBackupPath(BackupFolder);
      seed := 'PERIODIC-BACKUP-SENTINEL';
      AssignFile(f, periodic);
      Rewrite(f);
      Write(f, seed);
      CloseFile(f);

      image := NewImage([
         Rec('W1NEW', 621, 2, PeerLetter, Contest),
         Rec('W2NEW', 621, 3, PeerLetter, Contest)]);
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why), 'merged: ' + why);
         CheckEquals(2, added, 'two were added');

         backup := '';
         stamps := 0;
         if FindFirst(IncludeTrailingPathDelimiter(BackupFolder) + '* before catch-up *Z.db',
                      faAnyFile, found) = 0 then
            begin
            repeat
               Inc(stamps);
               backup := IncludeTrailingPathDelimiter(BackupFolder) + found.Name;
            until FindNext(found) <> 0;
            FindClose(found);
            end;
         CheckEquals(1, stamps, 'one dated "before catch-up" backup is there');
         CheckTrue(Pos('netstore before catch-up ', backup) > 0, 'named for the log: ' + backup);
         CheckEquals(1, integer(ScalarOfLogFile(backup, 'SELECT COUNT(*) FROM qso')),
                     'and holds the log AS IT WAS: one row, not three');
         CheckEquals(3, LogRowCount, 'while the log itself now holds three');

         AssignFile(f, periodic);
         Reset(f);
         ReadLn(f, seed);
         CloseFile(f);
         CheckEquals('PERIODIC-BACKUP-SENTINEL', seed, 'THE PERIODIC BACKUP IS UNTOUCHED');
         CheckFalse(FileExists(periodic + '.bak'), 'and was not rotated into a .bak');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* THE DATED NAME: the pre-clear name is what it always was, and the catch-up's
  is the same shape with its own purpose. Neither stacks on the other. *)
procedure TNetCatchUpTests.Test_TheDatedNamesAreOneRuleWithAPurpose;
var
   moment: TDateTime;
   backups: string;
begin
   BeginTest('the dated backup names are one rule with a purpose, and never stack');
   moment := EncodeDate(2026, 10, 23) + EncodeTime(23, 1, 44, 0);
   backups := 'B' + PathDelim;

   CheckEquals(backups + 'NY4I before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName('x' + PathDelim + 'NY4I.db', backups, moment),
               'Clear Log''s name is byte for byte what it was');
   CheckEquals(backups + 'NY4I before catch-up 2026-10-23 230144Z.db',
               LogStoreDatedBackupFileName('x' + PathDelim + 'NY4I.db', backups,
                                           ' before catch-up ', moment),
               'the catch-up''s name');
   CheckEquals(backups + 'NY4I before catch-up 2026-10-23 230144Z.db',
               LogStoreDatedBackupFileName('NY4I before clear 2026-10-22 101500Z.db', backups,
                                           ' before catch-up ', moment),
               'a pre-clear backup is named for the log it came from');
   CheckEquals(backups + 'NY4I before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName('NY4I before catch-up 2026-10-22 101500Z.db', backups, moment),
               'and so is a catch-up backup');
   CheckEquals(backups + 'NY4I before catch-up 2026-10-23 230144Z.db',
               LogStoreDatedBackupFileName('NY4I periodic.db', backups,
                                           ' before catch-up ', moment),
               'and a periodic one');
end;

(* A LOG THAT CANNOT BE BACKED UP IS NOT WRITTEN TO. *)
procedure TNetCatchUpTests.Test_WithoutABackupNothingIsWritten;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
begin
   BeginTest('without a backup nothing is written');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      AppendRow('K1HELD', 631, 1, True, False);

      image := NewImage([Rec('W1NEW', 631, 2, PeerLetter, Contest)]);
      try
         CheckFalse(MergeServerLog(image, IncludeTrailingPathDelimiter(FDir) + 'no such folder',
                                   added, skipped, why),
                    'a folder that is not there is a failed backup');
         CheckTrue(Pos('backup', why) > 0, 'and the reason names it: ' + why);
         CheckEquals(0, added, 'nothing was added');
         CheckEquals(1, LogRowCount, 'the log is as it was');
         CheckTrue(LogStoreIsUsable, 'and the store is still in use');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

procedure TNetCatchUpTests.Test_DoingItTwiceAddsNothingTheSecondTime;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
begin
   BeginTest('doing it twice adds nothing the second time');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      image := NewImage([
         Rec('W1NEW', 641, 1, PeerLetter, Contest),
         Rec('W2NEW', 641, 2, PeerLetter, Contest)]);
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why), 'first: ' + why);
         CheckEquals(2, added, 'the first adds both');
         CheckEquals(2, LogRowCount, 'and the log holds them');

         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why), 'second: ' + why);
         CheckEquals(0, added, 'THE SECOND ADDS NOTHING');
         CheckEquals(0, skipped, 'and has nothing to report about contests');
         CheckEquals(2, LogRowCount, 'the log is the same size');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* ALL OR NONE: one record the log refuses (a QSO needs a callsign) and not even
  the good ones around it are written. The store stays usable -- the fault is
  the file's, not the log's. *)
procedure TNetCatchUpTests.Test_ARecordThatWillNotGoInLeavesTheLogAsItWas;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
   row: ContestExchange;
begin
   BeginTest('a record the log refuses leaves the log as it was');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      AppendRow('K1HELD', 651, 1, True, False);

      image := NewImage([
         Rec('W1GOOD', 651, 2, PeerLetter, Contest),
         Rec('', 651, 3, PeerLetter, Contest),
         Rec('W3GOOD', 651, 4, PeerLetter, Contest)]);
      try
         CheckFalse(MergeServerLog(image, BackupFolder, added, skipped, why),
                    'the merge fails');
         CheckTrue(Pos('could not be written', why) > 0, 'and says why: ' + why);
         CheckEquals(0, added, 'nothing is counted as added');
         CheckEquals(1, LogRowCount, 'THE LOG IS AS IT WAS');
         CheckFalse(ReadRow(651, 2, row), 'not even the good record before it');
         CheckTrue(LogStoreIsUsable, 'the store is still usable');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* THE QUESTION TAKES TIME. The operator is asked on the main thread, which keeps
  running the link; a QSO the others relay meanwhile is logged by the live arm.
  The merge plans against the log AS IT IS WHEN IT RUNS, so that QSO, which is
  also in the server's file, is not added a second time. *)
procedure TNetCatchUpTests.Test_ARecordTheLogReceivedLiveMeanwhileIsNotAddedTwice;
var
   image: TServerLogImage;
   added, skipped, missing: integer;
   why: string;
begin
   BeginTest('a QSO logged live while the question was open is not added again');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      image := NewImage([
         Rec('W1NEW', 661, 1, PeerLetter, Contest),
         Rec('W2NEW', 661, 2, PeerLetter, Contest)]);
      try
         CheckTrue(CountMissingFromServer(image, missing), 'the count is read');
         CheckEquals(2, missing, 'two are missing when the operator is asked');

         AppendRow('W1NEW', 661, 1, True, False);   (* the live arm logged it *)

         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why), 'merged: ' + why);
         CheckEquals(1, added, 'only the one still missing is added');
         CheckEquals(2, LogRowCount, 'and no QSO is in the log twice');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

procedure TNetCatchUpTests.Test_AnEmptyServerLogChangesNothing;
var
   image: TServerLogImage;
   added, skipped: integer;
   why: string;
begin
   BeginTest('an empty server log changes nothing, and takes no backup');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      AppendRow('K1HELD', 671, 1, True, False);
      image := NewImage([]);
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, skipped, why), 'merged: ' + why);
         CheckEquals(0, added, 'nothing added');
         CheckEquals(1, LogRowCount, 'the log is the same');
         CheckFalse(FileExists(LogStorePeriodicBackupPath(BackupFolder)),
                    'and there was nothing to protect, so no backup was made');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the wiring                                                                   *)
(* --------------------------------------------------------------------------- *)

(* A SOURCE READ for what no unit test can drive: the thread, the question and the
  menu. The alternative is a test that passes whether or not the dead path came
  back. *)
procedure TNetCatchUpTests.Test_TheWiringIsWhatTheDesignSays;
var
   root, net, sync, form, mainText: string;

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

   (* The body of a routine, from the LAST place its header is written -- the
     implementation, when the unit also declares it above -- to the next top-level
     "end;" at the start of a line. *)
   function BodyOf(const aText, aHeader: string): string;
   var
      p, last, q: integer;
   begin
      last := 0;
      p := Pos(aHeader, aText);
      while p > 0 do
         begin
         last := p;
         p := PosEx(aHeader, aText, p + 1);
         end;
      CheckTrue(last > 0, aHeader + ' is there');
      Result := Copy(aText, last, Length(aText));
      q := Pos(LineEnding + 'end;', Result);
      if q > 0 then
         begin
         Result := Copy(Result, 1, q);
         end;
   end;

   (* Text from aFrom up to the next aTo. *)
   function Between(const aText, aFrom, aTo: string): string;
   var
      p, q: integer;
   begin
      p := Pos(aFrom, aText);
      CheckTrue(p > 0, aFrom + ' is there');
      Result := Copy(aText, p, Length(aText));
      q := Pos(aTo, Copy(Result, Length(aFrom) + 1, Length(Result)));
      if q > 0 then
         begin
         Result := Copy(Result, 1, Length(aFrom) + q);
         end;
   end;

begin
   BeginTest('the wiring: connect starts it, the setting decides, nothing replaces');
   root := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim;
   net := Slurp('uNet.pas');
   sync := Slurp('uGetServerLog.pas');
   form := Slurp('ui' + PathDelim + 'lcl' + PathDelim + 'uServerLogForm.pas');
   mainText := Slurp('MainUnit.pas');

   CheckTrue(Pos('NetServiceCatchUp;', BodyOf(net, 'procedure TNetDrainer.Drain(')) > 0,
             'the drain starts the catch-up after the resend');
   CheckTrue(Pos('GCatchUpDue := True', BodyOf(net, 'procedure HandleHelloReceived(')) > 0,
             'the server''s HELLO is what makes it due');
   CheckTrue(Pos('StartServerCatchUp(cuOnConnect)', BodyOf(net, 'procedure NetServiceCatchUp;')) > 0,
             'and NetServiceCatchUp starts it');
   CheckEquals(0, Pos('RunSyncThread', net), 'uNet knows no RunSyncThread');
   CheckEquals(0, Pos('ShowLogCompare', net), 'and no log-compare dialog');

   (* The setting decides whether the operator is asked. *)
   CheckTrue(Pos('Settings.Server.AutoSynchronizeLogOnConnect',
                 BodyOf(sync, 'procedure DecideOnConnect(')) > 0,
             'SERVER AUTO SYNCHRONIZE LOG ON CONNECT is read where the decision is made');
   CheckTrue(Pos('YesOrNo(', BodyOf(sync, 'procedure DecideOnConnect(')) > 0,
             'and with it off the operator is asked');

   (* Nothing replaces the log, and the merge backs up before it writes. *)
   CheckEquals(0, Pos('ReplaceLogByServerLog', sync + net + form), 'the replace is gone');
   CheckEquals(0, Pos('CopyFile', sync), 'no file is copied over the log');
   CheckEquals(0, Pos('TR4W_LOG_FILENAME', sync), 'and the .TRW is not named');
   CheckEquals(0, Pos('LogStoreBackupPeriodic', sync), 'and the periodic backup slot is never used');
   CheckTrue(Pos('LogStoreBackupBeforeCatchUp', BodyOf(sync, 'function MergeServerLog(')) <
             Pos('LogStoreAppendQSOs', BodyOf(sync, 'function MergeServerLog(')),
             'the backup is taken before the write');
   CheckTrue(Pos('LogStoreBackupBeforeCatchUp', BodyOf(sync, 'function MergeServerLog(')) > 0,
             'and there is one');

   (* The window's second button adds. *)
   CheckTrue(Pos('AddServerLogToLog', BodyOf(form, 'procedure TfrmServerLog.HandleClose(')) > 0,
             'the window''s button adds the QSOs the log lacks');

   (* The menu row opens the window and sends nothing. *)
   CheckTrue(Pos('ShowServerLogSync', Between(mainText, 'menu_getserverlog:', 'menu_clearserverlog:')) > 0,
             'Net > Synchronize opens the window');
   CheckEquals(0, Pos('NET_LOGINFO_MESSAGE', Between(mainText, 'menu_getserverlog:', 'menu_clearserverlog:')),
               'and no longer asks the server for a CRC');
end;

procedure TNetCatchUpTests.RunAllTests;
begin
   Test_AnImageIsWholeOrRefused;
   Test_ALegacyContestIsJudgedByItsByteAndItsAuthor;
   Test_AContestByIdIsJudgedByItsAuthorThenItsByte;
   Test_ThePlanAddsOnlyWhatTheLogLacks;
   Test_ACaughtUpRecordIsOursSentAndClean;
   Test_APlanOverALargeLogIsFast;

   Test_TheDownloadIsExactlyWhatTheServerSent;
   Test_TheDownloadSendsTenPasswordBytes;
   Test_AServerThatStopsShortIsReportedAndTheImageRefusesIt;
   Test_AnImpossibleSizeIsRefusedBeforeAnyByteIsRead;
   Test_NothingListeningIsReportedByName;

   Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
   Test_WhatIsAddedIsSentCleanAssumedAndOfThisContest;
   Test_AVerifiedBackupIsTakenFirst;
   Test_TheDatedNamesAreOneRuleWithAPurpose;
   Test_WithoutABackupNothingIsWritten;
   Test_DoingItTwiceAddsNothingTheSecondTime;
   Test_ARecordThatWillNotGoInLeavesTheLogAsItWas;
   Test_ARecordTheLogReceivedLiveMeanwhileIsNotAddedTwice;
   Test_AnEmptyServerLogChangesNothing;

   Test_TheWiringIsWhatTheDesignSays;
end;

end.
