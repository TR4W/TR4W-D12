unit utils_text;
{$I ..\tr4w.inc}

interface
uses VC, SysUtils;

function UpperCase(const s: string): string;

function tCharIsNumbers(c: Char): boolean;
function tCharIsAlphaNumericOrDash(c: Char): boolean;

function safeFloat(sStringFloat : string) : double;
function StringHas(LongString: string; SearchString: string): boolean;
function StringHasNumber(Prompt: string): boolean;
function StringHasLowerCase(InputString: string): boolean;
function StringIsAllNumbers(InputString: string): boolean;
function StringIsAllNumbersOrSpaces(InputString: string): boolean;
function StringIsAllNumbersOrDecimal(InputString: string): boolean;
function StringIsAllAlphanumericOrDash(InputString: string; bNoCase: boolean = false): boolean;
function StringHasLetters(InputString: string): boolean;
function StringWithFirstWordDeleted(InputString: string): string;

function PostcedingString(LongString: string; Deliminator: string): string;
function PrecedingString(LongString: string; Deliminator: string): string;

function tPos(s: ShortString; c: AnsiChar): integer; //wli  boundary: byte-char search (legacy ShortString callers)
function pPos(c: AnsiChar; p: PAnsiChar): integer;         // boundary: raw PAnsiChar scan


(* A FIXED AnsiChar BUFFER, WRITTEN AND READ THROUGH ITS OWN BOUNDS.

  These three replace StrPCopy / StrPLCopy / StrLCopy / StrPas and the
  PAnsiChar(@buf[0]) idiom. The point is not tidiness: the shim form takes the
  destination AND a byte count AND a conversion as three separate arguments
  that must agree BY HAND, and nothing checks that the count passed belongs to
  the array named. An open array parameter carries its own High(), so there is
  no count to get wrong.

  MOVED HERE FROM TF ON 2026-09-14, and the move is the point: TF pulls the
  LCL and the config model in behind it, so it is not in tr4w_unit_tests.lpr
  and these helpers could not be tested at all. utils_text is a leaf and is.

  UTF-8 both ways. SetCharBuffer encodes, CharBufferText decodes; a plain cast
  would reinterpret the bytes by the machine's codepage, and
  AnsiString(aFixedArray) would take the PADDING too -- the trap CLAUDE.md
  names directly. *)
procedure SetCharBuffer(var aBuf: array of AnsiChar; const aText: string);
function CharBufferText(const aBuf: array of AnsiChar): string;

(* THE SAME WRITE, BUT THE BYTES GO IN UNCHANGED.

  SetCharBuffer ENCODES -- it is for text, and UTF-8 is the encoding this
  program uses for text. Some buffers are not text: the multi-op server
  password is compared byte for byte against what a client sends, so encoding
  it differently would change the wire format and break an existing station.

  So this is StrPLCopy's contract without StrPLCopy's pointer: copy at most
  High(aBuf) bytes and terminate. Use it ONLY where the bytes are already the
  wire's, and SetCharBuffer everywhere else. *)
procedure SetCharBufferBytes(var aBuf: array of AnsiChar; const aBytes: AnsiString);

(* ONE SLICE OF A BUFFER, BY POSITION AND LENGTH.

  For fixed-column parsing -- a DX cluster line, where the callsign sits at a
  known offset. Equivalent to StrLCopy(@dest, @buf[aStart], aLen) without the
  two pointers: it stops at aLen characters, at a NUL, or at the end of the
  buffer, whichever comes first, and a start outside the buffer yields ''. *)
function CharBufferSlice(const aBuf: array of AnsiChar; aStart, aLen: integer): string;

(* THE LEADING INTEGER OF A STRING, AND NOTHING AFTER IT.

  A lenient parse for fixed-width text fields: an optional '-', then digits,
  stopping at the first character that is not one. No digits gives 0, and so
  does a lone '-'. It does NOT skip leading blanks, does not accept '+', and
  cannot fail -- which is why it exists rather than StrToIntDef: the fields it
  reads are slices of a record that may be padded or truncated, and a partial
  number is the answer there, not an error.

  IT REPLACES TWO IDENTICAL COPIES of TF.PCharToInt -- one in TF, one lifted
  verbatim into uCTYDAT to break a dependency, byte-for-byte the same and free
  to drift from each other unnoticed. Both took a PAnsiChar and walked it with
  two labels and two gotos, and neither could be tested: TF pulls in the LCL
  and the settings model, so it is not in the unit-test program at all. *)
function LeadingInt(const s: string): integer;

(* COMPARE TWO FIXED BUFFERS AS BYTES -- StrComp's answer without StrComp's
  pointers.

  Identical semantics to utils_text.StrComp: walk while the bytes match and
  the LEFT one has not hit its terminator, then return the difference of the
  two bytes at the stopping point. Unsigned, so $80..$FF sort ABOVE ASCII.

  IT MUST STAY BYTES, AND THAT IS NOT A STYLE POSITION. uCTYDAT's prefix
  table holds CTY.DAT text, which StrUpper's note below records may be
  CP1251/CP1250 -- so routing it through CharBufferText (UTF-8) would decode
  bytes that are not UTF-8 and change which prefixes match. The POINTERS are
  the problem here; the byte comparison is the requirement.

  The SIGN is load-bearing: ctyFindCallsign binary-searches the prefix table
  and the prefix sort insertion-sorts it, so this defines the sort ORDER and
  not merely equality. *)
function CompareCharBuffer(const a, b: array of AnsiChar): integer;

function StrComp(const Str1, Str2: PAnsiChar): integer;    // boundary: PAnsiChar
procedure StrUpper(Str: PAnsiChar);                        // boundary: PAnsiChar (ASCII a-z only)

// DataLen bytes as uppercase hex digits, unseparated -- 'KY 04' -> '4B592004'.
//
// Replaces Classes.BinToHex at the trace-logging call sites.  BinToHex writes
// through a PChar into a caller-supplied buffer, which means the caller has to
// size the buffer, terminate it by hand and get the *2 arithmetic right (the
// two call sites in LOGRADIO wrote their terminator at DIFFERENT offsets, one
// of them two bytes early).  A function that returns a string cannot get any
// of that wrong, and it is what the logger wants anyway.
//
// Unseparated deliberately, to keep the existing log lines byte-identical.
// uIcomNetworkTransport.BytesToHexStr is a SPACE-separated variant used for
// packet dumps; the two formats are read by different eyes, so they stay apart.
function BinToHexStr(const Data; DataLen: integer): string;

(* TEXT FOR AN LCL CONTROL OR DIALOG, which takes an AnsiString and wants
  UTF-8 in it.

  tr4w.inc makes `string` UTF-16. The LCL is compiled WITHOUT that, so its
  `string` parameters are AnsiString, and it sets DefaultSystemCodePage to
  65001 so those hold UTF-8. Passing our UTF-16 straight in therefore does the
  right thing at run time -- and the compiler still calls it a narrowing
  conversion "with potential data loss", because in general Unicode -> Ansi
  is one.

  Here it is not: UTF-16 to UTF-8 loses nothing. Saying so explicitly is what
  CLAUDE.md asks for -- convert at the boundary rather than letting the
  assignment do it silently -- and it keeps the narrowing ceiling meaningful,
  which is the point of the ceiling.

  RawByteString because the bytes carry no code-page tag, so nothing can
  convert them a second time on the way in.

  IT CAME FROM uAnsiStr, which is deleted. It was the last thing in that unit
  with a caller, and it never belonged there: it is the one routine in it that
  had nothing to do with PAnsiChar. *)
function LclText(const s: string): RawByteString;

implementation

function LclText(const s: string): RawByteString;
begin
   Result := RawByteString(UTF8Encode(s));
end;

function UpperCase(const s: string): string;
var
  i                                     : integer;
begin
  // ASCII-only upcase (a..z -> A..Z), byte-stable for callsign/contest text --
  // deliberately NOT SysUtils.UpperCase (which does full Unicode casing).
  // Was a PAnsiChar pointer loop; now a plain native-string loop.
  SetLength(Result, Length(s));
  for i := 1 to Length(s) do
    if (s[i] >= 'a') and (s[i] <= 'z') then
       begin
       Result[i] := Char(Ord(s[i]) - 32)
       end
    else
       begin
       Result[i] := s[i];
       end;
end;

function StringHas(LongString: string; SearchString: string): boolean;

{ This function will return TRUE if the SearchString is contained in the
    LongString.                                                                }

begin
  StringHas := pos(SearchString, LongString) <> 0;
end;



function StringIsAllAlphanumericOrDash(InputString: string; bNoCase: boolean = false): boolean;
var
  CharPos                               : integer;
begin
   StringIsAllAlphanumericOrDash := False;
   if InputString = '' then Exit;

   if bNoCase then
      begin
      InputString := UpperCase(InputString);
      end;

   for CharPos := 1 to length(InputString) do
      begin
      if not tCharIsAlphanumericOrDash(InputString[CharPos]) then
         begin
         Exit;
         end;
      end;

  StringIsAllAlphanumericOrDash := True;
end;




function StringHasLetters(InputString: string): boolean;

var
  CharPos                               : integer;

begin
  for CharPos := 1 to length(InputString) do

    if (UpCase(InputString[CharPos]) <= 'Z') and (UpCase(InputString[CharPos]) >= 'A') then
       begin
       StringHasLetters := True;
       Exit;
       end;

  StringHasLetters := False;
end;

function StringHasLowerCase(InputString: string): boolean;

var
  CharPos                               : integer;

begin
  for CharPos := 1 to length(InputString) do
    if (InputString[CharPos] <= 'z') and (InputString[CharPos] >= 'a') then
       begin
       StringHasLowerCase := True;
       Exit;
       end;

  StringHasLowerCase := False;
end;

function StringHasNumber(Prompt: string): boolean;

var
  ChrPtr                                : integer;

begin
  StringHasNumber := False;
  if length(Prompt) = 0 then Exit;

  for ChrPtr := 1 to length(Prompt) do
    //      if (Prompt[ChrPtr] >= '0') and (Prompt[ChrPtr] <= '9') then
    if tCharIsNumbers(Prompt[ChrPtr]) then
       begin
       StringHasNumber := True;
       Exit;
       end;
end;

function StringIsAllNumbers(InputString: string): boolean;

var
  CharPos                               : integer;

begin
  StringIsAllNumbers := False;
  if InputString = '' then Exit;

  for CharPos := 1 to length(InputString) do
    if not tCharIsNumbers(InputString[CharPos]) then
       begin
       Exit;
       end;

  StringIsAllNumbers := True;
end;

function tCharIsNumbers(c: Char): boolean;
begin
  Result := c in ['0'..'9'];
end;

function tCharIsAlphaNumericOrDash(c: Char): boolean;
begin
   Result := (c in ['0'..'9']) or
             (c in ['A'..'Z']) or
             (c in ['-']);
end;

function StringIsAllNumbersOrSpaces(InputString: string): boolean;

var
  CharPos                               : integer;

begin
  StringIsAllNumbersOrSpaces := False;
  if InputString = '' then Exit;

  for CharPos := 1 to length(InputString) do
    if not tCharIsNumbers(InputString[CharPos]) then
      //      if (InputString[CharPos] < '0') or (InputString[CharPos] > '9') then
      if InputString[CharPos] <> ' ' then Exit;

  StringIsAllNumbersOrSpaces := True;
end;

function StringIsAllNumbersOrDecimal(InputString: string): boolean;

var
  CharPos                               : integer;

begin
  StringIsAllNumbersOrDecimal := False;
  if InputString = '' then Exit;

  for CharPos := 1 to length(InputString) do
    //      if (InputString[CharPos] < '0') or (InputString[CharPos] > '9') then
    if not tCharIsNumbers(InputString[CharPos]) then
      if InputString[CharPos] <> '.' then Exit;

  StringIsAllNumbersOrDecimal := True;
end;

function StringWithFirstWordDeleted(InputString: string): string;

{ This function performs a wordstar like control-T operation on the
    string passed to it.                                                   }

var
  DeletedChar                           : Char;

begin
  if (InputString = '') or (not StringHas(InputString, ' ')) then
     begin
     StringWithFirstWordDeleted := '';
     Exit;
     end;

  repeat
    DeletedChar := InputString[1];
    Delete(InputString, 1, 1);

    if length(InputString) = 0 then
       begin
       StringWithFirstWordDeleted := '';
       Exit;
       end;

  until (DeletedChar = ' ') and (InputString[1] <> ' ');
  StringWithFirstWordDeleted := InputString;
end;

function PostcedingString(LongString: string; Deliminator: string): string;

var
  Position                              : integer;

begin

  Position := pos(Deliminator, LongString);

  if Position > 0 then
     begin
     PostcedingString := Copy(LongString,
       Position + length(Deliminator),
       length(LongString) - Position - (length(Deliminator) - 1))
     end
  else
     begin
     PostcedingString := '';
     end;
end;

function PrecedingString(LongString: string; Deliminator: string): string;

var
  Position                              : integer;

begin

  Position := pos(Deliminator, LongString);

  if Position >= 2 then
     begin
     PrecedingString := Copy(LongString, 1, Position - 1)
     end
  else
     begin
     PrecedingString := '';
     end;
end;

function pPos(c: AnsiChar; p: PAnsiChar): integer;
var
  i                                     : Cardinal;
begin
  Result := -1;
  for i := 0 to 255 do
     begin
     if p[i] = #0 then Break;
     if p[i] = c then
        begin
        Result := i;
        Break;
        end;
     end;
end;

function tPos(s: ShortString; c: AnsiChar): integer; //
var
  i                                     : Cardinal;
begin
  Result := 0;
  if s = '' then Exit;
  for i := 1 to length(s) do
    if s[i] = c then
       begin
       Result := i;
       Exit;
       end;
end;

{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  StrComp

  Compares two NUL-terminated byte strings and returns the difference between
  the first bytes that differ -- NOT a normalized -1/0/+1.  Callers use only the
  sign, but the magnitude is what the assembly this replaces returned, and
  uTestUtilsText pins it exactly.

  Bytes compare UNSIGNED, so anything >= $80 sorts AFTER every ASCII character.
  That is load-bearing rather than incidental: CTY.DAT and the language files
  carry codepage-specific high-bit bytes, and the country lookup binary-searches
  the prefix table this orders.  A signed comparison would reorder it silently.
}

procedure SetCharBufferBytes(var aBuf: array of AnsiChar; const aBytes: AnsiString);
var
   n: integer;
   i: integer;
begin
   n := Length(aBytes);
   if n > High(aBuf) then
      begin
      n := High(aBuf);          (* leave room for the terminator *)
      end;

   for i := 1 to n do
      begin
      aBuf[i - 1] := AnsiChar(aBytes[i]);
      end;
   aBuf[n] := #0;
end;

procedure SetCharBuffer(var aBuf: array of AnsiChar; const aText: string);
var
   raw: RawByteString;
   n: integer;
   i: integer;
begin
   raw := RawByteString(UTF8Encode(aText));

   n := Length(raw);
   if n > High(aBuf) then
      begin
      n := High(aBuf);          (* leave room for the terminator *)
      end;

   for i := 1 to n do
      begin
      aBuf[i - 1] := AnsiChar(raw[i]);
      end;
   aBuf[n] := #0;
end;

function CharBufferText(const aBuf: array of AnsiChar): string;
var
   n: integer;
   raw: RawByteString;
   i: integer;
begin
   n := 0;
   while (n <= High(aBuf)) and (aBuf[n] <> #0) do
      begin
      Inc(n);
      end;

   SetLength(raw, n);
   for i := 1 to n do
      begin
      raw[i] := aBuf[i - 1];
      end;

   Result := UTF8ToString(raw);
end;

function CompareCharBuffer(const a, b: array of AnsiChar): integer;
var
   i: integer;
   ca, cb: byte;
begin
   i := 0;
   while True do
      begin
      (* Past the end of a buffer reads as the terminator, which is what a
        PAnsiChar walk did when it met the NUL. *)
      if i > High(a) then ca := 0 else ca := Ord(a[i]);
      if i > High(b) then cb := 0 else cb := Ord(b[i]);

      if (ca = 0) or (ca <> cb) then
         begin
         Result := ca - cb;
         Exit;
         end;

      Inc(i);
      end;
end;

function LeadingInt(const s: string): integer;
var
   i        : integer;
   negative : boolean;
begin
   Result := 0;
   i := 1;
   negative := False;

   if (i <= Length(s)) and (s[i] = '-') then
      begin
      negative := True;
      Inc(i);
      end;

   while (i <= Length(s)) and (s[i] >= '0') and (s[i] <= '9') do
      begin
      Result := Result * 10 + (Ord(s[i]) - Ord('0'));
      Inc(i);
      end;

   if negative then
      begin
      Result := -Result;
      end;
end;

function CharBufferSlice(const aBuf: array of AnsiChar; aStart, aLen: integer): string;
var
   raw: RawByteString;
   n: integer;
   i: integer;
begin
   Result := '';
   if (aLen <= 0) or (aStart < 0) or (aStart > High(aBuf)) then
      begin
      Exit;
      end;

   (* STOP AT THE NUL, as StrLCopy did. The buffer is a whole line and the
     slice is usually shorter than the column width it was cut to. *)
   n := 0;
   while (n < aLen) and (aStart + n <= High(aBuf)) and (aBuf[aStart + n] <> #0) do
      begin
      Inc(n);
      end;

   SetLength(raw, n);
   for i := 1 to n do
      begin
      raw[i] := aBuf[aStart + i - 1];
      end;

   Result := UTF8ToString(raw);
end;

function StrComp(const Str1, Str2: PAnsiChar): integer;
var
   p1                                    : PAnsiChar;
   p2                                    : PAnsiChar;
begin
   p1 := Str1;
   p2 := Str2;

   // Stops at the first difference OR at Str1's terminator, so a string that is
   // a prefix of the other ends up comparing #0 against the other's next byte.
   while (p1^ <> #0) and (p1^ = p2^) do
      begin
      Inc(p1);
      Inc(p2);
      end;

   Result := Ord(p1^) - Ord(p2^);
end;

{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  StrUpper

  Uppercases in place, ASCII 'a'..'z' ONLY.  Every other byte -- including all
  of $80..$FF -- is left exactly as it was.

  That restriction is deliberate.  uCTYDAT and MainUnit run this over buffers
  that may hold CP1251/CP1250 text, and a locale-aware uppercase would rewrite
  those bytes and stop CTY.DAT matching.  Do not "improve" this into UpperCase
  or CharUpperBuff.
}
procedure StrUpper(Str: PAnsiChar);
var
   p                                     : PAnsiChar;
begin
   p := Str;
   while p^ <> #0 do
      begin
      if p^ in ['a' .. 'z'] then
         begin
         p^ := AnsiChar(Ord(p^) - 32);
         end;
      Inc(p);
      end;
end;

{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  safeFloat

  Strips many bad characters from a string and returns it as a double.
}
function safeFloat(sStringFloat : string) : double;
var
  dReturn : double;

begin
  sStringFloat := stringReplace(sStringFloat, '%', '', [rfIgnoreCase, rfReplaceAll]);
  sStringFloat := stringReplace(sStringFloat, FormatSettings.CurrencyString , '', [rfIgnoreCase, rfReplaceAll]);
  sStringFloat := stringReplace(sStringFloat, ' ', '', [rfIgnoreCase, rfReplaceAll]);
  sStringFloat := stringReplace(sStringFloat, ',', '', [rfIgnoreCase, rfReplaceAll]);
  sStringFloat := stringReplace(sStringFloat, FormatSettings.ThousandSeparator, '', [rfIgnoreCase, rfReplaceAll]);
  try
    dReturn := strToFloat(sStringFloat);
  except
    dReturn := 0;
  end;
  result := dReturn;

end;

function BinToHexStr(const Data; DataLen: integer): string;
const
   HexDigits: array[0..15] of Char = ('0','1','2','3','4','5','6','7',
                                      '8','9','A','B','C','D','E','F');
var
   bytes : array[0..MaxInt - 1] of Byte absolute Data;
   i     : integer;
begin
   Result := '';
   if DataLen <= 0 then
      begin
      Exit;
      end;

   SetLength(Result, DataLen * 2);
   for i := 0 to DataLen - 1 do
      begin
      Result[(i * 2) + 1] := HexDigits[bytes[i] shr 4];
      Result[(i * 2) + 2] := HexDigits[bytes[i] and $0F];
      end;
end;

end.

