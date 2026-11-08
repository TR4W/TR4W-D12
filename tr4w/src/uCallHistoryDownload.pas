unit uCallHistoryDownload;
{$I tr4w.inc}

(* DOWNLOADING A CONTEST'S CALL HISTORY FILE from supercheckhistory.com
  (NY4I, 2026-11-08; the design is in the planning notes, and the site's rules
  in the supercheckhistory-download-rules memory).

  THE SITE'S RULES ARE THIS UNIT'S SAFETY RULES:
    * MANUAL ONLY. Nothing here is called from a timer, from opening a
      contest or from a QSO. The one caller is the Help menu item.
    * A CONDITIONAL GET. The ETag and Last-Modified the last download
      returned are kept beside the file (<file>.meta) and sent back; the
      server answers 304 when nothing changed. A file on disk that does not
      match its sidecar (edited by hand, or no sidecar) sends no condition.
    * IDENTIFIED: the User-Agent is TR4W/<version>.

  THE FILE IS NEVER LEFT WORSE THAN IT WAS. The body goes to <file>.tmp, is
  validated (not a web page, a sane size, enough rows that the contest can
  read, not far smaller than the file it replaces) and only then replaces the
  old file in ONE step. On ANY failure the old file and its sidecar are
  untouched and no .tmp is left.

  THREADING. RunCallHistoryDownload is synchronous and reads nothing but its
  arguments: the main thread builds a TCallHistoryDownloadJob (it reads the
  contest, which is not thread-safe here) and the worker thread only gets
  plain values. The in-flight flag is main-thread only.

  This unit has no window and no contest: the caller says which site file,
  which fields and where to write. *)

interface

uses
   Classes, SysUtils, uCallHistory,
   uContestBase;   (* TContestBase -- NewCallHistoryJob's parameter. *)

const
   (* The N1MM library folder on the site. A contest's file is
     <this><CallHistorySiteName>.txt. *)
   CALL_HISTORY_SITE_URL = 'https://supercheckhistory.com/downloads/N1MM/';

   (* SANITY THRESHOLDS -- unattended defaults (2026-11-08), for NY4I to rule on.
     They exist because a captive portal, a proxy or a site error page answers
     200 with HTML, and a half file is not a call history.
     200 bytes: smaller is not a call history. 20 MB: the largest N1MM library
     file is a few hundred KB, so this is a runaway. 20 rows: fewer cannot be a
     running's file. 50 %: of the rows with a call, at least this share must
     give the contest what it prefills. 50 %: the new file may not hold fewer
     than this share of the rows of the file it replaces. *)
   CALL_HISTORY_MIN_BYTES        = 200;
   CALL_HISTORY_MAX_BYTES        = 20 * 1024 * 1024;
   CALL_HISTORY_MIN_ROWS         = 20;
   CALL_HISTORY_MIN_YIELD_PERCENT = 50;
   CALL_HISTORY_MIN_KEPT_PERCENT  = 50;

type
   TCallHistoryDownloadOutcome = (
      chdUpdated,        (* a new file is in place *)
      chdCurrent,        (* 304: the copy held is current *)
      chdNotAvailable,   (* 404: the site has no file for this contest *)
      chdRefused,        (* the server answered another status *)
      chdFailed);        (* no answer, or the file was not acceptable; old file kept *)

   (* WHAT TO DOWNLOAD, as plain values. A class (not a record) per this tree's
     rule; the caller fills it on the main thread. *)
   TCallHistoryDownloadJob = class
   public
      SiteName:   string;               (* the site's file stem: 'ARRL-SS-CW' *)
      TargetFile: string;               (* the full path of the file to write *)
      Fields:     TCallHistoryFields;   (* a COPY of what the contest prefills *)
      BaseUrl:    string;               (* CALL_HISTORY_SITE_URL; a test points it elsewhere *)
      UserAgent:  string;               (* TR4W/<version> *)
      constructor Create;
   end;

   TCallHistoryDownloadResult = class
   public
      Outcome:  TCallHistoryDownloadOutcome;
      Entries:  integer;     (* chdUpdated: the rows that give the contest a prefill *)
      FileDate: string;      (* chdUpdated: the UTC date, yyyy-mm-dd *)
      Status:   integer;     (* the HTTP status when there was one *)
      Reason:   string;      (* chdFailed: a sentence fragment *)
      TargetFile: string;    (* the file written (chdUpdated) *)
      (* THE OPERATOR'S MESSAGE for the outcome. *)
      function MessageText: string;
   end;

   TCallHistoryDownloadDoneEvent = procedure(Sender: TObject;
                                             aResult: TCallHistoryDownloadResult) of object;

(* THE DOWNLOAD FOR A CONTEST, as plain values: its site file, a copy of the
  fields it prefills and where the file goes -- the writable CallHistoryFiles
  folder (uAppPaths.DownloadedDataFilePath), which uCallHistory.CallHistoryFilePath
  finds first -- under the contest's own default name. NIL when the contest has
  no site file (CallHistorySiteName = ''). MAIN THREAD ONLY: the contest is not
  thread-safe here; hand the job to DownloadCallHistoryAsync and the worker never
  sees the contest. The caller owns the job until then. *)
function NewCallHistoryJob(aContest: TContestBase): TCallHistoryDownloadJob;

(* The URL of a site file, or '' when the base or the name is not usable. The
  name must be only letters, digits, '-' and '_' : it becomes a URL path. *)
function CallHistoryDownloadURL(const aBaseUrl, aSiteName: string): string;

(* THE SIDECAR: <aTargetFile>.meta. *)
function CallHistoryMetaPath(const aTargetFile: string): string;

(* The conditional-GET validators held for aTargetFile. False (both ''), and so
  an UNCONDITIONAL GET, unless the file is on disk, the sidecar reads, and the
  size the sidecar recorded is the file's size (a hand-edited file must not
  be answered 'not modified'). *)
function ReadCallHistoryMeta(const aTargetFile: string;
                             out aETag, aLastModified: string): boolean;

(* Write the sidecar (its own temp + replace). False when it could not be. *)
function WriteCallHistoryMeta(const aTargetFile, aETag, aLastModified: string;
                              aSize: Int64): boolean;

(* THE ACCEPTANCE TEST for a downloaded file, before it replaces anything.
  aContentType is the response's ('' when unknown). aOldRows is the rows with a
  call in the file it would replace (0 when there is none). aRows is the rows
  with a call; aGood those that give aFields a prefill. False with aReason (a
  sentence fragment) when the file is not acceptable. *)
function ValidateCallHistoryFile(const aPath, aContentType: string;
                                 const aFields: TCallHistoryFields;
                                 aOldRows: integer;
                                 out aRows, aGood: integer;
                                 out aReason: string): boolean;

(* The rows with a call in a call history file; 0 when it cannot be read. *)
function CountCallHistoryRows(const aPath: string): integer;

(* REPLACE aTarget WITH aSource IN ONE STEP, the old file never absent.
  Windows: MoveFileEx with MOVEFILE_REPLACE_EXISTING -- SysUtils.RenameFile
  fails when the target exists there, and deleting first opens a window with no
  file. Unix: rename(2), which replaces atomically. *)
function ReplaceFileAtomic(const aSource, aTarget: string): boolean;

(* THE WHOLE DOWNLOAD, synchronously, on the calling thread. Never raises.
  aResult is filled. This is what the worker runs and what the tests drive. *)
procedure RunCallHistoryDownload(aJob: TCallHistoryDownloadJob;
                                 aResult: TCallHistoryDownloadResult);

(* THE ASYNC FORM, for the Help menu. MAIN THREAD ONLY. Returns False (and
  does nothing) while a download is already running. aJob is owned by the
  thread from here on. aOnDone is raised on the main thread; the result is
  valid only during the call. *)
function DownloadCallHistoryAsync(aJob: TCallHistoryDownloadJob;
                                  const aOnDone: TCallHistoryDownloadDoneEvent): boolean;

(* Is a download running? Main thread only. *)
function CallHistoryDownloadRunning: boolean;

implementation

uses
   {$IFDEF WINDOWS}
   Windows,
   {$ENDIF}
   DateUtils,
   Log4D,
   Version,
   uAppPaths,   (* DownloadedDataFilePath *)
   uHTTPDownload,
   uAppStrings;

{$IFDEF WINDOWS}
const
   (* MOVEFILE_WRITE_THROUGH: the FPC Windows unit declares only
     MOVEFILE_REPLACE_EXISTING. The move is flushed before the call returns. *)
   MOVEFILE_WRITE_THROUGH_FLAG = $00000008;
{$ENDIF}

var
   (* Own logger, not MainUnit's global: this unit is linked by tests. *)
   logger: TLogLogger;
   (* Main thread only. *)
   GRunning: boolean = False;

constructor TCallHistoryDownloadJob.Create;
begin
   inherited Create;
   BaseUrl   := CALL_HISTORY_SITE_URL;
   UserAgent := 'TR4W/' + TR4W_CURRENTVERSION_NUMBER;
end;

function TCallHistoryDownloadResult.MessageText: string;
begin
   case Outcome of
      chdUpdated:
         begin
         Result := UnicodeFormat(SCallHistoryUpdated, [Entries, FileDate]);
         end;
      chdCurrent:
         begin
         Result := SCallHistoryCurrent;
         end;
      chdNotAvailable:
         begin
         Result := SCallHistoryNotAvailable;
         end;
      chdRefused:
         begin
         Result := UnicodeFormat(SCallHistoryRefused, [Status]);
         end;
   else
      begin
      Result := UnicodeFormat(SCallHistoryFailed, [Reason]);
      end;
   end;
end;

function NewCallHistoryJob(aContest: TContestBase): TCallHistoryDownloadJob;
var
   fileName: string;
begin
   Result   := nil;
   fileName := aContest.CallHistoryFileName;
   if (aContest.CallHistorySiteName = '') or (fileName = '') then
      begin
      Exit;
      end;
   Result := TCallHistoryDownloadJob.Create;
   Result.SiteName   := aContest.CallHistorySiteName;
   Result.Fields     := Copy(aContest.CallHistoryFields);
   Result.TargetFile := DownloadedDataFilePath(CALL_HISTORY_FOLDER + PathDelim + fileName);
end;

function CallHistoryDownloadURL(const aBaseUrl, aSiteName: string): string;
var
   i: integer;
begin
   Result := '';
   if (aBaseUrl = '') or (aSiteName = '') then
      begin
      Exit;
      end;
   for i := 1 to Length(aSiteName) do
      begin
      if not (aSiteName[i] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then
         begin
         Exit;
         end;
      end;
   Result := aBaseUrl + aSiteName + '.txt';
end;

function CallHistoryMetaPath(const aTargetFile: string): string;
begin
   Result := aTargetFile + '.meta';
end;

(* A file's size, -1 when it is not there or cannot be opened. *)
function SizeOfFile(const aPath: string): Int64;
var
   stream: TFileStream;
begin
   Result := -1;
   if not FileExists(aPath) then
      begin
      Exit;
      end;
   try
      stream := TFileStream.Create(AnsiString(aPath), fmOpenRead or fmShareDenyNone);
      try
         Result := stream.Size;
      finally
         stream.Free;
      end;
   except
      Result := -1;
   end;
end;

procedure DeleteQuietly(const aPath: string);
begin
   if FileExists(aPath) then
      begin
      SysUtils.DeleteFile(aPath);
      end;
end;

function ReplaceFileAtomic(const aSource, aTarget: string): boolean;
begin
   {$IFDEF WINDOWS}
   (* A RAW KERNEL32 CALL, JUSTIFIED: the RTL has no replace-existing. RenameFile
     is MoveFile on Windows and fails when the target exists, and the other
     RTL way (delete, then rename) leaves a window with no file at all. This
     is kernel32, not a new DLL binding: the Windows unit declares it. *)
   Result := MoveFileExW(PWideChar(aSource), PWideChar(aTarget),
                         MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH_FLAG);
   {$ELSE}
   (* rename(2) replaces an existing target atomically. *)
   Result := RenameFile(aSource, aTarget);
   {$ENDIF}
end;

function ReadCallHistoryMeta(const aTargetFile: string;
                             out aETag, aLastModified: string): boolean;
var
   lines: TStringList;
   size:  Int64;
begin
   Result        := False;
   aETag         := '';
   aLastModified := '';
   size := SizeOfFile(aTargetFile);
   if size < 0 then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      try
         lines.LoadFromFile(AnsiString(CallHistoryMetaPath(aTargetFile)));
      except
         Exit;
      end;
      (* etag, last-modified, fetched-at UTC (for a human), size. *)
      if lines.Count < 4 then
         begin
         Exit;
         end;
      if StrToInt64Def(Trim(lines[3]), -1) <> size then
         begin
         Exit;
         end;
      if (Trim(lines[0]) = '') and (Trim(lines[1]) = '') then
         begin
         Exit;
         end;
      aETag         := Trim(lines[0]);
      aLastModified := Trim(lines[1]);
      Result := True;
   finally
      lines.Free;
   end;
end;

function WriteCallHistoryMeta(const aTargetFile, aETag, aLastModified: string;
                              aSize: Int64): boolean;
var
   lines: TStringList;
   path, tmp: string;
begin
   Result := False;
   path := CallHistoryMetaPath(aTargetFile);
   tmp  := path + '.tmp';
   lines := TStringList.Create;
   try
      (* The AnsiString casts are this tree's way of stating a TStringList /
        TFileStream boundary (their signatures are AnsiString in FPC 3.2.2); the
        text is ASCII validators and a date. *)
      lines.Add(AnsiString(aETag));
      lines.Add(AnsiString(aLastModified));
      lines.Add(AnsiString(FormatDateTime('yyyy-mm-dd hh:nn:ss', LocalTimeToUniversal(Now)) + ' UTC'));
      lines.Add(IntToStr(aSize));
      try
         lines.SaveToFile(AnsiString(tmp));
         Result := ReplaceFileAtomic(tmp, path);
      except
         Result := False;
      end;
   finally
      lines.Free;
      DeleteQuietly(tmp);
   end;
end;

(* THE FIRST NON-BLANK BYTE OF THE FILE, past a UTF-8 byte-order mark; #0 when
  there is none. *)
function FirstSignificantByte(const aPath: string): AnsiChar;
var
   stream: TFileStream;
   buffer: array[0..4095] of AnsiChar;
   got, i: integer;
begin
   Result := #0;
   try
      stream := TFileStream.Create(AnsiString(aPath), fmOpenRead or fmShareDenyNone);
      try
         got := stream.Read(buffer, SizeOf(buffer));
      finally
         stream.Free;
      end;
   except
      Exit;
   end;
   i := 0;
   if (got >= 3) and (buffer[0] = #$EF) and (buffer[1] = #$BB) and (buffer[2] = #$BF) then
      begin
      i := 3;
      end;
   while i < got do
      begin
      if not (buffer[i] in [#9, #10, #13, ' ']) then
         begin
         Result := buffer[i];
         Exit;
         end;
      Inc(i);
      end;
end;

function CountCallHistoryRows(const aPath: string): integer;
var
   lines:  TStringList;
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
   i:      integer;
begin
   Result := 0;
   lines  := TStringList.Create;
   reader := TCallHistoryReader.Create;
   try
      if not ReadCallHistoryLines(aPath, lines) then
         begin
         Exit;
         end;
      for i := 0 to lines.Count - 1 do
         begin
         if reader.ReadLine(lines[i], values) then
            begin
            Inc(Result);
            end;
         end;
   finally
      reader.Free;
      lines.Free;
   end;
end;

function ValidateCallHistoryFile(const aPath, aContentType: string;
                                 const aFields: TCallHistoryFields;
                                 aOldRows: integer;
                                 out aRows, aGood: integer;
                                 out aReason: string): boolean;
var
   size:   Int64;
   lines:  TStringList;
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
   text:   string;
   i:      integer;
begin
   Result  := False;
   aRows   := 0;
   aGood   := 0;
   aReason := '';

   size := SizeOfFile(aPath);
   if size < CALL_HISTORY_MIN_BYTES then
      begin
      aReason := SCallHistoryReasonTooSmall;
      Exit;
      end;
   if size > CALL_HISTORY_MAX_BYTES then
      begin
      aReason := SCallHistoryReasonTooLarge;
      Exit;
      end;
   (* A WEB PAGE, by header or by its first byte: a portal or an error page that
     answered 200. *)
   if (Pos('html', LowerCase(aContentType)) > 0) or (FirstSignificantByte(aPath) = '<') then
      begin
      aReason := SCallHistoryReasonHtml;
      Exit;
      end;

   lines  := TStringList.Create;
   reader := TCallHistoryReader.Create;
   try
      if not ReadCallHistoryLines(aPath, lines) then
         begin
         aReason := SCallHistoryReasonTooSmall;
         Exit;
         end;
      (* COUNTED HERE, NOT BY ReadAll: its store is a plain function, so a
        count would need a global, and this runs on a worker thread. *)
      for i := 0 to lines.Count - 1 do
         begin
         if reader.ReadLine(lines[i], values) then
            begin
            Inc(aRows);
            if CallHistoryExchangeText(values, aFields, text) then
               begin
               Inc(aGood);
               end;
            end;
         end;
   finally
      reader.Free;
      lines.Free;
   end;

   if (aRows < CALL_HISTORY_MIN_ROWS) or
      (aGood * 100 < aRows * CALL_HISTORY_MIN_YIELD_PERCENT) then
      begin
      aReason := SCallHistoryReasonTooFewRows;
      Exit;
      end;
   if (aOldRows > 0) and (aRows * 100 < aOldRows * CALL_HISTORY_MIN_KEPT_PERCENT) then
      begin
      aReason := SCallHistoryReasonSmaller;
      Exit;
      end;
   Result := True;
end;

procedure RunCallHistoryDownload(aJob: TCallHistoryDownloadJob;
                                 aResult: TCallHistoryDownloadResult);
var
   url, tmp, etag, modified, newETag, newModified, ctype, reason: string;
   status, rows, good, oldRows: integer;
   outcome: TConditionalDownloadOutcome;
   size: Int64;
begin
   aResult.Outcome    := chdFailed;
   aResult.Entries    := 0;
   aResult.FileDate   := '';
   aResult.Status     := 0;
   aResult.Reason     := '';
   aResult.TargetFile := aJob.TargetFile;

   url := CallHistoryDownloadURL(aJob.BaseUrl, aJob.SiteName);
   if (url = '') or (aJob.TargetFile = '') then
      begin
      aResult.Reason := SCallHistoryNoSource;
      logger.Warn('[CallHistory] no download: site "%s", target "%s"',
                  [aJob.SiteName, aJob.TargetFile]);
      Exit;
      end;

   tmp := aJob.TargetFile + '.tmp';
   try
      try
         ForceDirectories(ExtractFilePath(aJob.TargetFile));

         (* A CONDITION ONLY FOR A FILE THAT IS ON DISK AND UNEDITED. *)
         etag     := '';
         modified := '';
         ReadCallHistoryMeta(aJob.TargetFile, etag, modified);

         logger.Info('[CallHistory] GET %s (If-None-Match "%s", If-Modified-Since "%s")',
                     [url, etag, modified]);
         outcome := DownloadFileConditional(url, tmp, aJob.UserAgent, etag, modified,
                                            newETag, newModified, ctype, status, reason);
         aResult.Status := status;

         case outcome of
            cdoNotModified:
               begin
               aResult.Outcome := chdCurrent;
               logger.Info('[CallHistory] %s is current (304)', [aJob.TargetFile]);
               end;
            cdoNotFound:
               begin
               aResult.Outcome := chdNotAvailable;
               logger.Info('[CallHistory] the site has no %s (404)', [url]);
               end;
            cdoHttpError:
               begin
               aResult.Outcome := chdRefused;
               logger.Warn('[CallHistory] %s answered HTTP %d; the previous file was kept',
                           [url, status]);
               end;
            cdoTransportFail:
               begin
               aResult.Outcome := chdFailed;
               aResult.Reason  := reason;
               logger.Warn('[CallHistory] %s failed (%s); the previous file was kept',
                           [url, reason]);
               end;
         else
            begin
            (* 200: the body is in the .tmp. NOTHING IS REPLACED UNTIL IT PASSES. *)
            oldRows := 0;
            if FileExists(aJob.TargetFile) then
               begin
               oldRows := CountCallHistoryRows(aJob.TargetFile);
               end;
            if not ValidateCallHistoryFile(tmp, ctype, aJob.Fields, oldRows,
                                           rows, good, reason) then
               begin
               aResult.Outcome := chdFailed;
               aResult.Reason  := reason;
               logger.Warn('[CallHistory] the download was not kept: %s (%d rows, %d usable, %d in the old file)',
                           [reason, rows, good, oldRows]);
               end
            else
               begin
               size := SizeOfFile(tmp);
               if not ReplaceFileAtomic(tmp, aJob.TargetFile) then
                  begin
                  aResult.Outcome := chdFailed;
                  aResult.Reason  := SCallHistoryReasonWrite;
                  logger.Error('[CallHistory] could not replace %s', [aJob.TargetFile]);
                  end
               else
                  begin
                  aResult.Outcome  := chdUpdated;
                  aResult.Entries  := good;
                  aResult.FileDate := FormatDateTime('yyyy-mm-dd', LocalTimeToUniversal(Now));
                  if not WriteCallHistoryMeta(aJob.TargetFile, newETag, newModified, size) then
                     begin
                     (* The old sidecar describes the OLD file; its size check
                       would normally refuse it, but do not rely on that. *)
                     DeleteQuietly(CallHistoryMetaPath(aJob.TargetFile));
                     logger.Warn('[CallHistory] the sidecar for %s could not be written; the next download will be unconditional',
                                 [aJob.TargetFile]);
                     end;
                  logger.Info('[CallHistory] %s updated: %d rows, %d usable (ETag %s)',
                              [aJob.TargetFile, rows, good, newETag]);
                  end;
               end;
            end;
         end;
      except
         on E: Exception do
            begin
            aResult.Outcome := chdFailed;
            aResult.Reason  := E.Message;
            logger.Error('[CallHistory] %s: %s', [E.ClassName, E.Message]);
            end;
      end;
   finally
      (* NEVER LEAVE A .tmp. *)
      DeleteQuietly(tmp);
   end;
end;

(* ---- the worker thread: the shape of uTRMasterUpdate ------------------------ *)

type
   TCallHistoryDownloadThread = class(TThread)
   private
      FJob:    TCallHistoryDownloadJob;
      FResult: TCallHistoryDownloadResult;
      FOnDone: TCallHistoryDownloadDoneEvent;
      procedure ReportDone(Sender: TObject);
   protected
      procedure Execute; override;
   public
      constructor Create(aJob: TCallHistoryDownloadJob;
                         const aOnDone: TCallHistoryDownloadDoneEvent);
      destructor Destroy; override;
   end;

constructor TCallHistoryDownloadThread.Create(aJob: TCallHistoryDownloadJob;
                                              const aOnDone: TCallHistoryDownloadDoneEvent);
begin
   inherited Create(True);
   FJob    := aJob;
   FResult := TCallHistoryDownloadResult.Create;
   FOnDone := aOnDone;
   OnTerminate     := ReportDone;
   FreeOnTerminate := True;
end;

destructor TCallHistoryDownloadThread.Destroy;
begin
   FResult.Free;
   FJob.Free;
   inherited Destroy;
end;

procedure TCallHistoryDownloadThread.Execute;
begin
   RunCallHistoryDownload(FJob, FResult);
end;

(* TThread.OnTerminate is raised through Synchronize by the RTL, so this runs on
  the main thread: the flag is cleared there, and the event is handed the result. *)
procedure TCallHistoryDownloadThread.ReportDone(Sender: TObject);
begin
   GRunning := False;
   if Assigned(FOnDone) then
      begin
      FOnDone(Self, FResult);
      end;
end;

function DownloadCallHistoryAsync(aJob: TCallHistoryDownloadJob;
                                  const aOnDone: TCallHistoryDownloadDoneEvent): boolean;
var
   thread: TCallHistoryDownloadThread;
begin
   if GRunning then
      begin
      aJob.Free;
      Result := False;
      Exit;
      end;
   GRunning := True;
   thread := TCallHistoryDownloadThread.Create(aJob, aOnDone);
   thread.Start;
   Result := True;
end;

function CallHistoryDownloadRunning: boolean;
begin
   Result := GRunning;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.CallHistory');

end.
