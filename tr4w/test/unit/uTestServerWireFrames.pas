unit uTestServerWireFrames;

(* WHAT THE SERVER DECIDES ABOUT ONE WIRE QSO MESSAGE -- protocol 5, design 13.7
  (issues 300 and 341): uServerWireFrames over a real TServerWireStore on a
  scratch SQLite file, with the real wire column list (uQsoColumns).

  The server program itself (tr4wserverUnit, uServerNet) cannot be linked into
  this binary (it needs Forms), so these tests drive the leaf it calls: the
  decision (stored / duplicate / refused / relayed / acknowledged) and the sync
  stream. The sending (relay re-stamp, the ACK after Release) is that unit's few
  lines and is proven by the netprobe cases against the real server.

  Every test uses a scratch directory under the temp directory, removed when the
  suite ends (NOT in TearDown: this framework calls TearDown after EVERY check). *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TServerWireFramesTests = class(TTestCase)
   private
      FDir: string;
      function ScratchFile(const aLeaf: string): string;
      procedure CleanUp;
   protected
      procedure Test_ANewRowIsStoredAndRelayedAndADuplicateIsNeither;
      procedure Test_ABadRowIsRefusedAndTheNextOneStillWorks;
      procedure Test_AnEditIsRelayedAndAckedWhetherOrNotTheRowIsHeld;
      procedure Test_AnOfflineRowIsStoredNeverRelayedAndAckedOnlyAfterTheRelease;
      procedure Test_TheContestIsTheFirstOneAnnouncedAndSurvivesARestart;
      procedure Test_TheSyncStreamIsOneSnapshotOfTheRowsInOrder;
      procedure Test_AClearIsBackedUpFirst;
      procedure Test_AllThreeKindsFrameAsWireMessages;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes,
   VC, uWireQso, uQsoColumns, uNetFraming, uNetHello, uServerWireStore, uServerWireFrames;

type
   (* Collects the frames the sync stream writes. *)
   TCollector = class
      Frames: array of TBytes;
      procedure Write(const aFrame: TBytes);
   end;

procedure TCollector.Write(const aFrame: TBytes);
begin
   SetLength(Frames, Length(Frames) + 1);
   Frames[High(Frames)] := Copy(aFrame, 0, Length(aFrame));
end;

function TServerWireFramesTests.ScratchFile(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_wireframes_' +
              IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TServerWireFramesTests.CleanUp;
var
   sr: TSearchRec;
begin
   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      if FindFirst(IncludeTrailingPathDelimiter(FDir) + '*', faAnyFile, sr) = 0 then
         begin
         repeat
            if (sr.Name <> '.') and (sr.Name <> '..') then
               begin
               DeleteFile(IncludeTrailingPathDelimiter(FDir) + sr.Name);
               end;
         until FindNext(sr) <> 0;
         FindClose(sr);
         end;
      RemoveDir(FDir);
      end;
   FDir := '';
end;

(* ---- helpers --------------------------------------------------------------- *)

function OpenStore(const aFile: string): TServerWireStore;
var
   why: string;
begin
   Result := TServerWireStore.Create(QsoWireColumns, aFile);
   if Result.Initialize(why) <> wsiReady then
      begin
      raise Exception.Create(AnsiString('the scratch store did not open: ' + why));
      end;
end;

procedure SetCol(var aRow: TWireValues; const aName, aValue: string);
begin
   aRow[QsoWireColumns.IndexOfName(aName)] := aValue;
end;

function MakeRow(const aGuid, aCall: string): TWireValues;
begin
   Result := QsoWireColumns.DefaultValues;
   SetCol(Result, 'guid', aGuid);
   SetCol(Result, 'callsign', aCall);
   SetCol(Result, 'band', '20');
   SetCol(Result, 'mode', 'CW');
   SetCol(Result, 'computer_id', 'A');
   SetCol(Result, 'serial_sent', '7');
end;

(* The payload (sender byte + JSON) of a message for this row. *)
function PayloadFor(const aKind: word; const aRow: TWireValues): TBytes;
var
   msg: TBytes;
begin
   msg := BuildWireMessage(aKind, 3, QsoWireColumns, aRow);
   Result := Copy(msg, NET_WIRE_HEADER_SIZE, Length(msg) - NET_WIRE_HEADER_SIZE);
end;

function ColOf(const aRow: TWireValues; const aName: string): string;
begin
   Result := aRow[QsoWireColumns.IndexOfName(aName)];
end;

(* ---- the tests ------------------------------------------------------------- *)

procedure TServerWireFramesTests.Test_ANewRowIsStoredAndRelayedAndADuplicateIsNeither;
var
   store: TServerWireStore;
   o: TWireFrameOutcome;
   row: TWireValues;
begin
   store := OpenStore(ScratchFile('new.tr4wsrv'));
   try
      row := MakeRow('guid-1', 'K1ABC');
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, PayloadFor(NET_WIRE_QSO_ID, row));
      Check(o.Take = wtOk, 'taken');
      Check(o.Stored = wiStored, 'stored');
      Check(o.Relay, 'a stored NEW row is relayed');
      CheckFalse(o.AckNow, 'a NEW row is not acknowledged (as before)');
      CheckEquals('K1ABC', o.Call, 'the call, for the log');
      CheckEquals(1, store.Count, 'one row');

      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, PayloadFor(NET_WIRE_QSO_ID, row));
      Check(o.Stored = wiDuplicate, 'the same guid again is a duplicate');
      CheckFalse(o.Relay, 'a duplicate is NOT relayed');
      CheckEquals(1, store.Count, 'and not stored twice');

      row := MakeRow('guid-2', 'W1AW');
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, PayloadFor(NET_WIRE_QSO_ID, row));
      Check(o.Relay and (o.Stored = wiStored), 'another guid is a new row');
      CheckEquals(2, store.Count, 'two rows');
   finally
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_ABadRowIsRefusedAndTheNextOneStillWorks;
var
   store: TServerWireStore;
   o: TWireFrameOutcome;
   good, bad: TBytes;
   i: integer;
begin
   store := OpenStore(ScratchFile('bad.tr4wsrv'));
   try
      good := PayloadFor(NET_WIRE_QSO_ID, MakeRow('guid-1', 'K1ABC'));
      bad := Copy(good, 0, Length(good));
      (* damage a byte of the callsign's value after the checksum was made *)
      for i := 1 to High(bad) do
         begin
         if bad[i] = Ord('K') then
            begin
            bad[i] := Ord('J');
            Break;
            end;
         end;
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, bad);
      Check(o.Take = wtBadChecksum, 'a bad checksum is refused');
      CheckFalse(o.Relay, 'not relayed');
      CheckFalse(o.AckNow or o.AckAfterRelease, 'not acknowledged');
      Check(o.Level = wlWarn, 'logged as a warning');
      CheckEquals(0, store.Count, 'not stored');

      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_OFFLINE_ID, Copy(bad, 0, Length(bad)));
      Check(o.Take = wtBadChecksum, 'an OFFLINE row with a bad checksum is refused too');
      CheckFalse(o.AckAfterRelease, 'and is not acknowledged');
      store.Release;

      SetLength(bad, 0);
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, bad);
      Check(o.Take = wtNoSender, 'an empty payload is refused');

      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, good);
      Check(o.Relay and (o.Stored = wiStored), 'the next good row is taken: the link was not dropped');
      CheckEquals(1, store.Count, 'one row');
   finally
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_AnEditIsRelayedAndAckedWhetherOrNotTheRowIsHeld;
var
   store: TServerWireStore;
   o: TWireFrameOutcome;
   row: TWireValues;
   rows: TWireRows;
begin
   store := OpenStore(ScratchFile('edit.tr4wsrv'));
   try
      row := MakeRow('guid-1', 'K1ABC');
      ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID, PayloadFor(NET_WIRE_QSO_ID, row));

      SetCol(row, 'callsign', 'K1XYZ');
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_EDIT_ID, PayloadFor(NET_WIRE_EDIT_ID, row));
      Check(o.Relay, 'an edit is relayed');
      Check(o.AckNow, 'and acknowledged');
      Check(store.ReadAll(rows), 'read');
      CheckEquals(1, Length(rows), 'still one row');
      CheckEquals('K1XYZ', ColOf(rows[0], 'callsign'), 'the whole row was rewritten');

      (* an edit for a guid the server never held: relayed and ACKed, not stored *)
      row := MakeRow('guid-never', 'N0PE');
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_EDIT_ID, PayloadFor(NET_WIRE_EDIT_ID, row));
      Check(o.Relay and o.AckNow, 'an unheld edit is relayed and acknowledged');
      CheckEquals(1, store.Count, 'and nothing is stored');

      (* a bad edit is refused and NOT relayed *)
      o := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_EDIT_ID, Copy(PayloadFor(NET_WIRE_EDIT_ID, row), 0, 5));
      Check(o.Take <> wtOk, 'a truncated edit is refused');
      CheckFalse(o.Relay or o.AckNow, 'not relayed, not acknowledged');
   finally
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_AnOfflineRowIsStoredNeverRelayedAndAckedOnlyAfterTheRelease;
var
   store: TServerWireStore;
   o1, o2, o3: TWireFrameOutcome;
   row: TWireValues;
   rows: TWireRows;
begin
   store := OpenStore(ScratchFile('offline.tr4wsrv'));
   try
      row := MakeRow('guid-1', 'K1ABC');
      o1 := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_OFFLINE_ID, PayloadFor(NET_WIRE_OFFLINE_ID, row));
      Check(o1.Stored = wiStored, 'stored');
      CheckFalse(o1.Relay, 'an OFFLINE row is never relayed');
      CheckFalse(o1.AckNow, 'and is not acknowledged at once');
      Check(o1.AckAfterRelease, 'its ACK waits for the commit');

      row := MakeRow('guid-2', 'W1AW');
      o2 := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_OFFLINE_ID, PayloadFor(NET_WIRE_OFFLINE_ID, row));
      Check(o2.AckAfterRelease, 'the second too');

      (* a duplicate of a row already held is acknowledged and not stored again *)
      o3 := ProcessWireFrame(store, QsoWireColumns, NET_WIRE_OFFLINE_ID, PayloadFor(NET_WIRE_OFFLINE_ID, row));
      Check(o3.Stored = wiDuplicate, 'a duplicate');
      Check(o3.AckAfterRelease and (not o3.Relay), 'acknowledged, not relayed');

      (* BEFORE the release nothing is durable: a reader on its own connection sees nothing *)
      Check(store.ReadAll(rows), 'read');
      CheckEquals(0, Length(rows), 'the held run is not committed yet');
      Check(store.Release, 'the release commits');
      Check(store.ReadAll(rows), 'read again');
      CheckEquals(2, Length(rows), 'both rows are durable after the release');
      Check(store.Release, 'a release with nothing held is a success');
   finally
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_TheContestIsTheFirstOneAnnouncedAndSurvivesARestart;
var
   store: TServerWireStore;
   name: string;
   rows: TWireRows;
   contest: string;
begin
   name := ScratchFile('contest.tr4wsrv');
   store := OpenStore(name);
   try
      CheckEquals('', store.Contest, 'a new log holds no contest');
      CheckFalse(store.RememberContest(''), 'an empty id is not recorded');
      Check(store.RememberContest('ARRL-DX-CW'), 'the first station''s contest is recorded');
      CheckFalse(store.RememberContest('CQ-WW-SSB'), 'a later announcement changes nothing');
      CheckEquals('ARRL-DX-CW', store.Contest, 'still the first');
      Check(store.ReadAll(rows, contest), 'read');
      CheckEquals('ARRL-DX-CW', contest, 'ReadAll names it in the same snapshot');
   finally
      store.Free;
   end;

   store := OpenStore(name);
   try
      CheckEquals('ARRL-DX-CW', store.Contest, 'it survives a restart');
      store.ForgetContest;
      CheckEquals('', store.Contest, 'a cleared log forgets it');
      Check(store.RememberContest('CQ-WW-SSB'), 'and the next station''s is taken');
   finally
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_TheSyncStreamIsOneSnapshotOfTheRowsInOrder;
var
   store: TServerWireStore;
   sink: TCollector;
   rowsIn: TWireRows;
   got: TWireValues;
   rows, schema, n, i: integer;
   contest, why: string;
begin
   store := OpenStore(ScratchFile('sync.tr4wsrv'));
   sink := TCollector.Create;
   try
      store.RememberContest('NAQP-CW');
      for i := 1 to 5 do
         begin
         ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID,
                          PayloadFor(NET_WIRE_QSO_ID, MakeRow('guid-' + IntToStr(i), 'K' + IntToStr(i) + 'ABC')));
         end;

      Check(SendSyncStream(store, QsoWireColumns, sink.Write, rows), 'the stream is made');
      CheckEquals(5, rows, 'five rows');
      CheckEquals(6, Length(sink.Frames), 'a header and five rows');

      n := Integer(GetCardinalLE(sink.Frames[0], 0));
      CheckEquals(Length(sink.Frames[0]) - 4, n, 'the header frame is length + JSON');
      Check(TakeSyncHeader(Copy(sink.Frames[0], 4, n), contest, rows, schema), 'the header parses');
      CheckEquals('NAQP-CW', contest, 'the contest');
      CheckEquals(5, rows, 'the row count');
      CheckEquals(NET_PROTOCOL_VERSION, schema, 'the schema');

      for i := 1 to 5 do
         begin
         n := Integer(GetCardinalLE(sink.Frames[i], 0));
         CheckEquals(Length(sink.Frames[i]) - 4, n, 'row frame ' + IntToStr(i));
         Check(TakeSyncRow(QsoWireColumns, Copy(sink.Frames[i], 4, n), got, why) = wtOk, 'row parses: ' + why);
         CheckEquals('guid-' + IntToStr(i), ColOf(got, 'guid'), 'arrival order, row ' + IntToStr(i));
         CheckEquals('K' + IntToStr(i) + 'ABC', ColOf(got, 'callsign'), 'callsign ' + IntToStr(i));
         CheckEquals('7', ColOf(got, 'serial_sent'), 'a number survives');
         end;

      (* the rows in the frames are exactly what ReadAll returns *)
      Check(store.ReadAll(rowsIn), 'read');
      CheckEquals(5, Length(rowsIn), 'five in the store');
   finally
      sink.Free;
      store.Free;
   end;
end;

procedure TServerWireFramesTests.Test_AClearIsBackedUpFirst;
var
   store, restored: TServerWireStore;
   backup, why: string;
begin
   store := OpenStore(ScratchFile('clear.tr4wsrv'));
   try
      ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID,
                       PayloadFor(NET_WIRE_QSO_ID, MakeRow('guid-1', 'K1ABC')));
      ProcessWireFrame(store, QsoWireColumns, NET_WIRE_QSO_ID,
                       PayloadFor(NET_WIRE_QSO_ID, MakeRow('guid-2', 'W1AW')));
      backup := ScratchFile('clear before.tr4wsrv');
      Check(store.BackupTo(backup, why), 'the backup is taken: ' + why);
      CheckFalse(store.BackupTo(backup, why), 'a backup never overwrites');
      Check(why <> '', 'and says why');
      Check(store.Clear, 'cleared');
      CheckEquals(0, store.Count, 'the log is empty');
   finally
      store.Free;
   end;

   restored := OpenStore(backup);
   try
      CheckEquals(2, restored.Count, 'the backup is a whole, openable server log holding both rows');
   finally
      restored.Free;
   end;
end;

procedure TServerWireFramesTests.Test_AllThreeKindsFrameAsWireMessages;
var
   msg: TBytes;
   row: TWireValues;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   row := MakeRow('guid-1', 'K1ABC');
   msg := BuildWireMessage(NET_WIRE_QSO_ID, 1, QsoWireColumns, row);
   Check(Length(msg) < NET_WIRE_MAX_PAYLOAD, 'a real row is far under the cap');
   offset := 1;
   Check(NextNetMessage(msg, Length(msg), offset, id, res), 'a real row frames');
   CheckEquals(NET_WIRE_QSO_ID, id, 'with its id');
   Check(OutboundWireMessageIsWellFormed(msg), 'and passes the outbound check');
end;

procedure TServerWireFramesTests.RunAllTests;
begin
   try
      Test_ANewRowIsStoredAndRelayedAndADuplicateIsNeither;
      Test_ABadRowIsRefusedAndTheNextOneStillWorks;
      Test_AnEditIsRelayedAndAckedWhetherOrNotTheRowIsHeld;
      Test_AnOfflineRowIsStoredNeverRelayedAndAckedOnlyAfterTheRelease;
      Test_TheContestIsTheFirstOneAnnouncedAndSurvivesARestart;
      Test_TheSyncStreamIsOneSnapshotOfTheRowsInOrder;
      Test_AClearIsBackedUpFirst;
      Test_AllThreeKindsFrameAsWireMessages;
   finally
      CleanUp;
   end;
end;

end.
