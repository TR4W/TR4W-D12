unit uWireQso;

(* THE MULTI-OP WIRE'S CANONICAL FORM OF A QSO ROW -- stage W1 of
  docs\TR4WSERVER_SQLITE_DESIGN.md section 13 (issues 300 and 341). The rulings
  and the measurements are docs\WIRE_FORMAT_METRICS.md.

  A LEAF: no database, no LCL, no program state. It knows a column list
  (TWireColumns: name, numeric or not, the column's DEFAULT as canonical text)
  and a row's values as canonical text (TWireValues, one per column, in column
  order). Who fills those is not its business: uLogRepository holds the ONE
  table of the qso columns and reads a committed row into this shape.

  CANONICAL TEXT. NULL is ''; an integer is its decimal digits; text is the
  native string (the wire is UTF-8, converted here). A NUL character never goes
  on the wire (WireText strips it) -- see WireText.

  THE CANONICAL STREAM (PackCanonical): for EVERY column, in order, defaults
  included: the tag (1-based column number, one byte), the value's UTF-8 byte
  length (two bytes, little-endian), the bytes. So it is the same whether or not
  a sender omitted anything. RecordCrc32 is CRC-32 (the crc unit, zlib's) over
  it.

  THE JSON (EncodeJson / DecodeJson). Omitting: a field EQUAL TO ITS COLUMN'S
  DEFAULT is left out -- never "is zero", so a nullable column's NULL and its 0
  stay distinct. A NULL numeric is JSON null. Member "k" is the record checksum
  as 8 hex digits. The receiver starts every field at its default and overlays
  what arrived; an unknown member is ignored (a newer sender's column).

  The semantics were copied from tr4w\test\bench\bench_wire_formats.lpr, which
  round-tripped 1,855 real QSOs with 0 failures against an independent Python
  receiver (wire_check.py). tr4w\test\wire\golden_vectors.json, made by
  make_vectors.py with no Pascal in the loop, pins this unit byte for byte
  (uTestWireQso). *)

{$I tr4w.inc}

interface

uses
   SysUtils, Classes,
   (* TDictionary<string, integer> -- the name index. NOT a TStringList: that
     is AnsiString in FPC 3.2.2, so every lookup would narrow the name. *)
   Generics.Collections;

type
   EWireQsoError = class(Exception);

   (* One value per column, index 0 = tag 1. *)
   TWireValues = array of string;

   (* THE COLUMN LIST, in tag order. A class, filled once by its owner and
     read-only after that, so readers on any thread may share one. *)
   TWireColumns = class
   private
      FName: array of string;
      FNumeric: array of boolean;
      FDefault: array of string;
      FIndex: TDictionary<string, integer>;   (* name -> index, for decoding *)
      function GetCount: integer;
      function GetName(i: integer): string;
      function GetNumeric(i: integer): boolean;
      function GetDefault(i: integer): string;
   public
      constructor Create;
      destructor Destroy; override;
      (* Refuses a 256th column (the tag is one byte), a duplicate name and the
        name "k", which is the checksum's member. *)
      procedure Add(const aName: string; aNumeric: boolean; const aDefault: string);
      (* -1 when there is no such column. Case-sensitive: the names are the
        schema's own spelling. *)
      function IndexOfName(const aName: string): integer;
      (* A row holding every column's default. *)
      function DefaultValues: TWireValues;
      property Count: integer read GetCount;
      property Name[i: integer]: string read GetName;
      property Numeric[i: integer]: boolean read GetNumeric;
      property Default[i: integer]: string read GetDefault;
   end;

(* A TEXT value as the wire carries it: every NUL character removed.

  A DATA FINDING, not a rule of the format (2026-11-22, bench_wire_formats):
  3,229 TEXT values in the corpus logs hold a literal NUL -- the old record's
  "no character" (AnsiChar #0) stored as a one-character string where NULL was
  meant. The WRITER should store NULL; until it does, the sender treats the
  NUL as blank. *)
function WireText(const aValue: string): string;

(* An integer's CANONICAL digits: an optional '-' then decimal digits, nothing
  else ('$1F', '0x1F' and spaces are refused). Public since W2: the server's
  store binds a numeric column by the same rule the JSON encoder checks it by. *)
function TryCanonicalInt64(const aText: string; out aValue: Int64): boolean;

(* aSkip: a column index (0-based) to treat as never received -- it takes its
  default. -1 = none. Used by the dropped-field test. *)
function PackCanonical(aColumns: TWireColumns; const aValues: TWireValues;
                       aSkip: integer = -1): TBytes;
function RecordCrc32(aColumns: TWireColumns; const aValues: TWireValues;
                     aSkip: integer = -1): Cardinal;

(* aOmit True: a field equal to its default is left out. False: every field is
  named. Raises EWireQsoError on a numeric column whose value is not an
  integer's canonical digits. *)
function EncodeJson(aColumns: TWireColumns; const aValues: TWireValues;
                    aCrc: Cardinal; aOmit: boolean): string;

(* Every field starts at its default and what arrived is overlaid; JSON null is
  ''. True when the text stated a well-formed checksum ("k", 8 hex digits),
  which is aStated; False and aStated = 0 otherwise. Raises EWireQsoError when
  the text is not one JSON object. *)
function DecodeJson(aColumns: TWireColumns; const aText: string;
                    out aValues: TWireValues; out aStated: Cardinal): boolean;

(* The checksum member's text: 8 upper-case hex digits. *)
function WireCrcText(aCrc: Cardinal): string;

implementation

uses
   crc, fpjson, jsonparser;

const
   CRC_MEMBER = 'k';

(* --------------------------------------------------------------------------- *)
(* TWireColumns                                                                 *)
(* --------------------------------------------------------------------------- *)

constructor TWireColumns.Create;
begin
   inherited Create;
   FIndex := TDictionary<string, integer>.Create;
end;

destructor TWireColumns.Destroy;
begin
   FIndex.Free;
   inherited Destroy;
end;

function TWireColumns.GetCount: integer;
begin
   Result := Length(FName);
end;

function TWireColumns.GetName(i: integer): string;
begin
   Result := FName[i];
end;

function TWireColumns.GetNumeric(i: integer): boolean;
begin
   Result := FNumeric[i];
end;

function TWireColumns.GetDefault(i: integer): string;
begin
   Result := FDefault[i];
end;

procedure TWireColumns.Add(const aName: string; aNumeric: boolean; const aDefault: string);
var
   n: integer;
begin
   n := Length(FName);
   if n >= 255 then
      begin
      raise EWireQsoError.Create('A wire record has at most 255 columns: the tag is one byte.');
      end;
   if aName = CRC_MEMBER then
      begin
      raise EWireQsoError.Create('"' + CRC_MEMBER + '" is the checksum''s member, not a column name.');
      end;
   if (aName = '') or FIndex.ContainsKey(aName) then
      begin
      (* Exception messages are AnsiString in FPC 3.2.2: the conversion is
        stated here, at that boundary. Column names are ASCII. *)
      raise EWireQsoError.Create(AnsiString('A wire column name must be present and unique: "' +
                                            aName + '".'));
      end;
   SetLength(FName, n + 1);
   SetLength(FNumeric, n + 1);
   SetLength(FDefault, n + 1);
   FName[n] := aName;
   FNumeric[n] := aNumeric;
   FDefault[n] := aDefault;
   FIndex.Add(aName, n);
end;

function TWireColumns.IndexOfName(const aName: string): integer;
begin
   if not FIndex.TryGetValue(aName, Result) then
      begin
      Result := -1;
      end;
end;

function TWireColumns.DefaultValues: TWireValues;
var
   i: integer;
begin
   SetLength(Result, Length(FDefault));
   for i := 0 to High(FDefault) do
      begin
      Result[i] := FDefault[i];
      end;
end;

(* --------------------------------------------------------------------------- *)

(* By hand: SysUtils.StringReplace is AnsiString in FPC 3.2.2. *)
function WireText(const aValue: string): string;
var
   i, n: integer;
begin
   Result := aValue;
   if Pos(#0, Result) = 0 then
      begin
      Exit;
      end;
   SetLength(Result, Length(aValue));
   n := 0;
   for i := 1 to Length(aValue) do
      begin
      if aValue[i] <> #0 then
         begin
         inc(n);
         Result[n] := aValue[i];
         end;
      end;
   SetLength(Result, n);
end;

function WireCrcText(aCrc: Cardinal): string;
begin
   Result := IntToHex(aCrc, 8);
end;

procedure CheckRowLength(aColumns: TWireColumns; const aValues: TWireValues);
begin
   if Length(aValues) <> aColumns.Count then
      begin
      raise EWireQsoError.CreateFmt('A wire row holds %d values for %d columns.',
         [Length(aValues), aColumns.Count]);
      end;
end;

function PackCanonical(aColumns: TWireColumns; const aValues: TWireValues;
                       aSkip: integer): TBytes;
var
   i, j, at: integer;
   v: UTF8String;
begin
   CheckRowLength(aColumns, aValues);
   (* Sized for the worst case first, then cut: one allocation per record. *)
   at := 0;
   for i := 0 to aColumns.Count - 1 do
      begin
      inc(at, 3 + 4 * Length(aValues[i]) + 4 * Length(aColumns.Default[i]));
      end;
   SetLength(Result, at);
   at := 0;
   for i := 0 to aColumns.Count - 1 do
      begin
      if i = aSkip then
         begin
         v := UTF8Encode(aColumns.Default[i]);
         end
      else
         begin
         v := UTF8Encode(aValues[i]);
         end;
      if Length(v) > $FFFF then
         begin
         raise EWireQsoError.CreateFmt('Column %s is %d bytes; a wire value is at most 65535.',
            [aColumns.Name[i], Length(v)]);
         end;
      Result[at] := i + 1;
      inc(at);
      Result[at] := Length(v) and $FF;
      inc(at);
      Result[at] := (Length(v) shr 8) and $FF;
      inc(at);
      for j := 1 to Length(v) do
         begin
         Result[at] := Ord(v[j]);
         inc(at);
         end;
      end;
   SetLength(Result, at);
end;

function RecordCrc32(aColumns: TWireColumns; const aValues: TWireValues;
                     aSkip: integer): Cardinal;
var
   b: TBytes;
begin
   b := PackCanonical(aColumns, aValues, aSkip);
   Result := crc32(0, nil, 0);
   if Length(b) > 0 then
      begin
      Result := crc32(Result, @b[0], Length(b));
      end;
end;

(* An integer's CANONICAL digits: an optional '-' then decimal digits, nothing
  else. TryStrToInt64 alone would also take '$1F', '0x1F' and spaces. *)
function TryCanonicalInt64(const aText: string; out aValue: Int64): boolean;
var
   i, first: integer;
begin
   Result := False;
   aValue := 0;
   first := 1;
   if (Length(aText) > 0) and (aText[1] = '-') then
      begin
      first := 2;
      end;
   if Length(aText) < first then
      begin
      Exit;
      end;
   for i := first to Length(aText) do
      begin
      if (aText[i] < '0') or (aText[i] > '9') then
         begin
         Exit;
         end;
      end;
   (* TryStrToInt64 takes an AnsiString; the text was just checked to be
     ASCII digits, so the conversion loses nothing. *)
   Result := TryStrToInt64(AnsiString(aText), aValue);
end;

function EncodeJson(aColumns: TWireColumns; const aValues: TWireValues;
                    aCrc: Cardinal; aOmit: boolean): string;
var
   o: TJSONObject;
   i: integer;
   number: Int64;
begin
   CheckRowLength(aColumns, aValues);
   o := TJSONObject.Create;
   try
      for i := 0 to aColumns.Count - 1 do
         begin
         if (not aOmit) or (aValues[i] <> aColumns.Default[i]) then
            begin
            if aColumns.Numeric[i] then
               begin
               if aValues[i] = '' then
                  begin
                  o.Add(UTF8Encode(aColumns.Name[i]));   (* a null *)
                  end
               else
                  begin
                  if not TryCanonicalInt64(aValues[i], number) then
                     begin
                     raise EWireQsoError.CreateFmt('Column %s is numeric and holds "%s".',
                        [aColumns.Name[i], aValues[i]]);
                     end;
                  o.Add(UTF8Encode(aColumns.Name[i]), number);
                  end;
               end
            else
               begin
               o.Add(UTF8Encode(aColumns.Name[i]), UTF8Encode(aValues[i]));
               end;
            end;
         end;
      o.Add(CRC_MEMBER, WireCrcText(aCrc));
      Result := o.AsJSON;
   finally
      o.Free;
   end;
end;

(* Exactly 8 hex digits, parsed by hand: no prefix, no sign, no spaces. *)
function TryParseCrcText(const aText: string; out aCrc: Cardinal): boolean;
var
   i: integer;
   c: Char;
   digit: Cardinal;
begin
   Result := False;
   aCrc := 0;
   if Length(aText) <> 8 then
      begin
      Exit;
      end;
   for i := 1 to 8 do
      begin
      c := aText[i];
      if (c >= '0') and (c <= '9') then
         begin
         digit := Ord(c) - Ord('0');
         end
      else if (c >= 'A') and (c <= 'F') then
         begin
         digit := Ord(c) - Ord('A') + 10;
         end
      else if (c >= 'a') and (c <= 'f') then
         begin
         digit := Ord(c) - Ord('a') + 10;
         end
      else
         begin
         aCrc := 0;
         Exit;
         end;
      aCrc := (aCrc shl 4) or digit;
      end;
   Result := True;
end;

function DecodeJson(aColumns: TWireColumns; const aText: string;
                    out aValues: TWireValues; out aStated: Cardinal): boolean;
var
   d: TJSONData;
   o: TJSONObject;
   i, at: integer;
   nm: string;
begin
   Result := False;
   aStated := 0;
   aValues := aColumns.DefaultValues;
   try
      d := GetJSON(UTF8Encode(aText));
   except
      on E: Exception do
         begin
         raise EWireQsoError.Create(AnsiString('A wire record is not JSON: ' + E.Message));
         end;
   end;
   try
      if not (d is TJSONObject) then
         begin
         raise EWireQsoError.Create('A wire record is not one JSON object.');
         end;
      o := TJSONObject(d);
      for i := 0 to o.Count - 1 do
         begin
         nm := o.Names[i];
         if nm = CRC_MEMBER then
            begin
            if (not o.Items[i].IsNull) and TryParseCrcText(o.Items[i].AsString, aStated) then
               begin
               Result := True;
               end;
            end
         else
            begin
            at := aColumns.IndexOfName(nm);
            if at >= 0 then
               begin
               if o.Items[i].IsNull then
                  begin
                  aValues[at] := '';
                  end
               else
                  begin
                  aValues[at] := o.Items[i].AsString;
                  end;
               end;
            end;
         end;
   finally
      d.Free;
   end;
end;

end.
