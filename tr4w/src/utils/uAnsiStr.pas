unit uAnsiStr;

// The handful of PAnsiChar routines TR4W actually uses, owned rather than
// borrowed.
//
// TR4W called these as System.AnsiStrings.StrPos / .StrPCopy / .StrComp /
// .StrLen / .StrPLCopy.  The qualifier was not decoration: under Delphi 12 the
// unqualified names resolve to SysUtils' PWideChar versions, so the prefix was
// the only thing keeping ANSI buffers off the Unicode routines.
//
// FPC has no AnsiStrings unit at all.  It ships `strings`, whose routines are
// declared over PChar and `string` AS COMPILED IN THAT UNIT -- which is exactly
// the kind of implicit, mode-dependent binding that has already cost this
// project real bugs (GetPrivateProfileString binding to W and writing UTF-16
// into an AnsiChar buffer, 1bea7af4).  Shimming one RTL onto the other with
// {$IFDEF FPC} would leave the signatures decided by whichever unit happened to
// be compiled in which mode.
//
// uStrSearch.pas already reached this conclusion for StrLen and StrComp: "Both
// routines it borrowed are a handful of lines, so the portable answer is to own
// them rather than to shim around the difference with {$IFDEF FPC}."  This unit
// is that decision applied once, in one place, for all five.
//
// Everything here is explicitly PAnsiChar and byte-oriented.  There is no
// conditional compilation in this unit BY DESIGN: both compilers see identical
// source, so both produce identical behaviour.
//
// Semantics deliberately match System.AnsiStrings:
//   StrLen     - characters before the terminating #0.
//   StrComp    - <0, 0, >0 by unsigned byte value at the first difference.
//   StrPos     - pointer to the first occurrence of Str2 in Str1, or nil.
//                An EMPTY Str2 returns Str1 (it occurs immediately).
//   StrPCopy   - copies Source and terminates; caller owns the buffer size.
//   StrPLCopy  - copies at most MaxLen characters, then terminates.  MaxLen is
//                the room for TEXT, not counting the terminator -- so the
//                buffer must hold MaxLen + 1 bytes.
// Nil handling matches too: StrLen(nil) = 0, and StrPos with a nil argument
// returns nil rather than faulting.

{$I ..\tr4w.inc}

interface

function StrLen(const Str: PAnsiChar): Cardinal;
function StrComp(const Str1, Str2: PAnsiChar): Integer;

// Case-insensitive over ASCII A-Z only, DELIBERATELY.
//
// Its caller matches an operator's config value against a table of fixed
// spellings, and the config loader has already uppercased the whole line
// (LogCfg.pas, EnumerateLinesInFile with UpperCase = True).  A locale-aware
// fold would be wrong here twice over: the spellings are program tokens, not
// prose, and TR4W's non-English builds carry high-bit bytes whose case mapping
// depends on a codepage this comparison must not depend on.
function StrIComp(const Str1, Str2: PAnsiChar): Integer;

function StrPos(const Str1, Str2: PAnsiChar): PAnsiChar;
function StrPCopy(Dest: PAnsiChar; const Source: AnsiString): PAnsiChar;
function StrPLCopy(Dest: PAnsiChar; const Source: AnsiString; MaxLen: Cardinal): PAnsiChar;

{ TEXT FOR A WIN32 ...A ENTRY POINT, in the machine's ANSI code page.

  NOT AnsiString(s). tr4w.inc makes `string` UTF-16 and the LCL sets
  DefaultSystemCodePage to 65001, so a plain AnsiString cast yields UTF-8
  BYTES, which an ...A entry point reads as cp1252. That is how the New
  Contest dialog showed 'Ultimo archivo de configuracion' with each accented
  letter doubled, in Spanish (NY4I, 2026-08-27).

  AnsiString(CP_ACP) does NOT help: CP_ACP is 0, and 0 means
  DefaultSystemCodePage -- the value that is wrong here. The code page must
  be named to the conversion, hence WideCharToMultiByte.

  RawByteString so the bytes carry no code-page tag and cannot be converted
  a second time on the way out. Use it AT the call, PAnsiChar(WinAnsi(s)),
  so the temporary outlives the statement.

  26 units still run a Win32 dialog proc, so this is not a corner case. It
  retires with the last of them -- an LCL form needs none of it. }
function WinAnsi(const s: string): RawByteString;

implementation

uses
   Windows;   // WideCharToMultiByte, CP_ACP

function WinAnsi(const s: string): RawByteString;
var
   n: integer;
begin
   Result := '';
   if s = '' then
      begin
      Exit;
      end;
   n := WideCharToMultiByte(CP_ACP, 0, PWideChar(s), Length(s), nil, 0, nil, nil);
   if n <= 0 then
      begin
      Exit;
      end;
   SetLength(Result, n);
   WideCharToMultiByte(CP_ACP, 0, PWideChar(s), Length(s),
                       PAnsiChar(Result), n, nil, nil);
end;

function StrLen(const Str: PAnsiChar): Cardinal;
var
   p: PAnsiChar;
begin
   Result := 0;
   if Str = nil then
      begin
      Exit;
      end;

   p := Str;
   while p^ <> #0 do
      begin
      Inc(p);
      end;
   Result := Cardinal(p - Str);
end;

function StrComp(const Str1, Str2: PAnsiChar): Integer;
var
   p1, p2: PAnsiChar;
begin
   p1 := Str1;
   p2 := Str2;

   // Compare as BYTES, not as AnsiChar.  AnsiChar comparison is signed on some
   // targets, which would order high-bit characters wrongly -- and TR4W's
   // callsign and Cabrillo text is full of them in the non-English builds.
   while (p1^ <> #0) and (p1^ = p2^) do
      begin
      Inc(p1);
      Inc(p2);
      end;

   Result := Integer(Byte(p1^)) - Integer(Byte(p2^));
end;

function StrIComp(const Str1, Str2: PAnsiChar): Integer;
var
   p1, p2: PAnsiChar;
   b1, b2: Byte;
begin
   p1 := Str1;
   p2 := Str2;

   while True do
      begin
      b1 := Byte(p1^);
      b2 := Byte(p2^);

      // ASCII lowercase -> uppercase, and nothing else.  See the header.
      if (b1 >= Ord('a')) and (b1 <= Ord('z')) then
         begin
         Dec(b1, 32);
         end;
      if (b2 >= Ord('a')) and (b2 <= Ord('z')) then
         begin
         Dec(b2, 32);
         end;

      if (b1 <> b2) or (b1 = 0) then
         begin
         Break;
         end;

      Inc(p1);
      Inc(p2);
      end;

   Result := Integer(b1) - Integer(b2);
end;

function StrPos(const Str1, Str2: PAnsiChar): PAnsiChar;
var
   pStart, pHay, pNeedle: PAnsiChar;
begin
   Result := nil;
   if (Str1 = nil) or (Str2 = nil) then
      begin
      Exit;
      end;

   // An empty needle occurs at the very start.  This matches the RTL, and it
   // matters: a caller that searches for a value it did not set would otherwise
   // get nil and take the "not found" branch.
   if Str2^ = #0 then
      begin
      Result := Str1;
      Exit;
      end;

   pStart := Str1;
   while pStart^ <> #0 do
      begin
      pHay := pStart;
      pNeedle := Str2;

      while (pNeedle^ <> #0) and (pHay^ = pNeedle^) do
         begin
         Inc(pHay);
         Inc(pNeedle);
         end;

      if pNeedle^ = #0 then
         begin
         Result := pStart;
         Exit;
         end;

      Inc(pStart);
      end;
end;

function StrPCopy(Dest: PAnsiChar; const Source: AnsiString): PAnsiChar;
begin
   Result := StrPLCopy(Dest, Source, Cardinal(Length(Source)));
end;

function StrPLCopy(Dest: PAnsiChar; const Source: AnsiString; MaxLen: Cardinal): PAnsiChar;
var
   count: Cardinal;
begin
   Result := Dest;
   if Dest = nil then
      begin
      Exit;
      end;

   count := Cardinal(Length(Source));
   if count > MaxLen then
      begin
      count := MaxLen;
      end;

   if count > 0 then
      begin
      // Source[1] is only legal for a non-empty string.
      Move(Source[1], Dest^, count);
      end;

   // Always terminate, including the empty case.
   Dest[count] := #0;
end;

end.
