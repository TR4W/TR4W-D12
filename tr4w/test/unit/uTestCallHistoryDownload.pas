(* THE CALL HISTORY DOWNLOAD -- uCallHistoryDownload, 2026-11-08.

  NO TEST HERE EVER REACHES supercheckhistory.com. Every download runs through
  a TFakeHttpTransport (SetHttpTransportForTest) and a job whose BaseUrl is an
  https://*.invalid name, so a transport that were NOT the fake would fail to
  resolve rather than touch the site. The real fetch is a bench item.

  WHAT IS PINNED:
    * the URL builder and the site name it will not accept;
    * the sidecar: written, read back, and IGNORED when the file was edited by
      hand, is missing, or the sidecar is;
    * the acceptance test: a web page (by header, by first byte, behind a BOM),
      too small, too large, too few rows, too low a yield, much smaller than
      the file it would replace -- and a good file;
    * the replace: over an existing file, and into none;
    * the whole run: 200 then 304 with the conditions sent from the sidecar;
      and for EVERY failure (HTML, empty, truncated, smaller, 404, 429, no
      answer) the old file and its sidecar are byte-identical afterwards and
      no .tmp is left;
    * the contest's side: the job for Sweepstakes, none for a contest with no
      site file, and the legacy file SSCW.txt still read when the new name is
      absent. *)
unit uTestCallHistoryDownload;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCallHistoryDownloadTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_UrlBuilder;
      procedure Test_SidecarRoundTripAndInvalidation;
      procedure Test_Validation;
      procedure Test_ReplaceFileAtomic;
      procedure Test_RunUpdatesThenIsCurrent;
      procedure Test_EveryFailureKeepsTheOldFile;
      procedure Test_NoSiteNameMakesNoRequest;
      procedure Test_JobForTheContest;
      procedure Test_LegacyFileStillLoads;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uHttpTransport,
   uTestFakeTransport,
   uSettingsRegistry,
   uSettingsDeclarations,
   uSettingsModel,
   uCallHistory,
   uCallHistoryDownload,
   uCallsigns,
   uContestBase,
   uContestRegistry,
   uAppPaths,
   uAppStrings,
   Version,
   (* Contest -- the session's contest handle. *)
   PostUnit,
   LogDupe,
   MainUnit;

const
   SITE   = 'ARRL-SS-CW';
   BASE   = 'https://callhistory.invalid/downloads/N1MM/';

(* ---- helpers -------------------------------------------------------------------- *)

function SweepstakesFieldList: TCallHistoryFields;
begin
   SetLength(Result, 2);
   Result[0] := chfCK;
   Result[1] := chfSect;
end;

(* N SWEEPSTAKES ROWS in the order Call,Sect,State,CK,Exch1: every one complete. *)
function GoodText(aRows: integer; const aTag: string): string;
var
   i: integer;
begin
   Result := '!!Order!!,Call,Sect,State,CK,Exch1,'#13#10 +
             '# ' + aTag + #13#10;
   for i := 1 to aRows do
      begin
      Result := Result + 'W1A' + IntToStr(i) + ',CT,CT,80,'#13#10;
      end;
end;

procedure WriteFile(const aPath, aText: string);
var
   stream: TFileStream;
   bytes: RawByteString;
begin
   bytes := ToWire(aText);
   stream := TFileStream.Create(aPath, fmCreate);
   try
      if bytes <> '' then
         begin
         stream.WriteBuffer(bytes[1], Length(bytes));
         end;
   finally
      stream.Free;
   end;
end;

function ReadFileBytes(const aPath: string): RawByteString;
var
   stream: TFileStream;
begin
   Result := '';
   if not FileExists(aPath) then
      begin
      Exit;
      end;
   stream := TFileStream.Create(aPath, fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, stream.Size);
      if stream.Size > 0 then
         begin
         stream.ReadBuffer(Result[1], stream.Size);
         end;
   finally
      stream.Free;
   end;
end;

function NewFolder: string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4w-chd-' +
             IntToStr(Random(100000000)) + PathDelim;
   ForceDirectories(Result);
end;

procedure RemoveFolder(const aFolder: string);
begin
   SysUtils.DeleteFile(aFolder + SITE + '.txt');
   SysUtils.DeleteFile(aFolder + SITE + '.txt.meta');
   SysUtils.DeleteFile(aFolder + SITE + '.txt.meta.tmp');
   SysUtils.DeleteFile(aFolder + SITE + '.txt.tmp');
   SysUtils.DeleteFile(aFolder + 'a.txt');
   SysUtils.DeleteFile(aFolder + 'b.txt');
   SysUtils.DeleteFile(aFolder + 'big.txt');
   RemoveDir(aFolder);
end;

function NewJob(const aTarget: string): TCallHistoryDownloadJob;
begin
   Result := TCallHistoryDownloadJob.Create;
   Result.SiteName   := SITE;
   Result.TargetFile := aTarget;
   Result.Fields     := SweepstakesFieldList;
   Result.BaseUrl    := BASE;
end;

procedure DeclareVerifyOn;
var
   setting: TSettingBase;
begin
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
end;

(* ---- the pure parts ------------------------------------------------------------ *)

procedure TCallHistoryDownloadTests.Test_UrlBuilder;
begin
   BeginTest('Test_UrlBuilder');
   CheckEquals('https://supercheckhistory.com/downloads/N1MM/ARRL-SS-CW.txt',
               CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, 'ARRL-SS-CW'), 'the site URL');
   CheckEquals('', CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, ''), 'no name: no URL');
   CheckEquals('', CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, '../x'), 'a path is refused');
   CheckEquals('', CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, 'A B'), 'a blank is refused');
   CheckEquals('', CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, 'A?b=1'), 'a query is refused');
   CheckEquals('', CallHistoryDownloadURL('', 'ARRL-SS-CW'), 'no base: no URL');
   CheckEquals('https://', Copy(CALL_HISTORY_SITE_URL, 1, 8), 'the site is https');
end;

procedure TCallHistoryDownloadTests.Test_SidecarRoundTripAndInvalidation;
var
   folder, target, etag, modified: string;
begin
   BeginTest('Test_SidecarRoundTripAndInvalidation');
   folder := NewFolder;
   target := folder + SITE + '.txt';
   try
      WriteFile(target, GoodText(30, 'one'));
      CheckFalse(ReadCallHistoryMeta(target, etag, modified), 'no sidecar: no condition');
      CheckEquals('', etag, 'and no ETag');

      CheckTrue(WriteCallHistoryMeta(target, '"abc"', 'Sat, 01 Nov 2025 00:00:00 GMT',
                                     Length(ReadFileBytes(target))), 'written');
      CheckFalse(FileExists(target + '.meta.tmp'), 'no sidecar temp left');
      CheckTrue(ReadCallHistoryMeta(target, etag, modified), 'read back');
      CheckEquals('"abc"', etag, 'ETag');
      CheckEquals('Sat, 01 Nov 2025 00:00:00 GMT', modified, 'Last-Modified');

      (* A HAND-EDITED FILE: the size no longer matches, so no condition. *)
      WriteFile(target, GoodText(30, 'one') + '# edited'#13#10);
      CheckFalse(ReadCallHistoryMeta(target, etag, modified), 'an edited file ignores the sidecar');
      CheckEquals('', etag, 'no ETag for an edited file');
      CheckEquals('', modified, 'no date for an edited file');

      (* THE FILE IS GONE: never send a condition for a file that is not there. *)
      WriteFile(target, GoodText(30, 'one'));
      CheckTrue(ReadCallHistoryMeta(target, etag, modified), 'the same size again reads');
      SysUtils.DeleteFile(target);
      CheckFalse(ReadCallHistoryMeta(target, etag, modified), 'no file: no condition');

      (* A BROKEN SIDECAR. *)
      WriteFile(target, GoodText(30, 'one'));
      WriteFile(target + '.meta', 'only one line');
      CheckFalse(ReadCallHistoryMeta(target, etag, modified), 'a short sidecar is ignored');
   finally
      SysUtils.DeleteFile(target + '.meta');
      RemoveFolder(folder);
   end;
end;

procedure TCallHistoryDownloadTests.Test_Validation;
var
   folder, path, reason: string;
   rows, good: integer;
   stream: TFileStream;
   fields: TCallHistoryFields;
begin
   BeginTest('Test_Validation');
   folder := NewFolder;
   path   := folder + 'a.txt';
   fields := SweepstakesFieldList;
   try
      WriteFile(path, GoodText(40, 'good'));
      CheckTrue(ValidateCallHistoryFile(path, 'text/plain', fields, 0, rows, good, reason),
                'a good file: ' + reason);
      CheckEquals(40, rows, 'rows with a call');
      CheckEquals(40, good, 'rows that prefill');
      CheckTrue(ValidateCallHistoryFile(path, '', fields, 40, rows, good, reason),
                'the same size as the old file is fine');

      CheckFalse(ValidateCallHistoryFile(path, 'text/html; charset=utf-8', fields, 0, rows, good, reason),
                 'an HTML Content-Type');
      CheckTrue(reason <> '', 'with a reason');

      WriteFile(path, '<!DOCTYPE html><html><body>' + StringOfChar('x', 400) + '</body></html>');
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'a web page by its first byte');
      WriteFile(path, #$EF#$BB#$BF#13#10'  <html>' + StringOfChar('x', 400));
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'a web page behind a BOM and blanks');

      WriteFile(path, '');
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'an empty file');
      WriteFile(path, 'W1AW,CT,CT,80,');
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'under the size floor');

      (* TOO LARGE: one byte over the cap. *)
      path := folder + 'big.txt';
      stream := TFileStream.Create(path, fmCreate);
      try
         stream.Size := CALL_HISTORY_MAX_BYTES + 1;
      finally
         stream.Free;
      end;
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'over the size cap');
      SysUtils.DeleteFile(path);

      path := folder + 'a.txt';
      WriteFile(path, GoodText(CALL_HISTORY_MIN_ROWS - 1, 'few') + StringOfChar('#', 200));
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'under the row floor');

      (* TOO LOW A YIELD: rows with a call that give no section. *)
      WriteFile(path, '!!Order!!,Call,Sect,State,CK,Exch1,'#13#10 + StringOfChar('#', 200) + #13#10 +
                      'W1A1,CT,CT,80,'#13#10'W1A2,CT,CT,80,'#13#10'W1A3,CT,CT,80,'#13#10 +
                      'W1A4,,,,'#13#10'W1A5,,,,'#13#10'W1A6,,,,'#13#10'W1A7,,,,'#13#10'W1A8,,,,'#13#10 +
                      'W1A9,,,,'#13#10'W1A10,,,,'#13#10'W1A11,,,,'#13#10'W1A12,,,,'#13#10 +
                      'W1A13,,,,'#13#10'W1A14,,,,'#13#10'W1A15,,,,'#13#10'W1A16,,,,'#13#10 +
                      'W1A17,,,,'#13#10'W1A18,,,,'#13#10'W1A19,,,,'#13#10'W1A20,,,,'#13#10 +
                      'W1A21,,,,'#13#10'W1A22,,,,'#13#10'W1A23,,,,'#13#10'W1A24,,,,'#13#10);
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 0, rows, good, reason), 'a poor yield');
      CheckEquals(24, rows, 'its rows');
      CheckEquals(3, good, 'its usable rows');

      (* MUCH SMALLER THAN THE FILE IT REPLACES. *)
      WriteFile(path, GoodText(40, 'small'));
      CheckFalse(ValidateCallHistoryFile(path, '', fields, 100, rows, good, reason),
                 'fewer than half the old rows');
      CheckTrue(ValidateCallHistoryFile(path, '', fields, 80, rows, good, reason),
                'exactly half the old rows is kept: ' + reason);

      CheckEquals(40, CountCallHistoryRows(path), 'CountCallHistoryRows');
      CheckEquals(0, CountCallHistoryRows(folder + 'nothere.txt'), 'a missing file counts 0');
   finally
      RemoveFolder(folder);
   end;
end;

procedure TCallHistoryDownloadTests.Test_ReplaceFileAtomic;
var
   folder: string;
begin
   BeginTest('Test_ReplaceFileAtomic');
   folder := NewFolder;
   try
      WriteFile(folder + 'a.txt', 'new');
      WriteFile(folder + 'b.txt', 'old');
      CheckTrue(ReplaceFileAtomic(folder + 'a.txt', folder + 'b.txt'), 'over an existing file');
      CheckEquals('new', string(ReadFileBytes(folder + 'b.txt')), 'the target holds the new text');
      CheckFalse(FileExists(folder + 'a.txt'), 'the source is gone');

      SysUtils.DeleteFile(folder + 'b.txt');
      WriteFile(folder + 'a.txt', 'again');
      CheckTrue(ReplaceFileAtomic(folder + 'a.txt', folder + 'b.txt'), 'into no file');
      CheckEquals('again', string(ReadFileBytes(folder + 'b.txt')), 'the target holds it');

      CheckFalse(ReplaceFileAtomic(folder + 'nothere.txt', folder + 'b.txt'), 'a missing source fails');
      CheckEquals('again', string(ReadFileBytes(folder + 'b.txt')), 'and the target is untouched');
   finally
      RemoveFolder(folder);
   end;
end;

(* ---- the whole run, over the fake transport ------------------------------------- *)

procedure TCallHistoryDownloadTests.Test_RunUpdatesThenIsCurrent;
var
   fake: TFakeHttpTransport;
   folder, target: string;
   job: TCallHistoryDownloadJob;
   res: TCallHistoryDownloadResult;
   first, etag, modified: string;
begin
   BeginTest('Test_RunUpdatesThenIsCurrent');
   DeclareVerifyOn;
   folder := NewFolder;
   target := folder + SITE + '.txt';
   fake := TFakeHttpTransport.Create;
   res := TCallHistoryDownloadResult.Create;
   SetHttpTransportForTest(fake);
   try
      (* 1. NO FILE: an unconditional GET; the file, its sidecar, no .tmp. *)
      first := GoodText(40, 'first');
      fake.ScriptStatus       := 200;
      fake.ScriptBody         := ToWire(first);
      fake.ScriptETag         := '"e1"';
      fake.ScriptLastModified := 'Sat, 01 Nov 2025 00:00:00 GMT';
      fake.ScriptContentType  := 'text/plain';
      job := NewJob(target);
      try
         RunCallHistoryDownload(job, res);
      finally
         job.Free;
      end;
      CheckTrue(res.Outcome = chdUpdated, 'first: updated');
      CheckEquals(40, res.Entries, 'first: 40 entries');
      CheckEquals(10, Length(res.FileDate), 'first: a yyyy-mm-dd date');
      CheckEquals(BASE + SITE + '.txt', fake.Last.URL, 'the URL asked');
      CheckEquals('TR4W/' + TR4W_CURRENTVERSION_NUMBER, fake.Last.UserAgent, 'identified');
      CheckEquals('', fake.Last.IfNoneMatch, 'no file: no If-None-Match');
      CheckEquals('', fake.Last.IfModifiedSince, 'no file: no If-Modified-Since');
      CheckEquals(first, string(ReadFileBytes(target)), 'the file is the body');
      CheckFalse(FileExists(target + '.tmp'), 'no .tmp');
      CheckTrue(ReadCallHistoryMeta(target, etag, modified), 'a sidecar is there and matches');
      CheckEquals('"e1"', etag, 'with the ETag');
      CheckEquals('Sat, 01 Nov 2025 00:00:00 GMT', modified, 'and the date');
      CheckTrue(Pos('updated', LowerCase(res.MessageText)) > 0, 'the message says updated: ' + res.MessageText);

      (* 2. THE SERVER SAYS 304: the conditions went out, nothing changed. *)
      fake.ScriptStatus := 304;
      fake.ScriptBody   := '';
      job := NewJob(target);
      try
         RunCallHistoryDownload(job, res);
      finally
         job.Free;
      end;
      CheckTrue(res.Outcome = chdCurrent, 'second: current');
      CheckEquals('"e1"', fake.Last.IfNoneMatch, 'the ETag went back');
      CheckEquals('Sat, 01 Nov 2025 00:00:00 GMT', fake.Last.IfModifiedSince, 'and the date');
      CheckEquals(first, string(ReadFileBytes(target)), 'the file is unchanged');
      CheckFalse(FileExists(target + '.tmp'), 'no .tmp');
      CheckEquals(SCallHistoryCurrent, res.MessageText, 'the message');

      (* 3. A NEWER FILE: 200 again replaces the old one and the sidecar. *)
      fake.ScriptStatus := 200;
      fake.ScriptBody   := ToWire(GoodText(45, 'second'));
      fake.ScriptETag   := '"e2"';
      job := NewJob(target);
      try
         RunCallHistoryDownload(job, res);
      finally
         job.Free;
      end;
      CheckTrue(res.Outcome = chdUpdated, 'third: updated');
      CheckEquals('"e1"', fake.Last.IfNoneMatch, 'the held ETag was sent');
      CheckEquals(45, res.Entries, 'third: 45 entries');
      CheckTrue(ReadCallHistoryMeta(target, etag, modified), 'the sidecar follows the new file');
      CheckEquals('"e2"', etag, 'with the new ETag');

      (* 4. A HAND-EDITED FILE: no condition is sent. *)
      WriteFile(target, GoodText(45, 'second') + '# my note'#13#10);
      job := NewJob(target);
      try
         RunCallHistoryDownload(job, res);
      finally
         job.Free;
      end;
      CheckEquals('', fake.Last.IfNoneMatch, 'an edited file: no If-None-Match');
      CheckEquals('', fake.Last.IfModifiedSince, 'an edited file: no If-Modified-Since');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      res.Free;
      RemoveFolder(folder);
   end;
end;

procedure TCallHistoryDownloadTests.Test_EveryFailureKeepsTheOldFile;
type
   TCase = (cHtml, cEmpty, cTruncated, cSmaller, c404, c429, c503, cNoAnswer, cBadType);
var
   fake: TFakeHttpTransport;
   folder, target, oldText, oldMeta, why: string;
   job: TCallHistoryDownloadJob;
   res: TCallHistoryDownloadResult;
   which: TCase;
begin
   BeginTest('Test_EveryFailureKeepsTheOldFile');
   DeclareVerifyOn;
   folder := NewFolder;
   target := folder + SITE + '.txt';
   oldText := GoodText(100, 'old');
   WriteFile(target, oldText);
   CheckTrue(WriteCallHistoryMeta(target, '"old"', 'Fri, 31 Oct 2025 00:00:00 GMT', Length(oldText)),
             'a sidecar for the old file');
   oldMeta := string(ReadFileBytes(target + '.meta'));
   fake := TFakeHttpTransport.Create;
   res := TCallHistoryDownloadResult.Create;
   SetHttpTransportForTest(fake);
   try
      for which := Low(TCase) to High(TCase) do
         begin
         fake.ScriptFailure := hfNone;
         fake.ScriptStatus  := 200;
         fake.ScriptETag    := '"new"';
         fake.ScriptContentType := 'text/plain';
         fake.ScriptBody    := ToWire(GoodText(100, 'new'));
         case which of
            cHtml:
               begin
               fake.ScriptBody := ToWire('<html><body>Sign in to the network ' + StringOfChar('x', 400) + '</body></html>');
               why := 'an HTML page with a 200';
               end;
            cBadType:
               begin
               fake.ScriptContentType := 'text/html';
               why := 'a good body under an HTML Content-Type';
               end;
            cEmpty:
               begin
               fake.ScriptBody := '';
               why := 'an empty body';
               end;
            cTruncated:
               begin
               fake.ScriptBody := ToWire(GoodText(5, 'cut'));
               why := 'a truncated file';
               end;
            cSmaller:
               begin
               fake.ScriptBody := ToWire(GoodText(30, 'smaller'));
               why := 'a file far smaller than the old one';
               end;
            c404:
               begin
               fake.ScriptStatus := 404;
               fake.ScriptBody   := ToWire('<html>not found</html>');
               why := '404';
               end;
            c429:
               begin
               fake.ScriptStatus := 429;
               fake.ScriptBody   := ToWire('slow down');
               why := '429';
               end;
            c503:
               begin
               fake.ScriptStatus := 503;
               fake.ScriptBody   := ToWire('<html>down</html>');
               why := '503';
               end;
            cNoAnswer:
               begin
               fake.ScriptStatus       := 0;
               fake.ScriptFailure      := hfConnectionLost;
               fake.ScriptErrorMessage := 'connection lost';
               why := 'no answer';
               end;
         end;
         job := NewJob(target);
         try
            RunCallHistoryDownload(job, res);
         finally
            job.Free;
         end;
         CheckTrue(res.Outcome <> chdUpdated, why + ': not updated');
         CheckEquals(oldText, string(ReadFileBytes(target)), why + ': the old file is byte-identical');
         CheckEquals(oldMeta, string(ReadFileBytes(target + '.meta')), why + ': the old sidecar is byte-identical');
         CheckFalse(FileExists(target + '.tmp'), why + ': no .tmp');
         CheckFalse(FileExists(target + '.meta.tmp'), why + ': no sidecar temp');
         CheckEquals('"old"', fake.Last.IfNoneMatch, why + ': the held ETag was sent');
         CheckTrue(res.MessageText <> '', why + ': the operator hears something');

         case which of
            c404:
               begin
               CheckTrue(res.Outcome = chdNotAvailable, '404 is not available');
               end;
            c429, c503:
               begin
               CheckTrue(res.Outcome = chdRefused, why + ' is refused');
               CheckTrue(res.Status = fake.ScriptStatus, why + ' keeps its status');
               end;
            cNoAnswer:
               begin
               CheckTrue(res.Outcome = chdFailed, 'no answer fails');
               CheckEquals('connection lost', res.Reason, 'with the reason');
               end;
         else
            begin
            CheckTrue(res.Outcome = chdFailed, why + ' fails');
            CheckTrue(res.Reason <> '', why + ' says why');
            end;
         end;
         end;
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      res.Free;
      RemoveFolder(folder);
   end;
end;

procedure TCallHistoryDownloadTests.Test_NoSiteNameMakesNoRequest;
var
   fake: TFakeHttpTransport;
   folder: string;
   job: TCallHistoryDownloadJob;
   res: TCallHistoryDownloadResult;
begin
   BeginTest('Test_NoSiteNameMakesNoRequest');
   DeclareVerifyOn;
   folder := NewFolder;
   fake := TFakeHttpTransport.Create;
   res := TCallHistoryDownloadResult.Create;
   SetHttpTransportForTest(fake);
   try
      job := NewJob(folder + SITE + '.txt');
      try
         job.SiteName := '';
         RunCallHistoryDownload(job, res);
      finally
         job.Free;
      end;
      CheckTrue(res.Outcome = chdFailed, 'no site name: failed');
      CheckEquals(0, fake.Calls, 'and nothing was requested');
      CheckFalse(FileExists(folder + SITE + '.txt.tmp'), 'no .tmp');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      res.Free;
      RemoveFolder(folder);
   end;
end;

(* ---- the contest's side ---------------------------------------------------------- *)

procedure TCallHistoryDownloadTests.Test_JobForTheContest;
var
   job: TCallHistoryDownloadJob;
begin
   BeginTest('Test_JobForTheContest');
   begin
      job := NewCallHistoryJob(ContestIdentity(ContestHandleOf(ARRLSSCW)));
      CheckTrue(job <> nil, 'SS CW has a download');
      if job <> nil then
         begin
         try
            CheckEquals('ARRL-SS-CW', job.SiteName, 'the site file');
            CheckEquals(2, Length(job.Fields), 'CK and Sect');
            CheckEquals('ARRL-SS-CW.txt', ExtractFileName(job.TargetFile), 'written under the contest''s own name');
            CheckEquals(CALL_HISTORY_FOLDER, ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(job.TargetFile))),
                        'in the CallHistoryFiles folder');
            CheckEquals(CALL_HISTORY_SITE_URL, job.BaseUrl, 'from the site');
            CheckEquals('TR4W/' + TR4W_CURRENTVERSION_NUMBER, job.UserAgent, 'identified');
         finally
            job.Free;
         end;
         end;

      job := NewCallHistoryJob(ContestIdentity(ContestHandleOf(ARRLSSSSB)));
      CheckTrue(job <> nil, 'SS SSB has a download');
      if job <> nil then
         begin
         CheckEquals('ARRL-SS-SSB', job.SiteName, 'its site file');
         job.Free;
         end;

      job := NewCallHistoryJob(ContestIdentity(ContestHandleOf(CQWWCW)));
      CheckTrue(job = nil, 'CQ WW has none');
      if job <> nil then
         begin
         job.Free;
         end;
   end;
end;

(* THE LEGACY FILE STILL LOADS when the new name is absent and the operator named
  nothing. The folder is wherever the lookup resolves a bare name; the test
  creates the file there only when no file of either name is, and removes it. *)
procedure TCallHistoryDownloadTests.Test_LegacyFileStillLoads;
var
   savedList: TCallsignsList;
   savedContest: TContestHandle;
   savedUse: boolean;
   savedName: string;
   legacyPath, newPath, folder: string;
   madeFolder: boolean;
begin
   BeginTest('Test_LegacyFileStillLoads');
   legacyPath := CallHistoryFilePath('SSCW.txt');
   newPath    := CallHistoryFilePath('ARRL-SS-CW.txt');
   if FileExists(legacyPath) or FileExists(newPath) then
      begin
      (* Somebody's real file is where the test would write: leave it alone. *)
      CheckTrue(True, 'skipped: a call history file is already there');
      Exit;
      end;
   folder := ExtractFilePath(legacyPath);
   madeFolder := not DirectoryExists(folder);
   ForceDirectories(folder);
   savedList := CallsignsList;
   savedContest := Contest;
   savedUse := Settings.Contest.UseCallHistoryFile;
   savedName := Settings.Contest.CallHistoryFilename;
   CallsignsList := TCallsignsList.Create;
   try
      WriteFile(legacyPath, GoodText(30, 'legacy'));
      Contest := ContestHandleOf(ARRLSSCW);
      Settings.Contest.UseCallHistoryFile := True;
      Settings.Contest.CallHistoryFilename := '';
      CheckEquals(30, LoadCallHistoryFile, 'the legacy file is read when the new name is absent');
      CheckEquals('80 CT', CallsignsList.GetIniitialExchange('W1A1'), 'and prefills');

      (* THE NEW NAME WINS once it exists. *)
      CallsignsList.Free;
      CallsignsList := TCallsignsList.Create;
      WriteFile(newPath, GoodText(12, 'new'));
      CheckEquals(12, LoadCallHistoryFile, 'the site-named file wins');
   finally
      SysUtils.DeleteFile(newPath);
      SysUtils.DeleteFile(legacyPath);
      if madeFolder then
         begin
         RemoveDir(folder);
         end;
      CallsignsList.Free;
      CallsignsList := savedList;
      Contest := savedContest;
      Settings.Contest.UseCallHistoryFile := savedUse;
      Settings.Contest.CallHistoryFilename := savedName;
   end;
end;

procedure TCallHistoryDownloadTests.RunAllTests;
begin
   Test_UrlBuilder;
   Test_SidecarRoundTripAndInvalidation;
   Test_Validation;
   Test_ReplaceFileAtomic;
   Test_RunUpdatesThenIsCurrent;
   Test_EveryFailureKeepsTheOldFile;
   Test_NoSiteNameMakesNoRequest;
   Test_JobForTheContest;
   Test_LegacyFileStillLoads;
end;

end.
