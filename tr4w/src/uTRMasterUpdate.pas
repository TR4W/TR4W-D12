unit uTRMasterUpdate;
{$I tr4w.inc}
{
  TRMASTER.DTA download -- the Super Check Partial database.

  Shape deliberately mirrors uCTYUpdate: an async form that posts a completion
  message to a window, and a synchronous form for callers that have no window
  and no message loop yet (a first-run wizard, or startup).

  WHAT THIS UNIT DOES NOT DO: load the file.  The caller's completion handler
  does (uMainWindowProc, TRMasterDownloadFinished -> CD.ReplaceTRMasterFile),
  which builds a snapshot of the new file and swaps it in -- no restart.
}

interface

uses
   Version;

const

   (* Stable data address, independent of the installed application version.
     The endpoint inventory probes https://tr4w.github.io/TRMASTER.DTA and
     the legacy mirror https://tr4w.net/TRMASTER.DTA. *)
   TRMASTER_DOWNLOAD_URL = TR4W_DATA_SITE + '/TRMASTER.DTA';
   TRMASTER_FALLBACK_URL = TR4W_WEBSITE + '/TRMASTER.DTA';

type
   (* Raised ON THE MAIN THREAD when the download finishes. *)
   TTRMasterDownloadDoneEvent = procedure(Sender: TObject;
                                          aSucceeded: boolean) of object;

procedure DownloadTRMasterAsync(const ATargetFile: string;
                                const aOnDone: TTRMasterDownloadDoneEvent);
// Starts a background thread that downloads TRMASTER.DTA to ATargetFile and
// raises aOnDone on the main thread when it finishes.

function DownloadTRMasterFile(const ATargetFile: string): boolean;
// Synchronous: downloads on the CALLING thread and returns success.
//
// For callers with no window to post to and no message loop to receive it --
// a setup wizard, or a startup check.  Everywhere else prefer the async form:
// this is a multi-megabyte transfer and it will block whatever thread it is on.

implementation

uses
   Classes,
   SysUtils,
   Log4D,
   LogSCP,
   uCallHistoryDownload,
   uHTTPDownload;

var
   // Own logger, not MainUnit's global -- see uHTTPDownload for the reasoning.
   logger: TLogLogger;

type
   TTRMasterDownloadThread = class(TThread)
   private
      FTargetFile: string;
      FSucceeded: boolean;
      FOnDone:    TTRMasterDownloadDoneEvent;
      procedure ReportDone(Sender: TObject);
   protected
      procedure Execute; override;
   public
      constructor Create(const ATargetFile: string;
                         const aOnDone: TTRMasterDownloadDoneEvent);
   end;

constructor TTRMasterDownloadThread.Create(const ATargetFile: string;
   const aOnDone: TTRMasterDownloadDoneEvent);
begin
   inherited Create(True);  // suspended; caller calls Resume
   FTargetFile     := ATargetFile;
   FOnDone         := aOnDone;
   OnTerminate     := ReportDone;
   FreeOnTerminate := True;
end;

procedure TTRMasterDownloadThread.Execute;
begin
   if DownloadTRMasterFile(FTargetFile) then
      begin
      FSucceeded := True;
      end
   else
      begin
      FSucceeded := False;
      end;
end;

(* THE RESULT COMES BACK AS AN EVENT, ON THE MAIN THREAD.

  TThread.OnTerminate is raised through Synchronize by the RTL itself
  (rtl/win/tthread.inc:46-50), so a handler assigned here runs on the main
  thread with nothing else needed -- no queue, no posted message, no window
  handle. The thread stores its result during Execute and the event carries it
  out.

  TYPED, so the caller is handed a boolean or a date rather than an integer
  whose meaning lives in a comment. *)
procedure TTRMasterDownloadThread.ReportDone(Sender: TObject);
begin
   if Assigned(FOnDone) then
      begin
      FOnDone(Self, FSucceeded);
      end;
end;

procedure DownloadTRMasterAsync(const ATargetFile: string;
                                const aOnDone: TTRMasterDownloadDoneEvent);
var
   Thread: TTRMasterDownloadThread;
begin
   logger.Info('[TRMaster] downloading to %s', [ATargetFile]);
   Thread := TTRMasterDownloadThread.Create(ATargetFile, aOnDone);
   Thread.Resume;
end;

function FetchTRMaster(const aURL, aStagedFile: string): boolean;
var
   snapshot: TTRMasterSnapshot;
   why: string;
begin
   Result := False;
   if not DownloadFileToPath(aURL, aStagedFile) then
      begin
      Exit;
      end;
   snapshot := LoadTRMasterSnapshot(aStagedFile, why);
   if snapshot = nil then
      begin
      logger.Warn('[TRMaster] %s returned unusable data: %s', [aURL, why]);
      Exit;
      end;
   snapshot.Free;
   Result := True;
end;

function DownloadTRMasterFile(const ATargetFile: string): boolean;
var
   stageId: TGUID;
   stagedFile: string;
begin
   Result := False;
   stagedFile := '';
   try
      try
         if CreateGUID(stageId) <> 0 then
            begin
            logger.Error('[TRMaster] could not stage data beside %s', [ATargetFile]);
            Exit;
            end;
         stagedFile := ATargetFile + '.' + GUIDToString(stageId) + '.download';
         if not FetchTRMaster(TRMASTER_DOWNLOAD_URL, stagedFile) then
            begin
            logger.Warn('[TRMaster] trying fallback %s', [TRMASTER_FALLBACK_URL]);
            if not FetchTRMaster(TRMASTER_FALLBACK_URL, stagedFile) then
               begin
               Exit;
               end;
            end;
         Result := ReplaceFileAtomic(stagedFile, ATargetFile);
         if Result then
            begin
            logger.Info('[TRMaster] saved %s', [ATargetFile]);
            end
         else
            begin
            logger.Error('[TRMaster] could not replace %s: %s',
                         [ATargetFile, SysErrorMessage(GetLastOSError)]);
            end;
      except
         on E: Exception do
            begin
            logger.Error('[TRMaster] download to %s failed: %s', [ATargetFile, E.Message]);
            end;
      end;
   finally
      if stagedFile <> '' then
         begin
         SysUtils.DeleteFile(stagedFile);
         SysUtils.DeleteFile(stagedFile + '.tmp');
         end;
   end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.TRMaster');

end.
