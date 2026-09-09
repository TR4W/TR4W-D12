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
                            const AAllowInsecure: boolean = False): boolean; overload;
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

function DownloadFileToPath(const AURL, ATargetFile: string;
                            out AFailReason: string;
                            const AAllowInsecure: boolean = False): boolean; overload;
// The same download, but it HANDS BACK WHY IT FAILED.
//
// The two-argument form logs the reason and returns False, and the header
// above called that the design -- "the reason is only visible here". It is not
// a design, it is a defect: the one caller with no log in front of the
// operator is the STARTUP country-file fetch, which then advised checking the
// network and the folder while the log said EIdOSSLCouldNotLoadSSLLibrary
// (NY4I, 2026-08-26). Wrong advice is worse than none -- it sends the operator
// to inspect two things that are both fine.
//
// AFailReason is a SENTENCE FRAGMENT for a "Reason: %s" slot, not a class
// name, and it is '' when the function returns True.

implementation

uses
   SysUtils,
   Classes,
   fphttpclient,      (* FPC's own client -- see the note on the transport *)
   opensslsockets,    (* registers the TLS handler fphttpclient asks for *)
   uOpenSSLLoader,
   uAppStrings,
   Log4D;

(*
  THE TRANSPORT IS FPC'S CLIENT, NOT INDY, AND ONLY HERE.

  This unit used TIdHTTP with TIdSSLIOHandlerSocketOpenSSL. On Linux that could
  not fetch anything over TLS, and the reason is not fixable from here: Indy
  10.6.3.3 FINDS OpenSSL 3 and then refuses it --

      Unsupported SSL Library version: 300000D0

  -- which is a hard version gate, measured on the runner with and without the
  library name made resolvable, identical both ways. Lifting it means Indy
  PR #529: unmerged, and it replaces the whole 22,000-line headers unit.

  Measured on the same box, same URL, same minute:

      Indy, OpenSSL 3                      FAIL, could not load SSL library
      Indy, name made resolvable           FAIL, same version gate
      fphttpclient + opensslsockets        OK, 105,954 bytes

  ONE IMPLEMENTATION, NOT A PER-PLATFORM SPLIT. Windows was never broken, but
  it takes this path too: FPC's loader looks for ssleay32.dll and libeay32.dll,
  which is exactly the pair the installer already ships, verified 2026-09-09 by
  fetching the same file with the bundled DLLs untouched. A conditional here
  would mean a bug found on one platform staying hidden on the other.

  INDY IS NOT BEING REPLACED. It keeps the DX cluster, the multi-op link and
  every socket it already owns. HTTPS request/response is the only thing that
  moved, because it is the only thing that was broken.
*)

var
   // Own logger rather than MainUnit's global, following uRegex: this unit has
   // no business pulling MainUnit in, and a standalone exe that links it does
   // not assign that global.
   logger: TLogLogger;

function DownloadFileToPath(const AURL, ATargetFile: string;
                            out AFailReason: string;
                            const AAllowInsecure: boolean = False): boolean;
var
   http:    TFPHTTPClient;
   fs:      TFileStream;
   tmpFile: string;
   useTLS:  boolean;
begin
   Result      := False;
   AFailReason := '';
   tmpFile     := ATargetFile + '.tmp';

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
         AFailReason := SDownloadCouldNotStart;
         Exit;
         end;
      logger.Warn('[Download] %s is PLAINTEXT (caller allowed it)', [AURL]);
      end
   else
      begin
      logger.Error('[Download] %s has no http:// or https:// scheme', [AURL]);
      AFailReason := SDownloadCouldNotStart;
      Exit;
      end;

   (* LOAD TLS BEFORE OPENING ANYTHING, and only when the URL needs it -- a
     plaintext fetch still works on a machine with no OpenSSL at all.

     Reported rather than left to fail deep in the client: EnsureOpenSSL knows
     WHICH library it found or could not find, and that sentence is what the
     operator needs. The failure this replaces said the OpenSSL libraries could
     not be loaded and then advised checking for two Windows DLLs, on Linux
     (NY4I, 2026-09-09). *)
   if useTLS and (not EnsureOpenSSL) then
      begin
      logger.Error('[Download] TLS unavailable for %s -- %s',
                   [AURL, OpenSSLDiagnostic]);
      AFailReason := SDownloadNoSSLLibrary;
      Exit;
      end;

   http := TFPHTTPClient.Create(nil);
   try
      http.AllowRedirect := True;
      http.AddHeader('User-Agent', 'TR4W');

      // TIMEOUTS ARE NOT OPTIONAL.  Indy's default is to wait forever, which
      // was merely untidy while every caller was a background thread -- a stuck
      // fetch simply never posted its completion and nobody noticed.  It is a
      // real hazard for the synchronous startup callers: a connection that is
      // accepted and then black-holed (a captive portal, a firewall that drops
      // rather than refuses) would hang TR4W before it has a window, showing
      // the operator nothing and offering no way to cancel.
      //
      // Generous rather than tight: the files fetched here are a few MB.
      (* FPC names these the same and measures them the same way; its default
        is likewise no limit. *)
      http.ConnectTimeout := 15000;   // ms
      http.IOTimeout      := 30000;   // ms

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
            AFailReason := SDownloadRenameFailed;
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

            (* THE ONE FAILURE AN OPERATOR CAN ACT ON keeps its own sentence.
              It is now caught BEFORE the request, by EnsureOpenSSL above, so
              this arm is the residue: a TLS failure that only shows itself
              once bytes are moving. EInOutError is what FPC raises when the
              library will not initialise. Everything else reports E.Message,
              which is the library's own diagnostic. *)
            if (E is EInOutError) and (Pos('OpenSSL', E.Message) > 0) then
               begin
               AFailReason := SDownloadNoSSLLibrary;
               end
            else
               begin
               AFailReason := E.Message;
               end;
            SysUtils.DeleteFile(tmpFile);
            end;
      end;
   finally
      (* One object now: FPC's client owns its own socket handler, so there is
        no separately-created IOHandler to outlive it. *)
      http.Free;
   end;
end;

function DownloadFileToPath(const AURL, ATargetFile: string;
                            const AAllowInsecure: boolean = False): boolean;
// Delegates -- ONE implementation, not two. The reason reaches only the log
// here, which is right for a caller that has a window and a log open, and
// wrong for the startup fetch, which is why the other form exists.
var
   ignored: string;
begin
   Result := DownloadFileToPath(AURL, ATargetFile, ignored, AAllowInsecure);
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.Download');

end.
