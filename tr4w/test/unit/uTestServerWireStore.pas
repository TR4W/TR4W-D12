unit uTestServerWireStore;

(* THE SERVER'S SQLITE STORE -- stage W2 of docs\TR4WSERVER_SQLITE_DESIGN.md
  section 13 (issues 300 and 341), uServerWireStore.

  Every test runs on a scratch file under the temp directory, removed when the
  suite ends. The rows are tr4w\test\wire\golden_vectors.json's (made by
  make_vectors.py, with no Pascal in the loop): NULL, 0, defaults, a NUL, non-ASCII,
  a 510-byte value, a character outside the BMP, the text "0".

  WHAT IS NOT DRIVEN HERE, SAID PLAINLY: a real process kill. The durability test
  opens a SECOND connection to the same file while the first is still open and
  asserts every acknowledged row is visible to it -- that proves each Insert was
  COMMITTED (WAL, synchronous = FULL, both read back and asserted), not that the
  bytes survived a power cut. A full disk IS injected (issue 341, P3): PRAGMA
  max_page_count through TServerWireStore.LimitPages, as the station's tests
  fill theirs. A refused write that is NOT a full disk (SQLITE_READONLY, an I/O
  error), which makes the store reopen its connection, is not driven here. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TServerWireStoreTests = class(TTestCase)
   private
      FDir: string;
      function ScratchFile(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      (* NOT TearDown: this framework calls TearDown after EVERY check. *)
      procedure CleanUp;
   protected
      procedure Test_TheVectorsComeBackByteForByteInOrder;
      procedure Test_ADuplicateIdentityIsNotStoredTwice;
      procedure Test_AnEditRewritesOnlyTheNewestCopy;
      procedure Test_AHeldRunIsOneTransaction;
      procedure Test_ClearAndCount;
      procedure Test_TheClearFlags;
      procedure Test_TheLargestSerial;
      procedure Test_ARowThatIsNotARowIsRejected;
      procedure Test_AFileThatIsNotOursIsRefusedUntouched;
      procedure Test_AnAcknowledgedQsoIsVisibleToASecondConnection;
      procedure Test_TheDdlIsTheColumnsFile;
      procedure Test_TheCallbacks;
      procedure Test_ADamagedFileIsRefusedBeforeItIsOpenedForWriting;
      procedure Test_AFullDiskKeepsEveryAcknowledgedQsoAndRecovers;
      procedure Test_ARunThatMeetsAFullDiskLeavesNothingOfItself;
      procedure Test_TheBackupIsAVerifiedCopyOfWhatIsCommitted;
      procedure Test_AMissingSqliteLibraryIsNamed;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, db, sqldb, fpjson, jsonparser,
   uWireQso, uQsoColumns, uLogDatabase, uServerWireStore, uTestWireColumns;

var
   GWritten, GCountCalls, GFailed, GLastCount: integer;
   GLastReason: string;

procedure NoteWritten;
begin
   Inc(GWritten);
end;

procedure NoteFailed(const aReason: string);
begin
   Inc(GFailed);
   GLastReason := aReason;
end;

procedure NoteCountChanged(aCount: integer);
begin
   Inc(GCountCalls);
   GLastCount := aCount;
end;

function TServerWireStoreTests.ScratchFile(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_wirestore_' +
              IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   Scrub(Result);
end;

procedure TServerWireStoreTests.Scrub(const aFileName: string);
const
   SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(aFileName + SUFFIXES[i]) then
         begin
         DeleteFile(aFileName + SUFFIXES[i]);
         end;
      end;
end;

procedure TServerWireStoreTests.CleanUp;
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

function OpenStore(const aFile: string; out aStore: TServerWireStore): TWireStoreInit;
var
   why: string;
begin
   aStore := TServerWireStore.Create(QsoWireColumns, aFile);
   Result := aStore.Initialize(why);
end;

(* The golden vectors' rows, in file order. *)
procedure LoadVectors(out aRows: TWireRows; out aLabels: TStringList);
var
   doc: TJSONData;
   rows, vals: TJSONArray;
   r, i: integer;
begin
   aLabels := TStringList.Create;
   doc := GetJSON(ReadUtf8File(WireTestFile('golden_vectors.json')));
   try
      rows := TJSONObject(doc).Arrays['rows'];
      SetLength(aRows, rows.Count);
      for r := 0 to rows.Count - 1 do
         begin
         vals := rows.Objects[r].Arrays['values'];
         aLabels.Add(string(rows.Objects[r].Strings['label']));
         SetLength(aRows[r], vals.Count);
         for i := 0 to vals.Count - 1 do
            begin
            aRows[r][i] := string(vals.Strings[i]);
            end;
         end;
   finally
      doc.Free;
   end;
end;

(* A row of defaults with the named columns set. *)
function MakeRow(const aNames, aValues: array of string): TWireValues;
var
   i, at: integer;
begin
   Result := QsoWireColumns.DefaultValues;
   for i := Low(aNames) to High(aNames) do
      begin
      at := QsoWireColumns.IndexOfName(aNames[i]);
      if at >= 0 then
         begin
         Result[at] := aValues[i];
         end;
      end;
end;

function ValueOf(const aRow: TWireValues; const aName: string): string;
begin
   Result := aRow[QsoWireColumns.IndexOfName(aName)];
end;

function SameRow(const aA, aB: TWireValues): boolean;
var
   i: integer;
begin
   Result := Length(aA) = Length(aB);
   if Result then
      begin
      for i := 0 to High(aA) do
         begin
         if aA[i] <> aB[i] then
            begin
            Result := False;
            Exit;
            end;
         end;
      end;
end;

(* Run one statement on a connection of the test's own, as another program
  would. *)
procedure ExecOn(const aFile, aSql: string);
var
   db: TLogDatabase;
begin
   db := TLogDatabase.Create;
   try
      db.OpenWithoutIdentity(aFile, False);
      db.Transaction.StartTransaction;
      db.Connection.ExecuteDirect(AnsiString(aSql));
      db.Transaction.Commit;
   finally
      db.Free;
   end;
end;

function FileBytes(const aFile: string): string;
var
   f: TFileStream;
   raw: RawByteString;
begin
   f := TFileStream.Create(aFile, fmOpenRead or fmShareDenyNone);
   try
      SetLength(raw, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(raw[1], f.Size);
         end;
      Result := string(raw);
   finally
      f.Free;
   end;
end;

(* ---- the tests ------------------------------------------------------------- *)

procedure TServerWireStoreTests.Test_TheVectorsComeBackByteForByteInOrder;
var
   fn: string;
   store, again: TServerWireStore;
   rows, back: TWireRows;
   labels: TStringList;
   r, i: integer;
   mismatch: string;
begin
   BeginTest('Test_TheVectorsComeBackByteForByteInOrder');
   fn := ScratchFile('vectors' + WIRE_STORE_EXTENSION);
   LoadVectors(rows, labels);
   store := nil;
   again := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'a new store opens');
      CheckTrue(store.JournalMode = 'wal', 'WAL');
      CheckEquals(2, store.Synchronous, 'synchronous = FULL');
      CheckEquals(0, store.Count, 'a new store is empty');
      for r := 0 to High(rows) do
         begin
         CheckTrue(store.Insert(rows[r]) = wiStored, labels[r] + ': stored');
         end;
      CheckEquals(Length(rows), store.Count, 'every vector is held');
      CheckTrue(store.ReadAll(back), 'read all');
      CheckEquals(Length(rows), Length(back), 'every row comes back');
      for r := 0 to High(rows) do
         begin
         if r >= Length(back) then
            begin
            Break;
            end;
         mismatch := '';
         for i := 0 to High(rows[r]) do
            begin
            if rows[r][i] <> back[r][i] then
               begin
               mismatch := QsoWireColumns.Name[i] + ' was [' + rows[r][i] + '] now [' + back[r][i] + ']';
               Break;
               end;
            end;
         CheckEquals('', mismatch, labels[r] + ': byte for byte, in arrival order');
         end;
      (* A restart: a second store over the same file reads the same rows. *)
      FreeAndNil(store);
      CheckTrue(OpenStore(fn, again) = wsiReady, 'an existing store reopens');
      CheckEquals(Length(rows), again.Count, 'the reopened store holds every row');
      CheckTrue(again.ReadAll(back) and (Length(back) = Length(rows)), 'and reads them');
      CheckTrue((Length(back) > 0) and SameRow(back[Length(back) - 1], rows[High(rows)]),
         'the last one is still last');
   finally
      store.Free;
      again.Free;
      labels.Free;
   end;
end;

procedure TServerWireStoreTests.Test_ADuplicateIdentityIsNotStoredTwice;
var
   fn: string;
   store: TServerWireStore;
   a, b, c, d: TWireValues;
   back: TWireRows;
begin
   BeginTest('Test_ADuplicateIdentityIsNotStoredTwice');
   fn := ScratchFile('dup' + WIRE_STORE_EXTENSION);
   a := MakeRow(['guid', 'callsign'], ['g-1', 'K1AAA']);
   b := MakeRow(['guid', 'callsign'], ['g-1', 'K1BBB']);   (* the same QSO, another copy *)
   c := MakeRow(['callsign'], ['K1CCC']);                  (* no identity *)
   d := MakeRow(['guid', 'callsign'], ['g-2', 'K1DDD']);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      CheckFalse(store.Holds('g-1'), 'not held yet');
      CheckTrue(store.Insert(a) = wiStored, 'the first copy is stored');
      CheckTrue(store.Holds('g-1'), 'now held');
      CheckTrue(store.Insert(b) = wiDuplicate, 'the second copy is not');
      CheckTrue(store.Insert(c) = wiStored, 'a row with no identity is stored');
      CheckTrue(store.Insert(c) = wiStored, '... every time');
      CheckFalse(store.Holds(''), 'an empty identity is never held');
      CheckTrue(store.Insert(d) = wiStored, 'another identity is stored');
      CheckEquals(4, store.Count, 'g-1 once, the unidentified twice, g-2');
      CheckTrue(store.ReadAll(back), 'read');
      CheckEquals('K1AAA', ValueOf(back[0], 'callsign'), 'the FIRST copy is the one kept');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_AnEditRewritesOnlyTheNewestCopy;
var
   fn: string;
   store: TServerWireStore;
   a, edit, edit2, ghost, none: TWireValues;
   back: TWireRows;
begin
   BeginTest('Test_AnEditRewritesOnlyTheNewestCopy');
   fn := ScratchFile('edit' + WIRE_STORE_EXTENSION);
   a := MakeRow(['guid', 'callsign', 'band'], ['g-9', 'K1OLD', '20']);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      CheckTrue(store.Insert(a) = wiStored, 'stored');
      (* The old logs hold repeats of one identity (a 10-16 ms tick was the second
        half of the pair). Another program writes the second copy. *)
      ExecOn(fn, 'INSERT INTO qso (guid, callsign, band) SELECT guid, callsign, band FROM qso');
      CheckEquals(2, store.Count, 'two copies of g-9');
      edit := MakeRow(['guid', 'callsign', 'band'], ['g-9', 'K1NEW', '40']);
      CheckTrue(store.UpdateNewest(edit), 'the edit is applied');
      CheckTrue(store.ReadAll(back) and (Length(back) = 2), 'read');
      CheckEquals('K1OLD', ValueOf(back[0], 'callsign'), 'the older copy is untouched');
      CheckEquals('K1NEW', ValueOf(back[1], 'callsign'), 'the newest copy is rewritten');
      CheckEquals('40', ValueOf(back[1], 'band'), 'whole row: the band changed');
      (* The whole row, last writer wins: a field left out comes back as its
        default, not as "unchanged". *)
      edit2 := MakeRow(['guid', 'callsign'], ['g-9', 'K1TWO']);
      CheckTrue(store.UpdateNewest(edit2), 'a second edit');
      CheckTrue(store.ReadAll(back) and (Length(back) = 2), 'read');
      CheckEquals('', ValueOf(back[1], 'band'), 'a snapshot: band is gone, not kept');
      (* An edit of a QSO the server never held: ACKed, relayed, NOT stored. *)
      ghost := MakeRow(['guid', 'callsign'], ['g-never', 'K1GHO']);
      CheckTrue(store.UpdateNewest(ghost), 'an unheld edit is not a failure');
      CheckEquals(2, store.Count, '... and stores nothing');
      (* An edit that names nothing changes nothing. *)
      none := MakeRow(['callsign'], ['K1NON']);
      CheckTrue(store.UpdateNewest(none), 'an edit with no identity is not a failure');
      CheckTrue(store.ReadAll(back), 'read');
      CheckEquals('K1OLD', ValueOf(back[0], 'callsign'), 'no row was rewritten by it (first)');
      CheckEquals('K1TWO', ValueOf(back[1], 'callsign'), 'no row was rewritten by it (second)');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_AHeldRunIsOneTransaction;
var
   fn: string;
   store: TServerWireStore;
   back: TWireRows;
   i: integer;
begin
   BeginTest('Test_AHeldRunIsOneTransaction');
   fn := ScratchFile('hold' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      store.Release;   (* nothing held: no effect, no error *)
      store.Hold;
      for i := 1 to 5 do
         begin
         CheckTrue(store.Insert(MakeRow(['guid', 'callsign'], ['h-' + IntToStr(i), 'K1HLD'])) = wiStored,
            'a held insert is stored');
         end;
      CheckTrue(store.Holds('h-3'), 'inside the run the store sees its own rows');
      CheckTrue(store.Insert(MakeRow(['guid'], ['h-3'])) = wiDuplicate,
         'and a repeat inside the run is a duplicate');
      (* ReadAll is a connection of its own: it sees only what is COMMITTED. *)
      CheckTrue(store.ReadAll(back), 'read from outside the transaction');
      CheckEquals(0, Length(back), 'nothing is durable until Release');
      store.Release;
      CheckTrue(store.ReadAll(back), 'read after Release');
      CheckEquals(5, Length(back), 'the whole run committed together');
      CheckEquals(5, store.Count, 'the count agrees');
      (* And the store writes normally afterwards. *)
      CheckTrue(store.Insert(MakeRow(['guid'], ['h-6'])) = wiStored, 'a later insert');
      CheckTrue(store.ReadAll(back) and (Length(back) = 6), 'committed at once outside a hold');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_ClearAndCount;
var
   fn: string;
   store: TServerWireStore;
   back: TWireRows;
begin
   BeginTest('Test_ClearAndCount');
   fn := ScratchFile('clear' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      store.Insert(MakeRow(['guid'], ['c-1']));
      store.Insert(MakeRow(['guid'], ['c-2']));
      CheckEquals(2, store.Count, 'two held');
      CheckTrue(store.Clear, 'clear');
      CheckEquals(0, store.Count, 'none held');
      CheckTrue(store.ReadAll(back) and (Length(back) = 0), 'and none read');
      CheckFalse(store.Holds('c-1'), 'a cleared identity is no longer held');
      CheckTrue(store.Insert(MakeRow(['guid'], ['c-1'])) = wiStored, 'it can be stored again');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_TheClearFlags;
const
   MULT_FLAGS: array[0..3] of string = ('mult_domestic', 'mult_dx', 'mult_prefix', 'mult_zone');
var
   fn: string;
   store: TServerWireStore;
   back: TWireRows;
   i: integer;
begin
   BeginTest('Test_TheClearFlags');
   fn := ScratchFile('flags' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      CheckFalse(store.ClearFlags(wfaSetClearDupesheet), 'an empty store has nothing to flag');
      store.Insert(MakeRow(['guid', 'record_kind', 'mult_domestic', 'mult_dx', 'mult_prefix', 'mult_zone'],
                           ['f-1', 'QSO', '1', '1', '1', '1']));
      store.Insert(MakeRow(['guid', 'record_kind', 'mult_dx'], ['f-2', 'NOTE', '1']));
      CheckTrue(store.ClearFlags(wfaSetClearDupesheet), 'set the dupesheet bit');
      CheckTrue(store.ReadAll(back) and (Length(back) = 2), 'read');
      CheckEquals('1', ValueOf(back[0], 'clear_dupe_sheet'), 'a QSO row is flagged');
      CheckEquals('0', ValueOf(back[1], 'clear_dupe_sheet'), 'a NOTE row is not');
      CheckEquals('0', ValueOf(back[0], 'clear_mult_sheet'), 'the mult sheet is not touched by it');
      CheckTrue(store.ClearFlags(wfaClearMults), 'clear the multipliers');
      CheckTrue(store.ReadAll(back) and (Length(back) = 2), 'read');
      CheckEquals('1', ValueOf(back[0], 'clear_mult_sheet'), 'the QSO row says its mults were cleared');
      for i := 0 to 3 do
         begin
         CheckEquals('0', ValueOf(back[0], MULT_FLAGS[i]), MULT_FLAGS[i] + ' is 0');
         end;
      CheckEquals('1', ValueOf(back[1], 'mult_dx'), 'a NOTE row keeps its flags');
      CheckEquals('0', ValueOf(back[1], 'clear_mult_sheet'), 'and its sheet bit');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_TheLargestSerial;
var
   fn: string;
   store: TServerWireStore;
   biggest: integer;
begin
   BeginTest('Test_TheLargestSerial');
   fn := ScratchFile('serial' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      CheckTrue(store.MaxNumberSent(biggest), 'ask an empty store');
      CheckEquals(0, biggest, 'no serials: 0');
      store.Insert(MakeRow(['guid', 'serial_sent'], ['s-1', '5']));
      store.Insert(MakeRow(['guid', 'serial_sent'], ['s-2', '12']));
      store.Insert(MakeRow(['guid', 'serial_sent'], ['s-3', '']));    (* the old -1: NULL *)
      store.Insert(MakeRow(['guid', 'serial_sent'], ['s-4', '9']));
      CheckTrue(store.MaxNumberSent(biggest), 'ask');
      CheckEquals(12, biggest, 'the largest, NULL ignored');
      (* A read must not leave a snapshot that fails the next write. *)
      CheckTrue(store.Insert(MakeRow(['guid', 'serial_sent'], ['s-5', '20'])) = wiStored,
         'a write after a read');
      CheckTrue(store.MaxNumberSent(biggest) and (biggest = 20), 'and it counts');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_ARowThatIsNotARowIsRejected;
var
   fn: string;
   store: TServerWireStore;
   short, bad: TWireValues;
begin
   BeginTest('Test_ARowThatIsNotARowIsRejected');
   fn := ScratchFile('reject' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      SetLength(short, 3);
      CheckTrue(store.Insert(short) = wiRejected, 'the wrong number of values');
      bad := MakeRow(['guid', 'freq_tx_hz'], ['r-1', '14.025']);
      CheckTrue(store.Insert(bad) = wiRejected, 'a number that is not an integer');
      bad := MakeRow(['guid', 'freq_tx_hz'], ['r-2', '$1F']);
      CheckTrue(store.Insert(bad) = wiRejected, 'nor is hexadecimal');
      CheckEquals(0, store.Count, 'nothing was written');
      CheckTrue(store.UpdateNewest(short), 'an edit that is not a row is not a failure of the disk');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_AFileThatIsNotOursIsRefusedUntouched;
var
   fn, before, why: string;
   store: TServerWireStore;
   st: TWireStoreInit;
   f: TFileStream;
begin
   BeginTest('Test_AFileThatIsNotOursIsRefusedUntouched');

   (* another application id (the station's own 'TR4W'), with the server's tables *)
   fn := ScratchFile('appid' + WIRE_STORE_EXTENSION);
   store := nil;
   CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
   store.Insert(MakeRow(['guid'], ['a-1']));
   FreeAndNil(store);
   ExecOn(fn, 'PRAGMA application_id = 1414092887');
   before := FileBytes(fn);
   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      st := store.Initialize(why);
      CheckTrue(st = wsiRefused, 'a file of another application id is refused');
      CheckTrue(Pos('application id', why) > 0, 'and says why: ' + why);
   finally
      store.Free;
   end;
   CheckTrue(before = FileBytes(fn), 'the refused file is byte for byte as it was');

   (* the right application id, another schema version *)
   fn := ScratchFile('version' + WIRE_STORE_EXTENSION);
   CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
   FreeAndNil(store);
   ExecOn(fn, 'UPDATE meta SET value = 99 WHERE key = ''schema_version''');
   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      st := store.Initialize(why);
      CheckTrue(st = wsiRefused, 'a file of another schema version is refused');
      CheckTrue(Pos('99', why) > 0, 'and names the version it found: ' + why);
   finally
      store.Free;
   end;

   (* the same version, but the qso table has another shape *)
   fn := ScratchFile('shape' + WIRE_STORE_EXTENSION);
   CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
   FreeAndNil(store);
   ExecOn(fn, 'ALTER TABLE qso ADD COLUMN surprise TEXT');
   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      CheckTrue(store.Initialize(why) = wsiRefused, 'a table with another column is refused');
   finally
      store.Free;
   end;

   (* not a database at all *)
   fn := ScratchFile('junk' + WIRE_STORE_EXTENSION);
   f := TFileStream.Create(fn, fmCreate);
   try
      f.WriteBuffer(PAnsiChar('this is not a SQLite database, just text, long enough to be read')^, 64);
   finally
      f.Free;
   end;
   before := FileBytes(fn);
   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      CheckTrue(store.Initialize(why) = wsiRefused, 'a text file is refused');
   finally
      store.Free;
   end;
   CheckTrue(before = FileBytes(fn), 'and left alone');

   (* a path that cannot be created *)
   store := TServerWireStore.Create(QsoWireColumns,
      IncludeTrailingPathDelimiter(FDir) + 'no' + PathDelim + 'such' + PathDelim + 'dir.tr4wsrv');
   try
      CheckTrue(store.Initialize(why) = wsiCannotOpen, 'a missing directory cannot be opened');
      CheckTrue(why <> '', 'and says why');
   finally
      store.Free;
   end;
end;

procedure TServerWireStoreTests.Test_AnAcknowledgedQsoIsVisibleToASecondConnection;
var
   fn: string;
   first, second: TServerWireStore;
   i: integer;
   back: TWireRows;
begin
   BeginTest('Test_AnAcknowledgedQsoIsVisibleToASecondConnection');
   fn := ScratchFile('durable' + WIRE_STORE_EXTENSION);
   first := nil;
   second := nil;
   try
      CheckTrue(OpenStore(fn, first) = wsiReady, 'opens');
      for i := 1 to 25 do
         begin
         CheckTrue(first.Insert(MakeRow(['guid', 'callsign'], ['d-' + IntToStr(i), 'K1DUR'])) = wiStored,
            'insert ' + IntToStr(i));
         end;
      (* The first store is NOT closed, as a killed process would not have closed
        it. Another connection must already see every row it acknowledged. *)
      CheckTrue(OpenStore(fn, second) = wsiReady, 'a second store opens the same file');
      CheckEquals(25, second.Count, 'every acknowledged QSO is committed');
      CheckTrue(second.ReadAll(back) and (Length(back) = 25), 'and readable');
      CheckEquals('d-25', ValueOf(back[24], 'guid'), 'in arrival order');
   finally
      second.Free;
      first.Free;
   end;
end;

(* A DEFAULT as PRAGMA table_info gives it, as canonical text. *)
function DefaultText(aField: TField): string;
begin
   Result := '';
   if aField.IsNull then
      begin
      Exit;
      end;
   Result := string(aField.AsString);
   if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
      begin
      Result := Copy(Result, 2, Length(Result) - 2);
      end;
end;

procedure TServerWireStoreTests.Test_TheDdlIsTheColumnsFile;
var
   fn: string;
   store: TServerWireStore;
   db: TLogDatabase;
   q: TSQLQuery;
   doc: TJSONData;
   cols: TJSONArray;
   i: integer;
   uniqueIdx: boolean;
   sawGuidIndex: boolean;
begin
   BeginTest('Test_TheDdlIsTheColumnsFile');
   fn := ScratchFile('ddl' + WIRE_STORE_EXTENSION);
   store := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
   finally
      FreeAndNil(store);
   end;
   doc := GetJSON(ReadUtf8File(WireTestFile('columns.json')));
   db := TLogDatabase.Create;
   q := TSQLQuery.Create(nil);
   try
      cols := TJSONArray(doc);
      db.OpenWithoutIdentity(fn, True);
      q.DataBase := db.Connection;
      (* PRAGMA table_info, one row a column, in cid order. Not the Pascal table:
        columns.json is what the Python server is built from. *)
      q.SQL.Text := 'SELECT name, type, dflt_value FROM pragma_table_info(''qso'') ORDER BY cid';
      q.Open;
      CheckEquals('seq', string(q.Fields[0].AsString), 'seq first');
      CheckEquals('INTEGER', string(q.Fields[1].AsString), 'seq is an INTEGER');
      q.Next;
      for i := 0 to cols.Count - 1 do
         begin
         CheckFalse(q.EOF, 'the table has column ' + IntToStr(i + 1));
         if q.EOF then
            begin
            Break;
            end;
         CheckEquals(string(cols.Objects[i].Strings['name']), string(q.Fields[0].AsString),
            'column ' + IntToStr(i + 1) + ': its name and place');
         if cols.Objects[i].Booleans['num'] then
            begin
            CheckEquals('INTEGER', string(q.Fields[1].AsString),
               string(cols.Objects[i].Strings['name']) + ': INTEGER');
            end
         else
            begin
            CheckEquals('TEXT', string(q.Fields[1].AsString),
               string(cols.Objects[i].Strings['name']) + ': TEXT');
            end;
         CheckEquals(string(cols.Objects[i].Strings['def']), DefaultText(q.Fields[2]),
            string(cols.Objects[i].Strings['name']) + ': its DEFAULT');
         q.Next;
         end;
      CheckTrue(q.EOF, 'and no column beyond columns.json');
      q.Close;
      q.SQL.Text := 'SELECT value FROM meta WHERE key = ''schema_version''';
      q.Open;
      CheckEquals(IntToStr(WIRE_STORE_SCHEMA_VERSION), string(q.Fields[0].AsString), 'schema_version');
      q.Close;
      q.SQL.Text := 'PRAGMA application_id';
      q.Open;
      CheckEquals(IntToStr(WIRE_STORE_APPLICATION_ID), string(q.Fields[0].AsString), 'application_id');
      q.Close;
      CheckTrue(WIRE_STORE_APPLICATION_ID <> $54523457, 'and it is not the station''s TR4W');
      q.SQL.Text := 'SELECT name, "unique" FROM pragma_index_list(''qso'')';
      q.Open;
      sawGuidIndex := False;
      uniqueIdx := False;
      while not q.EOF do
         begin
         if string(q.Fields[0].AsString) = 'idx_qso_guid' then
            begin
            sawGuidIndex := True;
            uniqueIdx := q.Fields[1].AsInteger <> 0;
            end;
         q.Next;
         end;
      q.Close;
      CheckTrue(sawGuidIndex, 'the identity is indexed');
      CheckFalse(uniqueIdx, '... NON-unique: uniqueness is the insert''s, inside the transaction');
   finally
      q.Free;
      db.Free;
      doc.Free;
   end;
end;

procedure TServerWireStoreTests.Test_TheCallbacks;
var
   fn, why: string;
   store: TServerWireStore;
begin
   BeginTest('Test_TheCallbacks');
   fn := ScratchFile('events' + WIRE_STORE_EXTENSION);
   GWritten := 0;
   GCountCalls := 0;
   GFailed := 0;
   GLastCount := -1;
   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      store.OnWritten := @NoteWritten;
      store.OnWriteFailed := @NoteFailed;
      store.OnCountChanged := @NoteCountChanged;
      CheckTrue(store.Initialize(why) = wsiReady, 'opens');
      CheckEquals(0, GLastCount, 'the count is announced at open');
      store.Insert(MakeRow(['guid'], ['e-1']));
      CheckEquals(1, GWritten, 'a stored row is a write');
      CheckEquals(1, GLastCount, 'and the count moved');
      store.Insert(MakeRow(['guid'], ['e-1']));
      CheckEquals(1, GWritten, 'a duplicate is not');
      store.Insert(MakeRow(['guid'], ['e-2']));
      store.Clear;
      CheckEquals(0, GLastCount, 'clear announces 0');
      CheckEquals(0, GFailed, 'nothing failed');
   finally
      store.Free;
   end;
end;

(* A ROW BIG ENOUGH THAT A FEW OF THEM FILL A 4 KB PAGE. *)
function BigRow(aNumber: integer): TWireValues;
begin
   Result := MakeRow(['guid', 'callsign'],
                     ['big-' + IntToStr(aNumber), StringOfChar('x', 1500)]);
end;

(* issue 341, P3: a file that passes the header and schema checks but whose
  pages are damaged is refused on the READ-ONLY peek, so not one byte of it is
  written -- and the server never carries on over it. *)
procedure TServerWireStoreTests.Test_ADamagedFileIsRefusedBeforeItIsOpenedForWriting;
var
   fn, before, why: string;
   store: TServerWireStore;
   i, pageSize: integer;
   f: TFileStream;
   hdr: array[0..1] of Byte;
   junk: array[0..11] of Byte;
begin
   BeginTest('Test_ADamagedFileIsRefusedBeforeItIsOpenedForWriting');
   fn := ScratchFile('damaged' + WIRE_STORE_EXTENSION);
   store := nil;
   CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
   try
      for i := 1 to 300 do
         begin
         CheckTrue(store.Insert(BigRow(i)) = wiStored, 'row ' + IntToStr(i));
         end;
   finally
      FreeAndNil(store);
   end;
   CheckFalse(FileExists(fn + '-wal'), 'the last connection closed, so the data is in the main file');

   (* Overwrite the b-tree PAGE HEADER of a page in the middle of the file (type,
     first free block, cell count, content start): the rows' text would still
     look well formed, so damaging the structure is what integrity_check cannot
     miss. Page 1, with the file header and the schema, is untouched, so only
     the integrity check (or a read of that page) can see it. The page size is in
     bytes 16-17 of the file, big-endian; 1 means 65536. *)
   f := TFileStream.Create(fn, fmOpenReadWrite);
   try
      f.Position := 16;
      f.ReadBuffer(hdr, SizeOf(hdr));
      pageSize := (Integer(hdr[0]) shl 8) or hdr[1];
      if pageSize = 1 then
         begin
         pageSize := 65536;
         end;
      CheckTrue(f.Size > 8 * pageSize, 'the file is big enough to damage a late page');
      for i := Low(junk) to High(junk) do
         begin
         junk[i] := $FF;
         end;
      f.Position := Int64(f.Size div pageSize div 2) * pageSize;
      f.WriteBuffer(junk, 12);
   finally
      f.Free;
   end;
   before := FileBytes(fn);

   store := TServerWireStore.Create(QsoWireColumns, fn);
   try
      CheckTrue(store.Initialize(why) = wsiRefused, 'a damaged log is refused');
      CheckTrue(why <> '', 'and says why: ' + why);
   finally
      store.Free;
   end;
   CheckTrue(before = FileBytes(fn), 'and is byte for byte as it was');
end;

(* issue 341, P3: the disk fills (PRAGMA max_page_count). The refused QSO is
  reported, nothing acknowledged is lost, the rows that were stored stay
  readable, and the very next write after space is back is the probe: it commits
  and the store announces that it is saving again. *)
procedure TServerWireStoreTests.Test_AFullDiskKeepsEveryAcknowledgedQsoAndRecovers;
var
   fn, why: string;
   store, second: TServerWireStore;
   i, stored: integer;
   refused: boolean;
   back: TWireRows;
begin
   BeginTest('Test_AFullDiskKeepsEveryAcknowledgedQsoAndRecovers');
   fn := ScratchFile('full' + WIRE_STORE_EXTENSION);
   GWritten := 0;
   GFailed := 0;
   GLastReason := '';
   store := TServerWireStore.Create(QsoWireColumns, fn);
   second := nil;
   try
      store.OnWritten := @NoteWritten;
      store.OnWriteFailed := @NoteFailed;
      CheckTrue(store.Initialize(why) = wsiReady, 'opens');
      stored := 0;
      for i := 1 to 5 do
         begin
         CheckTrue(store.Insert(BigRow(i)) = wiStored, 'room: ' + IntToStr(i));
         Inc(stored);
         end;

      (* SQLite will not set the limit below the file's size, so 1 means "no
        growth from here". Bounded: a disk that never fills fails the test. *)
      store.LimitPages(1);
      refused := False;
      for i := 6 to 3000 do
         begin
         if store.Insert(BigRow(i)) <> wiStored then
            begin
            refused := True;
            Break;
            end;
         Inc(stored);
         end;
      CheckTrue(refused, 'a QSO that needs a new page is refused, not acknowledged');
      CheckEquals(1, GFailed, 'the server is told once');
      CheckEquals('the disk is full', GLastReason, 'and that the disk is full');
      CheckEquals(stored, store.Count, 'the log holds every acknowledged QSO and not the refused one');
      CheckTrue(store.Insert(BigRow(9001)) = wiFailed, 'a later QSO is refused too');

      (* What a restart would find: another connection sees every acknowledged
        row, in order. *)
      CheckTrue(OpenStore(fn, second) = wsiReady, 'the file still opens');
      CheckEquals(stored, second.Count, 'a second connection counts the same');
      CheckTrue(second.ReadAll(back) and (Length(back) = stored), 'and reads them');
      CheckEquals('big-1', ValueOf(back[0], 'guid'), 'in arrival order');
      FreeAndNil(second);

      (* Space comes back: no restart. The next write is the probe. *)
      GWritten := 0;
      store.LimitPages(0);
      CheckTrue(store.Insert(BigRow(9002)) = wiStored, 'saving resumes on the next QSO');
      CheckEquals(1, GWritten, 'and the store says it is writing again');
      CheckEquals(stored + 1, store.Count, 'one more row, none lost');
   finally
      second.Free;
      store.Free;
   end;
end;

(* A held run (OFFLINEQSO packets) is ONE transaction: when the disk fills inside
  it, the whole run is rolled back and no row of it is visible to anyone. *)
procedure TServerWireStoreTests.Test_ARunThatMeetsAFullDiskLeavesNothingOfItself;
var
   fn, why: string;
   store, second: TServerWireStore;
   i, before: integer;
   refused: boolean;
begin
   BeginTest('Test_ARunThatMeetsAFullDiskLeavesNothingOfItself');
   fn := ScratchFile('fullrun' + WIRE_STORE_EXTENSION);
   store := TServerWireStore.Create(QsoWireColumns, fn);
   second := nil;
   try
      store.OnWriteFailed := @NoteFailed;
      GFailed := 0;
      CheckTrue(store.Initialize(why) = wsiReady, 'opens');
      for i := 1 to 5 do
         begin
         store.Insert(BigRow(i));
         end;
      before := store.Count;
      CheckEquals(5, before, 'five rows before the run');

      store.LimitPages(1);
      store.Hold;
      refused := False;
      for i := 100 to 3000 do
         begin
         if store.Insert(BigRow(i)) <> wiStored then
            begin
            refused := True;
            Break;
            end;
         end;
      CheckTrue(refused, 'the run meets the full disk');
      CheckEquals(1, GFailed, 'the failure is reported');
      store.Release;
      CheckTrue(OpenStore(fn, second) = wsiReady, 'the file opens');
      CheckEquals(before, second.Count, 'not one row of the failed run is stored');
      CheckEquals(before, store.Count, 'the writer agrees');
   finally
      second.Free;
      store.Free;
   end;
end;

(* issue 341, D9: the backup that Clear-all-logs takes first is a VERIFIED copy
  of what is committed, including a run that was still held. *)
procedure TServerWireStoreTests.Test_TheBackupIsAVerifiedCopyOfWhatIsCommitted;
var
   fn, dest, dest2, why: string;
   store, copyStore: TServerWireStore;
begin
   BeginTest('Test_TheBackupIsAVerifiedCopyOfWhatIsCommitted');
   fn := ScratchFile('tobackup' + WIRE_STORE_EXTENSION);
   dest := ScratchFile('copy1' + WIRE_STORE_EXTENSION);
   dest2 := ScratchFile('copy2' + WIRE_STORE_EXTENSION);
   store := nil;
   copyStore := nil;
   try
      CheckTrue(OpenStore(fn, store) = wsiReady, 'opens');
      store.Insert(MakeRow(['guid'], ['b-1']));
      store.Insert(MakeRow(['guid'], ['b-2']));
      store.Insert(MakeRow(['guid'], ['b-3']));
      CheckTrue(store.BackupTo(dest, why), 'the backup is taken: ' + why);
      CheckTrue(FileExists(dest), 'and exists');
      CheckTrue(OpenStore(dest, copyStore) = wsiReady, 'the copy is a server log');
      CheckEquals(3, copyStore.Count, 'holding every row');
      FreeAndNil(copyStore);

      CheckFalse(store.BackupTo(dest, why), 'an existing destination is never overwritten');
      CheckTrue(why <> '', 'and the reason is given');
      CheckEquals(3, store.Count, 'the log itself is untouched');

      (* A run still held is committed first, so the copy has it. *)
      store.Hold;
      store.Insert(MakeRow(['guid'], ['b-4']));
      CheckTrue(store.BackupTo(dest2, why), 'a backup with a held run: ' + why);
      CheckTrue(OpenStore(dest2, copyStore) = wsiReady, 'the second copy opens');
      CheckEquals(4, copyStore.Count, 'and holds the run');
   finally
      copyStore.Free;
      store.Free;
   end;
end;

(* issue 341, P3: a library that cannot be loaded is NAMED, with where the
  server looked, not reported as a log that cannot be opened. *)
procedure TServerWireStoreTests.Test_AMissingSqliteLibraryIsNamed;
var
   text: string;
begin
   BeginTest('Test_AMissingSqliteLibraryIsNamed');
   CheckEquals('', WireStoreLibraryProblem, 'the library this test binary uses loads');
   text := WireStoreLibraryProblemFor('tr4w-no-such-sqlite-library.dll',
                                      'C:\tr4w-no-such-folder\server\');
   CheckTrue(Pos('tr4w-no-such-sqlite-library.dll', text) > 0, 'it names the library: ' + text);
   CheckTrue(Pos('tr4w-no-such-folder', text) > 0, 'and where the server looked: ' + text);
end;

procedure TServerWireStoreTests.RunAllTests;
begin
   try
      Test_TheVectorsComeBackByteForByteInOrder;
      Test_ADuplicateIdentityIsNotStoredTwice;
      Test_AnEditRewritesOnlyTheNewestCopy;
      Test_AHeldRunIsOneTransaction;
      Test_ClearAndCount;
      Test_TheClearFlags;
      Test_TheLargestSerial;
      Test_ARowThatIsNotARowIsRejected;
      Test_AFileThatIsNotOursIsRefusedUntouched;
      Test_AnAcknowledgedQsoIsVisibleToASecondConnection;
      Test_TheDdlIsTheColumnsFile;
      Test_TheCallbacks;
      Test_ADamagedFileIsRefusedBeforeItIsOpenedForWriting;
      Test_AFullDiskKeepsEveryAcknowledgedQsoAndRecovers;
      Test_ARunThatMeetsAFullDiskLeavesNothingOfItself;
      Test_TheBackupIsAVerifiedCopyOfWhatIsCommitted;
      Test_AMissingSqliteLibraryIsNamed;
   finally
      CleanUp;
   end;
end;

end.
