unit uHTTPDownload;
{$I ..\tr4w.inc}   // relative: this unit lives in src\utils, the include in src
{
  Fetch a file over HTTPS to a path on disk.  One routine, no policy.

  WHY IT LIVES HERE.  This was private to uCTYUpdate, which was correct while
  CTY.DAT was the only thing TR4W downloaded.  It is not correct once TRMASTER
  .DTA uses it too: a second caller reaching into a CTY unit for a general
  facility makes the dependency graph lie about what depends on what.  Lifted
  when the second caller arrived (2026-08-16) rather than after the third.

  It knows no URLs.  Callers name the FILE they want; the unit that owns that
  file owns its address.
}

interface

function DownloadFileToPath(const AURL, ATargetFile: string;
                            const AAllowInsecure: boolean = False): boolean;
// Downloads AURL to ATargetFile.  Returns True only if the file is on disk
// under its final name.
//
// ATOMIC: writes <target>.tmp and renames, so a failed or partial transfer
// never replaces a good file with a truncated one.  A caller that finds False
// still has whatever it had before.
//
// SYNCHRONOUS -- it blocks the calling thread for the whole transfer.  Callers
// that have a window should run it on a thread and post their own completion
// message; the one exception is startup, before a message loop exists.
//
// HTTP *AND* HTTPS, decided by the URL's own scheme:
//
//   https://  TLS 1.2, OpenSSL IOHandler attached.
//   http://   plain, and ONLY if the caller passes AAllowInsecure = True.
//             No SSL IOHandler is created at all, so a plain fetch does not
//             need libeay32/ssleay32 present.
//   anything else, or no scheme -- refused.
//
// SECURE BY DEFAULT, AND THE CALLER SAYS OTHERWISE EXPLICITLY.  The flag is not
// "use TLS" (the URL already says that); it is the caller stating that it knows
// this particular file is fetched in the clear and accepts it.  Defaulting the
// other way would let a mistyped or redirected URL quietly downgrade a download
// nobody intended to be plaintext -- and TR4W's own rule is that a silent
// fallback is a defect.  A refusal is logged, never silent.
//
// Failures are logged here (the reason is only visible here) and reported to
// the caller as False.  It does not raise.

implementation

uses
   SysUtils,
   Classes,
   IdHTTP,
   IdSSLOpenSSL,
   Log4D;

var
   // Own logger rather than MainUnit's global, following uRegex: this unit has
   // no business pulling MainUnit in, and a standalone exe that links it does
   // not assign that global.
   logger: TLogLogger;

function DownloadFileToPath(const AURL, ATargetFile: string;
                            const AAllowInsecure: boolean = False): boolean;
var
   http:    TIdHTTP;
   ssl:     TIdSSLIOHandlerSocketOpenSSL;
   fs:      TFileStream;
   tmpFile: string;
   useTLS:  boolean;
begin
   Result  := False;
   tmpFile := ATargetFile + '.tmp';

   // Scheme first, and refuse before opening anything: the .tmp file must not
   // be created for a request that is never going to be made.
   if SameText(Copy(AURL, 1, 8), 'https://') then
      begin
      useTLS := True;
      end
   else if SameText(Copy(AURL, 1, 7), 'http://') then
      begin
      useTLS := False;
      if not AAllowInsecure then
         begin
         logger.Error('[Download] refusing plaintext %s -- the caller must pass ' +
                      'AAllowInsecure to accept an http:// URL', [AURL]);
         Exit;
         end;
      logger.Warn('[Download] %s is PLAINTEXT (caller allowed it)', [AURL]);
      end
   else
      begin
      logger.Error('[Download] %s has no http:// or https:// scheme', [AURL]);
      Exit;
      end;

   ssl  := nil;
   http := TIdHTTP.Create(nil);
   try
      // Only build the OpenSSL handler when it is actually needed. A plain
      // fetch then works on a machine with no libeay32/ssleay32 at all, and
      // TIdHTTP supplies its own default stack handler.
      if useTLS then
         begin
         ssl := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
         ssl.SSLOptions.Method := TIdSSLVersion(sslvTLSv1_2);
         http.IOHandler        := ssl;
         end;

      http.HandleRedirects   := True;
      http.Request.UserAgent := 'TR4W';

      // TIMEOUTS ARE NOT OPTIONAL.  Indy's default is to wait forever, which
      // was merely untidy while every caller was a background thread -- a stuck
      // fetch simply never posted its completion and nobody noticed.  It is a
      // real hazard for the synchronous startup callers: a connection that is
      // accepted and then black-holed (a captive portal, a firewall that drops
      // rather than refuses) would hang TR4W before it has a window, showing
      // the operator nothing and offering no way to cancel.
      //
      // Generous rather than tight: the files fetched here are a few MB.
      http.ConnectTimeout := 15000;   // ms
      http.ReadTimeout    := 30000;   // ms

      try
         fs := TFileStream.Create(tmpFile, fmCreate);
         try
            http.Get(AURL, fs);
         finally
            fs.Free;
         end;
         // Atomic replace: only remove the live file once .tmp is fully written
         SysUtils.DeleteFile(ATargetFile);
         Result := RenameFile(tmpFile, ATargetFile);
         if not Result then
            begin
            logger.Error('[Download] %s fetched but could not be renamed to %s',
                         [tmpFile, ATargetFile]);
            end;
      except
         on E: Exception do
            begin
            // The path matters as much as the message: "download failed" alone
            // does not tell the operator whether the network or the folder is
            // the problem, and an unwritable install directory looks identical
            // to an unreachable host from the outside.
            logger.Error('[Download] %s -> %s failed: %s: %s',
                         [AURL, ATargetFile, E.ClassName, E.Message]);
            SysUtils.DeleteFile(tmpFile);
            end;
      end;
   finally
      // http first: it holds a reference to the handler while it lives.
      http.Free;
      ssl.Free;   // nil for a plaintext fetch; TObject.Free tolerates that
   end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.Download');

end.
