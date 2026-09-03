unit uCTYUpdate;
{$I tr4w.inc}
{
  CTY.DAT version check and automatic download.

  Startup: CheckCTYVersionAsync fetches the RSS feed from country-files.com
  on a background thread, compares the date version to the installed file,
  and posts WM_CTY_VERSION_CHECKED(wParam=1, lParam=date) when an update is
  available. The main thread handler shows a QuickDisplay hint.

  Download: DownloadCTYAsync fetches cty.dat on a background thread and
  posts WM_CTY_DOWNLOAD_DONE when done. The main thread handler calls
  ctyLoadInCountryFile to reload — safe because the message handler is a
  quiescent point (CTY tables have no locking).

  Threading model matches uPOTAParks.pas exactly.
}

interface

uses
   Windows, Messages, Classes, SysUtils, IdHTTP, IdSSLOpenSSL, uMainThread;

procedure CheckCTYVersionAsync(const ACallback: TMainThreadCallback);
// Starts a background thread that fetches the RSS feed and compares the
// latest version to the installed CTY.DAT. Posts WM_CTY_VERSION_CHECKED.

procedure DownloadCTYAsync(const ATargetFile: string; const ACallback: TMainThreadCallback);
// Starts a background thread that downloads cty.dat to ATargetFile.
// Hands the result to ACallback on the main thread.

function DownloadCTYFile(const ATargetFile: string): boolean; overload;
// Downloads cty.dat to ATargetFile and returns True on success. SYNCHRONOUS:
// it runs on the calling thread. This is exactly what DownloadCTYAsync's
// thread does, minus the thread and the completion PostMessage.
//
// It exists for the one caller that cannot use the async form: the startup
// country-file check runs BEFORE CreateMainWindow, so there is no window to
// post WM_CTY_DOWNLOAD_DONE to and no message loop to receive it.
//
// PREFER DownloadCTYAsync EVERYWHERE ELSE. Blocking on a network fetch is
// only acceptable at startup because there is no UI yet to freeze.

function DownloadCTYFile(const ATargetFile: string;
                         out AFailReason: string): boolean; overload;
// As above, and hands back WHY it failed so the caller can say so. The startup
// caller has no log in front of the operator; without this it could only guess,
// and it guessed wrong.

function GetInstalledCTYVersion: integer;
// Scans the installed CTY.DAT for the embedded =VER\d{8} version marker
// and returns the date as an integer (e.g. 20260414), or 0 if not found.
// Called from background thread only.

implementation

uses
   MainUnit,
   VC,
   // The atomic HTTPS fetch used to live in this unit as a private helper.  It
   // moved out when TRMASTER.DTA became a second caller -- see uHTTPDownload.
   uHTTPDownload;

const
   CTY_RSS_URL      = 'https://www.country-files.com/feed/';
   CTY_DOWNLOAD_URL = 'https://www.country-files.com/cty/cty.dat';

// ---------------------------------------------------------------------------
// ParseVERDate
//
// Scans S for the pattern 'VER' followed immediately by exactly 8 digits.
// Returns the 8-digit integer (e.g. 20251218) or 0 if not found.
// ---------------------------------------------------------------------------

function ParseVERDate(const S: string): integer;
var
   P: integer;
   I: integer;
   Digits: string;
begin
   Result := 0;
   P := Pos('VER', S);
   if P = 0 then
      begin
      Exit;
      end;
   Inc(P, 3);  // advance past 'VER'
   if (P + 7) > Length(S) then
      begin
      Exit;
      end;
   Digits := '';
   for I := P to P + 7 do
      begin
      if not (S[I] in ['0'..'9']) then
         begin
         Exit;
         end;
      Digits := Digits + S[I];
      end;
   Result := StrToIntDef(Digits, 0);
end;

// ---------------------------------------------------------------------------
// ParseCTYRSS
//
// Extracts version info from the RSS feed XML. Locates the first
// <item><description> block and scans it for:
//   VER\d{8}  — date version integer (e.g. 20251218)
//   CTY-\d+   — numeric build (e.g. 3615, for log display only)
//
// No XML library is needed: the WordPress RSS structure is predictable.
// Returns True if a valid date version was found.
// ---------------------------------------------------------------------------

function ParseCTYRSS(const AXML: string;
   out ALatestDate, ANumericBuild: integer): boolean;
var
   P, I:  integer;
   Sub:   string;
   Digits: string;
begin
   Result        := False;
   ALatestDate   := 0;
   ANumericBuild := 0;

   // Narrow to the substring starting at the first <item>
   P := Pos('<item>', AXML);
   if P = 0 then
      begin
      Exit;
      end;
   Sub := Copy(AXML, P, Length(AXML));

   // Find <description> within that item
   P := Pos('<description>', Sub);
   if P = 0 then
      begin
      Exit;
      end;
   Inc(P, Length('<description>'));
   Sub := Copy(Sub, P, Length(Sub));

   // Trim at closing tag so we don't scan into the next item
   P := Pos('</description>', Sub);
   if P > 0 then
      begin
      Sub := Copy(Sub, 1, P - 1);
      end;

   // Extract VER\d{8} date
   ALatestDate := ParseVERDate(Sub);
   if ALatestDate = 0 then
      begin
      Exit;
      end;

   // Extract CTY-\d+ numeric build (for log display only)
   P := Pos('CTY-', Sub);
   if P > 0 then
      begin
      Inc(P, 4);  // advance past 'CTY-'
      Digits := '';
      I := P;
      while (I <= Length(Sub)) and (Sub[I] in ['0'..'9']) do
         begin
         Digits := Digits + Sub[I];
         Inc(I);
         end;
      ANumericBuild := StrToIntDef(Digits, 0);
      end;

   Result := True;
end;

// ---------------------------------------------------------------------------
// GetInstalledCTYVersion
//
// Scans CTY.DAT line-by-line for the embedded =VER\d{8} version marker.
// Returns the date integer (e.g. 20260414), or 0 if absent or not found.
// ---------------------------------------------------------------------------

function GetInstalledCTYVersion: integer;
var
   F:      TextFile;
   Line:   string;
   P, I:   integer;
   Digits: string;
begin
   Result := 0;
   AssignFile(F, string(PAnsiChar(@TR4W_CTY_FILENAME)));
   {$I-}
   Reset(F);
   {$I+}
   if IOResult <> 0 then
      begin
      Exit;
      end;
   try
      while not EOF(F) do
         begin
         ReadLn(F, Line);
         // Match =VER\d{8} — the '=' prefix makes this unambiguous vs. other
         // occurrences of 'VER' in the file.
         P := Pos('=VER', Line);
         if P = 0 then
            begin
            Continue;
            end;
         Inc(P, 4);  // advance past '=VER'
         if (P + 7) > Length(Line) then
            begin
            Continue;
            end;
         Digits := '';
         for I := P to P + 7 do
            begin
            if not (Line[I] in ['0'..'9']) then
               begin
               Digits := '';
               Break;
               end;
            Digits := Digits + Line[I];
            end;
         if Length(Digits) = 8 then
            begin
            Result := StrToIntDef(Digits, 0);
            if Result > 0 then
               begin
               Exit;
               end;
            end;
         end;
   finally
      CloseFile(F);
   end;
end;

// ---------------------------------------------------------------------------
// Version check thread
// ---------------------------------------------------------------------------

type
   TCTYVersionCheckThread = class(TThread)
   private
      FCallback: TMainThreadCallback;
   protected
      procedure Execute; override;
   public
      constructor Create(const ACallback: TMainThreadCallback);
   end;

constructor TCTYVersionCheckThread.Create(const ACallback: TMainThreadCallback);
begin
   inherited Create(True);  // suspended; caller calls Resume
   FCallback := ACallback;
   FreeOnTerminate := True;
end;

procedure TCTYVersionCheckThread.Execute;
var
   http:          TIdHTTP;
   ssl:           TIdSSLIOHandlerSocketOpenSSL;
   rssXml:        string;
   latestDate:    integer;
   numericBuild:  integer;
   installedDate: integer;
begin
   http := TIdHTTP.Create(nil);
   ssl  := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
   try
      ssl.SSLOptions.Method  := TIdSSLVersion(sslvTLSv1_2);
      http.IOHandler         := ssl;
      http.HandleRedirects   := True;
      http.Request.UserAgent := 'TR4W';

      // Same reasoning as uHTTPDownload's timeouts, less urgently: this one is
      // always on a background thread. But a thread wedged forever in a socket
      // read is still a leaked thread for the life of the process, and this
      // check runs on every startup.  (This is a plain GET of a small feed into
      // a string, not a file fetch, so it does not go through that unit.)
      http.ConnectTimeout := 15000;   // ms
      http.ReadTimeout    := 30000;   // ms

      try
         rssXml := http.Get(CTY_RSS_URL);
         if ParseCTYRSS(rssXml, latestDate, numericBuild) then
            begin
            installedDate := GetInstalledCTYVersion;
            logger.Info('[CTYUpdate] Installed CTY version: %d', [installedDate]);
            logger.Info('[CTYUpdate] Latest CTY version available: %d (CTY-%d)',
               [latestDate, numericBuild]);
            if latestDate > installedDate then
               begin
               logger.Info('[CTYUpdate] Update available — notifying user');
               RunOnMainThread(FCallback, PtrInt(latestDate));
               end
            else
               begin
               logger.Info('[CTYUpdate] CTY is up to date');
               RunOnMainThread(FCallback, 0);   (* nothing newer *)
               end;
            end
         else
            begin
            logger.Warn('[CTYUpdate] Failed to parse RSS feed');
            RunOnMainThread(FCallback, 0);   (* nothing newer *)
            end;
      except
         on E: Exception do
            begin
            logger.Error('[CTYUpdate] Version check failed: %s', [E.Message]);
            RunOnMainThread(FCallback, 0);   (* nothing newer *)
            end;
      end;
   finally
      http.Free;
      ssl.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Download thread
// ---------------------------------------------------------------------------

type
   TCTYDownloadThread = class(TThread)
   private
      FTargetFile: string;
      FCallback: TMainThreadCallback;
   protected
      procedure Execute; override;
   public
      constructor Create(const ATargetFile: string; const ACallback: TMainThreadCallback);
   end;

constructor TCTYDownloadThread.Create(const ATargetFile: string;
   const ACallback: TMainThreadCallback);
begin
   inherited Create(True);  // suspended; caller calls Resume
   FTargetFile     := ATargetFile;
   FCallback := ACallback;
   FreeOnTerminate := True;
end;

procedure TCTYDownloadThread.Execute;
begin
   if DownloadFileToPath(CTY_DOWNLOAD_URL, FTargetFile) then
      begin
      RunOnMainThread(FCallback, 1)
      end
   else
      begin
      RunOnMainThread(FCallback, 0);
      end;
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

procedure CheckCTYVersionAsync(const ACallback: TMainThreadCallback);
var
   Thread: TCTYVersionCheckThread;
begin
   Thread := TCTYVersionCheckThread.Create(ACallback);
   Thread.Resume;
end;

procedure DownloadCTYAsync(const ATargetFile: string; const ACallback: TMainThreadCallback);
var
   Thread: TCTYDownloadThread;
begin
   Thread := TCTYDownloadThread.Create(ATargetFile, ACallback);
   Thread.Resume;
end;

// The URL stays private: callers name the FILE they want, never the site it
// comes from. TCTYDownloadThread.Execute above is the same one line.
function DownloadCTYFile(const ATargetFile: string): boolean;
var
   ignored: string;
begin
   Result := DownloadCTYFile(ATargetFile, ignored);
end;

function DownloadCTYFile(const ATargetFile: string;
                         out AFailReason: string): boolean;
begin
   Result := DownloadFileToPath(CTY_DOWNLOAD_URL, ATargetFile, AFailReason);
end;

end.
