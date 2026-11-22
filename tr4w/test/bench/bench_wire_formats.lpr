program bench_wire_formats;

(* WHAT DOES A QSO COST ON THE MULTI-OP WIRE, AND IN WHICH FORMAT?
  (issue 300, NY4I 2026-11-22: "gather some metrics on sending data to the
  tr4wserver via JSON or some other extensible wire format ... we should not
  send fields that are blank (but we should checksum the record) so the server
  knows it did not miss some fields versus we did not send them.")

  THREE ENCODINGS of the SAME record, over every QSO of the corpus logs:

    BINARY  today: the raw ContestExchange, SizeOf = 376 bytes, blanks and all.
            Fixed; a new field means a new protocol version.
    JSON    one object, BLANK AND ZERO FIELDS OMITTED, plus a "k" member that
            is the record checksum. Self-describing and extensible: an unknown
            member is ignorable.
    TLV     tag byte, length byte, value; blank and zero omitted; tag 0 is the
            checksum. Extensible the same way, without the key names.

  THE CHECKSUM covers the FULL record -- every field, blanks included, in a
  fixed order, each as tag + length + value, blank and zero canonicalised to
  the empty value -- so it is the same whether or not the sender omitted the
  blanks. The receiver decodes, fills every missing field with blank, and
  recomputes. A match proves nothing was LOST in transit and that the sender
  merely had nothing to say; a mismatch is a record to re-request.

  THE DROPPED-FIELD TEST: for every non-blank field of every record, pretend
  that field never arrived and recompute. It must NOT match. The count of
  detections against the count of trials is the answer; CRC-32 is not a
  cryptographic hash, so a collision is possible in principle and shows up
  here as a number below 100 percent.

  WHAT THIS DOES NOT MEASURE, said plainly:
    - Values are carried as TEXT in both JSON and TLV (a number is its digits).
      A binary-integer TLV would be smaller; this is the pessimistic TLV.
    - JSON key names are the ones in EmitFields. Shorter keys are smaller.
    - Framing (the packet header) is not counted for any format.
    - Encode time starts from the collected field list, not the record; the
      record-to-field-list step is the same for every format and is timed on
      its own line.
    - Bytes are characters: every value in these logs is ASCII.

  Usage:  bench_wire_formats [corpus-dir] [repeat]
          defaults: ..\corpus  and 3 passes over each log's records
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
   crc,
   fpjson,
   jsonparser,
   Log4D,
   MainUnit,  (* logger -- units below log through it *)
   VC,
   uLogDatabase,
   uLogRepository;

const
   MAX_FIELDS = 128;
   BUF_SIZE   = 16384;

type
   TVals = array[1..MAX_FIELDS] of string;
   TByteBuf = array[0..BUF_SIZE - 1] of byte;

   (* One record's fields, in a fixed order. Val is the CANONICAL value: a
     zero or blank is ''. *)
   TFieldCollector = class(TObject)
   public
      Count: integer;
      Name: array[1..MAX_FIELDS] of string;
      Val: TVals;
      IsNum: array[1..MAX_FIELDS] of boolean;
      procedure Reset;
      procedure AddStr(const aName, aValue: string);
      procedure AddNum(const aName: string; aValue: Int64);
   end;

var
   gFreq: Int64 = 0;
   aTotJF: Int64 = 0;   (* total full-JSON bytes, across sets *)

(* THE CLOCK, as bench_callsign and bench_enter_latency: QueryPerformanceCounter
  on Windows; off Windows GetTickCount64 (1 ms) is the stand-in. *)
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

procedure TFieldCollector.Reset;
begin
   Count := 0;
end;

procedure TFieldCollector.AddStr(const aName, aValue: string);
begin
   inc(Count);
   Name[Count] := aName;
   Val[Count] := aValue;
   IsNum[Count] := False;
end;

procedure TFieldCollector.AddNum(const aName: string; aValue: Int64);
begin
   inc(Count);
   Name[Count] := aName;
   if aValue = 0 then
      begin
      Val[Count] := '';
      end
   else
      begin
      Val[Count] := IntToStr(aValue);
      end;
   IsNum[Count] := True;
end;

(* An AnsiChar field: #0 is blank. *)
function CharStr(aCh: AnsiChar): string;
begin
   if aCh = #0 then
      begin
      Result := '';
      end
   else
      begin
      Result := string(aCh);
      end;
end;

(* A fixed char array: up to the first NUL, as the log's own readers do. *)
function ArrayStr(const aArr: array of AnsiChar): string;
var
   i: integer;
begin
   Result := '';
   for i := Low(aArr) to High(aArr) do
      begin
      if aArr[i] = #0 then
         begin
         Break;
         end;
      Result := Result + string(aArr[i]);
      end;
end;

(* EVERY FIELD THAT BELONGS ON THE WIRE, in a fixed order. The ZERO_nn pad
  bytes, the legacy ceQSO_Skiped and sReserved are the layout's filler, not
  facts, and are not here. THE ORDER IS THE TAG: a new field goes at the end. *)
procedure EmitFields(const r: ContestExchange; c: TFieldCollector);
begin
   c.Reset;
   c.AddStr('t', Format('%.2d%.2d%.2d%.2d%.2d%.2d', [r.tSysTime.qtYear, r.tSysTime.qtMonth, r.tSysTime.qtDay, r.tSysTime.qtHour, r.tSysTime.qtMinute, r.tSysTime.qtSecond]));
   c.AddNum('band', Ord(r.Band));
   c.AddNum('mode', Ord(r.Mode));
   c.AddNum('id1', r.ceQSOID1);
   c.AddNum('id2', r.ceQSOID2);
   c.AddNum('freq', r.Frequency);
   c.AddNum('del', Ord(r.ceQSO_Deleted));
   c.AddStr('cid', CharStr(r.ceComputerID));
   c.AddNum('opid', r.ceOperatorID);
   c.AddNum('kind', Ord(r.ceRecordKind));
   c.AddNum('tosrv', Ord(r.ceSendToServer));
   c.AddNum('needae', Ord(r.ceNeedSendToServerAE));
   c.AddNum('dupe', Ord(r.ceDupe));
   c.AddStr('postal', string(r.PostalCode_old));
   c.AddStr('pfx', string(r.Prefix));
   c.AddStr('call', string(r.Callsign));
   c.AddNum('age', r.Age);
   c.AddNum('inqtc', Ord(r.ceWasSendInQTC));
   c.AddNum('domm', Ord(r.DomesticMult));
   c.AddNum('dxm', Ord(r.DXMult));
   c.AddNum('pfxm', Ord(r.PrefixMult));
   c.AddNum('zonem', Ord(r.ZoneMult));
   c.AddNum('xmode', Ord(r.ExtMode));
   c.AddStr('exch', string(r.ExchString));
   c.AddStr('class', string(r.ceClass));
   c.AddStr('prec', CharStr(r.Precedence));
   c.AddNum('crad', Ord(r.ceRadio));
   c.AddNum('check', r.Check);
   c.AddStr('q.cid', string(r.QTH.CountryID));
   c.AddNum('q.zone', r.QTH.Zone);
   c.AddStr('q.pfx', string(r.QTH.Prefix));
   c.AddNum('q.cont', Ord(r.QTH.Continent));
   c.AddStr('q.call', string(r.QTH.StandardCall));
   c.AddNum('q.ctry', r.QTH.Country);
   c.AddStr('dxqth', string(r.DXQTH));
   c.AddNum('radio', Ord(r.Radio));
   c.AddStr('dommq', string(r.DomMultQTH));
   c.AddStr('domq', string(r.DomesticQTH));
   c.AddStr('name', string(r.Name));
   c.AddStr('power', string(r.Power));
   c.AddNum('nrcv', r.NumberReceived);
   c.AddNum('nsent', r.NumberSent);
   c.AddNum('rsts', r.RSTSent);
   c.AddNum('rstr', r.RSTReceived);
   c.AddStr('qth', string(r.QTHString));
   c.AddStr('rcs', string(r.RandomCharsSent));
   c.AddNum('tt', r.TenTenNum);
   c.AddStr('chap', string(r.Chapter));
   c.AddNum('cdupe', Ord(r.ceClearDupeSheet));
   c.AddNum('snp', Ord(r.ceSearchAndPounce));
   c.AddNum('pref', r.Prefecture);
   c.AddNum('inhib', Ord(r.InhibitMults));
   c.AddNum('zone', r.Zone);
   c.AddNum('namesent', Ord(r.NameSent));
   c.AddStr('kids', string(r.Kids));
   c.AddNum('contest', r.ceContest.ToByte);
   c.AddNum('pts', r.QSOPoints);
   c.AddStr('rcr', string(r.RandomCharsReceived));
   c.AddNum('cmult', Ord(r.ceClearMultSheet));
   c.AddNum('mp3', Ord(r.MP3Record));
   c.AddStr('op', ArrayStr(r.ceOperator));
   c.AddStr('guid', string(r.id));
   c.AddNum('xqso', Ord(r.ceXQSO));
   c.AddNum('ryear', r.RcvdYear);
   c.AddNum('rykn', Ord(r.RcvdYearKnown));
   c.AddNum('sykn', Ord(r.YearSentKnown));
   c.AddNum('syear', r.YearSent);
   c.AddNum('offc', Ord(r.ceOffContest));
   c.AddStr('rover', string(r.ceRoverQTH));
end;

(* THE CANONICAL STREAM: every field, in order, as tag + length + value, blanks
  included. aSkip is the field to treat as never received (0 = none). *)
function PackCanon(const aVals: TVals; aCount, aSkip: integer; var aBuf: TByteBuf): integer;
var
   i, j: integer;
   v: string;
begin
   Result := 0;
   for i := 1 to aCount do
      begin
      v := aVals[i];
      if i = aSkip then
         begin
         v := '';
         end;
      aBuf[Result] := i;
      inc(Result);
      aBuf[Result] := Length(v);
      inc(Result);
      for j := 1 to Length(v) do
         begin
         aBuf[Result] := Ord(v[j]);
         inc(Result);
         end;
      end;
end;

function RecordCrc(const aVals: TVals; aCount, aSkip: integer; var aBuf: TByteBuf): Cardinal;
var
   n: integer;
begin
   n := PackCanon(aVals, aCount, aSkip, aBuf);
   Result := crc32(0, nil, 0);
   Result := crc32(Result, @aBuf[0], n);
end;

(* aOmit True: blank and zero fields are left out. False: EVERY field is named,
  a blank number as 0 and a blank string as "" -- the full record. *)
function EncodeJson(c: TFieldCollector; aCrc: Cardinal; aOmit: boolean): string;
var
   o: TJSONObject;
   i: integer;
begin
   o := TJSONObject.Create;
   try
      for i := 1 to c.Count do
         begin
         if (c.Val[i] <> '') or (not aOmit) then
            begin
            if c.IsNum[i] then
               begin
               if c.Val[i] = '' then
                  begin
                  o.Add(c.Name[i], 0);
                  end
               else
                  begin
                  o.Add(c.Name[i], StrToInt64(c.Val[i]));
                  end;
               end
            else
               begin
               o.Add(c.Name[i], c.Val[i]);
               end;
            end;
         end;
      o.Add('k', IntToHex(aCrc, 8));
      Result := o.AsJSON;
   finally
      o.Free;
   end;
end;

(* Tag 0 is the checksum, 4 bytes. *)
function EncodeTlv(c: TFieldCollector; aCrc: Cardinal; var aBuf: TByteBuf): integer;
var
   i, j: integer;
begin
   Result := 0;
   aBuf[Result] := 0; inc(Result);
   aBuf[Result] := 4; inc(Result);
   aBuf[Result] := aCrc and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 8) and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 16) and $FF; inc(Result);
   aBuf[Result] := (aCrc shr 24) and $FF; inc(Result);
   for i := 1 to c.Count do
      begin
      if c.Val[i] <> '' then
         begin
         aBuf[Result] := i;
         inc(Result);
         aBuf[Result] := Length(c.Val[i]);
         inc(Result);
         for j := 1 to Length(c.Val[i]) do
            begin
            aBuf[Result] := Ord(c.Val[i][j]);
            inc(Result);
            end;
         end;
      end;
end;

(* DECODE, and report the checksum the sender stated. Missing fields stay '':
  that is the whole point of omitting them. *)
procedure DecodeJson(const aText: string; aNames: TFieldCollector; out aVals: TVals; out aSent: Cardinal);
var
   d: TJSONData;
   o: TJSONObject;
   i, k: integer;
   nm: string;
begin
   for i := 1 to MAX_FIELDS do
      begin
      aVals[i] := '';
      end;
   aSent := 0;
   d := GetJSON(aText);
   try
      o := d as TJSONObject;
      for i := 0 to o.Count - 1 do
         begin
         nm := o.Names[i];
         if nm = 'k' then
            begin
            aSent := Cardinal(StrToInt64('$' + o.Items[i].AsString));
            end
         else
            begin
            for k := 1 to aNames.Count do
               begin
               if aNames.Name[k] = nm then
                  begin
                  aVals[k] := o.Items[i].AsString;
                  if aNames.IsNum[k] and (aVals[k] = '0') then
                     begin
                     aVals[k] := '';   (* canonical: a zero is blank *)
                     end;
                  Break;
                  end;
               end;
            end;
         end;
   finally
      d.Free;
   end;
end;

procedure DecodeTlv(const aBuf: TByteBuf; aLen: integer; out aVals: TVals; out aSent: Cardinal);
var
   p, tag, ln, j: integer;
   v: string;
begin
   for p := 1 to MAX_FIELDS do
      begin
      aVals[p] := '';
      end;
   aSent := 0;
   p := 0;
   while p < aLen do
      begin
      tag := aBuf[p];
      ln := aBuf[p + 1];
      inc(p, 2);
      if tag = 0 then
         begin
         aSent := aBuf[p] or (aBuf[p + 1] shl 8) or (aBuf[p + 2] shl 16) or (Cardinal(aBuf[p + 3]) shl 24);
         end
      else
         begin
         v := '';
         for j := 0 to ln - 1 do
            begin
            v := v + Chr(aBuf[p + j]);
            end;
         aVals[tag] := v;
         end;
      inc(p, ln);
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

procedure RunSet(const aName, aDb: string; aRepeat: integer;
                 var aTotQ, aTotJ, aTotT: Int64; var aTotTrials, aTotCaught, aTotBad: Int64);
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
   recs: array of ContestExchange;
   n, i, pass, f: integer;
   c: TFieldCollector;
   buf, buf2: TByteBuf;
   js: string;
   tl: integer;
   crcFull, sent: Cardinal;
   vals: TVals;
   sumJ, sumT, sumJF: Int64;
   jf, scratch: string;
   msJF, msDJF: double;
   at: Int64;
   msFields, msJson, msTlv, msDJson, msDTlv: double;
   trials, caught, bad: Int64;
begin
   db := TLogDatabase.Create;
   repo := nil;
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
      repo := TLogRepository.Create(db);
      repo.OpenSequentialRead;
      SetLength(recs, 1024);
      while repo.ReadNext(rec) do
         begin
         if n = Length(recs) then
            begin
            SetLength(recs, n * 2);
            end;
         recs[n] := rec;
         inc(n);
         end;
   finally
      repo.Free;
      db.Free;
   end;
   if n = 0 then
      begin
      WriteLn(Format('%-24s  no records', [aName]));
      Exit;
   end;

   c := TFieldCollector.Create;
   try
      sumJ := 0;
      sumJF := 0;
      sumT := 0;
      trials := 0;
      caught := 0;
      bad := 0;
      msFields := 0;
      msJson := 0;
      msTlv := 0;
      msDJson := 0;
      msDTlv := 0;

      (* Sizes, and the correctness of the round trip, once per record. *)
      for i := 0 to n - 1 do
         begin
         EmitFields(recs[i], c);
         crcFull := RecordCrc(c.Val, c.Count, 0, buf);
         js := EncodeJson(c, crcFull, True);
         jf := EncodeJson(c, crcFull, False);
         tl := EncodeTlv(c, crcFull, buf2);
         inc(sumJ, Length(js));
         inc(sumJF, Length(jf));
         inc(sumT, tl);

         DecodeJson(jf, c, vals, sent);
         if (sent <> crcFull) or (RecordCrc(vals, c.Count, 0, buf) <> crcFull) then
            begin
            inc(bad);
            end;

         DecodeJson(js, c, vals, sent);
         if (sent <> crcFull) or (RecordCrc(vals, c.Count, 0, buf) <> crcFull) then
            begin
            inc(bad);
            end;
         DecodeTlv(buf2, tl, vals, sent);
         if (sent <> crcFull) or (RecordCrc(vals, c.Count, 0, buf) <> crcFull) then
            begin
            inc(bad);
            end;

         (* THE DROPPED-FIELD TEST: every non-blank field, treated as lost. *)
         for f := 1 to c.Count do
            begin
            if c.Val[f] <> '' then
               begin
               inc(trials);
               if RecordCrc(c.Val, c.Count, f, buf) <> crcFull then
                  begin
                  inc(caught);
                  end;
               end;
            end;
         end;

      (* Times: aRepeat passes over every record, one format at a time. *)
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            end;
         end;
      msFields := StopClock(at);

      EmitFields(recs[0], c);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            js := EncodeJson(c, crcFull, True);
            end;
         end;
      msJson := StopClock(at) - msFields;

      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            jf := EncodeJson(c, crcFull, False);
            end;
         end;
      msJF := StopClock(at) - msFields;

      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            tl := EncodeTlv(c, crcFull, buf2);
            end;
         end;
      msTlv := StopClock(at) - msFields;

      (* Decode timing: one record's encoding decoded repeatedly would flatter
        the cache; decode each record's own encoding. *)
      EmitFields(recs[0], c);
      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            js := EncodeJson(c, crcFull, True);
            DecodeJson(js, c, vals, sent);
            crcFull := RecordCrc(vals, c.Count, 0, buf);
            end;
         end;
      msDJson := StopClock(at) - msFields - msJson;

      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            jf := EncodeJson(c, crcFull, False);
            DecodeJson(jf, c, vals, sent);
            crcFull := RecordCrc(vals, c.Count, 0, buf);
            end;
         end;
      msDJF := StopClock(at) - msFields - msJF;

      StartClock(at);
      for pass := 1 to aRepeat do
         begin
         for i := 0 to n - 1 do
            begin
            EmitFields(recs[i], c);
            crcFull := RecordCrc(c.Val, c.Count, 0, buf);
            tl := EncodeTlv(c, crcFull, buf2);
            DecodeTlv(buf2, tl, vals, sent);
            crcFull := RecordCrc(vals, c.Count, 0, buf);
            end;
         end;
      msDTlv := StopClock(at) - msFields - msTlv;

      WriteLn(Format('%-24s %6d  %4d  JSONfull %6.1f  JSON %6.1f  TLV %6.1f   enc us/rec: full %6.1f json %6.1f tlv %6.1f   dec us/rec: full %6.1f json %6.1f tlv %6.1f   dropped %d/%d  bad %d',
         [aName, n, SizeOf(ContestExchange),
          sumJF / n, sumJ / n, sumT / n,
          msJF * 1000.0 / (aRepeat * n), msJson * 1000.0 / (aRepeat * n), msTlv * 1000.0 / (aRepeat * n),
          msDJF * 1000.0 / (aRepeat * n), msDJson * 1000.0 / (aRepeat * n), msDTlv * 1000.0 / (aRepeat * n),
          caught, trials, bad]));
      inc(aTotJF, sumJF);
      inc(aTotQ, n);
      inc(aTotJ, sumJ);
      inc(aTotT, sumT);
      inc(aTotTrials, trials);
      inc(aTotCaught, caught);
      inc(aTotBad, bad);
   finally
      c.Free;
   end;
end;

var
   corpusDir, setDir: string;
   repeatCount: integer;
   sr: TSearchRec;
   totQ, totJ, totT, totTrials, totCaught, totBad: Int64;
   sets: TStringList;
   i: integer;
begin
   (* Any standalone EXE that links app units must assign the MainUnit global
     logger or it AVs on the first log call. *)
   logger := TLogLogger.GetLogger('bench');
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

   WriteLn('bench_wire_formats: corpus ', corpusDir, ', ', repeatCount, ' timing passes');
   WriteLn('columns: set, QSOs, binary bytes, avg JSON bytes, avg TLV bytes (both include the 4-byte checksum),');
   WriteLn('         encode and decode microseconds per record, dropped-field detections, round-trip failures');
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
      totQ := 0; totJ := 0; totT := 0; totTrials := 0; totCaught := 0; totBad := 0;
      for i := 0 to sets.Count - 1 do
         begin
         setDir := corpusDir + PathDelim + sets[i] + PathDelim + 'log.db';
         RunSet(sets[i], setDir, repeatCount, totQ, totJ, totT, totTrials, totCaught, totBad);
         end;
      WriteLn;
      if totQ > 0 then
         begin
         WriteLn(Format('ALL: %d QSOs; binary %d bytes; JSON full %.1f avg (%.0f%%); JSON omit-blanks %.1f avg (%.0f%% of binary); TLV %.1f avg (%.0f%% of binary)',
            [totQ, SizeOf(ContestExchange), aTotJF / totQ, 100.0 * aTotJF / totQ / SizeOf(ContestExchange),
             totJ / totQ, 100.0 * totJ / totQ / SizeOf(ContestExchange),
             totT / totQ, 100.0 * totT / totQ / SizeOf(ContestExchange)]));
         WriteLn(Format('     dropped-field test: %d of %d detected; round-trip failures: %d',
            [totCaught, totTrials, totBad]));
         end;
   finally
      sets.Free;
   end;
   if totBad <> 0 then
      begin
      Halt(2);
      end;
end.
