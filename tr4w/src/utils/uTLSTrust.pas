unit uTLSTrust;
{$I ..\tr4w.inc}
(*
  VERIFIED TLS: A TRUSTED CHAIN, AND THE RIGHT HOST AT THE END OF IT.

  Attach this to an FPC HTTP client and its HTTPS connections are checked.
  Leave it unattached and they are not -- FPC's VerifyPeerCert defaults to
  False, which is SSL_VERIFY_NONE.

  WHAT TR4W DID BEFORE, MEASURED RATHER THAN ASSUMED (2026-09-09). Every HTTPS
  connection this program made was UNVERIFIED. Indy's TIdSSLContext sets
  fVerifyMode := [], an empty set translates to SSL_VERIFY_NONE, and only one
  unit in the tree ever changed it. The version check, the CTY download, the
  contest-score post, the POTA fetch and HamScore all accepted whatever
  certificate the far end presented. HamScore is the one that matters most: it
  sends the operator's username and password as HTTP basic authentication.

  The single exception, the SuperCheckPartial upload, asked for sslvrfPeer and
  is thinner than it looks. Indy's own verify callback decides on

      VerifiedOK {and (Ok > 0)}

  -- the chain result COMMENTED OUT in Indy itself -- so OpenSSL's verdict
  is discarded and a date-and-name check decides alone.

  AND THE WINDOWS CERTIFICATE STORE WAS NEVER INVOLVED. Indy talks to the
  OpenSSL DLLs we ship, not to Schannel, so there is no platform trust store in
  play on any of the three platforms. That is why a bundle is the answer rather
  than an oversight to correct.

  TWO CHECKS, AND BOTH ARE NECESSARY.

  1. THE CHAIN. FPC loads trusted roots only from a CA file the caller names --
     it never calls SetDefaultVerifyPaths, so the system store is not used even
     where one exists. We name cacert.pem, the Mozilla root set as published by
     the curl project, shipped beside the program. One file, one behaviour,
     three platforms, no per-OS trust code.

  2. THE HOSTNAME. A valid chain proves the certificate is genuine, NOT that it
     belongs to the host we asked for. Without this second check, any
     certificate signed by any of the 121 roots would satisfy the first one --
     which is not verification, it is a formality. FPC 3.2.2 exposes only the
     subject and issuer as one-line strings: no Subject Alternative Name, and
     modern certificates put the hostname there rather than in the common name.
     So the check goes through OpenSSL's own X509_check_host, which knows about
     SAN entries and wildcards.

  THAT IS ONE NEW SYMBOL, NOT A NEW DEPENDENCY. X509_check_host is fetched from
  the libcrypto FPC has ALREADY loaded, through the handle FPC publishes
  (openssl.SSLUtilHandle). Nothing extra is loaded, shipped or searched for.
  It arrived in OpenSSL 1.0.2 (2015); if it is missing, this unit FAILS CLOSED
  and says why, because quietly skipping hostname verification is the exact
  downgrade it exists to prevent.

  WHAT THIS DELIBERATELY DOES NOT DO is decide policy. It reports whether
  verification could be set up and leaves refusing or proceeding to the caller,
  so that "the operator turned checking off" and "the bundle is missing" are
  distinguishable in a log rather than both appearing as a failed download.

  ---------------------------------------------------------------------------
  THE INTENDED macOS END STATE: NSURLSession, NOT OpenSSL AT ALL.
  ---------------------------------------------------------------------------

  Everything above assumes OpenSSL. On Windows that is fair -- the installer
  ships it. On Linux it is fair -- the distribution has it. ON macOS IT IS NOT:
  Apple ships no libssl.dylib, so TR4W currently depends on the operator having
  installed Homebrew, and a Mac without it has no TLS whatsoever. Not degraded:
  the country-file download, the version check and the score post simply do not
  work.

  Apple's own answer is NSURLSession -- HTTP and HTTPS through the system
  stack, verified against the user's Keychain. NY4I raised it (2026-09-09,
  citing wiki.lazarus.freepascal.org/macOS_NSURLSession) and it is the right
  end state for that platform, for three reasons:

    NO THIRD-PARTY INSTALL. The dependency on Homebrew disappears, and with it
    the support answer "run brew install openssl@3 before TR4W will fetch
    CTY.DAT", which no operator should ever be told.

    THE KEYCHAIN IS A BETTER TRUST SOURCE THAN OUR BUNDLE. cacert.pem is a
    snapshot we refresh at release time and that goes stale between releases;
    the Keychain is what that Mac already trusts, kept current by the OS.

    IT DELETES THE UGLIEST THING IN uOpenSSLLoader. That unit currently
    symlinks libssl.3.dylib under the name libssl.1.1.dylib, because FPC on
    Darwin will not attempt any filename a Mac actually has. Renaming a library
    so a search finds it is a hack, and it is labelled as one where it lives.

  THE BINDINGS ARE ALREADY PRESENT -- NSURLSession.inc ships in the cocoaint
  package this build already links (verified on the Mac mini, 2026-09-09), so
  this costs no new dependency.

  WHAT IT COSTS, so nobody starts it believing it is a swap:

    IT IS NOT A SOCKET HANDLER. NSURLSession is a separate API, not something
    UseVerifiedTLS can configure, so it REPLACES the client on macOS rather
    than adjusting it. That is a third implementation behind the same
    interface.

    IT IS ASYNCHRONOUS -- completion handlers and delegates -- while the three
    verbs in uHTTPDownload are synchronous. Bridging wants a semaphore or a
    run-loop pump, and doing that on the main thread is the exact deadlock
    shape this program has already been bitten by (see uCrashLog's
    main-thread notes).

    APP TRANSPORT SECURITY MAY REFUSE PLAIN http://, which the contest-score
    post deliberately allows for club servers. That needs an Info.plist
    exception or a stated limitation.

  WHY IT IS CHEAP LATER RATHER THAN NOW: uHTTPDownload's three verbs are
  already the seam. A macOS implementation slots in behind them with NO CALLER
  CHANGING -- which is the payoff from folding five copies of the transport
  into one unit. Sequenced deliberately AFTER someone has actually run the GUI
  on a Mac: if that turns out to be the real problem, the networking question
  gets reconsidered alongside it rather than solved first.
*)

interface

uses
   fphttpclient;

(* Where the bundle is, whether or not it exists. Named so a failure message
  can show the path the operator should look at.

  THE SEARCH ORDER (issue 221): the data directory first -- DataFilePath, the
  working directory on Windows -- then the folder the program itself is in
  (BesideProgramFilePath). The first USABLE file wins, so a bundle beside the
  program is found when the program is started from somewhere else. When
  neither exists the data-directory path is returned, so a message names
  something. Which place answered is logged once, and again if it changes. *)
function TrustBundlePath: string;

(* Is there a bundle that can be opened for reading? False means a verified
  request cannot be made and NOTHING WOULD BE SENT. *)
function TrustBundleUsable: boolean;

(* The places looked, for a message: "C:\a\cacert.pem; C:\b\cacert.pem". *)
function TrustBundleSearchPlaces: string;

(* The operator notice for a missing bundle, ONCE per service per session:
  the text the first time, '' afterwards. The first call also writes the log
  line. Safe from any thread. It builds text and touches nothing visible: the
  caller hands it to the main thread. *)
function TrustBundleAlertText(const aService: string): string;

(* TEST SEAMS. Both folders replace the two real ones (an empty folder means
  "none"); two empty strings restore the real lookup. The second clears the
  once-only latches. *)
procedure SetTrustBundleFolders(const aDataDir, aProgramDir: string);
procedure ResetTrustBundleLatches;

(* Attach chain and hostname verification to aClient.

  False means verification could NOT be set up and aReason says why -- a
  missing bundle, or an OpenSSL too old to check a hostname. The client is
  left untouched in that case, so a caller that proceeds anyway is making an
  explicit choice rather than inheriting a silent one. *)
function UseVerifiedTLS(aClient: TFPHTTPClient; out aReason: string): boolean;

(* The last verification failure, for a log line or a dialog. '' when nothing
  has failed. Set even when the connection error the caller sees is generic. *)
function LastTLSFailure: string;

implementation

uses
   SysUtils,
   Classes,
   sslsockets,
   ssockets,
   opensslsockets,
   openssl,
   fpopenssl,
   dynlibs,
   SyncObjs,
   Log4D,
   uAppPaths,
   uAppStrings,
   uOpenSSLLoader;

const
   BUNDLE_NAME = 'cacert.pem';

   (* X509_V_OK. Named rather than written as 0 at the comparison, because
     "the verify result is zero" reads like an absence and it is a verdict. *)
   X509_V_OK = 0;

type
   (* int X509_check_host(X509 *x, const char *chk, size_t chklen,
                          unsigned int flags, char **peername);

     1 match, 0 mismatch, negative on error. A NIL peername is legal and means
     "do not hand back the matched name", which we do not need. *)
   TX509CheckHost = function(aCert: pointer; aName: PAnsiChar; aLen: PtrUInt;
                             aFlags: LongWord; aPeerName: pointer): integer; cdecl;

   (* X509 *SSL_get1_peer_certificate(const SSL *ssl);

     Returns a certificate whose reference count has been INCREMENTED, so the
     caller frees it. Both spellings behave identically in that respect. *)
   TSSLGetPeerCert = function(aSSL: pointer): pointer; cdecl;

var
   GCheckHost:      TX509CheckHost = nil;
   GCheckLoaded:    boolean = False;
   GGetPeerCert:    TSSLGetPeerCert = nil;
   GPeerCertLoaded: boolean = False;
   GLastFailure:    string = '';

   (* Everything below is read by delivery workers as well as the main thread. *)
   GLock:           TCriticalSection = nil;
   GFoldersSet:     boolean = False;
   GDataDirSeam:    string = '';
   GProgramDirSeam: string = '';
   GBundleLogged:   string = '';
   GAlerted:        array of string;
   (* Own logger rather than a unit's global, as uHTTPDownload does; the same
     name so one appender sees both. *)
   GLog:            TLogLogger = nil;

(* Can the file be opened for reading? FileExists alone says nothing about a
  file the account may not read, and a handshake would then fail AFTER the
  connection was made. *)
function BundleUsable(const aPath: string): boolean;
var
   handle: THandle;
begin
   Result := False;
   if (aPath = '') or (not FileExists(aPath)) then
      begin
      Exit;
      end;
   (* FileOpen answers with an invalid handle rather than raising. *)
   handle := FileOpen(aPath, fmOpenRead or fmShareDenyNone);
   if handle <> feInvalidHandle then
      begin
      FileClose(handle);
      Result := True;
      end;
end;

(* The two places, in search order. A place that is not there is ''; the
  program folder is '' when it is the data folder. *)
procedure BundleCandidates(out aData, aProgram: string);
var
   seamed:   boolean;
   dataDir:  string;
   progDir:  string;
begin
   GLock.Enter;
   try
      seamed  := GFoldersSet;
      dataDir := GDataDirSeam;
      progDir := GProgramDirSeam;
   finally
      GLock.Leave;
   end;

   if seamed then
      begin
      aData    := '';
      aProgram := '';
      if dataDir <> '' then
         begin
         aData := IncludeTrailingPathDelimiter(dataDir) + BUNDLE_NAME;
         end;
      if progDir <> '' then
         begin
         aProgram := IncludeTrailingPathDelimiter(progDir) + BUNDLE_NAME;
         end;
      end
   else
      begin
      (* Case-tolerantly, like every other shipped file -- see uAppPaths. *)
      aData    := ExistingDataFile(DataFilePath(BUNDLE_NAME));
      aProgram := ExistingDataFile(BesideProgramFilePath(BUNDLE_NAME));
      end;

   if (aProgram <> '') and (aProgram = aData) then
      begin
      aProgram := '';
      end;
end;

function TrustBundlePath: string;
var
   dataCandidate:    string;
   programCandidate: string;
   tier:             string;
begin
   BundleCandidates(dataCandidate, programCandidate);

   tier := '';
   if BundleUsable(dataCandidate) then
      begin
      Result := dataCandidate;
      tier   := 'data directory';
      end
   else if BundleUsable(programCandidate) then
      begin
      Result := programCandidate;
      tier   := 'beside the program';
      end
   else if dataCandidate <> '' then
      begin
      Result := dataCandidate;
      end
   else
      begin
      Result := programCandidate;
      end;

   (* WHICH PLACE ANSWERED, once. Workers ask for the path on every connection,
     so the latch is the answer itself: it logs again only when the answer
     changes, and a bundle that goes missing and returns is logged again. *)
   GLock.Enter;
   try
      if tier = '' then
         begin
         GBundleLogged := '';
         end
      else if Result <> GBundleLogged then
         begin
         GBundleLogged := Result;
         GLog.Info('[TLS] CA bundle: %s (%s)', [Result, tier]);
         end;
   finally
      GLock.Leave;
   end;
end;

function TrustBundleUsable: boolean;
begin
   Result := BundleUsable(TrustBundlePath);
end;

function TrustBundleSearchPlaces: string;
var
   dataCandidate:    string;
   programCandidate: string;
begin
   BundleCandidates(dataCandidate, programCandidate);
   Result := dataCandidate;
   if programCandidate <> '' then
      begin
      if Result <> '' then
         begin
         Result := Result + '; ';
         end;
      Result := Result + programCandidate;
      end;
end;

function TrustBundleAlertText(const aService: string): string;
var
   places: string;
   first:  boolean;
   i:      integer;
begin
   Result := '';
   places := TrustBundleSearchPlaces;

   (* One entry per SERVICE: the reason is always "the bundle is missing" here. *)
   GLock.Enter;
   try
      first := True;
      for i := 0 to High(GAlerted) do
         begin
         if GAlerted[i] = aService then
            begin
            first := False;
            end;
         end;
      if first then
         begin
         SetLength(GAlerted, Length(GAlerted) + 1);
         GAlerted[High(GAlerted)] := aService;
         end;
   finally
      GLock.Leave;
   end;

   if first then
      begin
      Result := UnicodeFormat(SCaBundleMissingNotice, [places, aService]);
      (* The path and the service name are the only inserts: there is no
        credential anywhere near this text. *)
      GLog.Warn('[TLS] %s', [Result]);
      end;
end;

procedure SetTrustBundleFolders(const aDataDir, aProgramDir: string);
begin
   GLock.Enter;
   try
      GFoldersSet     := (aDataDir <> '') or (aProgramDir <> '');
      GDataDirSeam    := aDataDir;
      GProgramDirSeam := aProgramDir;
      GBundleLogged   := '';
   finally
      GLock.Leave;
   end;
end;

procedure ResetTrustBundleLatches;
begin
   GLock.Enter;
   try
      SetLength(GAlerted, 0);
      GBundleLogged := '';
   finally
      GLock.Leave;
   end;
end;

function LastTLSFailure: string;
begin
   Result := GLastFailure;
end;

(* Fetch X509_check_host from the libcrypto already in memory. Once, and the
  answer is remembered including a negative one. *)
function CheckHostAvailable: boolean;
begin
   if not GCheckLoaded then
      begin
      GCheckLoaded := True;
      if SSLUtilHandle <> 0 then
         begin
         GCheckHost := TX509CheckHost(GetProcedureAddress(SSLUtilHandle,
                                                          'X509_check_host'));
         end;
      end;
   Result := Assigned(GCheckHost);
end;

(* THE PEER CERTIFICATE, UNDER WHICHEVER NAME THIS OpenSSL USES.

  FPC 3.2.2's TSSL.PeerCertificate binds SSL_get_peer_certificate, and OpenSSL
  3 DOES NOT EXPORT THAT NAME. It was renamed to SSL_get1_peer_certificate and
  the old spelling survives only as a macro in the C headers, which does
  nothing for a library loaded at run time:

      nm -D --defined-only libssl.so.3 | grep peer_certificate
      SSL_get1_peer_certificate@@OPENSSL_3.0.0

  So on any current Linux, FPC hands back nil -- and so do PeerName,
  PeerSubject and PeerNameHash, which all go through it. FPC's certificate
  inspection is entirely blind against OpenSSL 3.

  Found by running the badssl probe on the Linux runner after it passed on
  Windows: every site was rejected with "the server presented no certificate",
  including the ones that must succeed. Failing closed is the right way round
  to have that bug, but it would have broken every download on Linux.

  Both names are tried, new one first, through the libssl handle FPC itself
  publishes. TSSL.FSSL is public, so this uses FPC's own surface rather than
  reaching around it.

  This is a SECOND new symbol on top of X509_check_host, and it deserves the
  same justification: nothing extra is loaded, and the alternative is that
  hostname verification cannot work at all on the platform that needed it. *)
function PeerCertificateOf(aSSL: pointer): pointer;
begin
   Result := nil;
   if aSSL = nil then
      begin
      Exit;
      end;

   if not GPeerCertLoaded then
      begin
      GPeerCertLoaded := True;
      if SSLLibHandle <> 0 then
         begin
         GGetPeerCert := TSSLGetPeerCert(GetProcedureAddress(SSLLibHandle,
                                         'SSL_get1_peer_certificate'));
         if not Assigned(GGetPeerCert) then
            begin
            (* OpenSSL 1.x, where the old spelling is the real symbol. *)
            GGetPeerCert := TSSLGetPeerCert(GetProcedureAddress(SSLLibHandle,
                                            'SSL_get_peer_certificate'));
            end;
         end;
      end;

   if Assigned(GGetPeerCert) then
      begin
      Result := GGetPeerCert(aSSL);
      end;
end;

type
   { A class only because the two hooks are method pointers. It holds no
     per-connection state: one instance serves every client. }
   TTrustHooks = class(TObject)
   public
      procedure GetHandler(Sender: TObject; const UseSSL: boolean;
                           out AHandler: TSocketHandler);
      procedure VerifyCertificate(Sender: TObject; var Allow: boolean);
   end;

var
   GHooks: TTrustHooks = nil;

procedure TTrustHooks.VerifyCertificate(Sender: TObject; var Allow: boolean);
var
   handler: TOpenSSLSocketHandler;
   host:    string;
   (* The bytes OpenSSL reads. Named, so the pointer below is not taken of a
     temporary -- see uOpenSSLLoader, which states the rule. *)
   hostBytes: AnsiString;
   cert:    pointer;
   rc:      integer;
   verdict: integer;
begin
   Allow := False;

   if not (Sender is TOpenSSLSocketHandler) then
      begin
      GLastFailure := 'TLS verification: unexpected handler type';
      Exit;
      end;
   handler := TOpenSSLSocketHandler(Sender);

   (* THE CHAIN FIRST. OpenSSL has already walked it against the bundle; this
     reads its verdict. Anything but X509_V_OK means untrusted, expired, or
     signed by a root we do not carry. *)
   verdict := handler.SSL.VerifyResult;
   if verdict <> X509_V_OK then
      begin
      GLastFailure := string(Format('TLS verification failed: the server certificate '
                             + 'chain was rejected (OpenSSL verify result %d). '
                             + 'The trusted-root bundle is "%s".',
                             [verdict, TrustBundlePath]));
      Exit;
      end;

   (* THEN THE HOSTNAME, which the chain says nothing about. *)
   if not (handler.Socket is TInetSocket) then
      begin
      GLastFailure := 'TLS verification: no host to check the certificate against';
      Exit;
      end;
   (* A host name is ASCII by the time it reaches a socket -- an
     internationalised one is punycode already -- so this widening is exact.
     Named anyway: an implicit conversion here is indistinguishable from one
     that loses characters, and the build counts them all. *)
   host := string(TInetSocket(handler.Socket).Host);

   if not CheckHostAvailable then
      begin
      (* FAILS CLOSED. Proceeding here would mean a trusted certificate for
        SOME host being accepted for THIS one, which is the whole attack this
        check prevents. *)
      GLastFailure := 'TLS verification: this OpenSSL has no X509_check_host, '
                      + 'so the certificate cannot be matched to the host name. '
                      + 'OpenSSL 1.0.2 or later is required.';
      Exit;
      end;

   (* NOT handler.SSL.PeerCertificate -- see PeerCertificateOf for why that
     returns nil on OpenSSL 3. *)
   cert := PeerCertificateOf(handler.SSL.FSSL);
   if cert = nil then
      begin
      GLastFailure := 'TLS verification failed: the server presented no certificate';
      Exit;
      end;

   try
      (* Length 0 means "aName is NUL-terminated", which it is. *)
      hostBytes := AnsiString(host);
      rc := GCheckHost(cert, PAnsiChar(hostBytes), 0, 0, nil);
   finally
      (* PeerCertificate hands back a reference the caller owns -- TSSL's own
        PeerSubject frees it the same way. *)
      X509Free(cert);
   end;

   if rc <> 1 then
      begin
      GLastFailure := string(Format('TLS verification failed: the certificate is valid '
                             + 'but was not issued for "%s".', [host]));
      Exit;
      end;

   GLastFailure := '';
   Allow := True;
end;

procedure TTrustHooks.GetHandler(Sender: TObject; const UseSSL: boolean;
                                 out AHandler: TSocketHandler);
var
   ssl: TOpenSSLSocketHandler;
begin
   if not UseSSL then
      begin
      (* A plain http:// request through the same client. Nothing to verify,
        and returning a TLS handler here would break it. *)
      AHandler := TSocketHandler.Create;
      Exit;
      end;

   (* CLEARED PER CONNECTION, AND THIS WAS A REAL DEFECT.

     A chain that OpenSSL itself rejects -- self-signed, expired, an untrusted
     root -- fails during the handshake, so VerifyCertificate below is NEVER
     REACHED and cannot record anything. Without this line the last message
     stayed set, and a caller reading LastTLSFailure after a self-signed
     certificate was told the previous request's host name did not match.

     Measured, not reasoned about: the first run of the badssl probe rejected
     all four bad certificates correctly and reported the wrong reason for
     three of them.

     Empty now means "nothing TLS-specific to add" and the caller should show
     the connection error it already has, which for a rejected chain is the
     honest answer -- the rejection happened inside OpenSSL, before we had a
     certificate to describe. *)
   GLastFailure := '';

   ssl := TOpenSSLSocketHandler.Create;
   ssl.VerifyPeerCert := True;                       (* SSL_VERIFY_PEER *)
   (* FPC's certificate record holds a byte string. The bundle sits beside
     the program, so the path is whatever the install directory is called --
     converted explicitly because this is the one crossing here that CAN lose
     characters, on a machine whose paths are not ASCII. *)
   ssl.CertificateData.CertCA.FileName := AnsiString(TrustBundlePath);
   ssl.OnVerifyCertificate := VerifyCertificate;
   AHandler := ssl;
end;

function UseVerifiedTLS(aClient: TFPHTTPClient; out aReason: string): boolean;
var
   bundle: string;
begin
   Result  := False;
   aReason := '';

   if aClient = nil then
      begin
      aReason := 'no client';
      Exit;
      end;

   (* OpenSSL must be loadable before any of this means anything, and on Linux
     that is uOpenSSLLoader's job -- see there for why the library name is the
     hard part on that platform. *)
   if not EnsureOpenSSL then
      begin
      aReason := OpenSSLDiagnostic;
      Exit;
      end;

   bundle := TrustBundlePath;
   if not BundleUsable(bundle) then
      begin
      (* Missing or unreadable: either way no handshake can be checked, and
        uHTTPDownload reads this as "nothing was sent" (TrustBundleMissing). *)
      aReason := UnicodeFormat('the trusted-root bundle is missing or cannot be '
                        + 'read (looked in: %s), so server certificates cannot '
                        + 'be checked', [TrustBundleSearchPlaces]);
      Exit;
      end;

   (* Asked for HERE as well as in the callback, so a machine unable to check
     host names is reported when the client is set up, rather than at the first
     failed request. *)
   if not CheckHostAvailable then
      begin
      aReason := 'this OpenSSL has no X509_check_host (1.0.2 or later is '
                 + 'required), so a certificate cannot be matched to a host name';
      Exit;
      end;

   if GHooks = nil then
      begin
      GHooks := TTrustHooks.Create;
      end;

   aClient.OnGetSocketHandler := GHooks.GetHandler;
   Result := True;
end;

initialization
   GLock    := TCriticalSection.Create;
   GLog     := TLogLogger.GetLogger('TR4WDebugLog.HTTP');

finalization
   GHooks.Free;
   GHooks := nil;
   FreeAndNil(GLock);

end.
