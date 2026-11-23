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
  -- Phase 1, C6, 2026-10-27; REBUILT FOR PROTOCOL 5 (W3+W5, 2026-11-22).

  THREE LAYERS.

  uNetCatchUp, ALONE: the server's log as the rows its sync port sent (the image,
  keyed by GUID), the one contest comparison from the header, the plan -- what a
  catch-up would add and why it leaves each of the others -- and the push plan:
  only rows LOGGED HERE that the server's guid set lacks. No store, no socket.

  THE DOWNLOAD (uGetServerLog.FetchServerLog) is run against a REAL socket: an
  in-process TIdTCPServer on loopback that plays the server's sync port -- reads
  the password, writes the header frame and the row frames (4-byte length, UTF-8
  JSON) -- so what is pinned is the client's side of the protocol: ten password
  bytes, exact frames however TCP cuts them (a 1 MB stream split into odd
  chunks), a server that stops short, an impossible length, a row whose checksum
  does not match, and a server that is not there.

  THE MERGE, over a REAL SQLite log in a scratch directory (uGetServerLog.
  MergeServerLog): absent rows go in VERBATIM under the sender's guid, station
  facts and my_source as sent (NY4I ruling 2), and present rows are not touched,
  even when the server's copy differs; a row with no guid is skipped; what is
  added is sent and clean; a verified backup is taken first and without one
  nothing is written; a row the log refuses leaves it as it was; doing it twice
  adds nothing the second time; and a server on another contest is refused whole.

  WHAT IT CANNOT REACH: a real server's sync port (tools/netprobe's `catchup`
  case, against both servers), the thread and the question asked of the
  operator, and two stations. Those are BENCH_QUEUE. *)
unit uTestNetCatchUp;

{$I ..\..\src\tr4w.inc}

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, VC, uTR4WTestFramework,
   uTestNetSupport, uNetCatchUp, uNetHello, uWireQso;

type
   TNetCatchUpTests = class(TNetStoreTestCase)
   public
      procedure RunAllTests; override;

   private
      (* THE FIXTURE SYNC PORT. What the server writes after the password: FStream
        (a header frame and row frames, built by the test), cut short at
        FSendOnly bytes when that is >= 0, in chunks of the sizes in FChunks. *)
      FServer: TIdTCPServer;
      FStream: TBytes;
      FSendOnly: integer;
      FChunks: array of integer;
      FPasswordSeen: TBytes;
      FLock: TCriticalSection;
      procedure ServerExecute(AContext: TIdContext);
      function StartServer: Word;
      procedure StopServer;
      (* A sync stream: the header frame and aRows row frames. *)
      function StreamOf(aRows: integer; const aContest: string): TBytes;
      (* A row as the server holds it: a guid, a call, the station that logged it. *)
      function Row(aN: integer; const aComputerId: string = 'B'): TWireValues;
      function BackupFolder: string;
      function Guid(aN: integer): string;
      function ComputerLetter: string;

      (* uNetCatchUp alone. *)
      procedure Test_AnImageHoldsTheRowsTheHeaderPromised;
      procedure Test_TheContestIsComparedOnceByIdString;
      procedure Test_ThePlanAddsOnlyWhatTheLogLacks;
      procedure Test_APushPlanSendsOnlyRowsLoggedHereThatTheServerLacks;
      procedure Test_TheDecisionOnConnectAsksAtMostOnce;
      procedure Test_APlanOverALargeLogIsFast;

      (* The download, against a fixture sync port. *)
      procedure Test_TheDownloadIsExactlyWhatTheServerSent;
      procedure Test_AOneMegabyteStreamSplitIntoOddChunksArrivesWhole;
      procedure Test_TheDownloadSendsTenPasswordBytes;
      procedure Test_AServerThatStopsShortIsReported;
      procedure Test_AnImpossibleFrameOrCountIsRefused;
      procedure Test_ARowWithABadChecksumEndsTheDownload;
      procedure Test_NothingListeningIsReportedByName;

      (* The merge, over a scratch log. *)
      procedure Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
      procedure Test_AnAddedRowIsTheSendersVerbatimSentAndClean;
      procedure Test_AVerifiedBackupIsTakenFirst;
      procedure Test_TheDatedNamesAreOneRuleWithAPurpose;
      procedure Test_WithoutABackupNothingIsWritten;
      procedure Test_DoingItTwiceAddsNothingTheSecondTime;
      procedure Test_ARowThatWillNotGoInLeavesTheLogAsItWas;
      procedure Test_ARowTheLogReceivedLiveMeanwhileIsNotAddedTwice;
      procedure Test_AnEmptyServerLogChangesNothing;
      procedure Test_AServerOnAnotherContestIsRefusedWhole;
      procedure Test_ThePushOnlyEverSendsRowsLoggedHere;

      (* The wiring, by source. *)
      procedure Test_TheWiringIsWhatTheDesignSays;
   end;

implementation

uses
   StrUtils, TF, uNet, uNetClient, uNetFraming, uComputerID, uContestRegistry, PostUnit,
   uLogStore, uGuidSet, uGetServerLog, uQsoColumns, uLogRepository, uSettingsModel;

const
   (* The station-id every test peer announces itself as. *)
   PEER = 2;

(* --------------------------------------------------------------------------- *)
(* builders                                                                     *)
(* --------------------------------------------------------------------------- *)

function TNetCatchUpTests.Guid(aN: integer): string;
begin
   Result := Format('00000000-0000-4000-8000-%.12d', [aN]);
end;

function TNetCatchUpTests.ComputerLetter: string;
begin
   Result := 'A';
end;

function TNetCatchUpTests.Row(aN: integer; const aComputerId: string): TWireValues;
begin
   Result := MakeWireRow(Guid(aN), 'K' + IntToStr(aN), aComputerId);
   (* THE STATION FACTS THE SENDER RECORDED travel with the row. *)
   SetWireValue(Result, 'my_call', 'W1AW');
   SetWireValue(Result, 'my_source', 'logged');
   SetWireValue(Result, 'my_grid', 'FN31');
   SetWireValue(Result, 'exchange_sent', '599 CT');
end;

function TNetCatchUpTests.BackupFolder: string;
begin
   Result := IncludeTrailingPathDelimiter(FDir) + 'backup';
end;

function TNetCatchUpTests.StreamOf(aRows: integer; const aContest: string): TBytes;
var
   frame: TBytes;
   n, at: integer;

   procedure Put;
   var
      k: integer;
   begin
      SetLength(Result, at + Length(frame));
      for k := 0 to High(frame) do
         begin
         Result[at + k] := frame[k];
         end;
      Inc(at, Length(frame));
   end;

begin
   Result := nil;
   at := 0;
   frame := BuildSyncHeaderFrame(aContest, aRows);
   Put;
   for n := 1 to aRows do
      begin
      frame := BuildSyncRowFrame(QsoWireColumns, Row(n));
      Put;
      end;
end;

(* --------------------------------------------------------------------------- *)
(* uNetCatchUp alone                                                            *)
(* --------------------------------------------------------------------------- *)

procedure TNetCatchUpTests.Test_AnImageHoldsTheRowsTheHeaderPromised;
var
   image: TServerLogImage;
   deleted, note: TWireValues;
begin
   BeginTest('a server image holds the rows its header promised, by guid');
   deleted := Row(2);
   SetWireValue(deleted, 'deleted', '1');
   note := Row(3);
   SetWireValue(note, 'record_kind', 'NOTE');

   image := NewImage([Row(1), deleted, note], 'ARRLDXCW');
   try
      CheckEquals('ARRLDXCW', image.Contest, 'the contest the header named');
      CheckEquals(3, image.DeclaredRows, 'and how many rows it promised');
      CheckEquals(3, image.Count, 'three rows held');
      CheckEquals(1, image.QsoCount, 'and one counts: a deleted QSO and a note do not');
      CheckEquals('K2', WireValue(image.Row(1), 'callsign'), 'a row can be read back by position');
      CheckEquals(0, Length(image.Row(3)), 'one past the end is nothing');
      CheckEquals(0, Length(image.Row(-1)), 'and so is before the start');
      CheckTrue(image.HoldsGuid(Guid(1)), 'a guid the server holds');
      CheckFalse(image.HoldsGuid(Guid(9)), 'and one it does not');
      CheckFalse(image.HoldsGuid(''), 'the empty guid is never held');
   finally
      image.Free;
   end;
end;

procedure TNetCatchUpTests.Test_TheContestIsComparedOnceByIdString;
begin
   BeginTest('the server''s contest is compared once, by id string, ignoring case');
   CheckTrue(JudgeSyncContest('ARRLDXCW', 'ARRLDXCW') = scSame, 'the same id');
   CheckTrue(JudgeSyncContest('arrldxcw', 'ARRLDXCW') = scSame, 'the compare ignores case');
   CheckTrue(JudgeSyncContest('', 'ARRLDXCW') = scServerNone,
             'a server that names none holds nothing yet: nothing to refuse');
   CheckTrue(JudgeSyncContest('CQWWCW', 'ARRLDXCW') = scOther,
             'another contest is refused whole');
end;

procedure TNetCatchUpTests.Test_ThePlanAddsOnlyWhatTheLogLacks;
var
   held: TGuidSet;
   image: TServerLogImage;
   plan: TCatchUpPlan;
   noGuid: TWireValues;
begin
   BeginTest('the plan adds only what the log lacks, each once, and says why it left the rest');
   held := TGuidSet.Create;
   try
      held.Add(Guid(1));
      noGuid := Row(5);
      SetWireValue(noGuid, 'guid', '');
      image := NewImage([Row(1), Row(2), Row(3), noGuid, Row(2), Row(4)], 'ARRLDXCW');
      try
         plan := BuildCatchUpPlan(image, held);
         try
            CheckEquals(3, plan.Count, 'rows 2, 3 and 4 are to be added');
            CheckEquals(1, plan.Skipped(cusAlreadyHeld), 'one is held');
            CheckEquals(1, plan.Skipped(cusNoIdentity), 'one names nothing');
            CheckEquals(1, plan.Skipped(cusRepeated), 'one is the server''s own repeat');
            CheckEquals('K5', plan.FirstCallSkipped(cusNoIdentity), 'the first skipped is named');
            CheckEquals(1, plan.RowIndex(0), 'in the server''s order');
            CheckEquals(5, plan.RowIndex(2), 'and each once');
            CheckTrue(Pos('3 to add', CatchUpSummary(plan)) = 1, 'the summary: ' + CatchUpSummary(plan));
            CheckEquals(1, held.Count, 'it still holds one');
         finally
            plan.Free;
         end;
      finally
         image.Free;
      end;
   finally
      held.Free;
   end;
end;

(* NY4I RULING 3: A STATION PUSHES ONLY ROWS LOGGED HERE. A row copied from a peer
  by an older build carries a local guid unlike the original, so pushing it would
  duplicate it on the server. Rows the server holds, rows still owed, rows
  resent on this link, rows with no guid and repeats are left out, each counted. *)
procedure TNetCatchUpTests.Test_APushPlanSendsOnlyRowsLoggedHereThatTheServerLacks;
var
   image: TServerLogImage;
   plan: TPushPlan;
   resent: TGuidSet;
   noGuid: TWireValues;
begin
   BeginTest('a push plan sends only rows logged here that the server lacks');
   resent := TGuidSet.Create;
   image := NewImage([Row(1, 'A')], 'ARRLDXCW');
   try
      resent.Add(Guid(5));
      plan := TPushPlan.Create(image, 'A', resent);
      try
         noGuid := Row(9, 'A');
         SetWireValue(noGuid, 'guid', '');

         CheckTrue(plan.Consider(101, Row(1, 'A')) = pvServerHas, 'the server holds it');
         CheckTrue(plan.Consider(102, Row(2, 'A')) = pvSend, 'logged here, the server lacks it');
         CheckTrue(plan.Consider(103, Row(3, 'B')) = pvNotLoggedHere,
                   'LOGGED AT ANOTHER STATION: never pushed from here');
         CheckTrue(plan.Consider(104, Row(4, 'A'), True) = pvOwed, 'still owed: the resend sends it');
         CheckTrue(plan.Consider(105, Row(5, 'A')) = pvOwed, 'posted by the resend on this link');
         CheckTrue(plan.Consider(106, noGuid) = pvNoIdentity, 'no guid names nothing');
         CheckTrue(plan.Consider(107, Row(2, 'A')) = pvRepeated, 'this log''s own repeat: once');
         CheckTrue(plan.Consider(108, Row(6, 'A')) = pvSend, 'another to send');

         CheckEquals(2, plan.Count, 'two rows to send');
         CheckEquals(102, integer(plan.RowId(0)), 'the row ids go with them, in order');
         CheckEquals(108, integer(plan.RowId(1)), 'both');
         CheckEquals('K6', WireValue(plan.Row(1), 'callsign'), 'and the values');
         CheckEquals(1, plan.Verdicts(pvNotLoggedHere), 'the other station''s row is counted');
         CheckTrue(plan.ServerHolds(Guid(1)) and (not plan.ServerHolds(Guid(2))),
                   'the repository asks the plan what the server holds');
         CheckTrue(Pos('2 to send', PushSummary(plan)) = 1, 'the summary: ' + PushSummary(plan));
      finally
         plan.Free;
      end;
   finally
      image.Free;
      resent.Free;
   end;
end;

procedure TNetCatchUpTests.Test_TheDecisionOnConnectAsksAtMostOnce;
begin
   BeginTest('the decision on connect asks at most once');
   CheckTrue(SyncOnConnect(0, 0, False) = socNothing, 'both complete: nothing is said');
   CheckTrue(SyncOnConnect(0, 0, True) = socNothing, 'even with auto on');
   CheckTrue(SyncOnConnect(3, 0, True) = socDoNow, 'auto on: just do it');
   CheckTrue(SyncOnConnect(3, 2, True) = socDoNow, 'both directions, auto on: do it');
   CheckTrue(SyncOnConnect(3, 0, False) = socAskPull, 'only the server has something: ask');
   CheckTrue(SyncOnConnect(0, 2, False) = socAskPush, 'only this log has: ask');
   CheckTrue(SyncOnConnect(3, 2, False) = socAskBoth, 'both: ONE question covering both');
end;

procedure TNetCatchUpTests.Test_APlanOverALargeLogIsFast;
const
   ROWS = 20000;
   HELD_ROWS = 10000;
var
   image: TServerLogImage;
   held: TGuidSet;
   plan: TCatchUpPlan;
   i: integer;
   started, planMs: QWord;
begin
   BeginTest('a plan over 20,000 server rows against 10,000 held is fast');
   image := TServerLogImage.Create;
   held := TGuidSet.Create;
   try
      image.StartImage('ARRLDXCW', ROWS);
      for i := 1 to ROWS do
         begin
         image.AddRow(Row(i));
         end;
      for i := 1 to HELD_ROWS do
         begin
         held.Add(Guid(i));
         end;

      started := GetTickCount64;
      plan := BuildCatchUpPlan(image, held);
      planMs := GetTickCount64 - started;
      try
         CheckEquals(ROWS - HELD_ROWS, plan.Count, 'half of them are missing');
         CheckEquals(HELD_ROWS, plan.Skipped(cusAlreadyHeld), 'half are held');
         WriteLn('[info] ', ROWS, ' rows planned against ', HELD_ROWS, ' held in ', planMs, ' ms');
         CheckTrue(planMs < 10000, 'the plan took ' + IntToStr(planMs) + ' ms');
      finally
         plan.Free;
      end;
   finally
      held.Free;
      image.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the download, against a fixture sync port                                    *)
(* --------------------------------------------------------------------------- *)

(* THE SERVER'S SYNC PORT, AS BOTH OUR SERVERS PLAY IT: read what the client
  writes as its password (up to 50 bytes, whatever has arrived), write the stream
  (header frame, row frames), then close. The test decides what the stream is,
  how much of it is actually sent and in what chunk sizes. *)
procedure TNetCatchUpTests.ServerExecute(AContext: TIdContext);
var
   raw: TIdBytes;
   got, sendCount, i, at, take, k: integer;
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

   sendCount := Length(FStream);
   if (FSendOnly >= 0) and (FSendOnly < sendCount) then
      begin
      sendCount := FSendOnly;
      end;
   at := 0;
   k := 0;
   while at < sendCount do
      begin
      take := sendCount - at;
      if Length(FChunks) > 0 then
         begin
         if FChunks[k mod Length(FChunks)] < take then
            begin
            take := FChunks[k mod Length(FChunks)];
            end;
         Inc(k);
         end;
      AContext.Connection.IOHandler.Write(RawToBytes(FStream[at], take));
      Inc(at, take);
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

procedure TNetCatchUpTests.Test_TheDownloadIsExactlyWhatTheServerSent;
var
   image: TServerLogImage;
   why: string;
   port: Word;
   i: integer;
   same: boolean;
begin
   BeginTest('the download is exactly the rows the server sent');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(300, 'ARRLDXCW');
      FSendOnly := -1;
      FChunks := nil;
      port := StartServer;
      try
         CheckTrue(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                  image, why), 'the download succeeds: ' + why);
      finally
         StopServer;
      end;

      CheckEquals('ARRLDXCW', image.Contest, 'the header''s contest');
      CheckEquals(300, image.DeclaredRows, 'the header''s count');
      CheckEquals(300, image.Count, 'and every row arrived');
      same := True;
      for i := 1 to 300 do
         begin
         if (WireValue(image.Row(i - 1), 'guid') <> Guid(i)) or
            (WireValue(image.Row(i - 1), 'callsign') <> 'K' + IntToStr(i)) or
            (WireValue(image.Row(i - 1), 'my_source') <> 'logged') then
            begin
            same := False;
            end;
         end;
      CheckTrue(same, 'each row is the row sent, in order, my_* as sent');
   finally
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* THE 1 MB STREAM, CUT INTO ODD CHUNKS. 3,200 rows is a little over a megabyte; the
  server writes it 1, 7, 13, 509, 4,093 and 65,537 bytes at a time, so every frame
  boundary and every length prefix is split somewhere in the run. *)
procedure TNetCatchUpTests.Test_AOneMegabyteStreamSplitIntoOddChunksArrivesWhole;
const
   ROWS = 3200;
var
   image: TServerLogImage;
   why: string;
   port: Word;
begin
   BeginTest('a one-megabyte sync stream split into odd chunks arrives whole');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(ROWS, 'ARRLDXCW');
      CheckTrue(Length(FStream) > 1000 * 1000, 'the stream is over a megabyte: ' +
                IntToStr(Length(FStream)));
      FSendOnly := -1;
      SetLength(FChunks, 6);
      FChunks[0] := 1;
      FChunks[1] := 7;
      FChunks[2] := 13;
      FChunks[3] := 509;
      FChunks[4] := 4093;
      FChunks[5] := 65537;
      port := StartServer;
      try
         CheckTrue(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                  image, why), 'the download succeeds: ' + why);
      finally
         StopServer;
      end;
      CheckEquals(ROWS, image.Count, 'every row arrived');
      CheckEquals(Guid(ROWS), WireValue(image.Row(ROWS - 1), 'guid'), 'the last is the last sent');
      CheckEquals(Guid(1), WireValue(image.Row(0), 'guid'), 'and the first the first');
   finally
      FChunks := nil;
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* THE PASSWORD IS TEN BYTES, NUL PADDED -- what D7's client wrote with
  send(buf, 10). The in-tree server's sync port once waited for fifty. *)
procedure TNetCatchUpTests.Test_TheDownloadSendsTenPasswordBytes;
var
   image: TServerLogImage;
   why: string;
   port: Word;
   seen: TBytes;
begin
   BeginTest('the download writes the password as ten bytes, NUL padded');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(1, 'ARRLDXCW');
      FSendOnly := -1;
      FChunks := nil;
      port := StartServer;
      try
         CheckTrue(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('PW'),
                                  image, why), 'the download succeeds: ' + why);
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
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* A SERVER THAT STOPS SHORT -- a link cut mid-transfer -- is a failed download
  that says how far it got. *)
procedure TNetCatchUpTests.Test_AServerThatStopsShortIsReported;
var
   image: TServerLogImage;
   why: string;
   port: Word;
begin
   BeginTest('a server that stops short is reported with how far it got');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(10, 'ARRLDXCW');
      FSendOnly := Length(FStream) div 2;
      FChunks := nil;
      port := StartServer;
      try
         CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                   image, why), 'the download fails');
      finally
         StopServer;
      end;
      CheckTrue(Pos(' of 10 row(s)', why) > 0, 'and says how far it got: ' + why);
      CheckTrue(image.Count < 10, 'and the image is not whole');
   finally
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* NOTHING IS GUESSED: a frame over the limit, a count past the limit and a schema
  this build does not speak each end the download with the reason. *)
procedure TNetCatchUpTests.Test_AnImpossibleFrameOrCountIsRefused;
var
   image: TServerLogImage;
   why: string;
   port: Word;
   bad: TBytes;
   header: TBytes;
   i: integer;

   function Run(const aStream: TBytes): boolean;
   begin
      FStream := aStream;
      FSendOnly := -1;
      FChunks := nil;
      image.Free;
      image := TServerLogImage.Create;
      port := StartServer;
      try
         Result := FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                  image, why);
      finally
         StopServer;
      end;
   end;

begin
   BeginTest('an impossible frame length, count or schema is refused');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      (* A frame longer than the protocol's limit. *)
      SetLength(bad, 8);
      for i := 0 to High(bad) do
         begin
         bad[i] := 0;
         end;
      PutCardinalLE(bad, 0, NET_RECEIVE_BUFFER_SIZE + 1);
      CheckFalse(Run(bad), 'an oversize header frame fails');
      CheckTrue(Pos('limit', why) > 0, 'and says so: ' + why);

      (* More rows than any contest has. *)
      CheckFalse(Run(BuildSyncHeaderFrame('ARRLDXCW', SERVER_LOG_MAX_ROWS + 1)),
                 'a count past the limit fails');
      CheckTrue(Pos('cannot read', why) > 0, 'and says so: ' + why);
      CheckEquals(0, image.Count, 'and nothing was read');

      (* Another schema: the header says 4. *)
      header := BuildSyncHeaderFrame('ARRLDXCW', 0);
      for i := 4 to High(header) do
         begin
         if (header[i] = Ord('5')) and ((header[i - 1] = Ord(':')) or (header[i - 1] = Ord(' '))) then
            begin
            header[i] := Ord('4');
            end;
         end;
      CheckFalse(Run(header), 'a header of another schema fails');
      CheckTrue(Pos('schema 4', why) > 0, 'and names it: ' + why);
   finally
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* A ROW WHOSE CHECKSUM DOES NOT MATCH ENDS THE DOWNLOAD, naming the row: a station
  that took it would store a row nobody can vouch for. *)
procedure TNetCatchUpTests.Test_ARowWithABadChecksumEndsTheDownload;
var
   image: TServerLogImage;
   why: string;
   port: Word;
   frame: TBytes;
   at, i: integer;
begin
   BeginTest('a row with a bad checksum ends the download and names the row');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(3, 'ARRLDXCW');
      (* Flip a byte inside the LAST frame's JSON (its callsign). *)
      frame := BuildSyncRowFrame(QsoWireColumns, Row(3));
      at := Length(FStream) - Length(frame);
      for i := at + 4 to High(FStream) do
         begin
         if (FStream[i] = Ord('K')) and (FStream[i + 1] = Ord('3')) then
            begin
            FStream[i + 1] := Ord('4');
            Break;
            end;
         end;
      FSendOnly := -1;
      FChunks := nil;
      port := StartServer;
      try
         CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                   image, why), 'the download fails');
      finally
         StopServer;
      end;
      CheckTrue(Pos('row 3 of 3', why) > 0, 'naming the row: ' + why);
      CheckEquals(2, image.Count, 'the two good rows before it were read');
   finally
      image.Free;
      FreeAndNil(FLock);
   end;
end;

procedure TNetCatchUpTests.Test_NothingListeningIsReportedByName;
var
   image: TServerLogImage;
   why: string;
   port: Word;
begin
   BeginTest('a server that is not there is reported with its address');
   FLock := TCriticalSection.Create;
   image := TServerLogImage.Create;
   try
      FStream := StreamOf(1, 'ARRLDXCW');
      FSendOnly := -1;
      FChunks := nil;
      (* A port that was listening a moment ago and is not now. *)
      port := StartServer;
      StopServer;

      CheckFalse(FetchServerLog('127.0.0.1', port, ServerPasswordOnWire('TR4WSERVER'),
                                image, why), 'the download fails');
      CheckTrue(Pos('could not connect to 127.0.0.1:' + IntToStr(port), why) > 0,
                'and names where it tried: ' + why);
   finally
      image.Free;
      FreeAndNil(FLock);
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the merge, over a scratch log                                                *)
(* --------------------------------------------------------------------------- *)

(* THE POINT OF INSERT-ONLY: the log keeps what it has. A row the server holds
  under the same guid, with a DIFFERENT callsign, is not applied; a row the
  station has not yet sent keeps its flags; and every absent row is added once.
  A row with no guid and a repeated guid are left. *)
procedure TNetCatchUpTests.Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
var
   image: TServerLogImage;
   added: integer;
   why, heldGuid: string;
   heldValues, differing, noGuid: TWireValues;
   rec: ContestExchange;
begin
   BeginTest('the merge adds what is absent and never touches what is present');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      AppendRow('K1HELD', 601, 1, True, False);
      AppendRow('K1MINE', 601, 9, False, True);
      heldGuid := RowGuid(601, 1);
      CheckTrue(heldGuid <> '', 'the held row has a guid');

      differing := Row(1);
      SetWireValue(differing, 'guid', heldGuid);
      SetWireValue(differing, 'callsign', 'K1DIFF');
      noGuid := Row(5);
      SetWireValue(noGuid, 'guid', '');

      image := NewImage([differing, Row(2), Row(3), Row(4), noGuid, Row(2)],
                        ContestId(Contest));
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'the merge succeeds: ' + why);
         CheckEquals(3, added, 'three QSOs were added');
         CheckEquals(5, LogRowCount, 'the log holds the two it had and the three');

         CheckTrue(RowWire(601, 1, heldValues), 'the held row is still there');
         CheckEquals('K1HELD', WireValue(heldValues, 'callsign'),
                     'and is NOT OVERWRITTEN by the server''s differing copy');
         CheckTrue(ReadRow(601, 9, rec), 'the unsent row is still there');
         CheckFalse(rec.ceSendToServer, 'it is still unsent');
         CheckTrue(rec.ceNeedSendToServerAE, 'and still dirty: the resend will take it up');

         CheckTrue((LogStoreRowIdByGuid(Guid(2)) <> 0) and (LogStoreRowIdByGuid(Guid(3)) <> 0) and
                   (LogStoreRowIdByGuid(Guid(4)) <> 0), 'the three new rows are in, by their guids');
         CheckEquals(1, integer(ScalarOfLogFile(FDb,
                     'SELECT COUNT(*) FROM qso WHERE callsign = ''K2''')),
                     'a guid twice in the server''s rows is added once');
         CheckEquals(0, integer(ScalarOfLogFile(FDb,
                     'SELECT COUNT(*) FROM qso WHERE callsign = ''K5''')),
                     'and the row that names nothing is not added');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* WHAT AN ADDED ROW IS (NY4I ruling 2): the sender's row VERBATIM -- its guid, its
  station facts and my_source and its sent exchange exactly as it sent them, a
  deleted QSO still deleted -- with only this database's own columns set: sent
  and clean, so the resend never sends it back. *)
procedure TNetCatchUpTests.Test_AnAddedRowIsTheSendersVerbatimSentAndClean;
var
   image: TServerLogImage;
   added, unsent, dirtyCount, i: integer;
   why: string;
   sentRow, deleted, back: TWireValues;
   rec: ContestExchange;
   same: boolean;
begin
   BeginTest('an added row is the sender''s, verbatim, and sent and clean');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      sentRow := Row(1, 'B');
      SetWireValue(sentRow, 'rcvd_qth', 'CT');
      SetWireValue(sentRow, 'my_state', 'MA');
      SetWireValue(sentRow, 'serial_sent', '17');
      deleted := Row(2, 'B');
      SetWireValue(deleted, 'deleted', '1');
      image := NewImage([sentRow, deleted], ContestId(Contest));
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'the merge succeeds: ' + why);
         CheckEquals(2, added, 'both were added');

         CheckTrue(LogStoreReadWireValues(LogStoreRowIdByGuid(Guid(1)), back), 'read back');
         same := Length(back) = Length(sentRow);
         for i := 0 to High(sentRow) do
            begin
            if same and (back[i] <> sentRow[i]) then
               begin
               same := False;
               CheckEquals(sentRow[i], back[i], 'column ' + QsoWireColumns.Name[i]);
               end;
            end;
         CheckTrue(same, 'EVERY on-wire column is as the sender sent it');
         CheckEquals('logged', WireValue(back, 'my_source'),
                     'the sender''s my_source is kept (ruling 2 replaces ruling D)');
         CheckEquals('W1AW', WireValue(back, 'my_call'), 'and its station');
         CheckEquals('599 CT', WireValue(back, 'exchange_sent'), 'and the exchange it sent');
         CheckEquals('B', WireValue(back, 'computer_id'), 'and who logged it');

         CheckTrue(LogStoreRepository.LoadQSO(LogStoreRowIdByGuid(Guid(1)), rec), 'the row reads');
         CheckTrue(rec.ceSendToServer, 'sent: it came from the server');
         CheckFalse(rec.ceNeedSendToServerAE, 'clean');
         CheckTrue(LogStoreRepository.LoadQSO(LogStoreRowIdByGuid(Guid(2)), rec), 'the deleted one reads');
         CheckTrue(rec.ceQSO_Deleted, 'and is still deleted');

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
   added: integer;
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

      image := NewImage([Row(2), Row(3)], ContestId(Contest));
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'merged: ' + why);
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
   added: integer;
   why: string;
begin
   BeginTest('without a backup nothing is written');
   OpenScratchStore;
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      AppendRow('K1HELD', 631, 1, True, False);

      image := NewImage([Row(2)], ContestId(Contest));
      try
         CheckFalse(MergeServerLog(image, IncludeTrailingPathDelimiter(FDir) + 'no such folder',
                                   added, why),
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
   added: integer;
   why: string;
begin
   BeginTest('doing it twice adds nothing the second time');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      image := NewImage([Row(1), Row(2)], ContestId(Contest));
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'first: ' + why);
         CheckEquals(2, added, 'the first adds both');
         CheckEquals(2, LogRowCount, 'and the log holds them');

         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'second: ' + why);
         CheckEquals(0, added, 'THE SECOND ADDS NOTHING');
         CheckEquals(2, LogRowCount, 'the log is the same size');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* ALL OR NONE: one row the log refuses (a number that is not digits) and not even
  the good ones around it are written. The store stays usable -- the fault is
  the row's, not the log's. *)
procedure TNetCatchUpTests.Test_ARowThatWillNotGoInLeavesTheLogAsItWas;
var
   image: TServerLogImage;
   added: integer;
   why: string;
   bad: TWireValues;
begin
   BeginTest('a row the log refuses leaves the log as it was');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      AppendRow('K1HELD', 651, 1, True, False);

      bad := Row(3);
      SetWireValue(bad, 'freq_tx_hz', '14.025');
      image := NewImage([Row(2), bad, Row(4)], ContestId(Contest));
      try
         CheckFalse(MergeServerLog(image, BackupFolder, added, why), 'the merge fails');
         CheckTrue(Pos('could not be written', why) > 0, 'and says why: ' + why);
         CheckEquals(0, added, 'nothing is counted as added');
         CheckEquals(1, LogRowCount, 'THE LOG IS AS IT WAS');
         CheckEquals(0, integer(LogStoreRowIdByGuid(Guid(2))), 'not even the good row before it');
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
  also in the server's rows, is not added a second time. *)
procedure TNetCatchUpTests.Test_ARowTheLogReceivedLiveMeanwhileIsNotAddedTwice;
var
   image: TServerLogImage;
   added, missing: integer;
   why: string;
   rowId: Int64;
   save: TWireSave;
begin
   BeginTest('a QSO logged live while the question was open is not added again');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      image := NewImage([Row(1), Row(2)], ContestId(Contest));
      try
         CheckTrue(CountMissingFromServer(image, missing), 'the count is read');
         CheckEquals(2, missing, 'two are missing when the operator is asked');

         (* The live arm stores row 1 meanwhile. *)
         CheckTrue(LogStoreSaveWireRow(Row(1), 661, 1, rowId, save), 'the live arm stored it');
         CheckTrue(save = wsInserted, 'as a new row');

         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'merged: ' + why);
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
   added: integer;
   why: string;
begin
   BeginTest('an empty server log changes nothing, and takes no backup');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      AppendRow('K1HELD', 671, 1, True, False);
      image := NewImage([], '');
      try
         CheckTrue(MergeServerLog(image, BackupFolder, added, why), 'merged: ' + why);
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

(* A SERVER ON ANOTHER CONTEST IS REFUSED WHOLE, from the header, once (design
  13.7 ruling 4): nothing is backed up, added or compared. *)
procedure TNetCatchUpTests.Test_AServerOnAnotherContestIsRefusedWhole;
var
   image: TServerLogImage;
   added: integer;
   why: string;
begin
   BeginTest('a server on another contest is refused whole');
   OpenScratchStore;
   ForceDirectories(BackupFolder);
   NetBeginLinkSession;
   try
      AppendRow('K1HELD', 681, 1, True, False);
      image := NewImage([Row(2), Row(3)], 'CQWWCW');
      try
         CheckFalse(MergeServerLog(image, BackupFolder, added, why),
                    'the merge is refused: our contest is ' + ContestId(Contest));
         CheckTrue(Pos('(the server)', why) > 0, 'with the existing contest-mismatch notice: ' + why);
         CheckEquals(0, added, 'nothing was added');
         CheckEquals(1, LogRowCount, 'the log is as it was');
         CheckFalse(FileExists(LogStorePeriodicBackupPath(BackupFolder)), 'and nothing was backed up');
      finally
         image.Free;
      end;
   finally
      CloseScratchStore;
   end;
end;

(* THE PUSH, END TO END over the scratch log and a stub writer: rows logged here
  that the server lacks go as OFFLINE messages (stored, not relayed); a row logged
  at ANOTHER station, and a row the server holds, never do. *)
procedure TNetCatchUpTests.Test_ThePushOnlyEverSendsRowsLoggedHere;
var
   image: TServerLogImage;
   plan: TPushPlan;
   link: TStubLink;
   posted: integer;
   savedId: AnsiChar;
begin
   BeginTest('the push sends only rows logged here that the server lacks');
   OpenScratchStore;
   NetBeginLinkSession;
   savedId := Settings.Computer.Id;
   Settings.Computer.Id := 'A';
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         FeedHello(0, '');
         FRowAuthor := 'A';
         AppendRow('K1MINE1', 701, 1, True, False);
         AppendRow('K1MINE2', 701, 2, True, False);
         FRowAuthor := 'B';
         AppendRow('K1THEIRS', 701, 3, True, False);
         FRowAuthor := 'A';
         AppendRow('K1HAVE', 701, 4, True, False);

         (* The server holds the last of ours only. *)
         image := NewImage([MakeWireRow(RowGuid(701, 4), 'K1HAVE', 'A')], ContestId(Contest));
         try
            CheckTrue(MakePushPlan(image, plan), 'the push is planned from the log');
            try
               CheckEquals(2, plan.Count, 'two rows: ours, and the server lacks them');
               CheckEquals(0, plan.Verdicts(pvServerHas), 'the server''s row is skipped by the repository before it is read');
               CheckTrue(RestockServer(plan, posted), 'the plan is posted');
               CheckEquals(2, posted, 'both');
            finally
               plan.Free;
            end;
         finally
            image.Free;
         end;
         CheckTrue(WaitWrites(link, 2), 'both were written');
         CheckEquals('OK1MINE1,OK1MINE2', link.WrittenText,
                     'as OFFLINE rows (stored, not relayed), ours and only ours');
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      Settings.Computer.Id := savedId;
      link.Free;
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
             Pos('LogStoreSaveWireRows', BodyOf(sync, 'function MergeServerLog(')),
             'the backup is taken before the write');
   CheckTrue(Pos('LogStoreBackupBeforeCatchUp', BodyOf(sync, 'function MergeServerLog(')) > 0,
             'and there is one');
   CheckEquals(0, Pos('NET_QSOINFO_ID', sync + net), 'no retired QSO id is named');
   CheckEquals(0, Pos('uServerQsoIndex', sync + net), 'and no pair index');

   (* The window's second button adds. *)
   CheckTrue(Pos('AddServerLogToLog', BodyOf(form, 'procedure TfrmServerLog.HandleClose(')) > 0,
             'the window''s button adds the QSOs the log lacks');

   (* The menu row opens the window and sends nothing. *)
   CheckTrue(Pos('ShowServerLogSync', Between(mainText, 'menu_getserverlog:', 'menu_clearserverlog:')) > 0,
             'Net > Add missing QSOs from the server opens the window');
   CheckEquals(0, Pos('NET_LOGINFO_MESSAGE', Between(mainText, 'menu_getserverlog:', 'menu_clearserverlog:')),
               'and no longer asks the server for a CRC');
end;

procedure TNetCatchUpTests.RunAllTests;
begin
   Test_AnImageHoldsTheRowsTheHeaderPromised;
   Test_TheContestIsComparedOnceByIdString;
   Test_ThePlanAddsOnlyWhatTheLogLacks;
   Test_APushPlanSendsOnlyRowsLoggedHereThatTheServerLacks;
   Test_TheDecisionOnConnectAsksAtMostOnce;
   Test_APlanOverALargeLogIsFast;

   Test_TheDownloadIsExactlyWhatTheServerSent;
   Test_AOneMegabyteStreamSplitIntoOddChunksArrivesWhole;
   Test_TheDownloadSendsTenPasswordBytes;
   Test_AServerThatStopsShortIsReported;
   Test_AnImpossibleFrameOrCountIsRefused;
   Test_ARowWithABadChecksumEndsTheDownload;
   Test_NothingListeningIsReportedByName;

   Test_TheMergeAddsWhatIsAbsentAndNeverTouchesWhatIsPresent;
   Test_AnAddedRowIsTheSendersVerbatimSentAndClean;
   Test_AVerifiedBackupIsTakenFirst;
   Test_TheDatedNamesAreOneRuleWithAPurpose;
   Test_WithoutABackupNothingIsWritten;
   Test_DoingItTwiceAddsNothingTheSecondTime;
   Test_ARowThatWillNotGoInLeavesTheLogAsItWas;
   Test_ARowTheLogReceivedLiveMeanwhileIsNotAddedTwice;
   Test_AnEmptyServerLogChangesNothing;
   Test_AServerOnAnotherContestIsRefusedWhole;
   Test_ThePushOnlyEverSendsRowsLoggedHere;

   Test_TheWiringIsWhatTheDesignSays;
end;

end.
