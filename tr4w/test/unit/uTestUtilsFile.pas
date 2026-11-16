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
      procedure Test_ReportFile_AbandonedKeepsTheOldFile;
      procedure Test_ReportFile_AnUnrelatedFailedWriteDoesNotFailIt;
      procedure Test_ReportFile_TwoReportsFailIndependently;
      procedure Test_ReportFile_AFailedReplaceKeepsTheOldFile;
{$IFDEF WINDOWS}
      procedure Test_ReportFile_AFileHeldOpenIsNotLostWhenItCannotBeReplaced;
{$ENDIF}
      procedure Test_ReportText_WritesWhatATextFileWrites;
      procedure Test_ReportText_FailuresAreReportedAndKeepTheOldFile;
      (* The whole file as bytes -- FileText reads only the first 4 KB. *)
      function FileTextWhole(const aName: string): AnsiString;

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

function TUtilsFileTests.FileTextWhole(const aName: string): AnsiString;
var
   h    : THandle;
   size : Int64;
   got  : Integer;
begin
   Result := '';
   h := FileOpen(aName, fmOpenRead or fmShareDenyNone);
   if h = THandle(-1) then
      begin
      Exit;
      end;
   try
      size := sFileSize(h);
      SetLength(Result, size);
      got := 0;
      if size > 0 then
         begin
         got := FileRead(h, Result[1], size);
         end;
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
      CheckEquals('', ReportFileProblem(h), 'no problem was recorded');

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
      CheckTrue(ReportFileProblem(h) <> '', 'and the reason is recorded');
      CheckFalse(CloseReportFile(h, True), 'the report is not kept');
      CheckTrue(ReportFileProblem(h) <> '', 'and the reason is still there after the close');
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
   CheckTrue(ReportFileProblem(h) <> '', 'with a reason');
end;

(* ISSUE 313 (a): THE FAILURE BELONGS TO THE REPORT'S HANDLE. A write that fails
  to some OTHER file -- here a closed one, as an unrelated log or settings write
  can -- neither fails the report nor is blamed on it. *)
procedure TUtilsFileTests.Test_ReportFile_AnUnrelatedFailedWriteDoesNotFailIt;
var
   target : string;
   h      : THandle;
   other  : THandle;
begin
   BeginTest('Test_ReportFile_AnUnrelatedFailedWriteDoesNotFailIt');
   target := UniqueTempFileName('tr4wreport');
   try
      CheckTrue(OpenReportFile(h, target), 'opens');
      sWriteFileFromString(h, 'complete');
      other := FileCreate(UniqueTempFileName('tr4wother'));
      FileClose(other);
      CheckFalse(sWriteFileFromString(other, 'lost'), 'a write to some other closed file fails');
      CheckEquals('', ReportFileProblem(h), 'and is not the report''s problem');
      CheckTrue(CloseReportFile(h, True), 'the report is kept');
      CheckEquals('complete', string(FileText(target)), 'whole');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

(* TWO REPORTS OPEN AT ONCE FAIL INDEPENDENTLY: the one whose handle fails is
  not kept, the other is, and each says its own reason. *)
procedure TUtilsFileTests.Test_ReportFile_TwoReportsFailIndependently;
var
   a, b     : string;
   ha, hb   : THandle;
begin
   BeginTest('Test_ReportFile_TwoReportsFailIndependently');
   a := UniqueTempFileName('tr4wreporta');
   b := UniqueTempFileName('tr4wreportb');
   try
      CheckTrue(OpenReportFile(ha, a), 'the first opens');
      CheckTrue(OpenReportFile(hb, b), 'the second opens');
      FileClose(ha);
      CheckFalse(sWriteFileFromString(ha, 'lost'), 'the first''s write fails');
      CheckTrue(sWriteFileFromString(hb, 'fine'), 'the second''s write succeeds');
      CheckTrue(ReportFileProblem(ha) <> '', 'the first has a reason');
      CheckEquals('', ReportFileProblem(hb), 'the second has none');
      CheckTrue(CloseReportFile(hb, True), 'the second is kept');
      CheckFalse(CloseReportFile(ha, True), 'the first is not');
      CheckEquals('fine', string(FileText(b)), 'the second''s file is whole');
      CheckFalse(FileExists(a), 'and the first''s target was never made');
      CheckFalse(FileExists(a + '.partial'), 'with no partial file');
   finally
      SysUtils.DeleteFile(a);
      SysUtils.DeleteFile(a + '.partial');
      SysUtils.DeleteFile(b);
      SysUtils.DeleteFile(b + '.partial');
   end;
end;

(* ISSUE 313 (b): THE OLD FILE IS REPLACED IN ONE OPERATION, so when that fails
  it is still there. The replace is made to fail by making the target a
  non-empty FOLDER, which no platform's rename lets a file replace: the folder
  and what is in it survive, the report is not kept, a reason is recorded, and
  the partial file is gone. (The earlier delete-then-rename could not even
  try: it deleted what it could and lost the rest.) *)
procedure TUtilsFileTests.Test_ReportFile_AFailedReplaceKeepsTheOldFile;
var
   target : string;
   inner  : string;
   h      : THandle;
begin
   BeginTest('Test_ReportFile_AFailedReplaceKeepsTheOldFile');
   target := UniqueTempFileName('tr4wreportdir');
   SysUtils.DeleteFile(target);
   inner := IncludeTrailingPathDelimiter(target) + 'old.txt';
   try
      CheckTrue(ForceDirectories(target), 'the stand-in for the old file is made');
      h := FileCreate(inner);
      sWriteFileFromString(h, 'old');
      FileClose(h);

      CheckTrue(OpenReportFile(h, target), 'the report opens');
      sWriteFileFromString(h, 'new');
      CheckFalse(CloseReportFile(h, True), 'a replace that cannot happen is not a kept report');
      CheckTrue(ReportFileProblem(h) <> '', 'and says why');
      CheckEquals('old', string(FileText(inner)), 'what was at the target is untouched');
      CheckFalse(FileExists(target + '.partial'), 'and the partial file is removed');
   finally
      SysUtils.DeleteFile(inner);
      RemoveDir(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

{$IFDEF WINDOWS}
(* THE SAME ON WINDOWS WITH A REAL FILE: the old report is open in a viewer
  that shares nothing, so it cannot be replaced. The old bytes are still
  there afterwards, the report says it was not kept, and nothing is left over. *)
procedure TUtilsFileTests.Test_ReportFile_AFileHeldOpenIsNotLostWhenItCannotBeReplaced;
var
   target : string;
   h      : THandle;
   held   : THandle;
begin
   BeginTest('Test_ReportFile_AFileHeldOpenIsNotLostWhenItCannotBeReplaced');
   target := UniqueTempFileName('tr4wreport');
   try
      CheckTrue(OpenReportFile(h, target), 'opens');
      sWriteFileFromString(h, 'old report');
      CheckTrue(CloseReportFile(h, True), 'the old report is kept');

      held := FileOpen(target, fmOpenRead or fmShareExclusive);
      CheckTrue(held <> THandle(-1), 'a viewer holds it with no sharing');
      try
         CheckTrue(OpenReportFile(h, target), 'the new report opens');
         sWriteFileFromString(h, 'new report');
         CheckFalse(CloseReportFile(h, True), 'it cannot replace the held file');
         CheckTrue(ReportFileProblem(h) <> '', 'and says why');
      finally
         FileClose(held);
      end;
      CheckEquals('old report', string(FileText(target)), 'the old report is intact');
      CheckFalse(FileExists(target + '.partial'), 'and the partial file is removed');

      (* And once the viewer lets go, the same report replaces it. *)
      CheckTrue(OpenReportFile(h, target), 'opens again');
      sWriteFileFromString(h, 'new report');
      CheckTrue(CloseReportFile(h, True), 'now it is kept');
      CheckEquals('new report', string(FileText(target)), 'and it replaced the old one');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;
{$ENDIF}

(* THE TEXT-FILE FORM, for the reports written with Write / WriteLn. Its bytes
  are what a Text file to the target gave: the RTL formats them, the checked
  handle takes them, and past the RTL's 256-byte buffer too. *)
procedure TUtilsFileTests.Test_ReportText_WritesWhatATextFileWrites;
var
   target   : string;
   t        : Text;
   i        : integer;
   expected : string;
begin
   BeginTest('Test_ReportText_WritesWhatATextFileWrites');
   target := UniqueTempFileName('tr4wtext');
   try
      CheckTrue(OpenReportText(t, target), 'the text report opens');
      CheckFalse(FileExists(target), 'nothing is at the target until the end');
      expected := '';
      for i := 1 to 300 do
         begin
         WriteLn(t, i:5, ' line ', 'x');
         expected := expected + Format('%5d line x', [i]) + LineEnding;
         end;
      Write(t, ' ');
      expected := expected + ' ';
      CheckTrue(CloseReportText(t, True), 'it is kept');
      CheckEquals(Length(expected), Length(FileTextWhole(target)), 'its length is what WriteLn gave');
      CheckEquals(expected, string(FileTextWhole(target)), 'and its bytes');
      CheckFalse(FileExists(target + '.partial'), 'no partial file is left');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

(* A TEXT REPORT THAT CANNOT BE WRITTEN: the handle under it fails, the close
  says so, and the old file is still there. Abandoning one keeps the old file
  too, and a folder that is not there is refused with a reason. *)
procedure TUtilsFileTests.Test_ReportText_FailuresAreReportedAndKeepTheOldFile;
var
   target : string;
   t      : Text;
   h      : TFileHandle;
begin
   BeginTest('Test_ReportText_FailuresAreReportedAndKeepTheOldFile');
   target := UniqueTempFileName('tr4wtext');
   try
      CheckTrue(OpenReportText(t, target), 'opens');
      Write(t, 'good');
      CheckTrue(CloseReportText(t, True), 'the good report is kept');

      CheckTrue(OpenReportText(t, target), 'opens again');
      (* The device keeps its handle in the TextRec; closing it under the
        report is the failure -- the same one the file-handle tests use. *)
      h := TextReportHandle(t);
      FileClose(h);
      WriteLn(t, 'lost, and long enough to be written when the text is closed');
      CheckFalse(CloseReportText(t, True), 'the failed report is not kept');
      CheckTrue(ReportTextProblem(t) <> '', 'and says why');
      CheckEquals('good', string(FileTextWhole(target)), 'the previous good file is still there');
      CheckFalse(FileExists(target + '.partial'), 'and the partial file is removed');

      CheckTrue(OpenReportText(t, target), 'opens a third time');
      Write(t, 'half');
      CheckFalse(CloseReportText(t, False), 'an abandoned report is not kept');
      CheckEquals('good', string(FileTextWhole(target)), 'the good file is still there');

      CheckFalse(OpenReportText(t, UniqueTempFileName('tr4wnone') + '.nodir' +
                                   PathDelim + 'x.txt'), 'a missing folder is refused');
      CheckTrue(ReportTextProblem(t) <> '', 'with a reason');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

(* An export that cannot go on is abandoned: the partial file goes, the old one
  stays, and nothing is reported as written. *)
procedure TUtilsFileTests.Test_ReportFile_AbandonedKeepsTheOldFile;
var
   target : string;
   h      : THandle;
begin
   BeginTest('Test_ReportFile_AbandonedKeepsTheOldFile');
   target := UniqueTempFileName('tr4wreport');
   try
      CheckTrue(OpenReportFile(h, target), 'opens');
      sWriteFileFromString(h, 'good');
      CheckTrue(CloseReportFile(h, True), 'the good report is kept');

      CheckTrue(OpenReportFile(h, target), 'opens again');
      sWriteFileFromString(h, 'half');
      CheckFalse(CloseReportFile(h, False), 'an abandoned report is not kept');
      CheckEquals('good', string(FileText(target)), 'the previous good file is still there');
      CheckFalse(FileExists(target + '.partial'), 'and the partial file is removed');
   finally
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.partial');
   end;
end;

procedure TUtilsFileTests.RunAllTests;
begin
   Test_ReportFile_AbandonedKeepsTheOldFile;
   Test_ReportFile_KeptOnlyWhenComplete;
   Test_ReportFile_FailedWriteKeepsTheOldFile;
   Test_ReportFile_UnopenableFolderSaysWhy;
   Test_ReportFile_AnUnrelatedFailedWriteDoesNotFailIt;
   Test_ReportFile_TwoReportsFailIndependently;
   Test_ReportFile_AFailedReplaceKeepsTheOldFile;
{$IFDEF WINDOWS}
   Test_ReportFile_AFileHeldOpenIsNotLostWhenItCannotBeReplaced;
{$ENDIF}
   Test_ReportText_WritesWhatATextFileWrites;
   Test_ReportText_FailuresAreReportedAndKeepTheOldFile;
   Test_LongString_NoTruncationOrGarbage;
   Test_BoundaryLengths_255_256_257;
   Test_ShortString;
   Test_EmptyString_WritesNothing;
end;

end.
