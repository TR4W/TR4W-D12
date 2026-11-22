program bench_wire_formats;

(* WHAT DOES A QSO COST ON THE MULTI-OP WIRE, AND IN WHICH FORMAT?
  (issue 300, NY4I 2026-11-22: "gather some metrics on sending data to the
  tr4wserver via JSON or some other extensible wire format ... we should not
  send fields that are blank (but we should checksum the record) so the server
  knows it did not miss some fields versus we did not send them." And, once
  the wire became the QSO AS AN EVENT: "the 376 byte record is woefully poor
  design for an event source".)

  THE FIELD LIST IS THE REPOSITORY'S (stage W1, design note section 13). The
  wire carries the qso table's columns, by column name, minus the local
  bookkeeping that is about THIS database and not about the QSO. The list --
  names, kinds, defaults, on the wire or local -- is defined ONCE, beside
  TQsoColumn in uLogRepository (QsoWireColumns), and uTestWireColumns pins it
  to the CREATE TABLE. The values are read by uLogRepository.ReadWireValues,
  row by row id. This bench used to read PRAGMA table_info and run its own
  SELECT, an interim exception that is now gone.

  THE CODEC IS uWireQso -- the canonical stream, the CRC-32 and the JSON
  encode/decode the program will ship -- so the corpus run below verifies the
  code that ships, not a copy. Only TLV (not chosen) is local here.

  THREE ENCODINGS of the same row, over every QSO of the corpus logs:

    JSON full   one object, EVERY field named (a NULL is JSON null).
    JSON omit   one object, a field left out when it equals its column's
                DEFAULT, plus a "k" member that is the record checksum.
    TLV         tag byte, 2-byte length, UTF-8 value; defaults omitted; tag 0
                is the checksum.  (Considered and not chosen -- kept as the
                small-end reference.)

  OMISSION IS "EQUALS THE COLUMN'S DEFAULT", NOT "IS ZERO". A nullable
  integer column with no default is NULL when absent, and a real 0 there is
  SENT; a NOT NULL DEFAULT 0 column omits its zero. NULL and 0 stay distinct.
  The receiver starts every field at its default and overlays what arrived.

  THE CHECKSUM covers the FULL row -- every field, defaults included, in the
  schema's column order, each as tag + 2-byte byte-length + the value's UTF-8
  bytes -- so it is the same whether or not the sender omitted anything. The
  receiver decodes, fills every missing field with its default, recomputes and
  compares. A match means nothing was LOST; a mismatch is a record to
  re-request. THE WIRE IS UTF-8 (NY4I: we own every sender and the server).

  THE DROPPED-FIELD TEST: every field whose value is not its default is
  pretended lost (reverts to the default) and the checksum recomputed. It must
  differ. CRC-32 is not cryptographic; a collision shows as below 100 percent.

  THE ROUND TRIP is exact: after decoding, EVERY field must equal the sender's,
  not only the checksum.

  WHAT THIS DOES NOT MEASURE, said plainly:
    - A number is its decimal text in JSON/TLV. A binary-integer TLV would be
      smaller; JSON key names are the columns' names.
    - Framing (the packet header) is not counted.
    - Encode time is the checksum plus building the payload from the row's
      values; decode time is parsing plus recomputing the checksum. Reading
      the row from SQLite is the same for every format and is not timed.
    - The corpus logs' non-ASCII content is nil; the unicode_synthetic set
      (--out) pins that path, and so do the golden vectors
      (tr4w\test\wire, uTestWireQso). Text columns are read by the repository.
    - Encode now includes PackCanonical's per-record allocation (the bench
      used a fixed buffer), so its microseconds are not comparable one for
      one with the numbers recorded before W1; sizes and counts are.

  Usage:  bench_wire_formats [corpus-dir] [passes] [out-dir]
          defaults: ..\corpus  and 3 passes; with an out-dir it also writes
          every set's encoded frames, fields.json and the unicode set, for
          wire_check.py (a receiver in another language).
  sqlite3.dll must be beside the exe (copy tr4w\redist\x86_64-win64\sqlite3.dll;
  Build-Bench.ps1 does not stage DLLs). *)

{$I ..\..\src\tr4w.inc}

uses
   (* Interfaces FIRST, as every bench: the log units reach the LCL. *)
   Interfaces,
   SysUtils,
   Classes,
{$IFDEF WINDOWS}
   Windows,   (* QueryPerformanceCounter -- see StartClock *)
{$ENDIF}
   fpjson,     (* fields.json, for wire_check.py *)
   Log4D,
   MainUnit,  (* logger -- units below log through it *)
   uLogDatabase,
   uLogRepository,   (* ReadWireValues -- a row as wire values *)
   uQsoColumns,      (* QsoWireColumns -- the wire's columns *)
   uWireQso;         (* the codec that ships *)

const
   BUF_SIZE   = 131072;   (* 100+ fields; a few may be 255 non-Latin characters *)

type
   (* A row: one canonical value per wire column, index 0 = tag 1. *)
   TVals = TWireValues;
   TByteBuf = array[0..BUF_SIZE - 1] of byte;

var
   gFreq: Int64 = 0;
   gOutDir: string = '';
   (* uLogRepository's, shared and read-only: never freed here. *)
   gCols: TWireColumns = nil;
   gDiffShown: integer = 0;   (* the first few field differences are printed *)
   gNulValues: Int64 = 0;     (* TEXT values that held a NUL character *)

(* THE CLOCK, as bench_callsign and bench_enter_latency. *)
procedure StartClock(out aAt: Int64);
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(aAt);
{$ELSE}
   aAt := Int64(GetTickCount64);
{$ENDIF}
end;

function StopClock(const aAt: Int64): double;   (* milliseconds *)
var
   stamp: Int64;
begin
{$IFDEF WINDOWS}
   QueryPerformanceCounter(stamp);
   Result := (stamp - aAt) * 1000.0 / gFreq;
{$ELSE}
   stamp := Int64(GetTickCount64);
   Result := stamp - aAt;
{$ENDIF}
end;

(* THE SHIPPING CODEC under the bench's old call shapes, so the measuring
  logic below is unchanged. aSkip is a 0-based column, -1 = none; aBuf is no
  longer used (PackCanonical allocates). *)
function RecordCrc(const aVals: TVals; aSkip: integer; var aBuf: TByteBuf): Cardinal;
begin
   Result := RecordCrc32(gCols, aVals, aSkip);
end;

function EncodeJson(const aVals: TVals; aCrc: Cardinal; aOmit: boolean): string;
begin
   Result := uWireQso.EncodeJson(gCols, aVals, aCrc, aOmit);
end;

procedure DecodeJson(const aText: string; out aVals: TVals; out aSent: Cardinal);
begin
   uWireQso.DecodeJson(gCols, aText, aVals, aSent);
end;

procedure ResetToDefaults(out aVals: TVals);
begin
   aVals := gCols.DefaultValues;
end;

(* Tag 0 is the checksum, 4 bytes. *)
function EncodeTlv(const aVals: TVals; aCrc: Cardinal; var aBuf: TByteBuf): integer;
var
   i, j: integer;
   u: UTF8String;
begin
   Result := 0;
   aBuf[Result] := 0; inc(Result);
   aBuf[Result] := 4; inc(Result);
   aBuf[Result] := 0; inc(Result);
   aBuf[Result] := aCrc and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 8) and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 16) and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 24) and $FF; inc(Result);
   for i := 0 to gCols.Count - 1 do
      begin
      if aVals[i] <> gCols.Default[i] then
         begin
         u := UTF8Encode(aVals[i]);
         aBuf[Result] := i + 1;
         inc(Result);
         aBuf[Result] := Length(u) and $FF;
         inc(Result);
         aBuf[Result] := (Length(u) shr 8) and $FF;
         inc(Result);
         for j := 1 to Length(u) do
            begin
            aBuf[Result] := Ord(u[j]);
            inc(Result);
            end;
         end;
      end;
end;

procedure DecodeTlv(const aBuf: TByteBuf; aLen: integer; out aVals: TVals; out aSent: Cardinal);
var
   p, tag, ln, j: integer;
   v: UTF8String;
begin
   ResetToDefaults(aVals);
   aSent := 0;
   p := 0;
   while p < aLen do
      begin
      tag := aBuf[p];
      ln := aBuf[p + 1] or (aBuf[p + 2] shl 8);
      inc(p, 3);
      if tag = 0 then
         begin
         aSent := aBuf[p] or (aBuf[p + 1] shl 8) or (aBuf[p + 2] shl 16) or (Cardinal(aBuf[p + 3]) shl 24);
         end
      else
         begin
         SetLength(v, ln);
         for j := 0 to ln - 1 do
            begin
            v[j + 1] := AnsiChar(aBuf[p + j]);
            end;
         aVals[tag - 1] := UTF8Decode(v);
         end;
      inc(p, ln);
      end;
end;

(* One frame: a 4-byte little-endian length, then the bytes. *)
procedure WriteFrame(aStream: TStream; const aData; aLen: integer);
var
   len: LongWord;
begin
   len := LongWord(aLen);
   aStream.WriteBuffer(len, 4);
   aStream.WriteBuffer(aData, aLen);
end;

procedure WriteFrameText(aStream: TStream; const aText: string);
var
   u: UTF8String;
begin
   u := UTF8Encode(aText);
   WriteFrame(aStream, u[1], Length(u));
end;

(* The schema's fields in tag order, with the numeric flag and the default, for
  the receiver: [{"name":..,"num":..,"def":..}, ...]. Tag i is entry i. *)
procedure WriteFieldList(const aPath: string);
var
   a: TJSONArray;
   o: TJSONObject;
   i: integer;
   sl: TStringList;
begin
   a := TJSONArray.Create;
   sl := TStringList.Create;
   try
      for i := 0 to gCols.Count - 1 do
         begin
         o := TJSONObject.Create;
         o.Add('name', gCols.Name[i]);
         o.Add('num', gCols.Numeric[i]);
         o.Add('def', gCols.Default[i]);
         a.Add(o);
         end;
      sl.Text := a.AsJSON;
      sl.SaveToFile(aPath);
   finally
      sl.Free;
      a.Free;
   end;
end;

(* Replaces aTo with a byte copy of aFrom (TFileStream: no PChar, no Windows). *)
procedure CopyBytes(const aFrom, aTo: string);
var
   src, dst: TFileStream;
begin
   SysUtils.DeleteFile(aTo);
   src := TFileStream.Create(aFrom, fmOpenRead or fmShareDenyNone);
   try
      dst := TFileStream.Create(aTo, fmCreate);
      try
         dst.CopyFrom(src, 0);
      finally
         dst.Free;
      end;
   finally
      src.Free;
   end;
end;

(* Are two rows identical in every field? *)
function SameVals(const a, b: TVals): boolean;
var
   i: integer;
begin
   Result := True;
   for i := 0 to gCols.Count - 1 do
      begin
      if a[i] <> b[i] then
         begin
         Result := False;
         if gDiffShown < 6 then
            begin
            inc(gDiffShown);
            WriteLn(Format('  DIFF field %s (tag %d): decoded [%s] sent [%s]',
               [gCols.Name[i], i + 1, a[i], b[i]]));
            end;
         Exit;
         end;
      end;
end;

(* The round trip, and WHICH half failed: the checksum the sender stated, the
  checksum recomputed from what was decoded, or a field. The first few are
  printed. *)
function RoundOk(const aWhat: string; aSent, aCrcFull: Cardinal; const aVals, aRow: TVals): boolean;
var
   b: TByteBuf;
   again: Cardinal;
   same: boolean;
begin
   again := RecordCrc(aVals, -1, b);
   same := SameVals(aVals, aRow);   (* always run, so the differing field is named *)
   Result := (aSent = aCrcFull) and (again = aCrcFull) and same;
   if (not Result) and (gDiffShown < 6) then
      begin
      inc(gDiffShown);
      WriteLn(Format('  ROUND-TRIP %s: stated %.8x, sender %.8x, recomputed %.8x',
         [aWhat, aSent, aCrcFull, again]));
      end;
end;

type
   TBytesArray = array of array of byte;

   TSetResult = record
      Rows: integer;
      SumJF, SumJ, SumT: Int64;
      NonDefault: Int64;
      Trials, Caught, Bad: Int64;
      MsEncJF, MsEncJ, MsEncT, MsDecJF, MsDecJ, MsDecT: double;
   end;

(* One log: read its rows, then size, verify and time every format. *)
procedure RunSet(const aName, aDb: string; aRepeat: integer; out aRes: TSetResult);
var
   db: TLogDatabase;
   repo: TLogRepository;
   rows: array of TVals;
   n, i, pass, f, tl, nul: integer;
   scratch, js, jf: string;
   buf, buf2: TByteBuf;
   crcFull, sent: Cardinal;
   vals: TVals;
   at, rowCount, index: Int64;
   jfs, jss: array of string;
   tls: TBytesArray;
   fJF, fJ, fT: TFileStream;
begin
   FillChar(aRes, SizeOf(aRes), 0);
   db := TLogDatabase.Create;
   n := 0;
   try
      (* The fixtures are older schemas and Open MIGRATES, so it runs on a copy
        under the system temp folder; a tracked fixture is never opened for
        write. *)
      scratch := IncludeTrailingPathDelimiter(GetTempDir) + 'wirebench_' + aName + '.db';
      CopyBytes(aDb, scratch);
      if FileExists(aDb + '-wal') then
         begin
         CopyBytes(aDb + '-wal', scratch + '-wal');
         end;
      db.Open(scratch);

      (* THE REPOSITORY READS THE ROWS, in log order, each by its row id --
        the way the W4 sender will read a committed row. RowIdAtIndex is an
        OFFSET walk; at corpus sizes it is not what is being measured (the
        read is not timed). *)
      repo := TLogRepository.Create(db);
      try
         rowCount := repo.RecordCount;
         SetLength(rows, rowCount);
         index := 0;
         while index < rowCount do
            begin
            if repo.ReadWireValues(repo.RowIdAtIndex(index), rows[n], nul) then
               begin
               (* FINDING (2026-11-22): a TEXT column can hold a literal NUL,
                 the old record's "no character" (AnsiChar #0) stored as a
                 one-character string where NULL was meant. The repository
                 strips it (uWireQso.WireText) and COUNTS it, so the defect at
                 the writer is not hidden. *)
               inc(gNulValues, nul);
               inc(n);
               end;
            inc(index);
            end;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   aRes.Rows := n;
   if n = 0 then
      begin
      Exit;
      end;

   fJF := nil;
   fJ := nil;
   fT := nil;
   SetLength(jfs, n);
   SetLength(jss, n);
   SetLength(tls, n);
   try
      if gOutDir <> '' then
         begin
         fJF := TFileStream.Create(gOutDir + PathDelim + aName + '.jsonfull', fmCreate);
         fJ := TFileStream.Create(gOutDir + PathDelim + aName + '.jsonomit', fmCreate);
         fT := TFileStream.Create(gOutDir + PathDelim + aName + '.tlv', fmCreate);
         end;

      (* Sizes and CORRECTNESS, once per row. *)
      for i := 0 to n - 1 do
         begin
         crcFull := RecordCrc(rows[i], -1, buf);
         jss[i] := EncodeJson(rows[i], crcFull, True);
         jfs[i] := EncodeJson(rows[i], crcFull, False);
         tl := EncodeTlv(rows[i], crcFull, buf2);
         SetLength(tls[i], tl);
         Move(buf2[0], tls[i][0], tl);
         inc(aRes.SumJ, Length(UTF8Encode(jss[i])));
         inc(aRes.SumJF, Length(UTF8Encode(jfs[i])));
         inc(aRes.SumT, tl);
         if fT <> nil then
            begin
            WriteFrameText(fJF, jfs[i]);
            WriteFrameText(fJ, jss[i]);
            WriteFrame(fT, buf2[0], tl);
            end;

         (* Exact reconstruction in all three, and the checksum agrees. *)
         DecodeJson(jss[i], vals, sent);
         if not RoundOk('jsonomit', sent, crcFull, vals, rows[i]) then
            begin
            inc(aRes.Bad);
            end;
         DecodeJson(jfs[i], vals, sent);
         if not RoundOk('jsonfull', sent, crcFull, vals, rows[i]) then
            begin
            inc(aRes.Bad);
            end;
         DecodeTlv(buf2, tl, vals, sent);
         if not RoundOk('tlv', sent, crcFull, vals, rows[i]) then
            begin
            inc(aRes.Bad);
            end;

         (* THE DROPPED-FIELD TEST: every non-default field, treated as lost. *)
         for f := 0 to gCols.Count - 1 do
            begin
            if rows[i][f] <> gCols.Default[f] then
               begin
               inc(aRes.NonDefault);
               inc(aRes.Trials);
               if RecordCrc(rows[i], f, buf) <> crcFull then
                  begin
                  inc(aRes.Caught);
                  end;
               end;
            end;
         end;

      (* Timing: aRepeat passes over every row, one stage at a time. *)
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            crcFull := RecordCrc(rows[i], -1, buf);
            jf := EncodeJson(rows[i], crcFull, False);
            end;
         end;
      aRes.MsEncJF := StopClock(at);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            crcFull := RecordCrc(rows[i], -1, buf);
            js := EncodeJson(rows[i], crcFull, True);
            end;
         end;
      aRes.MsEncJ := StopClock(at);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            crcFull := RecordCrc(rows[i], -1, buf);
            tl := EncodeTlv(rows[i], crcFull, buf2);
            end;
         end;
      aRes.MsEncT := StopClock(at);

      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            DecodeJson(jfs[i], vals, sent);
            crcFull := RecordCrc(vals, -1, buf);
            end;
         end;
      aRes.MsDecJF := StopClock(at);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            DecodeJson(jss[i], vals, sent);
            crcFull := RecordCrc(vals, -1, buf);
            end;
         end;
      aRes.MsDecJ := StopClock(at);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            Move(tls[i][0], buf2[0], Length(tls[i]));
            DecodeTlv(buf2, Length(tls[i]), vals, sent);
            crcFull := RecordCrc(vals, -1, buf);
            end;
         end;
      aRes.MsDecT := StopClock(at);
   finally
      fJF.Free;
      fJ.Free;
      fT.Free;
   end;
end;

(* A string from Unicode code points, so this source file carries no non-ASCII
  literal. Above $FFFF: a surrogate pair. *)
function FromCodePoints(const aPoints: array of Cardinal): string;
var
   i: integer;
   cp: Cardinal;
begin
   Result := '';
   for i := Low(aPoints) to High(aPoints) do
      begin
      cp := aPoints[i];
      if cp > $FFFF then
         begin
         cp := cp - $10000;
         Result := Result + WideChar($D800 + (cp shr 10)) + WideChar($DC00 + (cp and $3FF));
         end
      else
         begin
         Result := Result + WideChar(cp);
         end;
      end;
end;

function TagOf(const aName: string): integer;
var
   at: integer;
begin
   at := gCols.IndexOfName(aName);
   if at < 0 then
      begin
      WriteLn('no such column: ', aName);
      Halt(3);
      end;
   Result := at;
end;

(* THE NON-ASCII PIN (the wire is UTF-8; every sender converts from its own
  native strings). Values go straight into a default row. Written as
  unicode_synthetic.* beside the corpus sets, for wire_check.py. *)
procedure RunUnicodeSet;
const
   CASES = 7;
var
   buf, buf2: TByteBuf;
   fJF, fJ, fT: TFileStream;
   k, i, tl, bad: integer;
   crcFull, sent: Cardinal;
   js, jf, longName: string;
   row, back: TVals;
begin
   fJF := TFileStream.Create(gOutDir + PathDelim + 'unicode_synthetic.jsonfull', fmCreate);
   fJ := TFileStream.Create(gOutDir + PathDelim + 'unicode_synthetic.jsonomit', fmCreate);
   fT := TFileStream.Create(gOutDir + PathDelim + 'unicode_synthetic.tlv', fmCreate);
   bad := 0;
   try
      longName := '';
      for i := 1 to 255 do
         begin
         longName := longName + FromCodePoints([$0416]);   (* 2 UTF-8 bytes each *)
         end;
      for k := 1 to CASES do
         begin
         ResetToDefaults(row);
         row[TagOf('callsign')] := 'K1ABC';
         case k of
            1: row[TagOf('rcvd_name')] := 'Jos' + FromCodePoints([$E9]);                       (* accented Latin *)
            2: row[TagOf('rcvd_name')] := FromCodePoints([$0418, $0432, $0430, $043D]);       (* Cyrillic *)
            3: row[TagOf('rcvd_name')] := FromCodePoints([$5C71, $7530, $592A, $90CE]);       (* Japanese *)
            4: row[TagOf('rcvd_kids')] := longName;                                           (* 255 chars = 510 bytes *)
            5: row[TagOf('exchange_received')] := '73 ' + FromCodePoints([$1F600]);           (* outside the BMP *)
            6: begin
               row[TagOf('exchange_received')] := '0';                                        (* a string "0" is a value *)
               row[TagOf('qso_points')] := '2';
               end;
            7: row[TagOf('rcvd_qth')] := FromCodePoints([$FC, $DF, $E5, $F8, $20AC]);         (* Latin-1 and euro *)
         end;
         crcFull := RecordCrc(row, -1, buf);
         js := EncodeJson(row, crcFull, True);
         jf := EncodeJson(row, crcFull, False);
         tl := EncodeTlv(row, crcFull, buf2);
         WriteFrameText(fJF, jf);
         WriteFrameText(fJ, js);
         WriteFrame(fT, buf2[0], tl);

         DecodeJson(js, back, sent);
         if (sent <> crcFull) or (not SameVals(back, row)) then
            begin
            inc(bad);
            end;
         DecodeJson(jf, back, sent);
         if (sent <> crcFull) or (not SameVals(back, row)) then
            begin
            inc(bad);
            end;
         DecodeTlv(buf2, tl, back, sent);
         if (sent <> crcFull) or (not SameVals(back, row)) then
            begin
            inc(bad);
            end;
         end;
      WriteLn(Format('unicode_synthetic: %d rows, Pascal round-trip failures: %d', [CASES, bad]));
      if bad <> 0 then
         begin
         Halt(2);
         end;
   finally
      fJF.Free;
      fJ.Free;
      fT.Free;
   end;
end;

var
   corpusDir, setDir: string;
   repeatCount: integer;
   sr: TSearchRec;
   sets: TStringList;
   i: integer;
   r: TSetResult;
   totRows, totJF, totJ, totT, totND, totTrials, totCaught, totBad: Int64;
   totEncJF, totEncJ, totEncT, totDecJF, totDecJ, totDecT: double;

function PerRec(aMs: double; aRepeat: integer; aRows: Int64): double;
begin
   Result := aMs * 1000.0 / (aRepeat * aRows);
end;

begin
   (* Any standalone EXE that links app units must assign the MainUnit global
     logger or it AVs on the first log call. *)
   logger := TLogLogger.GetLogger('bench');
   gCols := QsoWireColumns;
   if QsoWireTableProblem <> '' then
      begin
      WriteLn(string(QsoWireTableProblem));
      Halt(3);
      end;
{$IFDEF WINDOWS}
   QueryPerformanceFrequency(gFreq);
{$ENDIF}
   if ParamCount >= 1 then
      begin
      corpusDir := ParamStr(1);
      end
   else
      begin
      corpusDir := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\corpus');
      end;
   repeatCount := 3;
   if ParamCount >= 2 then
      begin
      repeatCount := StrToIntDef(ParamStr(2), 3);
      end;
   if ParamCount >= 3 then
      begin
      gOutDir := ExpandFileName(ParamStr(3));
      ForceDirectories(gOutDir);
      end;

   WriteLn('bench_wire_formats: corpus ', corpusDir, ', ', repeatCount, ' timing passes');
   WriteLn('bytes are per QSO and include the 4-byte checksum; "fields" = non-default fields sent;');
   WriteLn('encode = checksum + build, decode = parse + checksum (microseconds per QSO)');
   WriteLn;

   sets := TStringList.Create;
   try
      if FindFirst(corpusDir + PathDelim + '*', faDirectory, sr) = 0 then
         begin
         repeat
            if ((sr.Attr and faDirectory) <> 0) and (sr.Name <> '.') and (sr.Name <> '..') and
               FileExists(corpusDir + PathDelim + sr.Name + PathDelim + 'log.db') then
               begin
               sets.Add(sr.Name);
               end;
         until FindNext(sr) <> 0;
         SysUtils.FindClose(sr);
         end;
      sets.Sort;
      if sets.Count = 0 then
         begin
         WriteLn('no corpus sets found under ', corpusDir);
         Halt(1);
         end;
      totRows := 0; totJF := 0; totJ := 0; totT := 0; totND := 0;
      totTrials := 0; totCaught := 0; totBad := 0;
      totEncJF := 0; totEncJ := 0; totEncT := 0; totDecJF := 0; totDecJ := 0; totDecT := 0;
      for i := 0 to sets.Count - 1 do
         begin
         setDir := corpusDir + PathDelim + sets[i] + PathDelim + 'log.db';
         RunSet(sets[i], setDir, repeatCount, r);
         if r.Rows > 0 then
            begin
            WriteLn(Format('%-24s %5d QSOs  fields %5.1f  JSONfull %6.1f  JSON %6.1f  TLV %6.1f   enc: full %6.1f json %6.1f tlv %6.1f   dec: full %6.1f json %6.1f tlv %6.1f   dropped %d/%d  bad %d',
               [sets[i], r.Rows, r.NonDefault / r.Rows, r.SumJF / r.Rows, r.SumJ / r.Rows, r.SumT / r.Rows,
                PerRec(r.MsEncJF, repeatCount, r.Rows), PerRec(r.MsEncJ, repeatCount, r.Rows), PerRec(r.MsEncT, repeatCount, r.Rows),
                PerRec(r.MsDecJF, repeatCount, r.Rows), PerRec(r.MsDecJ, repeatCount, r.Rows), PerRec(r.MsDecT, repeatCount, r.Rows),
                r.Caught, r.Trials, r.Bad]));
            inc(totRows, r.Rows);
            inc(totJF, r.SumJF);
            inc(totJ, r.SumJ);
            inc(totT, r.SumT);
            inc(totND, r.NonDefault);
            inc(totTrials, r.Trials);
            inc(totCaught, r.Caught);
            inc(totBad, r.Bad);
            totEncJF := totEncJF + r.MsEncJF; totEncJ := totEncJ + r.MsEncJ; totEncT := totEncT + r.MsEncT;
            totDecJF := totDecJF + r.MsDecJF; totDecJ := totDecJ + r.MsDecJ; totDecT := totDecT + r.MsDecT;
            end;
         end;
      WriteLn;
      if totRows > 0 then
         begin
         WriteLn(Format('SCHEMA: %d wire fields (uLogRepository.QsoWireColumns)', [gCols.Count]));
         WriteLn(Format('DATA FINDING: %d TEXT values held a NUL character (stripped by the repository)',
            [gNulValues]));
         WriteLn(Format('ALL: %d QSOs, %.1f non-default fields each on average', [totRows, totND / totRows]));
         WriteLn(Format('     JSON full %.1f B   JSON omit %.1f B   TLV %.1f B   (old record: 376 B)',
            [totJF / totRows, totJ / totRows, totT / totRows]));
         WriteLn(Format('     encode us/QSO: full %.1f json %.1f tlv %.1f   decode us/QSO: full %.1f json %.1f tlv %.1f',
            [PerRec(totEncJF, repeatCount, totRows), PerRec(totEncJ, repeatCount, totRows), PerRec(totEncT, repeatCount, totRows),
             PerRec(totDecJF, repeatCount, totRows), PerRec(totDecJ, repeatCount, totRows), PerRec(totDecT, repeatCount, totRows)]));
         WriteLn(Format('     dropped-field test: %d of %d detected; exact round-trip failures: %d',
            [totCaught, totTrials, totBad]));
         end;
      if gOutDir <> '' then
         begin
         WriteFieldList(gOutDir + PathDelim + 'fields.json');
         RunUnicodeSet;
         end;
   finally
      sets.Free;
   end;
   if totBad <> 0 then
      begin
      Halt(2);
      end;
end.
