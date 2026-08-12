unit utils_text;

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

function StrComp(const Str1, Str2: PAnsiChar): integer;    // boundary: PAnsiChar
procedure StrUpper(Str: PAnsiChar);                        // boundary: PAnsiChar (ASCII a-z only)

implementation

function UpperCase(const s: string): string;
var
  i                                     : integer;
begin
  // ASCII-only upcase (a..z -> A..Z), byte-stable for callsign/contest text --
  // deliberately NOT System.SysUtils.UpperCase (which does full Unicode casing).
  // Was a PAnsiChar pointer loop; now a plain native-string loop.
  SetLength(Result, Length(s));
  for i := 1 to Length(s) do
    if (s[i] >= 'a') and (s[i] <= 'z') then
      Result[i] := Char(Ord(s[i]) - 32)
    else
      Result[i] := s[i];
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
      InputString := UpperCase(InputString);

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
      Exit;

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
    PostcedingString := Copy(LongString,
      Position + length(Deliminator),
      length(LongString) - Position - (length(Deliminator) - 1))
  else
    PostcedingString := '';
end;

function PrecedingString(LongString: string; Deliminator: string): string;

var
  Position                              : integer;

begin

  Position := pos(Deliminator, LongString);

  if Position >= 2 then
    PrecedingString := Copy(LongString, 1, Position - 1)
  else
    PrecedingString := '';
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
end.

