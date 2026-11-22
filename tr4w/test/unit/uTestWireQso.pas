unit uTestWireQso;

(* uWireQso AGAINST THE GOLDEN VECTORS -- stage W1 of
  docs\TR4WSERVER_SQLITE_DESIGN.md section 13.

  tr4w\test\wire\golden_vectors.json is made by make_vectors.py, an
  independent Python implementation of the format that knows nothing of this
  code. For every row it holds the values, the canonical stream as hex, the
  CRC-32 and Python's JSON with defaults omitted. This suite asserts:

    - the Pascal canonical stream and checksum EQUAL Python's, byte for byte;
    - Python's JSON decodes here to the same values and the same checksum;
    - this unit's own JSON (omitted and full) decodes back to the row exactly,
      and omits the same members Python's does;
    - dropping any non-default field changes the checksum;
    - a NUL in an input value is stripped, as Python strips it.

  The column list is uLogRepository.QsoWireColumns; uTestWireColumns pins it
  to the schema and to columns.json, which the vectors were made from. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TWireQsoTests = class(TTestCase)
   protected
      procedure Test_TheGoldenVectorsMatch;
      procedure Test_AnUnknownMemberIsIgnored;
      procedure Test_ANumericColumnRefusesText;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, fpjson, jsonparser,
   uQsoColumns, uWireQso,
   uTestWireColumns;   (* WireTestFile, ReadUtf8File *)

function HexOf(const aBytes: TBytes): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aBytes) do
      begin
      Result := Result + LowerCase(IntToHex(aBytes[i], 2));
      end;
end;

function SameRow(const a, b: TWireValues; out aFirst: integer): boolean;
var
   i: integer;
begin
   aFirst := -1;
   Result := Length(a) = Length(b);
   if not Result then
      begin
      Exit;
      end;
   for i := 0 to High(a) do
      begin
      if a[i] <> b[i] then
         begin
         aFirst := i;
         Result := False;
         Exit;
         end;
      end;
end;

(* ' (first difference: <column>)', or '' -- a function, because BoolToStr
  would evaluate the column name even for -1. *)
function DiffNote(aWire: TWireColumns; aFirst: integer): string;
begin
   Result := '';
   if aFirst >= 0 then
      begin
      Result := ' (first difference: ' + aWire.Name[aFirst] + ')';
      end;
end;

function MemberCount(const aJson: string): integer;
var
   d: TJSONData;
begin
   d := GetJSON(aJson);
   try
      Result := TJSONObject(d).Count;
   finally
      d.Free;
   end;
end;

procedure TWireQsoTests.Test_TheGoldenVectorsMatch;
var
   wire: TWireColumns;
   doc: TJSONData;
   rows, vals: TJSONArray;
   row: TJSONObject;
   r, i, first, dropped, caught: integer;
   values, back: TWireValues;
   lbl, pyJson, mine: string;
   crc, stated, pyCrc: Cardinal;
   ok: boolean;
begin
   BeginTest('Test_TheGoldenVectorsMatch');
   wire := QsoWireColumns;
   doc := GetJSON(ReadUtf8File(WireTestFile('golden_vectors.json')));
   try
      CheckEquals(wire.Count, TJSONObject(doc).Integers['columns'],
         'the vectors were made for this column list');
      rows := TJSONObject(doc).Arrays['rows'];
      CheckTrue(rows.Count >= 14, 'every case the plan asks for is there');
      dropped := 0;
      caught := 0;
      for r := 0 to rows.Count - 1 do
         begin
         row := rows.Objects[r];
         lbl := string(row.Strings['label']);
         vals := row.Arrays['values'];
         CheckEquals(wire.Count, vals.Count, lbl + ': one value per column');
         if vals.Count <> wire.Count then
            begin
            Continue;
            end;
         SetLength(values, vals.Count);
         for i := 0 to vals.Count - 1 do
            begin
            values[i] := string(vals.Strings[i]);
            end;

         (* The NUL rule: the leaf's WireText strips exactly what Python did. *)
         if row.IndexOfName('input') >= 0 then
            begin
            for i := 0 to vals.Count - 1 do
               begin
               CheckEquals(values[i], WireText(string(row.Arrays['input'].Strings[i])),
                  lbl + ': ' + wire.Name[i] + ' with its NUL stripped');
               end;
            end;

         (* Byte for byte, and the checksum. *)
         CheckEquals(string(row.Strings['canonical_hex']), HexOf(PackCanonical(wire, values)),
            lbl + ': the canonical stream');
         crc := RecordCrc32(wire, values);
         CheckEquals(string(row.Strings['crc']), WireCrcText(crc), lbl + ': the CRC-32');

         (* Python's JSON, decoded here. *)
         pyJson := string(row.Strings['json_omit']);
         ok := DecodeJson(wire, pyJson, back, pyCrc);
         CheckTrue(ok, lbl + ': Python''s JSON states a checksum');
         CheckTrue(pyCrc = crc, lbl + ': ... and it is this row''s');
         CheckTrue(SameRow(back, values, first), lbl + ': Python''s JSON decodes to the row' +
            DiffNote(wire, first));

         (* Our own JSON, both ways, back to the row exactly. *)
         mine := EncodeJson(wire, values, crc, True);
         CheckEquals(MemberCount(pyJson), MemberCount(mine),
            lbl + ': the same members are omitted as Python omits');
         CheckTrue(DecodeJson(wire, mine, back, stated) and (stated = crc), lbl + ': omit states the CRC');
         CheckTrue(SameRow(back, values, first), lbl + ': omit round-trips' +
            DiffNote(wire, first));
         CheckTrue(RecordCrc32(wire, back) = crc, lbl + ': omit recomputes the CRC');
         mine := EncodeJson(wire, values, crc, False);
         CheckEquals(wire.Count + 1, MemberCount(mine), lbl + ': full names every field');
         CheckTrue(DecodeJson(wire, mine, back, stated) and (stated = crc), lbl + ': full states the CRC');
         CheckTrue(SameRow(back, values, first), lbl + ': full round-trips');

         (* THE DROPPED-FIELD TEST: every non-default field, treated as lost. *)
         for i := 0 to wire.Count - 1 do
            begin
            if values[i] <> wire.Default[i] then
               begin
               inc(dropped);
               if RecordCrc32(wire, values, i) <> crc then
                  begin
                  inc(caught);
                  end
               else
                  begin
                  CheckTrue(False, lbl + ': dropping ' + wire.Name[i] + ' left the CRC unchanged');
                  end;
               end;
            end;
         end;
      CheckTrue(dropped > 0, 'the vectors hold non-default fields');
      CheckEquals(dropped, caught, 'every dropped field changes the checksum');
   finally
      doc.Free;
   end;
end;

procedure TWireQsoTests.Test_AnUnknownMemberIsIgnored;
var
   wire: TWireColumns;
   values, back: TWireValues;
   crc, stated: Cardinal;
   text: string;
   first: integer;
begin
   BeginTest('Test_AnUnknownMemberIsIgnored');
   wire := QsoWireColumns;
   values := wire.DefaultValues;
   values[wire.IndexOfName('callsign')] := 'K1ABC';
   crc := RecordCrc32(wire, values);
   text := '{"callsign":"K1ABC","a_newer_column":"x","k":"' + WireCrcText(crc) + '"}';
   CheckTrue(DecodeJson(wire, text, back, stated), 'the checksum is read');
   CheckTrue(stated = crc, 'and it is the row''s');
   CheckTrue(SameRow(back, values, first), 'the unknown member changed nothing');
   CheckFalse(DecodeJson(wire, '{"callsign":"K1ABC","k":"12345"}', back, stated),
      'a short checksum is no checksum');
   CheckFalse(DecodeJson(wire, '{"callsign":"K1ABC","k":"0x123456"}', back, stated),
      'a prefixed checksum is no checksum');
end;

procedure TWireQsoTests.Test_ANumericColumnRefusesText;
var
   wire: TWireColumns;
   values: TWireValues;
   raised: boolean;
begin
   BeginTest('Test_ANumericColumnRefusesText');
   wire := QsoWireColumns;
   values := wire.DefaultValues;
   values[wire.IndexOfName('qso_points')] := '$1F';
   raised := False;
   try
      EncodeJson(wire, values, 0, True);
   except
      on EWireQsoError do
         begin
         raised := True;
         end;
   end;
   CheckTrue(raised, 'a numeric column holding "$1F" is refused, not sent');
end;

procedure TWireQsoTests.RunAllTests;
begin
   Test_TheGoldenVectorsMatch;
   Test_AnUnknownMemberIsIgnored;
   Test_ANumericColumnRefusesText;
end;

end.
