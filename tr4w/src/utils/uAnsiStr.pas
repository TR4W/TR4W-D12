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

(* COPY AT MOST MaxLen CHARACTERS BETWEEN TWO PAnsiChars, ALWAYS
  NUL-TERMINATING -- the missing member of this set, and the exact replacement
  for Win32's lstrcpynA.

  THE OFF-BY-ONE IS THE WHOLE POINT. lstrcpynA(d, s, n) writes at most n-1
  characters PLUS the NUL -- its count INCLUDES the terminator. StrLCopy's
  MaxLen counts CHARACTERS and the NUL is extra, which is FPC's own
  strings.StrLCopy convention. So a faithful conversion of a call site reads

      lstrcpynA(d, s, n)   ->   StrLCopy(d, s, n - 1)

  and getting it wrong writes one byte further than the Win32 version did.

  The source need NOT be NUL-terminated inside MaxLen -- the callers that
  wanted this point into the middle of a received cluster line -- but a NUL
  found earlier still stops the copy, as lstrcpynA's did. *)
function StrLCopy(Dest: PAnsiChar; const Source: PAnsiChar; MaxLen: Cardinal): PAnsiChar;


(* WinAnsi IS GONE (2026-09-07), and what it did is worth keeping a note of
  because the reason it existed is the reason it could go.

  It converted a UTF-16 `string` to bytes in the MACHINE'S ANSI CODE PAGE,
  named explicitly through WideCharToMultiByte, because AnsiString(s) gives
  UTF-8 -- the LCL sets DefaultSystemCodePage to 65001 -- and a Win32 '...A'
  entry point reads UTF-8 as cp1252. That is how the New Contest dialog
  showed 'Ultimo archivo de configuracion' with every accented letter
  doubled, in Spanish (NY4I, 2026-08-27).

  SO IT WAS ALWAYS A FUNCTION ABOUT ONE THING: feeding a Win32 '...A' call.
  Its 73 call sites did not survive the Win32-to-LCL conversion as a group,
  and the last of them went today, each for its own reason:

    42  passed the result as a FORMAT STRING to TF.Format, correct while
        TF.Format WAS wsprintfA and wrong the moment it became Pascal over
        SysUtils.Format -- ANSI bytes handed to the RTL, which tags them
        UTF-8. Those are LclText now.
     9  fed lstrcpyA/lstrcpynA, which are StrLCopy.
     4  fed a Win32 call taking ASCII -- a dotted quad, 'LPT2', a resource
        name. A code-page conversion of ASCII returns what it was given.
     2  fed CopyFileA and WinExec, both replaced by their FCL/LCL
        equivalents, which take strings.
     1  converted an array of AnsiChar to UTF-16 and straight back.
     rest  passed bytes to a routine that already took a string.

  IF A NEW WIN32 '...A' CALL EVER NEEDS THIS, the answer is to use the wide
  entry point instead. That is the whole lesson: every site above had a
  destination that wanted a string, and the conversion existed only because
  something underneath it did not. *)

{ TEXT FOR AN LCL DIALOG, which takes an AnsiString and wants UTF-8 in it.

  THE MIRROR IMAGE OF THE WinAnsi DESCRIBED ABOVE, and the direction that
  survived it. tr4w.inc
  makes `string` UTF-16; the LCL is compiled without that, so its `string`
  parameters are AnsiString, and it sets DefaultSystemCodePage to 65001 so that
  those hold UTF-8. Passing our UTF-16 straight in therefore does the RIGHT
  thing at run time -- and the compiler still calls it a narrowing conversion
  "with potential data loss", because in general Unicode -> Ansi is one.

  Here it is not: UTF-16 to UTF-8 loses nothing. Saying so explicitly is what
  CLAUDE.md asks for -- convert at the boundary rather than letting the
  assignment do it silently -- and it keeps the narrowing ceiling meaningful,
  which is the point of the ceiling.

  RawByteString for the same reason WinAnsi used it: the bytes carry no
  code-page tag, so nothing can convert them a second time on the way in. }
function LclText(const s: string): RawByteString;

implementation

function LclText(const s: string): RawByteString;
begin
   Result := RawByteString(UTF8Encode(s));
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

function StrLCopy(Dest: PAnsiChar; const Source: PAnsiChar; MaxLen: Cardinal): PAnsiChar;
var
   count: Cardinal;
begin
   Result := Dest;
   if (Dest = nil) or (Source = nil) then
      begin
      Exit;
      end;

   { Stop at a NUL inside the range, exactly as lstrcpynA did. }
   count := 0;
   while (count < MaxLen) and (Source[count] <> #0) do
      begin
      Inc(count);
      end;

   if count > 0 then
      begin
      Move(Source^, Dest^, count);
      end;

   { Always terminate, including the empty case. }
   Dest[count] := #0;
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
