unit uTestServerLogStore;
{$I ..\..\src\tr4w.inc}

(*
   THE TR4WSERVER LOG SEAM (design note P1, 2026-11-19): TFileServerLogStore over
   a scratch SERVERLOG.TRW. The server unit is not linked into this binary; the
   leaf it calls is, and carries every decision. The same bodies ran in
   tr4wserverUnit before the move, and the P0 sync-port baselines
   (tools/netprobe/Run-SyncBaseline.ps1) pin the bytes through a real server;
   these pin what no probe case reaches (the flag walk, the CRC cache, the
   failure callbacks, a missing directory).
*)

interface

uses
   SysUtils,
   Classes,
   FileUtil,
   uTR4WTestFramework;

type
   TServerLogStoreTests = class(TTestCase)
   private
      FDir: string;
      function NewPath(const aName: string): string;
      procedure Test_InitializeWritesTheHeaderIntoANewFile;
      procedure Test_InitializeRefusesAnOddSizeAndTouchesNothing;
      procedure Test_InitializeFailsWhenTheDirectoryIsMissing;
      procedure Test_AppendStoresInArrivalOrderAndTellsTheCount;
      procedure Test_AHeldRunIsFlushedOnceAndSeesItsOwnQsos;
      procedure Test_HoldsIgnoresZeroZeroAndRebuildsWhenTheFileChanged;
      procedure Test_UpdateNewestRewritesOnlyTheNewestCopy;
      procedure Test_UpdateNewestOfAnUnknownPairIsTrueAndChangesNothing;
      procedure Test_ClearKeepsTheHeaderAndForgetsThePairs;
      procedure Test_ClearFlagsTouchesOnlyQsoRecords;
      procedure Test_TheCrcIsTheWholeFilesAndGoesStaleOnAWrite;
      procedure Test_DescribeSaysTheFirstContestAndNoContestWhenEmpty;
      procedure Test_MaxNumberSentIsTheLargest;
      procedure Test_TheImageIsTheFileByteForByte;
      procedure Test_AnAppendThatCannotOpenTellsTheCallback;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uCRC32,
   uServerLogStore;

var
   GFailures: integer;
   GWrites: integer;
   GLastReason: string;
   GLastCount: integer;

procedure NoteFailed(const aReason: string);
begin
   inc(GFailures);
   GLastReason := aReason;
end;

procedure NoteWritten;
begin
   inc(GWrites);
end;

procedure NoteCount(aCount: integer);
begin
   GLastCount := aCount;
end;

function ReadAll(const aName: string): TBytes;
var
   f: TFileStream;
begin
   f := TFileStream.Create(aName, fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(Result[0], f.Size);
         end;
   finally
      f.Free;
   end;
end;

function SameBytes(const a, b: TBytes): boolean;
begin
   Result := (Length(a) = Length(b)) and
             ((Length(a) = 0) or CompareMem(@a[0], @b[0], Length(a)));
end;

function Qso(aId1, aId2: Cardinal; const aCall: string; aNumber: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceQSOID1 := aId1;
   Result.ceQSOID2 := aId2;
   Result.Callsign := ShortString(aCall);
   Result.NumberSent := aNumber;
   Result.ceRecordKind := rkQSO;
end;

function RecordAt(const aBytes: TBytes; aIndex: integer): ContestExchange;
begin
   Move(aBytes[SizeOfTLogHeader + aIndex * SizeOf(ContestExchange)], Result,
        SizeOf(ContestExchange));
end;

function TServerLogStoreTests.NewPath(const aName: string): string;
begin
   Result := FDir + aName;
   if FileExists(Result) then
      begin
      DeleteFile(Result);
      end;
end;

(* A store on a fresh file, initialised, with the callbacks counting. *)
function MakeStore(const aPath: string): TFileServerLogStore;
var
   size: Int64;
begin
   GFailures := 0;
   GWrites := 0;
   GLastReason := '';
   GLastCount := -99;
   Result := TFileServerLogStore.Create(aPath);
   Result.OnWriteFailed := NoteFailed;
   Result.OnWritten := NoteWritten;
   Result.OnCountChanged := NoteCount;
   Result.Initialize(size);
end;

procedure TServerLogStoreTests.Test_InitializeWritesTheHeaderIntoANewFile;
var
   path: string;
   store: TFileServerLogStore;
   size: Int64;
   bytes: TBytes;
   header: TLogHeader;
begin
   BeginTest('Test_InitializeWritesTheHeaderIntoANewFile');
   path := NewPath('new.trw');
   store := TFileServerLogStore.Create(path);
   try
      store.OnCountChanged := NoteCount;
      GLastCount := -99;
      CheckEquals(Ord(silReady), Ord(store.Initialize(size)), 'ready');
      CheckEquals(0, Integer(size), 'the size found is the empty new file, before the header');
      bytes := ReadAll(path);
      CheckEquals(Integer(SizeOfTLogHeader), Integer(Length(bytes)), 'a header and nothing else');
      header := LogHeader;
      CheckTrue(CompareMem(@bytes[0], @header, SizeOf(TLogHeader)), 'the header bytes');
      CheckEquals(0, GLastCount, 'the window is told no QSOs');
      CheckEquals(0, store.Count, 'count');
      (* a second start leaves a whole file alone *)
      CheckEquals(Ord(silReady), Ord(store.Initialize(size)), 'ready again');
      CheckTrue(SameBytes(bytes, ReadAll(path)), 'unchanged');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_InitializeRefusesAnOddSizeAndTouchesNothing;
var
   path: string;
   store: TFileServerLogStore;
   f: TFileStream;
   size: Int64;
   before: TBytes;
begin
   BeginTest('Test_InitializeRefusesAnOddSizeAndTouchesNothing');
   path := NewPath('odd.trw');
   f := TFileStream.Create(path, fmCreate);
   try
      f.WriteBuffer(LogHeader, SizeOfTLogHeader);
      f.WriteBuffer(LogHeader, 100);
   finally
      f.Free;
   end;
   before := ReadAll(path);
   store := TFileServerLogStore.Create(path);
   try
      CheckEquals(Ord(silBadSize), Ord(store.Initialize(size)), 'refused');
      CheckEquals(Integer(SizeOfTLogHeader) + 100, Integer(size), 'the size found');
      CheckTrue(SameBytes(before, ReadAll(path)), 'untouched');
      (* and the log was closed again: a later open is not refused as re-entrant *)
      CheckTrue(store.Count >= 0, 'closed after the refusal');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_InitializeFailsWhenTheDirectoryIsMissing;
var
   store: TFileServerLogStore;
   size: Int64;
begin
   BeginTest('Test_InitializeFailsWhenTheDirectoryIsMissing');
   store := TFileServerLogStore.Create(FDir + 'nowhere' + PathDelim + 'x.trw');
   try
      CheckEquals(Ord(silCannotOpen), Ord(store.Initialize(size)), 'cannot open');
      CheckEquals(-1, store.Count, 'count says so');
      CheckFalse(store.Clear, 'clear');
      CheckFalse(store.Holds(1, 2), 'holds');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_AppendStoresInArrivalOrderAndTellsTheCount;
var
   path: string;
   store: TFileServerLogStore;
   bytes: TBytes;
begin
   BeginTest('Test_AppendStoresInArrivalOrderAndTellsTheCount');
   path := NewPath('append.trw');
   store := MakeStore(path);
   try
      CheckTrue(store.Append(Qso(1, 1, 'K1AAA', 5), True), 'first');
      CheckEquals(1, GLastCount, 'count 1');
      CheckTrue(store.Append(Qso(2, 2, 'K2BBB', 6), True), 'second');
      CheckEquals(2, GLastCount, 'count 2');
      CheckEquals(2, GWrites, 'one written notice per append');
      CheckEquals(0, GFailures, 'no failure');
      bytes := ReadAll(path);
      CheckEquals(Integer(SizeOfTLogHeader) + 2 * Integer(SizeOf(ContestExchange)), Integer(Length(bytes)), 'size');
      CheckEquals('K1AAA', string(RecordAt(bytes, 0).Callsign), 'first in place');
      CheckEquals('K2BBB', string(RecordAt(bytes, 1).Callsign), 'second after it');
      CheckEquals(2, store.Count, 'Count');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_AHeldRunIsFlushedOnceAndSeesItsOwnQsos;
var
   path: string;
   store: TFileServerLogStore;
begin
   BeginTest('Test_AHeldRunIsFlushedOnceAndSeesItsOwnQsos');
   path := NewPath('held.trw');
   store := MakeStore(path);
   try
      store.Hold;
      CheckFalse(store.Holds(10, 10), 'not yet');
      CheckTrue(store.Append(Qso(10, 10, 'K1AAA', 1), False), 'first');
      CheckTrue(store.Holds(10, 10), 'held within the run, noted in the index');
      CheckTrue(store.Append(Qso(11, 11, 'K1BBB', 2), False), 'second');
      CheckTrue(store.Holds(11, 11), 'second');
      store.Release;
      store.Release;   // safe with no hold in force
      CheckEquals(2, store.Count, 'count after the run (the log is closed again)');
      CheckTrue(store.Holds(10, 10), 'still held after release');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_HoldsIgnoresZeroZeroAndRebuildsWhenTheFileChanged;
var
   path: string;
   store: TFileServerLogStore;
   f: TFileStream;
   rec: ContestExchange;
begin
   BeginTest('Test_HoldsIgnoresZeroZeroAndRebuildsWhenTheFileChanged');
   path := NewPath('holds.trw');
   store := MakeStore(path);
   try
      CheckTrue(store.Append(Qso(0, 0, 'K0ZZZ', 1), True), 'a (0, 0) QSO is stored');
      CheckFalse(store.Holds(0, 0), '(0, 0) names nothing');
      CheckFalse(store.Holds(7, 8), 'not yet');
      (* someone else appends: the set is stale and is built again from the file *)
      f := TFileStream.Create(path, fmOpenReadWrite or fmShareDenyNone);
      try
         f.Seek(0, soEnd);
         rec := Qso(7, 8, 'K7XXX', 2);
         f.WriteBuffer(rec, SizeOf(ContestExchange));
      finally
         f.Free;
      end;
      CheckTrue(store.Holds(7, 8), 'found after an outside append');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_UpdateNewestRewritesOnlyTheNewestCopy;
var
   path: string;
   store: TFileServerLogStore;
   bytes: TBytes;
begin
   BeginTest('Test_UpdateNewestRewritesOnlyTheNewestCopy');
   path := NewPath('edit.trw');
   store := MakeStore(path);
   try
      store.Append(Qso(5, 5, 'K1OLD', 1), True);
      store.Append(Qso(6, 6, 'K1MID', 2), True);
      store.Append(Qso(5, 5, 'K1TWO', 3), True);
      CheckTrue(store.UpdateNewest(Qso(5, 5, 'K1NEW', 9)), 'edited');
      bytes := ReadAll(path);
      CheckEquals('K1OLD', string(RecordAt(bytes, 0).Callsign), 'the older copy is as it was');
      CheckEquals('K1MID', string(RecordAt(bytes, 1).Callsign), 'another QSO untouched');
      CheckEquals('K1NEW', string(RecordAt(bytes, 2).Callsign), 'the newest copy rewritten');
      CheckEquals(9, RecordAt(bytes, 2).NumberSent, 'whole record');
      CheckEquals(0, GFailures, 'no failure');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_UpdateNewestOfAnUnknownPairIsTrueAndChangesNothing;
var
   path: string;
   store: TFileServerLogStore;
   before: TBytes;
begin
   BeginTest('Test_UpdateNewestOfAnUnknownPairIsTrueAndChangesNothing');
   path := NewPath('edit2.trw');
   store := MakeStore(path);
   try
      store.Append(Qso(5, 5, 'K1OLD', 1), True);
      before := ReadAll(path);
      CheckTrue(store.UpdateNewest(Qso(99, 99, 'K9NEW', 1)), 'True, as it always was');
      CheckTrue(SameBytes(before, ReadAll(path)), 'not stored');
      CheckEquals(0, GFailures, 'no failure');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_ClearKeepsTheHeaderAndForgetsThePairs;
var
   path: string;
   store: TFileServerLogStore;
   bytes: TBytes;
begin
   BeginTest('Test_ClearKeepsTheHeaderAndForgetsThePairs');
   path := NewPath('clear.trw');
   store := MakeStore(path);
   try
      store.Append(Qso(1, 1, 'K1AAA', 1), True);
      CheckTrue(store.Holds(1, 1), 'held');
      CheckTrue(store.Clear, 'cleared');
      CheckEquals(0, GLastCount, 'the window is told');
      bytes := ReadAll(path);
      CheckEquals(Integer(SizeOfTLogHeader), Integer(Length(bytes)), 'the header only');
      CheckFalse(store.Holds(1, 1), 'the set forgot it');
      CheckTrue(store.Append(Qso(1, 1, 'K1AAA', 1), True), 'and it can be stored again');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_ClearFlagsTouchesOnlyQsoRecords;
var
   path: string;
   store: TFileServerLogStore;
   bytes: TBytes;
   note: ContestExchange;
   withMults: ContestExchange;
begin
   BeginTest('Test_ClearFlagsTouchesOnlyQsoRecords');
   path := NewPath('flags.trw');
   store := MakeStore(path);
   try
      CheckFalse(store.ClearFlags(actSetClearDupesheetBit), 'no QSO, nothing to do');
      withMults := Qso(1, 1, 'K1AAA', 1);
      withMults.DomesticMult := True;
      withMults.DXMult := True;
      withMults.PrefixMult := True;
      withMults.ZoneMult := True;
      store.Append(withMults, True);
      note := Qso(2, 2, 'K2NOTE', 2);
      note.ceRecordKind := rkNote;
      note.DomesticMult := True;
      store.Append(note, True);

      CheckTrue(store.ClearFlags(actSetClearDupesheetBit), 'dupesheet');
      bytes := ReadAll(path);
      CheckTrue(RecordAt(bytes, 0).ceClearDupeSheet, 'QSO: dupe sheet bit set');
      CheckFalse(RecordAt(bytes, 1).ceClearDupeSheet, 'note untouched');
      CheckTrue(RecordAt(bytes, 0).DomesticMult, 'dupesheet leaves the mults');

      CheckTrue(store.ClearFlags(actClearMults), 'mults');
      bytes := ReadAll(path);
      CheckTrue(RecordAt(bytes, 0).ceClearMultSheet, 'QSO: mult sheet bit set');
      CheckFalse(RecordAt(bytes, 0).DomesticMult or RecordAt(bytes, 0).DXMult or
                 RecordAt(bytes, 0).PrefixMult or RecordAt(bytes, 0).ZoneMult, 'QSO: mults off');
      CheckTrue(RecordAt(bytes, 1).DomesticMult, 'note keeps its flag');
      CheckFalse(RecordAt(bytes, 1).ceClearMultSheet, 'note untouched');
      CheckEquals(Integer(SizeOfTLogHeader) + 2 * Integer(SizeOf(ContestExchange)), Integer(Length(bytes)), 'size unchanged');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_TheCrcIsTheWholeFilesAndGoesStaleOnAWrite;
var
   path: string;
   store: TFileServerLogStore;
   size: Int64;
   contest: TContestHandle;
   crc1, crc2: Cardinal;
begin
   BeginTest('Test_TheCrcIsTheWholeFilesAndGoesStaleOnAWrite');
   path := NewPath('crc.trw');
   store := MakeStore(path);
   try
      store.Append(Qso(1, 1, 'K1AAA', 1), True);
      CheckTrue(store.Describe(size, contest, crc1), 'described');
      CheckEquals(Integer(GetCRC32(ReadAll(path))), Integer(crc1), 'the CRC32 of every byte, header included');
      store.Append(Qso(2, 2, 'K2BBB', 2), True);
      CheckTrue(store.Describe(size, contest, crc2), 'described again');
      CheckEquals(Integer(GetCRC32(ReadAll(path))), Integer(crc2), 'recomputed after an append');
      CheckTrue(crc1 <> crc2, 'and it moved');
      store.UpdateNewest(Qso(2, 2, 'K2ZZZ', 2));
      store.Describe(size, contest, crc1);
      CheckEquals(Integer(GetCRC32(ReadAll(path))), Integer(crc1), 'recomputed after an edit');
      store.ClearFlags(actSetClearDupesheetBit);
      store.Describe(size, contest, crc2);
      CheckEquals(Integer(GetCRC32(ReadAll(path))), Integer(crc2), 'recomputed after the flags');
      store.Clear;
      store.Describe(size, contest, crc1);
      CheckEquals(Integer(GetCRC32(ReadAll(path))), Integer(crc1), 'recomputed after a clear');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_DescribeSaysTheFirstContestAndNoContestWhenEmpty;
var
   path: string;
   store: TFileServerLogStore;
   size: Int64;
   contest: TContestHandle;
   crc: Cardinal;
   rec: ContestExchange;
begin
   BeginTest('Test_DescribeSaysTheFirstContestAndNoContestWhenEmpty');
   path := NewPath('describe.trw');
   store := MakeStore(path);
   try
      CheckTrue(store.Describe(size, contest, crc), 'empty log');
      CheckEquals(Integer(SizeOfTLogHeader), Integer(size), 'size is the header');
      CheckTrue(contest = NoContest, 'no contest in an empty log');
      rec := Qso(1, 1, 'K1AAA', 1);
      rec.ceContest := TContestHandle.FromByte(5);
      store.Append(rec, True);
      rec := Qso(2, 2, 'K2BBB', 2);
      rec.ceContest := TContestHandle.FromByte(9);
      store.Append(rec, True);
      CheckTrue(store.Describe(size, contest, crc), 'two QSOs');
      CheckEquals(Integer(SizeOfTLogHeader) + 2 * Integer(SizeOf(ContestExchange)), Integer(size), 'size');
      CheckEquals(5, contest.ToByte, 'the FIRST record''s contest byte');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_MaxNumberSentIsTheLargest;
var
   path: string;
   store: TFileServerLogStore;
   highest: integer;
begin
   BeginTest('Test_MaxNumberSentIsTheLargest');
   path := NewPath('serial.trw');
   store := MakeStore(path);
   try
      CheckTrue(store.MaxNumberSent(highest), 'empty');
      CheckEquals(0, highest, 'none');
      store.Append(Qso(1, 1, 'K1AAA', 12), True);
      store.Append(Qso(2, 2, 'K2BBB', 40), True);
      store.Append(Qso(3, 3, 'K3CCC', 7), True);
      CheckTrue(store.MaxNumberSent(highest), 'three');
      CheckEquals(40, highest, 'the header is not read as a QSO, the largest wins');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_TheImageIsTheFileByteForByte;
var
   path: string;
   store: TFileServerLogStore;
   image: TStream;
   got: TBytes;
begin
   BeginTest('Test_TheImageIsTheFileByteForByte');
   path := NewPath('image.trw');
   store := MakeStore(path);
   try
      store.Append(Qso(1, 1, 'K1AAA', 1), True);
      store.Append(Qso(2, 2, 'K2BBB', 2), True);
      image := store.OpenImage;
      try
         SetLength(got, image.Size);
         image.ReadBuffer(got[0], image.Size);
      finally
         image.Free;
      end;
      CheckTrue(SameBytes(got, ReadAll(path)), 'the header, then every record');
      CheckEquals(Integer(SizeOfTLogHeader) + 2 * Integer(SizeOf(ContestExchange)), Integer(Length(got)), 'size');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.Test_AnAppendThatCannotOpenTellsTheCallback;
var
   store: TFileServerLogStore;
begin
   BeginTest('Test_AnAppendThatCannotOpenTellsTheCallback');
   GFailures := 0;
   GLastReason := '';
   store := TFileServerLogStore.Create(FDir + 'absent' + PathDelim + 'x.trw');
   try
      store.OnWriteFailed := NoteFailed;
      CheckFalse(store.Append(Qso(1, 1, 'K1AAA', 1), True), 'not stored');
      CheckEquals(1, GFailures, 'the server is told');
      CheckEquals('cannot open the log', GLastReason, 'with the reason it always gave');
      CheckFalse(store.UpdateNewest(Qso(1, 1, 'K1AAA', 1)), 'an edit says so too');
      CheckEquals(2, GFailures, 'and is counted');
   finally
      store.Free;
   end;
end;

procedure TServerLogStoreTests.RunAllTests;
begin
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-logstore-' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   try
      Test_InitializeWritesTheHeaderIntoANewFile;
      Test_InitializeRefusesAnOddSizeAndTouchesNothing;
      Test_InitializeFailsWhenTheDirectoryIsMissing;
      Test_AppendStoresInArrivalOrderAndTellsTheCount;
      Test_AHeldRunIsFlushedOnceAndSeesItsOwnQsos;
      Test_HoldsIgnoresZeroZeroAndRebuildsWhenTheFileChanged;
      Test_UpdateNewestRewritesOnlyTheNewestCopy;
      Test_UpdateNewestOfAnUnknownPairIsTrueAndChangesNothing;
      Test_ClearKeepsTheHeaderAndForgetsThePairs;
      Test_ClearFlagsTouchesOnlyQsoRecords;
      Test_TheCrcIsTheWholeFilesAndGoesStaleOnAWrite;
      Test_DescribeSaysTheFirstContestAndNoContestWhenEmpty;
      Test_MaxNumberSentIsTheLargest;
      Test_TheImageIsTheFileByteForByte;
      Test_AnAppendThatCannotOpenTellsTheCallback;
   finally
      DeleteDirectory(FDir, False);
   end;
end;

end.
