unit uTestUtilsFile;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for utils_file.sWriteFileFromString.

  Regression net for the v4.147.04 stack-buffer-overflow fix (Issue #887):
  the prior implementation copied its input into a fixed 256-byte stack buffer
  via StrLCopy and then asked WriteFile to write Length(sBuffer) bytes -- so any
  input >= 256 chars wrote 256 valid bytes followed by uninitialized stack data
  (truncation + garbage).  It only mattered once the ADIF export refactor wrote
  a whole document in one call.

  These tests write a string through sWriteFileFromString to a real temp file,
  read the raw bytes back, and assert the file contents match the input exactly
  -- byte count AND content -- across the 256-byte boundary.
}

interface

uses
   SysUtils, uTR4WTestFramework, utils_file;

type
   TUtilsFileTests = class(TTestCase)
   protected
      // Write s via sWriteFileFromString, read the raw file back as a string.
      function RoundTrip(const s: AnsiString): AnsiString;
      function FileText(const aName: string): AnsiString;
      procedure Test_ReportFile_KeptOnlyWhenComplete;
      procedure Test_ReportFile_FailedWriteKeepsTheOldFile;
      procedure Test_ReportFile_UnopenableFolderSaysWhy;

      procedure Test_LongString_NoTruncationOrGarbage;
      procedure Test_BoundaryLengths_255_256_257;
      procedure Test_ShortString;
      procedure Test_EmptyString_WritesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

(* THE RTL'S FILE API, NOT WIN32'S -- and the substitution is not quite
  one-for-one, so the differences are worth stating.

    - GetTempPathW + GetTempFileNameW become GetTempFileName, which does
      both.  The Win32 pair CREATED the file as a side effect; this does not,
      so the write below has to create it -- which FileCreate does anyway.
    - The failure value is -1 (feInvalidHandle), NOT INVALID_HANDLE_VALUE.
      Those are the same bit pattern, but only one of them exists off Windows.
    - FileRead RETURNS the count instead of filling a DWORD var, and returns
      -1 on error where ReadFile returned False.  The test wants the count, so
      a negative result must not become a Length.

  What this test is FOR is unchanged: it asks for more bytes than were
  written, so extra garbage at the tail shows up rather than being clipped. *)
function TUtilsFileTests.RoundTrip(const s: AnsiString): AnsiString;
var
   tmpFile : string;
   h       : THandle;
   buf     : AnsiString;
   got     : Integer;
begin
   Result := '';
   tmpFile := UniqueTempFileName('tr4wutil');

   // Write phase
   h := FileCreate(tmpFile);
   Check(h <> THandle(-1), 'temp file opened for write');
   try
      sWriteFileFromString(h, s);
   finally
      FileClose(h);
   end;

   // Read phase -- request more than we wrote so a length mismatch (extra
   // garbage bytes) would be visible, not silently clipped.
   h := FileOpen(tmpFile, fmOpenRead or fmShareDenyNone);
   Check(h <> THandle(-1), 'temp file opened for read');
   try
      SetLength(buf, Length(s) + 64);
      got := FileRead(h, buf[1], Length(buf));
      if got < 0 then
         begin
         got := 0;   // a read error is an empty result, not a negative length
         end;
      SetLength(buf, got);
      Result := buf;
   finally
      FileClose(h);
      SysUtils.DeleteFile(tmpFile);
   end;
end;

procedure TUtilsFileTests.Test_LongString_NoTruncationOrGarbage;
var
   s, got : string;
   i      : Integer;
begin
   BeginTest('Test_LongString_NoTruncationOrGarbage');
   // 1000 chars -- well past the old 256-byte stack buffer.
   s := '';
   for i := 1 to 1000 do
      s := s + Chr(Ord('A') + (i mod 26));
   got := RoundTrip(s);
   CheckEquals(Length(s), Length(got), 'byte count matches (no truncation, no extra)');
   CheckEquals(s, got, 'content matches exactly past the 256-byte boundary');
end;

procedure TUtilsFileTests.Test_BoundaryLengths_255_256_257;
var
   n : Integer;
   s, got : string;
   i : Integer;
begin
   BeginTest('Test_BoundaryLengths_255_256_257');
   for n := 255 to 257 do
      begin
      s := '';
      for i := 1 to n do
         s := s + Chr(Ord('0') + (i mod 10));
      got := RoundTrip(s);
      CheckEquals(n, Length(got), Format('length %d round-trips', [n]));
      CheckEquals(s, got, Format('content of length %d matches', [n]));
      end;
end;

procedure TUtilsFileTests.Test_ShortString;
var
   got : string;
begin
   BeginTest('Test_ShortString');
   // The historically-safe case (short fragments) must still work.
   got := RoundTrip('<CALL:4>KG1S<EOR>');
   CheckEquals('<CALL:4>KG1S<EOR>', got, 'short string round-trips');
end;

procedure TUtilsFileTests.Test_EmptyString_WritesNothing;
var
   got : string;
begin
   BeginTest('Test_EmptyString_WritesNothing');
   // Empty string: sWriteFileFromString returns True and writes zero bytes.
   got := RoundTrip('');
   CheckEquals(0, Length(got), 'empty string produces a 0-byte file');
end;

function TUtilsFileTests.FileText(const aName: string): AnsiString;
var
   h   : THandle;
   got : Integer;
begin
   Result := '';
   h := FileOpen(aName, fmOpenRead or fmShareDenyNone);
   if h = THandle(-1) then
      begin
      Exit;
      end;
   try
      SetLength(Result, 4096);
      got := FileRead(h, Result[1], Length(Result));
      if got < 0 then
         begin
         got := 0;
         end;
      SetLength(Result, got);
   finally
      FileClose(h);
   end;
end;

(* ISSUE 313: a good report is put in place whole, and the previous file is
  replaced only then. *)
procedure TUtilsFileTests.Test_ReportFile_KeptOnlyWhenComplete;
var
   target : string;
   h      : THandle;
begin
   BeginTest('Test_ReportFile_KeptOnlyWhenComplete');
   target := UniqueTempFileName('tr4wreport');
   try
      CheckTrue(OpenReportFile(h, target), 'the partial file opens');
      CheckFalse(FileExists(target), 'nothing is at the target until the end');
      CheckTrue(sWriteFileFromString(h, 'first'), 'the write succeeds');
      CheckTrue(CloseReportFile(h, True), 'a complete report is kept');
      CheckEquals('first', string(FileText(target)), 'the target holds it');
      CheckFalse(FileExists(target + '.partial'), 'and no partial file is left');
      CheckEquals('', ReportFileProblem, 'no problem was recorded');

      CheckTrue(OpenReportFile(h, target), 'a second report opens');
      CheckEquals('first', string(FileText(target)), 'the old file is untouched while it is written');
      sWriteFileFromString(h, 'second');
      CheckTrue(CloseReportFile(h, True), 'the second is kept');
      CheckEquals('second', string(FileText(target)), 'and replaces the first');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

(* A write that fails leaves the previous good file alone and says why. The
  failure is made by writing through a handle that is already closed. *)
procedure TUtilsFileTests.Test_ReportFile_FailedWriteKeepsTheOldFile;
var
   target : string;
   h      : THandle;
begin
   BeginTest('Test_ReportFile_FailedWriteKeepsTheOldFile');
   target := UniqueTempFileName('tr4wreport');
   try
      CheckTrue(OpenReportFile(h, target), 'opens');
      sWriteFileFromString(h, 'good');
      CheckTrue(CloseReportFile(h, True), 'the good report is kept');

      CheckTrue(OpenReportFile(h, target), 'opens again');
      FileClose(h);
      CheckFalse(sWriteFileFromString(h, 'lost'), 'a write to a closed handle fails');
      CheckTrue(ReportFileProblem <> '', 'and the reason is recorded');
      CheckFalse(CloseReportFile(h, True), 'the report is not kept');
      CheckEquals('good', string(FileText(target)), 'the previous good file is still there');
      CheckFalse(FileExists(target + '.partial'), 'and the partial file is removed');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

(* A folder that does not exist cannot be opened, and the reason is there. *)
procedure TUtilsFileTests.Test_ReportFile_UnopenableFolderSaysWhy;
var
   h : THandle;
begin
   BeginTest('Test_ReportFile_UnopenableFolderSaysWhy');
   CheckFalse(OpenReportFile(h, UniqueTempFileName('tr4wnone') + '.nodir' +
                                PathDelim + 'x.adi'), 'a missing folder is refused');
   CheckTrue(ReportFileProblem <> '', 'with a reason');
end;

procedure TUtilsFileTests.RunAllTests;
begin
   Test_ReportFile_KeptOnlyWhenComplete;
   Test_ReportFile_FailedWriteKeepsTheOldFile;
   Test_ReportFile_UnopenableFolderSaysWhy;
   Test_LongString_NoTruncationOrGarbage;
   Test_BoundaryLengths_255_256_257;
   Test_ShortString;
   Test_EmptyString_WritesNothing;
end;

end.
