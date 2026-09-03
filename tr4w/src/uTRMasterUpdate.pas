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
   Windows, Messages, uMainThread;

const

   TRMASTER_DOWNLOAD_URL = 'https://tr4w.net/TRMASTER.DTA';
   // NY4I's own copy, 2026-08-16.  ~3.5 MB.

procedure DownloadTRMasterAsync(const ATargetFile: string; const ACallback: TMainThreadCallback);
// Starts a background thread that downloads TRMASTER.DTA to ATargetFile and
// Hands the result to ACallback on the main thread.

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
      FCallback: TMainThreadCallback;
   protected
      procedure Execute; override;
   public
      constructor Create(const ATargetFile: string; const ACallback: TMainThreadCallback);
   end;

constructor TTRMasterDownloadThread.Create(const ATargetFile: string;
   const ACallback: TMainThreadCallback);
begin
   inherited Create(True);  // suspended; caller calls Resume
   FTargetFile     := ATargetFile;
   FCallback := ACallback;
   FreeOnTerminate := True;
end;

procedure TTRMasterDownloadThread.Execute;
begin
   if DownloadTRMasterFile(FTargetFile) then
      begin
      RunOnMainThread(FCallback, 1);
      end
   else
      begin
      RunOnMainThread(FCallback, 0);
      end;
end;

procedure DownloadTRMasterAsync(const ATargetFile: string; const ACallback: TMainThreadCallback);
var
   Thread: TTRMasterDownloadThread;
begin
   logger.Info('[TRMaster] downloading to %s', [ATargetFile]);
   Thread := TTRMasterDownloadThread.Create(ATargetFile, ACallback);
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
