unit uTRMasterUpdate;
{$I tr4w.inc}
{
  TRMASTER.DTA download -- the Super Check Partial database.

  Shape deliberately mirrors uCTYUpdate: an async form that posts a completion
  message to a window, and a synchronous form for callers that have no window
  and no message loop yet (a first-run wizard, or startup).

  WHAT THIS UNIT DOES NOT DO: reload SCP in the running program.  See
  WM_TRMASTER_DOWNLOAD_DONE's handler in tr4w.lpr for why that is a restart
  rather than a live swap.
}

interface

uses
   Windows, Messages;

const

   TRMASTER_DOWNLOAD_URL = 'https://tr4w.net/TRMASTER.DTA';
   // NY4I's own copy, 2026-08-16.  ~3.5 MB.

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

function DownloadTRMasterFile(const ATargetFile: string): boolean;
begin
   // The URL stays inside this unit: callers name the FILE they want, never the
   // site it comes from.  uHTTPDownload has already logged any failure reason.
   Result := DownloadFileToPath(TRMASTER_DOWNLOAD_URL, ATargetFile);
   if Result then
      begin
      logger.Info('[TRMaster] saved %s', [ATargetFile]);
      end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.TRMaster');

end.
