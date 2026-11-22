unit uTestWireColumns;

(* THE WIRE'S COLUMN TABLE IS THE qso TABLE -- stage W1 of
  docs\TR4WSERVER_SQLITE_DESIGN.md section 13.

  uLogRepository.QSO_TABLE_COLUMNS repeats the CREATE TABLE's names, types and
  defaults, and says which columns go on the multi-op wire. This suite is what
  keeps the two equal (design note 13.5): a column added to the schema FAILS
  HERE until the table classifies it, on the wire or local.

  It is the one place a PRAGMA is justified: the question IS what the schema
  says. It reads pragma_table_info one row per column (never group_concat --
  see TLogDatabase.PragmaRowsAsText for why), on the database's connection.

  It also pins tr4w\test\wire\columns.json, the column list the Python golden
  vector maker reads (make_vectors.py), to the same table. Set
  TR4W_WRITE_WIRE_COLUMNS=1 to rewrite the file from the table instead.

  And it reads a row written by SaveQSO through ReadWireValues, and compares
  every value with the same row read by column NAME. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TWireColumnsTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
   protected
      procedure Test_TheTableIsTheCreateTable;
      procedure Test_TheLocalColumnsAreTheBookkeeping;
      procedure Test_TheColumnsFileIsTheWireTable;
      procedure Test_ACommittedRowReadsAsTheWireCarriesIt;
   public
      procedure RunAllTests; override;
   end;

(* tr4w\test\wire\<aLeaf>, found from the test exe (which lives in
  tr4w\test\unit). *)
function WireTestFile(const aLeaf: string): string;
(* A whole UTF-8 file, decoded to the native string. *)
function ReadUtf8File(const aPath: string): string;

implementation

uses
   SysUtils, Classes, db, sqldb, fpjson, jsonparser,
   VC, uLogDatabase, uLogRepository, uQsoColumns, uWireQso;

const
   NONE_DEFAULT = '<none>';

function WireTestFile(const aLeaf: string): string;
begin
   Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
                            'wire' + PathDelim + aLeaf);
end;

function ReadUtf8File(const aPath: string): string;
var
   f: TFileStream;
   bytes: RawByteString;
begin
   f := TFileStream.Create(aPath, fmOpenRead or fmShareDenyNone);
   try
      bytes := '';
      SetLength(bytes, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(bytes[1], f.Size);
         end;
   finally
      f.Free;
   end;
   Result := UTF8Decode(bytes);
end;

procedure WriteUtf8File(const aPath, aText: string);
var
   f: TFileStream;
   bytes: UTF8String;
begin
   bytes := UTF8Encode(aText);
   f := TFileStream.Create(aPath, fmCreate);
   try
      if Length(bytes) > 0 then
         begin
         f.WriteBuffer(bytes[1], Length(bytes));
         end;
   finally
      f.Free;
   end;
end;

(* A DEFAULT as PRAGMA table_info gives it, as canonical text: NULL (here
  NONE_DEFAULT) is '', a quoted string loses its quotes, a number stays its
  digits -- the bench's DefaultText. *)
function CanonicalDefault(const aRaw: string): string;
begin
   Result := '';
   if aRaw = NONE_DEFAULT then
      begin
      Exit;
      end;
   Result := aRaw;
   if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
      begin
      Result := Copy(Result, 2, Length(Result) - 2);
      Result := StringReplace(Result, '''''', '''', [rfReplaceAll]);
      end;
end;

function TWireColumnsTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_wirecols_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TWireColumnsTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '-wal') then
      begin
      DeleteFile(aFileName + '-wal');
      end;
   if FileExists(aFileName + '-shm') then
      begin
      DeleteFile(aFileName + '-shm');
      end;
end;

procedure TWireColumnsTests.Test_TheTableIsTheCreateTable;
var
   db: TLogDatabase;
   fn, raw: string;
   rows, parts: TStringList;
   table: TWireColumns;
   i: integer;
   q: TSQLQuery;
begin
   BeginTest('Test_TheTableIsTheCreateTable');
   CheckEquals('', string(QsoWireTableProblem), 'the wire table agrees with QSO_COLUMNS');
   fn := TempLogName('schema.db');
   Scrub(fn);
   rows := TStringList.Create;
   parts := TStringList.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      (* TLogDatabase.PragmaRowsAsText is private, so this reads the pragma the
        way the other schema tests do (uTestLatestContest.TestLogHasColumn):
        a query on the database's connection. One short row per column. *)
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT name, type, ifnull(dflt_value, ''' + NONE_DEFAULT + ''') AS dflt ' +
                       'FROM pragma_table_info(''qso'') ORDER BY cid';
         q.Open;
         while not q.EOF do
            begin
            rows.Add(string(q.Fields[0].AsString) + '|' + string(q.Fields[1].AsString) + '|' +
                     string(q.Fields[2].AsString));
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
      raw := rows.Text;
      table := QsoTableColumns;
      CheckEquals(rows.Count, table.Count,
         'QSO_TABLE_COLUMNS has a row for every column of the qso table');
      for i := 0 to rows.Count - 1 do
         begin
         parts.Clear;
         parts.Delimiter := '|';
         parts.StrictDelimiter := True;
         parts.DelimitedText := rows[i];
         CheckEquals(3, parts.Count, 'pragma row ' + rows[i]);
         if (parts.Count <> 3) or (i >= table.Count) then
            begin
            Continue;
            end;
         CheckEquals(parts[0], table.Name[i],
            'column ' + IntToStr(i) + ': the table names the CREATE TABLE''s column ' +
            '(an unclassified or moved column fails here)');
         CheckEquals(Ord(Pos('INT', UpperCase(parts[1])) > 0), Ord(table.Numeric[i]),
            parts[0] + ': INTEGER or not');
         CheckEquals(CanonicalDefault(parts[2]), table.Default[i],
            parts[0] + ': its DEFAULT');
         end;
   finally
      db.Free;
      parts.Free;
      rows.Free;
      Scrub(fn);
   end;
end;

procedure TWireColumnsTests.Test_TheLocalColumnsAreTheBookkeeping;
const
   LOCAL: array[0..6] of string = ('id', 'session_id', 'session_seq',
      'sent_to_server', 'server_dirty', 'sent_udp', 'udp_dirty');
var
   table, wire: TWireColumns;
   i, locals, lastTag: integer;
   ordered: boolean;
begin
   BeginTest('Test_TheLocalColumnsAreTheBookkeeping');
   table := QsoTableColumns;
   wire := QsoWireColumns;
   for i := Low(LOCAL) to High(LOCAL) do
      begin
      CheckTrue(QsoColumnIsLocal(LOCAL[i]), LOCAL[i] + ' is local');
      CheckEquals(-1, wire.IndexOfName(LOCAL[i]), LOCAL[i] + ' is not on the wire');
      end;
   (* Exactly those: every other column is on the wire, in table order. *)
   locals := 0;
   lastTag := -1;
   ordered := True;
   for i := 0 to table.Count - 1 do
      begin
      if QsoColumnIsLocal(table.Name[i]) then
         begin
         inc(locals);
         end
      else
         begin
         if wire.IndexOfName(table.Name[i]) <> lastTag + 1 then
            begin
            ordered := False;
            end;
         lastTag := wire.IndexOfName(table.Name[i]);
         CheckEquals(Ord(table.Numeric[i]), Ord(wire.Numeric[lastTag]), table.Name[i] + ' kind');
         CheckEquals(table.Default[i], wire.Default[lastTag], table.Name[i] + ' default');
         end;
      end;
   CheckEquals(Length(LOCAL), locals, 'the local columns are exactly the bookkeeping');
   CheckEquals(table.Count - Length(LOCAL), wire.Count, 'every other column is on the wire');
   CheckTrue(ordered, 'the wire''s tags follow the table''s order');
   (* Pending a ruling (design note 13.5), and on the wire until then. *)
   CheckTrue(wire.IndexOfName('notes') >= 0, 'notes is on the wire');
   CheckTrue(wire.IndexOfName('rcvd_extra') >= 0, 'rcvd_extra is on the wire');
   CheckTrue(wire.IndexOfName('qso_set_id') >= 0, 'qso_set_id is on the wire');
end;

(* [{"name":..,"num":..,"def":..}, ...], one entry per line, in tag order --
  the shape wire_check.py's fields.json already has. *)
function ColumnsFileText(aWire: TWireColumns): string;
var
   o: TJSONObject;
   i: integer;
begin
   Result := '[' + #13#10;
   for i := 0 to aWire.Count - 1 do
      begin
      o := TJSONObject.Create;
      try
         o.Add('name', aWire.Name[i]);
         o.Add('num', aWire.Numeric[i]);
         o.Add('def', aWire.Default[i]);
         Result := Result + '  ' + string(o.AsJSON);
      finally
         o.Free;
      end;
      if i < aWire.Count - 1 then
         begin
         Result := Result + ',';
         end;
      Result := Result + #13#10;
      end;
   Result := Result + ']' + #13#10;
end;

procedure TWireColumnsTests.Test_TheColumnsFileIsTheWireTable;
var
   wire: TWireColumns;
   path: string;
   d: TJSONData;
   a: TJSONArray;
   o: TJSONObject;
   i: integer;
begin
   BeginTest('Test_TheColumnsFileIsTheWireTable');
   wire := QsoWireColumns;
   path := WireTestFile('columns.json');
   if GetEnvironmentVariable('TR4W_WRITE_WIRE_COLUMNS') = '1' then
      begin
      WriteUtf8File(path, ColumnsFileText(wire));
      end;
   CheckTrue(FileExists(path), path + ' exists (TR4W_WRITE_WIRE_COLUMNS=1 writes it)');
   if not FileExists(path) then
      begin
      Exit;
      end;
   (* Compared by CONTENT: the line endings are the lint's business. *)
   d := GetJSON(ReadUtf8File(path));
   try
      CheckTrue(d is TJSONArray, 'columns.json is an array');
      if not (d is TJSONArray) then
         begin
         Exit;
         end;
      a := TJSONArray(d);
      CheckEquals(wire.Count, a.Count, 'columns.json has every wire column');
      for i := 0 to a.Count - 1 do
         begin
         if i >= wire.Count then
            begin
            Break;
            end;
         o := a.Objects[i];
         CheckEquals(wire.Name[i], string(o.Strings['name']), 'tag ' + IntToStr(i + 1) + ' name');
         CheckEquals(Ord(wire.Numeric[i]), Ord(o.Booleans['num']), wire.Name[i] + ' num');
         CheckEquals(wire.Default[i], string(o.Strings['def']), wire.Name[i] + ' def');
         end;
   finally
      d.Free;
   end;
end;

procedure TWireColumnsTests.Test_ACommittedRowReadsAsTheWireCarriesIt;
const
   (* 'Jos' + U+00E9, as UTF-8 bytes. *)
   JOSE_UTF8_HEX = '4A6F73C3A9';
   (* rcvd_extra is the UPDATE below. rcvd_precedence is SaveQSO's OWN: a
     record whose Precedence is the "no character" #0 (what FillChar and the
     .TRW leave) is stored as a one-character NUL string, not NULL. MEASURED
     here 2026-11-22 -- the writer-side cause of the corpus finding in
     bench_wire_formats. Fixing the writer is not W1; when it stores NULL,
     this constant becomes 'rcvd_extra'. *)
   NUL_COLUMNS_SEEN = 'rcvd_precedence rcvd_extra';
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
   fn, expected: string;
   rowId: Int64;
   values: TWireValues;
   nul, i: integer;
   wire: TWireColumns;
   q: TSQLQuery;
   field: TField;
   name: ShortString;
   nulColumns: string;
   nulCount: integer;
begin
   BeginTest('Test_ACommittedRowReadsAsTheWireCarriesIt');
   fn := TempLogName('read.db');
   Scrub(fn);
   wire := QsoWireColumns;

   FillChar(rec, SizeOf(ContestExchange), 0);
   rec.ceRecordKind := rkQSO;
   rec.ceContest := NoContest;
   rec.id := 'exchange1';
   rec.ceQSOID1 := 1001;
   rec.ceQSOID2 := 2002;
   rec.ceComputerID := 'B';
   rec.tSysTime.qtYear := 26;
   rec.tSysTime.qtMonth := 6;
   rec.tSysTime.qtDay := 1;
   rec.tSysTime.qtHour := 12;
   rec.tSysTime.qtMinute := 30;
   rec.tSysTime.qtSecond := 15;
   rec.Callsign := 'K1ABC';
   rec.QTH.StandardCall := 'K1ABC';
   rec.Frequency := 14025000;
   rec.Band := Band20;
   rec.Mode := CW;
   rec.ExtMode := eCW;
   rec.RSTSent := 599;
   rec.RSTReceived := 579;
   rec.NumberSent := 1;
   rec.NumberReceived := 17;
   rec.QSOPoints := 3;
   (* The name as UTF-8 BYTES, put in byte by byte: assigning a UTF8String to
     a ShortString would CONVERT it to the ANSI code page. *)
   name := 'Jos';
   name := name + AnsiChar($C3) + AnsiChar($A9);
   rec.Name := name;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         rowId := repo.SaveQSO(rec);
         repo.Commit;

         (* Two values no writer in this program produces: a NUL inside a TEXT
           value, and rcvd_extra, which no build writes. *)
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.SQL.Text := 'UPDATE qso SET rcvd_extra = ''a'' || char(0) || ''b'', ' +
                          'notes = ''Jos'' || char(233) WHERE id = ' + IntToStr(rowId);
            q.ExecSQL;
         finally
            q.Free;
         end;
         repo.Commit;

         CheckTrue(repo.ReadWireValues(rowId, values, nul), 'the row reads');
         CheckEquals(wire.Count, Length(values), 'one value per wire column');
         CheckFalse(repo.ReadWireValues(rowId + 1000, values, nul), 'no such row');
         CheckTrue(repo.ReadWireValues(rowId, values, nul), 'the row reads again');

         (* EVERY value, against the same row read by column NAME. *)
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.SQL.Text := 'SELECT *, hex(rcvd_name) AS name_hex, hex(notes) AS notes_hex ' +
                          'FROM qso WHERE id = ' + IntToStr(rowId);
            q.Open;
            CheckFalse(q.EOF, 'the row is there by name');
            nulColumns := '';
            nulCount := 0;
            for i := 0 to wire.Count - 1 do
               begin
               field := q.FieldByName(wire.Name[i]);
               if field.IsNull then
                  begin
                  expected := '';
                  end
               else if wire.Numeric[i] then
                  begin
                  expected := IntToStr(field.AsLargeInt);
                  end
               else
                  begin
                  expected := UTF8Decode(AnsiString(field.AsString));
                  if Pos(#0, expected) > 0 then
                     begin
                     nulColumns := nulColumns + wire.Name[i] + ' ';
                     inc(nulCount);
                     end;
                  expected := StringReplace(expected, #0, '', [rfReplaceAll]);
                  end;
               CheckEquals(expected, values[i], wire.Name[i]);
               end;
            (* rcvd_extra is ours (the UPDATE above). Any other is SaveQSO's
              own -- the writer-side NUL the bench found in the corpus. *)
            CheckEquals(NUL_COLUMNS_SEEN, Trim(nulColumns),
               'the TEXT columns that hold a NUL');
            CheckEquals(nulCount, nul, 'ReadWireValues counts each');
            (* What the FILE holds: UTF-8, both from SaveQSO and from SQL. *)
            CheckEquals(JOSE_UTF8_HEX, string(q.FieldByName('name_hex').AsString),
               'rcvd_name is stored as UTF-8');
            CheckEquals(JOSE_UTF8_HEX, string(q.FieldByName('notes_hex').AsString),
               'notes is stored as UTF-8');
            q.Close;
         finally
            q.Free;
         end;

         CheckEquals('Jos' + WideChar($E9), values[wire.IndexOfName('rcvd_name')],
            'rcvd_name decodes to the native string');
         CheckEquals('Jos' + WideChar($E9), values[wire.IndexOfName('notes')],
            'notes decodes to the native string');
         CheckEquals('ab', values[wire.IndexOfName('rcvd_extra')], 'the NUL is stripped');
         CheckEquals('K1ABC', values[wire.IndexOfName('callsign')], 'callsign');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      Scrub(fn);
   end;
end;

procedure TWireColumnsTests.RunAllTests;
begin
   Test_TheTableIsTheCreateTable;
   Test_TheLocalColumnsAreTheBookkeeping;
   Test_TheColumnsFileIsTheWireTable;
   Test_ACommittedRowReadsAsTheWireCarriesIt;
end;

end.
