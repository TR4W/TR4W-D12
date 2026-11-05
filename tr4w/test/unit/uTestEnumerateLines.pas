(*
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
 *)

(* TF.EnumerateLinesInFile AND THE HELLO.DAT READER -- pointer audit P16,
  2026-11-05.

  WRITTEN FIRST, against the callback shape `procedure(Line: PShortString)`,
  and run green there; the callback type then became
  `procedure(var aLine: ShortString)` and only the collector's parameter line
  below changed with it. Every assertion is the same on both sides.

  WHAT THE ENGINE PROMISES ITS NINE CALL SITES, read from the code:
    - a line ends at CR or LF, and any run of them is ONE break, so a blank
      line is never delivered and CRLF is not two lines;
    - the last line is delivered whether or not the file ends with a break;
    - a line is at most 255 bytes: a longer one is cut there, and the next
      line is unaffected;
    - the bytes arrive unchanged, high bytes included, unless the caller asked
      for upper case;
    - a callback may EDIT its line (four of the eight loaders do), and the edit
      does not reach the next line;
    - a missing or empty file answers False and delivers nothing.

  HELLO.DAT is read by one caller (LOGSTUFF.LoadSpecialHelloFile) through
  LOGSTUFF.EnumHelloDAT, and no test drove it. The test below runs the same
  callback through the same engine on a file of its own; only the bare-name
  path resolution of LoadSpecialHelloFile is not exercised. It builds records
  in the unit's list, so it saves the list, frees what it built and restores
  the list (the heaptrc run counts unfreed blocks). *)
unit uTestEnumerateLines;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TEnumerateLinesTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_LinesEndAtCRAndLFAndBlankLinesAreSkipped;
      procedure Test_TheLastLineNeedsNoBreak;
      procedure Test_UpperCaseIsTheCallersChoice;
      procedure Test_ALongLineIsCutAt255AndTheNextIsWhole;
      procedure Test_HighBytesArriveUnchanged;
      procedure Test_AnEditDoesNotReachTheNextLine;
      procedure Test_AMissingOrEmptyFileDeliversNothing;
      procedure Test_HelloDatBuildsTheGreetingList;
   end;

implementation

uses
   Classes,
   SysUtils,
   TF,
   LogStuff;

var
   (* What the collector was handed, line by line. ShortStrings, not a
     TStringList, so a high byte is compared as the byte it was. *)
   GLines: array of ShortString;
   (* When True the collector cuts each line it is handed to its first
     character AFTER recording it -- the in-place edit the loaders make. *)
   GEditEachLine: boolean = False;

procedure CollectLine(var aLine: ShortString);
begin
   SetLength(GLines, Length(GLines) + 1);
   GLines[High(GLines)] := aLine;
   if GEditEachLine then
      begin
      Delete(aLine, 2, 255);
      end;
end;

function TestFilePath(const aName: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + aName;
end;

(* Writes aBytes exactly -- no line-ending translation, no encoding. *)
function WriteRawFile(const aName: string; const aBytes: RawByteString): string;
var
   fs: TFileStream;
begin
   Result := TestFilePath(aName);
   fs := TFileStream.Create(AnsiString(Result), fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         fs.WriteBuffer(aBytes[1], Length(aBytes));
         end;
   finally
      fs.Free;
   end;
end;

function Enumerate(const aPath: string; aUpperCase: boolean): boolean;
begin
   SetLength(GLines, 0);
   Result := EnumerateLinesInFile(aPath, CollectLine, aUpperCase);
end;

procedure TEnumerateLinesTests.Test_LinesEndAtCRAndLFAndBlankLinesAreSkipped;
var
   path: string;
begin
   BeginTest('Test_LinesEndAtCRAndLFAndBlankLinesAreSkipped');
   path := WriteRawFile('tr4w_enumlines_breaks.txt',
                        #13#10'ONE'#13#10'TWO'#10'THREE'#13'FOUR'#13#10#13#10#10#13'FIVE'#13#10);
   try
      CheckTrue(Enumerate(path, False), 'the file is read');
      CheckEquals(5, Length(GLines), 'five lines: a run of breaks is one break, a blank line is skipped');
      if Length(GLines) = 5 then
         begin
         CheckEquals('ONE', string(GLines[0]), 'a leading break delivers nothing');
         CheckEquals('TWO', string(GLines[1]), 'CRLF ends a line');
         CheckEquals('THREE', string(GLines[2]), 'LF alone ends a line');
         CheckEquals('FOUR', string(GLines[3]), 'CR alone ends a line');
         CheckEquals('FIVE', string(GLines[4]), 'after a run of blank lines');
         end;
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_TheLastLineNeedsNoBreak;
var
   path: string;
begin
   BeginTest('Test_TheLastLineNeedsNoBreak');
   path := WriteRawFile('tr4w_enumlines_last.txt', 'A'#13#10'LAST');
   try
      CheckTrue(Enumerate(path, False), 'the file is read');
      CheckEquals(2, Length(GLines), 'both lines');
      if Length(GLines) = 2 then
         begin
         CheckEquals('LAST', string(GLines[1]), 'the unterminated last line is delivered');
         end;
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_UpperCaseIsTheCallersChoice;
var
   path: string;
begin
   BeginTest('Test_UpperCaseIsTheCallersChoice');
   path := WriteRawFile('tr4w_enumlines_case.txt', 'my call = ny4i'#13#10);
   try
      CheckTrue(Enumerate(path, False), 'read as written');
      CheckEquals(1, Length(GLines), 'one line');
      if Length(GLines) = 1 then
         begin
         CheckEquals('my call = ny4i', string(GLines[0]), 'case kept when not asked');
         end;

      CheckTrue(Enumerate(path, True), 'read upper-cased');
      CheckEquals(1, Length(GLines), 'one line');
      if Length(GLines) = 1 then
         begin
         CheckEquals('MY CALL = NY4I', string(GLines[0]), 'upper-cased when asked');
         end;
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_ALongLineIsCutAt255AndTheNextIsWhole;
var
   path: string;
   long: RawByteString;
   i: integer;
   allX: boolean;
begin
   BeginTest('Test_ALongLineIsCutAt255AndTheNextIsWhole');
   long := '';
   for i := 1 to 300 do
      begin
      long := long + 'x';
      end;
   path := WriteRawFile('tr4w_enumlines_long.txt', long + #13#10'NEXT'#13#10);
   try
      CheckTrue(Enumerate(path, False), 'the file is read');
      CheckEquals(2, Length(GLines), 'still two lines -- the cut does not make a third');
      if Length(GLines) = 2 then
         begin
         CheckEquals(255, Length(GLines[0]), 'a 300-byte line arrives as its first 255');
         allX := True;
         for i := 1 to Length(GLines[0]) do
            begin
            if GLines[0][i] <> 'x' then
               begin
               allX := False;
               end;
            end;
         CheckTrue(allX, 'and they are its bytes');
         CheckEquals('NEXT', string(GLines[1]), 'the next line is whole');
         end;
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_HighBytesArriveUnchanged;
var
   path: string;
   bytes: RawByteString;
begin
   BeginTest('Test_HighBytesArriveUnchanged');
   (* BUILT BYTE BY BYTE: a literal holding #$E9 could be converted through a
     code page on its way to a RawByteString, and then the test would write
     something other than what it checks. *)
   SetLength(bytes, 7);
   bytes[1] := 'A';
   bytes[2] := AnsiChar($E9);
   bytes[3] := AnsiChar($80);
   bytes[4] := AnsiChar($FF);
   bytes[5] := 'Z';
   bytes[6] := AnsiChar(13);
   bytes[7] := AnsiChar(10);
   path := WriteRawFile('tr4w_enumlines_high.txt', bytes);
   try
      CheckTrue(Enumerate(path, False), 'the file is read');
      CheckEquals(1, Length(GLines), 'one line');
      if Length(GLines) = 1 then
         begin
         CheckEquals(5, Length(GLines[0]), 'five bytes');
         if Length(GLines[0]) = 5 then
            begin
            CheckEquals(Ord('A'), Ord(GLines[0][1]), 'byte 1');
            CheckEquals($E9, Ord(GLines[0][2]), 'byte 2, unchanged');
            CheckEquals($80, Ord(GLines[0][3]), 'byte 3, unchanged');
            CheckEquals($FF, Ord(GLines[0][4]), 'byte 4, unchanged');
            CheckEquals(Ord('Z'), Ord(GLines[0][5]), 'byte 5');
            end;
         end;
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_AnEditDoesNotReachTheNextLine;
var
   path: string;
begin
   BeginTest('Test_AnEditDoesNotReachTheNextLine');
   path := WriteRawFile('tr4w_enumlines_edit.txt', 'ABCDEFGH'#13#10'XY'#13#10'LONGER LINE'#13#10);
   GEditEachLine := True;
   try
      CheckTrue(Enumerate(path, False), 'the file is read');
      CheckEquals(3, Length(GLines), 'three lines');
      if Length(GLines) = 3 then
         begin
         CheckEquals('ABCDEFGH', string(GLines[0]), 'the first line as written');
         CheckEquals('XY', string(GLines[1]), 'a shorter line after an edited one carries none of it');
         CheckEquals('LONGER LINE', string(GLines[2]), 'nor does a longer one');
         end;
   finally
      GEditEachLine := False;
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_AMissingOrEmptyFileDeliversNothing;
var
   path: string;
begin
   BeginTest('Test_AMissingOrEmptyFileDeliversNothing');
   path := TestFilePath('tr4w_enumlines_no_such_file.txt');
   DeleteFile(path);
   CheckFalse(Enumerate(path, False), 'a missing file answers False');
   CheckEquals(0, Length(GLines), 'and delivers nothing');

   path := WriteRawFile('tr4w_enumlines_empty.txt', '');
   try
      CheckFalse(Enumerate(path, False), 'an empty file answers False');
      CheckEquals(0, Length(GLines), 'and delivers nothing');
   finally
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.Test_HelloDatBuildsTheGreetingList;
var
   path: string;
   savedFirst, savedLast: HelloRecPtr;
   rec, nextRec: HelloRecPtr;
   count: integer;
begin
   BeginTest('Test_HelloDatBuildsTheGreetingList');
   savedFirst := FirstHelloRecord;
   savedLast := LastHelloRecord;
   FirstHelloRecord := nil;
   LastHelloRecord := nil;
   (* As LoadSpecialHelloFile asks: upper case. Leading and trailing blanks
     around the ID and the greeting go; the record's fields are string[6]. *)
   path := WriteRawFile('tr4w_hello_test.dat',
                        '  dl   guten tag  '#13#10'F BONJOURS'#13#10'abcdefgh HI'#13#10);
   try
      CheckTrue(EnumerateLinesInFile(path, EnumHelloDAT, True), 'the file is read');

      count := 0;
      rec := FirstHelloRecord;
      while rec <> nil do
         begin
         Inc(count);
         rec := rec^.NextRecord;
         end;
      CheckEquals(3, count, 'one record a line, in file order');

      rec := FirstHelloRecord;
      if rec <> nil then
         begin
         CheckEquals('DL', string(rec^.ID), 'the ID is the first word, upper-cased');
         CheckEquals('GUTEN ', string(rec^.Greeting), 'the greeting is the rest, trimmed, cut to six');
         rec := rec^.NextRecord;
         end;
      if rec <> nil then
         begin
         CheckEquals('F', string(rec^.ID), 'second ID');
         CheckEquals('BONJOU', string(rec^.Greeting), 'second greeting, cut to six');
         rec := rec^.NextRecord;
         end;
      if rec <> nil then
         begin
         CheckEquals('ABCDEF', string(rec^.ID), 'an ID is cut to six');
         CheckEquals('HI', string(rec^.Greeting), 'third greeting');
         CheckTrue(rec = LastHelloRecord, 'the last record is the list''s tail');
         end;
   finally
      rec := FirstHelloRecord;
      while rec <> nil do
         begin
         nextRec := rec^.NextRecord;
         Dispose(rec);
         rec := nextRec;
         end;
      FirstHelloRecord := savedFirst;
      LastHelloRecord := savedLast;
      DeleteFile(path);
   end;
end;

procedure TEnumerateLinesTests.RunAllTests;
begin
   Test_LinesEndAtCRAndLFAndBlankLinesAreSkipped;
   Test_TheLastLineNeedsNoBreak;
   Test_UpperCaseIsTheCallersChoice;
   Test_ALongLineIsCutAt255AndTheNextIsWhole;
   Test_HighBytesArriveUnchanged;
   Test_AnEditDoesNotReachTheNextLine;
   Test_AMissingOrEmptyFileDeliversNothing;
   Test_HelloDatBuildsTheGreetingList;
end;

end.
