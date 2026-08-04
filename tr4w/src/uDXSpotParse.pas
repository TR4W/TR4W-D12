{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uDXSpotParse;

{
  DECODE one DX cluster spot line into a TSpotRecord.  Nothing else.

  WHY THIS UNIT EXISTS.  This code was the first half of uTelnet.ProcessDX,
  which decoded AND applied in one 313-line function: it read the line and went
  on to check the log for a dupe, check the multiplier, add to the band map,
  search the alert list box and beep.  That mixture is why the decoder had
  no test -- linking it meant linking VisibleLog, SpotsList, MainUnit and the
  window layer.  Everything here is a pure function of the line: no globals, no
  I/O, no window handles, so it links into tr4w_unit_tests.exe.  ProcessDX keeps
  the apply half and calls in here for the decode.

  THE COLUMN ARITHMETIC IS UNCHANGED, DELIBERATELY.  Every offset below is
  copied verbatim from ProcessDX.  Those numbers are tuned against what real
  cluster nodes emit and were never covered by a test, so this extraction moves
  them without touching them; behaviour is pinned first (uTestDXSpotParse), and
  any correction is a separate, deliberate change on top of that pin.

  The format, measured over 198,979 real "DX de" lines captured from AR-Cluster
  and DXSpider nodes (D7-LogFilesForTesting/dxcluster):

     0         1         2         3         4         5         6         7
     0123456789012345678901234567890123456789012345678901234567890123456789012345
     DX de W1FM:       3729.8  EA7IXM       PAC0 PAGA L0S 10 MIL EUR0S DE  1713Z

  The frequency is RIGHT-justified so its decimal point lands on column 22 --
  198,977 of those 198,979 lines put it exactly there.  `Offset` below is the
  correction for the rest: a spotter callsign too long for the field shoves the
  frequency right, e.g.

     DX de 3V/KF5EYY-#:14007.0  PA3DZM      CW 20 DB 33 WPM CQ          PA 1941Z

  which puts the point on 23, and the DX call one column further along.  That
  is what the four `Offset :=` tests are compensating for.
}

interface

uses
   VC;

// Decode a complete cluster line.  Returns False -- leaving Spot partly filled
// and NOT usable -- when the line does not decode: an absurd frequency, or a
// DX call that fails GoodCallSyntax.  That is ProcessDX's original behaviour
// (it simply Exited with Result False on those two paths).
//
// Fills FFrequency, FFreqString, FCall, FSourceCall, FNotes and FQSXFrequency.
// FBand/FMode are left NoBand/NoMode: the band-map band/mode mapping is a
// SETTING (GetBandMapBandModeFromFrequency), not a property of the line, so it
// stays on the apply side.  FDupe, FMult, FSysTime and FMinutesLeft likewise
// depend on the log and the clock, not on the line.
function ParseDXSpotLine(const Line: AnsiString; out Spot: TSpotRecord): boolean;

// The "1713Z" stamp at the end of the line, as minutes since midnight UTC.
// Returns False when column 74 is not 'Z', which is how ProcessDX decides the
// line carries no usable time and falls back to the current clock.  Split out
// rather than folded into ParseDXSpotLine because the caller has to combine it
// with today's date from the UTC global to get a comparable timestamp.
function ParseDXSpotTimeUTC(const Line: AnsiString; out MinuteOfDay: integer): boolean;

implementation

uses
   Windows,
   utils_text,          // StrUpper (PAnsiChar, ANSI)
   uBandLookup,         // CalculateBandMode -- tree.pas forwards to this unit
   uCallSignRoutines;   // GoodCallSyntax

type
   // The line, NUL-filled, so a read past its end sees a terminator exactly as
   // it did when this walked the NUL-terminated receive buffer.  1024 is far
   // beyond any real cluster line (~80-120 chars).
   TDXLineBuf = array[0..1023] of AnsiChar;

procedure LineToBuf(const Line: AnsiString; var Buf: TDXLineBuf);
var
   copyLen: integer;
begin
   Windows.ZeroMemory(@Buf, SizeOf(Buf));
   copyLen := Length(Line);
   if copyLen > SizeOf(Buf) - 1 then
      begin
      copyLen := SizeOf(Buf) - 1;
      end;
   if copyLen > 0 then
      begin
      Move(Line[1], Buf[0], copyLen);
      end;
end;

// Does `Token` appear at 0-based offset `Index`?
//
// This replaces the `PInteger(@Buf[i])^ = $20585351 {QSX }` idiom that ran
// through this decoder.  That trick compared four characters as one 32-bit
// integer -- a D7-era micro-optimisation that saved a few cycles on 1990s
// hardware and has cost every reader since, because the constant only spells
// "QSX " if you know the machine is little-endian and read the bytes backwards.
// It is also silently limited to exactly four characters and silently wrong on
// a big-endian target.  The compare below is the same test, written down.
function TokenAt(const Buf: array of AnsiChar; Index: integer;
                 const Token: AnsiString): boolean;
var
   k: integer;
begin
   Result := False;
   if (Index < 0) or (Index + Length(Token) > Length(Buf)) then
      begin
      Exit;
      end;
   for k := 1 to Length(Token) do
      begin
      if Buf[Index + k - 1] <> Token[k] then
         begin
         Exit;
         end;
      end;
   Result := True;
end;

function ParseDXSpotLine(const Line: AnsiString; out Spot: TSpotRecord): boolean;
var
   LineBuf: TDXLineBuf;
   DX: integer;        // always 0; kept so the offsets below read as they did
   i: integer;
   TempFrequency: integer;

   f: integer;
   QSXPos: integer;
   TempChar: AnsiChar;
   Hertz: integer;
   DivHertz: boolean;
   QSXBand: BandType;
   QSXMode: ModeType;
   UpKhz: integer;

   Offset: integer;
begin
   LineToBuf(Line, LineBuf);
   DX := 0;   // the line starts at the start; see the header

   Offset := 0;
   Result := False;

   // Safe: TSpotRecord holds only value types (its callsigns are ShortStrings),
   // so there is nothing here for a wipe to leak.
   Windows.ZeroMemory(@Spot, SizeOf(TSpotRecord));
   Spot.FBand := NoBand;
   Spot.FMode := NoMode;

   if LineBuf[DX + 24] = '.' then
      begin
      Offset := 3; // 4.92.6
      end;
   if LineBuf[DX + 25] = '.' then
      begin
      Offset := 4;
      end;
   if LineBuf[DX + 26] = '.' then
      begin
      Offset := 5;
      end;
   if LineBuf[DX + 23] = '.' then
      begin
      Offset := 1;
      end;

   {Source Callsign}
   for i := DX + 9 to DX + 20 do
      begin
      if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) then
         begin
         // NOTE, pre-existing and NOT changed here: the length byte is only
         // written when the next column is non-blank, while the characters are
         // copied either way.  On the ordinary padded line ("W1FM:      ") the
         // next column IS blank, so FSourceCall keeps the zero length left by
         // the wipe above even though its bytes hold the spotter.  Everything
         // downstream reads it as @FSourceCall[1], i.e. as a NUL-terminated C
         // string, which is why this has never shown.  Verified identical in
         // the D7 tree (c:\TR4W, tagged "4.92.6"), so it is upstream behaviour,
         // not a D12 port artifact.  Pinned by uTestDXSpotParse.
         if LineBuf[i + 1] <> ' ' then // 4.92.6
            begin
            SetLength(Spot.FSourceCall, i - DX - 6);
            end;
         Windows.lstrcpynA(@Spot.FSourceCall[1], @LineBuf[DX + 6], i - DX - 5);
         Break;
         end;
      end;

   for i := DX + 10 to DX + 20 do
      begin
      // if LineBuf[i] = ' ' then if LineBuf[i + 1] <> ' ' then
      // Two nested single-statement ifs collapsed into one condition -- no else
      // on either, so this is the same test, and it satisfies the begin/end rule
      // without adding a pointless nesting level.  4.92.6
      if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) and
         (LineBuf[i + 1] <> ' ') then
         begin
         Windows.lstrcpynA(@Spot.FFreqString[0], @LineBuf[i + 1],
                           DX + 24 - i + Offset);

         TempFrequency := 0;

         for f := 0 to 12 do
            begin
            if TempFrequency > 2100000 { $ 7FFFFFF} then
               begin
               Exit;
               end;

            if Spot.FFreqString[f] = '.' then
               begin
               // 0010368100 - 009E3464
               // 1778165408 - 69FCA6A0
               // 2147483647   7FFFFFFF
               TempFrequency :=
                  (
                  TempFrequency * 10 +
                  (Ord(Spot.FFreqString[f + 1]) - 48)
                  ) * 100;
               //103 681 190 00
               if (TempFrequency > 1300000000) or (TempFrequency < 0) then
                  begin
                  Exit;
                  end;
               Spot.FFrequency := TempFrequency;
               Break;
               end;
            if Spot.FFreqString[f] = #0 then
               begin
               Break;
               end;
            if Spot.FFreqString[f] in ['0'..'9'] then
               begin
               TempFrequency := TempFrequency * 10 +
                                (Ord(Spot.FFreqString[f]) - 48);
               end;
            end;
         end;
      end;

   {DX}
   if Offset = 4 then
      begin
      Offset := 3; // 4.92.7
      end;
   for i := DX + 27 to DX + 39 do
      begin
      // Nested single-statement ifs collapsed; same test, no else on either. 4.92.7
      if (LineBuf[i] <> ' ') and
         (LineBuf[i + 1] = ' ') then
         begin
         SetLength(Spot.FCall, i - (DX + 25 + Offset));
         Windows.lstrcpynA(@Spot.FCall[1], @LineBuf[DX + 26 + Offset],
                           i - (DX + 24 + Offset));
         if not GoodCallSyntax(Spot.FCall) then
            begin
            Exit;
            end;
         Break;
         end;
      end;

   {Note}
   // Always true -- an AnsiChar compared against a 30-space string never equals
   // it.  Kept as written rather than "fixed": the comment says what was meant,
   // the note block below is harmless on a blank comment (it copies spaces),
   // and rewriting the test would change which lines take this path.  ny4i
   if LineBuf[DX + 39 + Offset] <> '                              ' then
      begin
      Windows.lstrcpynA(@Spot.FNotes[0], @LineBuf[DX + 39 + Offset], 31);
      //was 31 but allow for null ny4i

      // In place, so the QSX / UP matching below is against an uppercased
      // comment.  FNotes was copied first and keeps the original case.
      StrUpper(PAnsiChar(@LineBuf[DX + 39 + Offset]));

      for i := DX + 39 to DX + 65 do
         begin
         if TokenAt(LineBuf, i, 'QSX ') then
            begin
            if LineBuf[i + 4] in ['0'..'9'] then
               begin
               Hertz := 1000;
               DivHertz := False;

               for QSXPos := 4 to 12 do
                  begin
                  TempChar := LineBuf[i + QSXPos];
                  case TempChar of
                     ' ': Break;
                     '0'..'9':
                        begin
                        Spot.FQSXFrequency := Spot.FQSXFrequency * 10 +
                                              (Ord(TempChar) - 48);
                        if DivHertz then
                           begin
                           Hertz := Hertz div 10;
                           end;
                        end;
                     '.': DivHertz := True;
                  end;
                  end;

               Spot.FQSXFrequency := Spot.FQSXFrequency * Hertz;
               if Spot.FQSXFrequency < 10000 then
                  begin
                  Spot.FQSXFrequency := Spot.FFrequency + Spot.FQSXFrequency;
                  end;
               QSXBand := NoBand;
               CalculateBandMode(Spot.FQSXFrequency, QSXBand, QSXMode);
               if QSXBand = NoBand then
                  begin
                  Spot.FQSXFrequency := 0;
                  end;
               end;
            end;

         // "UP n" -- QSX n kHz up.  ONE test covering every spelling the format
         // has: UP1, UP 5, UP10, UP 10.  Read "UP", allow one optional space, then
         // take the digits and do the arithmetic.
         //
         // This replaces TWO blocks that between them still missed cases: five
         // hard-coded tokens UP1..UP5, and a separate space-form block.  So "UP7"
         // and "UP10" (no space) were silently ignored -- the QSX was dropped and
         // the operator worked the wrong frequency.  Reading the number instead of
         // enumerating spellings is why this now handles all of them.
         //
         // Left word boundary is required so PUP / CUP / SOUP in a comment cannot
         // fake a QSX -- and guarded on i > 0, because the old space-form block
         // read LineBuf[i - 1] with no such guard and would step off the front of
         // the buffer when the match sat at offset 0.
         if (i > 0) and (LineBuf[i - 1] = ' ') and
            (LineBuf[i] = 'U') and (LineBuf[i + 1] = 'P') then
            begin
            QSXPos := i + 2;
            if LineBuf[QSXPos] = ' ' then      // the optional space: "UP 10"
               begin
               Inc(QSXPos);
               end;
            UpKhz := 0;
            // Terminates on the NUL that fills the tail of LineBuf, so a match at
            // the very end of the line cannot run past it.
            while (QSXPos <= High(LineBuf)) and (LineBuf[QSXPos] in ['0'..'9']) do
               begin
               UpKhz := UpKhz * 10 + (Ord(LineBuf[QSXPos]) - Ord('0'));
               Inc(QSXPos);
               end;
            if UpKhz > 0 then
               begin
               Spot.FQSXFrequency := Spot.FFrequency + UpKhz * 1000;
               end;
            end;
         end;
      end;

   Result := True;
end;

function ParseDXSpotTimeUTC(const Line: AnsiString; out MinuteOfDay: integer): boolean;
var
   LineBuf: TDXLineBuf;
   DX: integer;
begin
   LineToBuf(Line, LineBuf);
   DX := 0;

   MinuteOfDay := 0;
   Result := LineBuf[DX + 74] = 'Z';
   if not Result then
      begin
      Exit;
      end;

   // Columns 70..73 are HHMM.  No digit check, exactly as before: a non-digit
   // there yields a nonsense number rather than a rejection.  The 'Z' in the
   // fixed column is the whole validation this format ever had.
   MinuteOfDay := ((Ord(LineBuf[DX + 70]) - $30) * 10 +
                    Ord(LineBuf[DX + 71]) - $30) * 60 +
                  ((Ord(LineBuf[DX + 72]) - $30) * 10 +
                    Ord(LineBuf[DX + 73]) - $30);
end;

end.
