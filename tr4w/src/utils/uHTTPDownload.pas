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

  TWO LAYERS SINCE ISSUE 224 (docs/HTTP_TRANSPORT_DESIGN.md).  This unit is the
  SHARED layer: the three verbs, THttpRequest, the scheme and bearer policy, the
  verify-or-not policy, the secrets rule and ALL logging of anything derived
  from a request.  The wire -- the client, TLS, the trust decision -- is a
  TRANSPORT (uHttpTransport is the contract, uHttpTransportGeneric the FPC +
  OpenSSL implementation that used to be written out here).  A transport
  returns what happened as data; this unit scrubs and logs it.
}

interface

uses
   Classes, SysUtils, uHttpTransport;

(* THE STREAM THAT CARRIES A REQUEST BODY: the body's UTF-8 bytes, untouched.

  Exposed so a test can read the bytes that are really SENT. It is a
  TRawByteStringStream and NOT a TStringStream, on purpose: in FPC 3.2.2
  TStringStream is encoding-aware. TStringStream.Create(<UnicodeString>)
  encodes as UTF-16LE (streams.inc:874-876), which put '{' #0 '"' #0 on the
  wire for the SCP upload and drew "key must be a string at line 1 column 2"
  from the server; and the plain-string overload re-encodes to the ANSI
  codepage, which loses anything outside it. A raw byte stream does neither.
  The caller owns the result. *)
function CreateWireBodyStream(const aBody: string): TRawByteStringStream;

(* DOES THIS URL SEND ITS REQUEST IN THE CLEAR? True when the text, trimmed,
  starts with http:// in any case; False for https://, for any other scheme
  and for no scheme at all.

  It describes a URL an OPERATOR TYPED, which is why it trims: Preferences
  shows a note while it is true, and the HamScore uploader logs a warning, and
  both must agree. It is deliberately NOT what CheckScheme asks -- that gates a
  real fetch of the exact string it is given and does not trim, so a URL with a
  leading space is refused there rather than quietly repaired. *)
function IsPlainHttpUrl(const aUrl: string): boolean;

(* A SECRET AS IT MAY APPEAR IN A LOG: always '********', whatever its length
  and with no prefix (NY4I, 2026-11-05: not even the length is shown). An empty
  secret is '(empty)', which still tells a blank value from a real one. *)
function MaskSecret(const aSecret: string): string;

(* EVERY OCCURRENCE OF THE SECRET IN aText, AND OF ITS URL-ENCODED FORM,
  replaced by MaskSecret(aSecret). For text a server or a library wrote -- an
  exception message can echo what we sent -- before it reaches a log or a
  reason shown to the operator. An empty secret leaves the text alone. *)
function ScrubSecret(const aText, aSecret: string): string;

(* THE ONE LOG LINE FOR A TRANSPORT FAILURE: method, URL, exception class and
  message, with both secrets scrubbed out of ALL of it. A URL can carry a key in
  a query string and a server's error text can echo one back, so neither is
  trusted. aSecret2 is for a second credential (a form password); '' for none. *)
function RequestFailureLine(const aMethod, aURL: string; aE: Exception;
                            const aSecret1, aSecret2: string): string;

(* THE TRACE LINE FOR ONE REQUEST: 'POST https://host/path Authorization:
  Bearer ********'. The URL is shown (NY4I, 2026-11-05); the token is
  masked and also scrubbed out of the URL. *)
function RequestTraceLine(const aMethod, aURL, aBearer, aPassword: string): string;

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


type
   (* WHAT A CONDITIONAL DOWNLOAD CAME TO. *)
   TConditionalDownloadOutcome = (
      cdoUpdated,        (* 200: the body is in the target file *)
      cdoNotModified,    (* 304: the copy held is current; no file written *)
      cdoNotFound,       (* 404 *)
      cdoHttpError,      (* any other status: AStatus says which *)
      cdoTransportFail); (* no answer: TLS, trust, network, timeout; AFailReason says why *)

function DownloadFileConditional(const AURL, ATargetFile, AUserAgent: string;
                                 const AIfNoneMatch, AIfModifiedSince: string;
                                 out AETag, ALastModified, AContentType: string;
                                 out AStatus: integer;
                                 out AFailReason: string): TConditionalDownloadOutcome;
(* A GET THAT ASKS "IS MY COPY STILL CURRENT?" -- If-None-Match and
  If-Modified-Since are sent when not '' (a copy that is not on disk must send
  neither: the caller's rule).

  IT NEVER RENAMES AND NEVER TOUCHES ANYTHING BUT ATargetFile. The body goes to
  ATargetFile, which the caller names (its own .tmp) and validates before it
  replaces a good file; this routine only reports what arrived. ATargetFile
  exists afterwards ONLY for cdoUpdated -- for every other outcome it is
  deleted, because every status's body is streamed into it (a 404 or 429 page,
  or nothing at all for a 304).

  Unlike DownloadFileToPath, any status is an answer (AcceptAnyStatus). The
  scheme rule is the shared one (https only); redirects are followed. AETag,
  ALastModified and AContentType are the response headers of a 200 (and of a
  304 when the server repeats them); '' when absent. Never raises. DownloadFileToPath's
  behaviour for its callers is unchanged. *)

function HttpGetText(const AURL: string;
                     out AText: string;
                     out AFailReason: string;
                     const AUserAgent: string = 'TR4W';
                     const AConnectMs: integer = 15000;
                     const AIOMs: integer = 30000): boolean;
// A GET whose answer is a DOCUMENT, not a file: the version JSON, the CTY
// release feed.  Same rules as the download above -- https only unless the
// scheme says otherwise, same reason string, never raises.
//
// THE TIMEOUTS ARE A PARAMETER BECAUSE ONE CALLER IS ON THE STARTUP PATH.
// The version check ran on 5 seconds deliberately, so a slow or black-holed
// server delays the program by five seconds and not by thirty.  Folding these
// callers onto a shared routine with a generous default would have quietly
// made startup six times more patient, which is the kind of regression that
// never shows up in a test and shows up in a contest.

type
   THttpRequest = class
   (* ONE POST, DESCRIBED BY AN OBJECT RATHER THAN BY NINE PARAMETERS.

     The three POST callers in this program want overlapping but different
     things -- a status code, a response body, HTTP basic authentication, an
     Accept-Encoding, and in one case permission to use plain http:// because
     the operator configured a custom server that way. As parameters that is a
     signature nobody can read and every caller has to pass defaults through.
     As fields, each caller sets the two or three it cares about.

     WHY THESE LIVE HERE AND NOT IN EACH CALLER, which is where they were until
     2026-09-09: five units each built their own TIdHTTP and their own TLS
     handler, with their own timeouts and their own idea of what to do when it
     failed. That is five copies of a transport, and copies drift -- when Indy
     turned out to be unable to speak to OpenSSL 3, five separate places had to
     be found and fixed rather than one. The header of this unit already stated
     the rule ("It knows no URLs"); the rule was simply not being followed.

     USE: set what you need, call Send, read Response / StatusCode /
     FailReason. Send never raises. *)
   private
      function GetTlsUnavailable: boolean;
      procedure SetTlsUnavailable(aValue: boolean);
      function GetTrustBundleMissing: boolean;
      procedure SetTrustBundleMissing(aValue: boolean);
   public
      (* the request *)
      URL:            string;
      Method:         string;
      Body:           string;
      ContentType:    string;
      UserAgent:      string;
      Username:       string;   (* basic auth is sent when this is not '' *)
      Password:       string;
      BearerToken:    string;
      Sensitive:      boolean;  (* form credentials also require redacted transport errors *)
      FollowRedirects: boolean;
      MaxResponseBytes: Int64;  (* 0 = unlimited, retained for existing POST callers *)
      AcceptEncoding: string;
      IfNoneMatch:    string;   (* conditional GET: the ETag held; '' = no header *)
      IfModifiedSince: string;  (* conditional GET: the Last-Modified held; '' = none *)
      AllowInsecure:  boolean;  (* the caller accepts an http:// URL *)
      (* THIS DESTINATION'S OWN "VERIFY THE SERVER'S CERTIFICATE" CHOICE (issue
        256, docs/HTTP_TRANSPORT_DESIGN.md question 13). True unless the
        operator opted this one destination out. It is a REQUEST to be
        checked, never a way to check: the shared layer decides, in ONE place
        (VerifyWanted), that a certificate is verified only when the global
        master switch (network.verifyServerCertificates) AND this choice are
        both on. So True never overrides a global off, and False weakens this
        destination alone. It is read only for an https:// URL. *)
      VerifyServer:   boolean;
      (* WHO IS ASKING, for the one Warn line an opt-out writes ('Cloudlog
        shack'): the destination's display name. '' = not named. Never a secret. *)
      Destination:    string;
      ConnectMs:      integer;
      IOMs:           integer;

      (* the answer *)
      Response:       string;
      StatusCode:     integer;
      ResponseStatusText: string; (* some APIs report their result in the HTTP reason phrase *)
      FailReason:     string;   (* '' when Send returned True *)
      (* WHAT HAPPENED, as the transport and the shared layer know it. hfNone
        after an answer. NothingSent below is the claim a caller may act on:
        it is True ONLY for a failure that proves no byte was sent. Writable
        so a test double can stand in for any outcome; Send resets it. *)
      Failure:        THttpFailure;
      RetryAfter:     string;
      RequestId:      string;
      ETag:           string;   (* response headers, '' when absent *)
      LastModified:   string;
      ResponseContentType: string;
      FinalURL:       string;   (* set only when a followed redirect ended at another address *)
      ErrorDetail:    string;   (* the transport's own words ('Class: message'), '' after an answer
                                   or when the failure came from the shared layer's own checks *)

      (* The two proof flags every caller used before issue 224. They are now
        views of Failure: reading is Failure = hfTlsUnavailable /
        hfTrustUnavailable, writing sets Failure. New code asks NothingSent. *)
      property TlsUnavailable: boolean read GetTlsUnavailable write SetTlsUnavailable;
      (* https was asked for, checking is on, and the CA bundle (cacert.pem) is
        missing or cannot be read (issue 221). *)
      property TrustBundleMissing: boolean read GetTrustBundleMissing write SetTrustBundleMissing;

      constructor Create(const aURL: string);
      function Send: boolean; virtual;
      (* NO REQUEST BYTE LEFT THE MACHINE, PROVED. A caller may then retry or
        fail the work without fearing a double delivery. False means "may have
        been sent", which is also what a request that was never made reads as
        before Send runs. *)
      function NothingSent: boolean;
   end;

   (* Existing POST callers keep their API and defaults. REST callers use the
      same transport, TLS verification and encoding, with an explicit method. *)
   THttpPost = class(THttpRequest)
   public
      constructor Create(const aURL: string);
   end;

implementation

uses
   SyncObjs,
   fphttpclient,     (* EncodeURLElement ONLY -- a pure string function; the
                        client itself lives in uHttpTransportGeneric *)
   uHttpTransportGeneric,  (* linked here so the registry is never empty in any
                        program that can make a request, probes included *)
   uSettingsRegistry,
   uAppStrings,
   Log4D;

var
   // Own logger rather than MainUnit's global, following uRegex: this unit has
   // no business pulling MainUnit in, and a standalone exe that links it does
   // not assign that global.
   logger: TLogLogger;
   // The last TLS-unavailable diagnostic written, so a retrying worker logs
   // it once. Cleared when TLS works again.
   GTlsLogLock:   TCriticalSection;
   GLastTlsLogged: string = '';
   // The same latch for the "REFUSING ... cannot be verified" line, so a worker
   // retrying every 300 s does not write the Error each time. Cleared when
   // verification can be set up again. Under GTlsLogLock.
   GLastRefusalLogged: string = '';

function CreateWireBodyStream(const aBody: string): TRawByteStringStream;
begin
   Result := TRawByteStringStream.Create(ToWire(aBody));
end;

function MaskSecret(const aSecret: string): string;
begin
   if aSecret = '' then
      begin
      Result := '(empty)';
      end
   else
      begin
      Result := '********';
      end;
end;

function ScrubSecret(const aText, aSecret: string): string;
var
   encoded: string;
begin
   Result := aText;
   if aSecret = '' then
      begin
      Exit;
      end;
   encoded := UTF8Decode(EncodeURLElement(UTF8Encode(aSecret)));
   if encoded <> aSecret then
      begin
      (* UnicodeStringReplace: FPC 3.2.2's SysUtils.StringReplace takes
         AnsiString, which narrowed all three arguments and would have left a
         secret holding a non-ANSI character unmasked. *)
      Result := UnicodeStringReplace(Result, encoded, MaskSecret(aSecret), [rfReplaceAll]);
      end;
   Result := UnicodeStringReplace(Result, aSecret, MaskSecret(aSecret), [rfReplaceAll]);
end;

(* Scrub both credentials out of one piece of text. *)
function ScrubBoth(const aText, aSecret1, aSecret2: string): string;
begin
   Result := ScrubSecret(ScrubSecret(aText, aSecret1), aSecret2);
end;

function RequestTraceLine(const aMethod, aURL, aBearer, aPassword: string): string;
begin
   Result := aMethod + ' ' + ScrubBoth(aURL, aBearer, aPassword);
   if aBearer <> '' then
      begin
      Result := Result + ' Authorization: Bearer ' + MaskSecret(aBearer);
      end;
end;

(* THE WHOLE REQUEST WE SEND, as one DEBUG line: method, URL, the headers we set
  and the body (NY4I, 2026-11-05: "good to see what we actually send to WRL").
  Every credential is masked in all of it, the body included -- a form body can
  carry the password. THIS LOGS WHAT WE SEND AND NOTHING WE RECEIVE: no response
  body and no response header is logged anywhere, at any level (NY4I's ruling). *)
function RequestDebugLine(aWire: THttpWireRequest;
                          const aSecret1, aSecret2: string): string;
begin
   Result := RequestTraceLine(aWire.Method, aWire.URL, aWire.BearerToken,
                              aWire.Password);
   if aWire.UserAgent <> '' then
      begin
      Result := Result + ' User-Agent: ' + aWire.UserAgent;
      end;
   if aWire.ContentType <> '' then
      begin
      Result := Result + ' Content-Type: ' + aWire.ContentType;
      end;
   if aWire.AcceptEncoding <> '' then
      begin
      Result := Result + ' Accept-Encoding: ' + aWire.AcceptEncoding;
      end;
   if aWire.IfNoneMatch <> '' then
      begin
      Result := Result + ' If-None-Match: ' + aWire.IfNoneMatch;
      end;
   if aWire.IfModifiedSince <> '' then
      begin
      Result := Result + ' If-Modified-Since: ' + aWire.IfModifiedSince;
      end;
   if aWire.Username <> '' then
      begin
      Result := Result + ' Authorization: Basic ' +
                ScrubBoth(aWire.Username, aSecret1, aSecret2) + ':' +
                MaskSecret(aWire.Password);
      end;
   if aWire.HasBody then
      begin
      Result := Result + ' Body: ' + ScrubBoth(FromWire(aWire.Body), aSecret1, aSecret2);
      end;
end;

(* The failure line from text rather than an exception: a transport hands back
  the class name and message as data (design 3.1). *)
function FailureLineFromDetail(const aMethod, aURL, aDetail: string;
                               const aSecret1, aSecret2: string): string;
begin
   Result := ScrubBoth(aMethod + ' ' + aURL + ' failed: ' + aDetail, aSecret1, aSecret2);
end;

function RequestFailureLine(const aMethod, aURL: string; aE: Exception;
                            const aSecret1, aSecret2: string): string;
begin
   Result := FailureLineFromDetail(aMethod, aURL, aE.ClassName + ': ' + aE.Message,
                                   aSecret1, aSecret2);
end;


function IsPlainHttpUrl(const aUrl: string): boolean;
begin
   Result := UnicodeSameText(Copy(Trim(aUrl), 1, 7), 'http://');
end;

(* ONE PLACE THAT DECIDES WHETHER A URL MAY BE FETCHED, shared by all three
  verbs.  Returns True and sets AUseTLS when the request may proceed.  It is
  the SCHEME RULE and nothing more: whether TLS can START is the transport's
  question, asked when the request is made.  A refusal sets AFailure. *)
function CheckScheme(const AURL: string;
                     const AAllowInsecure: boolean;
                     out AUseTLS: boolean;
                     out AFailReason: string;
                     out AFailure: THttpFailure;
                     const ASecret: string = '';
                     const ASecret2: string = ''): boolean;
var
   shownUrl: string;
begin
   (* A credential-bearing request names its secret so that nothing logged
     here can carry it, even if a caller ever put it in the URL. *)
   shownUrl := ScrubBoth(AURL, ASecret, ASecret2);
   Result      := False;
   AUseTLS     := False;
   AFailReason := '';
   AFailure    := hfNone;

   if SameText(Copy(AURL, 1, 8), 'https://') then
      begin
      AUseTLS := True;
      end
   else if SameText(Copy(AURL, 1, 7), 'http://') then
      begin
      if not AAllowInsecure then
         begin
         logger.Error('[HTTP] refusing plaintext %s -- the caller must pass '
                      + 'AAllowInsecure to accept an http:// URL', [shownUrl]);
         AFailReason := SDownloadCouldNotStart;
         AFailure    := hfPlaintextNotAllowed;
         Exit;
         end;
      logger.Warn('[HTTP] %s is PLAINTEXT (caller allowed it)', [shownUrl]);
      end
   else
      begin
      logger.Error('[HTTP] %s has no http:// or https:// scheme', [shownUrl]);
      AFailReason := SDownloadCouldNotStart;
      AFailure    := hfBadScheme;
      Exit;
      end;

   Result := True;
end;

(* IS SERVER CERTIFICATE CHECKING WANTED? THE POLICY, in the shared layer; the
  transport applies it (VerifyServer).

  Until 2026-09-09 this program verified NOTHING: Indy's default VerifyMode is
  an empty set, which is SSL_VERIFY_NONE, and FPC's VerifyPeerCert defaults to
  False. Every HTTPS connection accepted whatever certificate was presented --
  including the HamScore upload, which sends the operator's password.

  A FAILURE TO SET IT UP REFUSES THE REQUEST (the transport reports it as
  hfTrustUnavailable or hfVerificationUnavailable; RunTransport logs it). It
  used to be a procedure that logged and RETURNED, and the caller went on to
  make the request unverified -- found in review by Codex, 2026-09-11. The case
  that matters is not the opt-out: an operator who turns checking off has made
  a choice and still gets it. It is verification ON with something missing.
  They asked for verified TLS, the program could not provide it, and it
  connected anyway and said so only in the log. That is worse than the old
  unverified-everywhere state, because a verification setting makes fail-open
  read as a secure default. FAIL CLOSED: the only way to send unverified is to
  ask for it (network.verifyServerCertificates, see uSettingsDeclarations).

  PER DESTINATION (issue 256): aDestinationWants is the destination's own
  choice (THttpRequest.VerifyServer), aDestination its display name for the
  log. THE RULE, written once: verified = (global master ON) AND (the
  destination ON). Global off wins for everything, exactly as before; global
  on lets one destination opt out for itself and nothing else. A request that
  names no destination (a download) passes True. Each opt-out is a Warn line
  naming the destination and the URL (credentials already scrubbed by the
  caller) -- the visible half of the warning is the Preferences / editor
  check box. *)
function VerifyWanted(const aShownUrl: string; aDestinationWants: boolean;
                      const aDestination: string): boolean;
var
   setting:    TSettingBase;
   globalWants: boolean;
   shownName:  string;
begin
   globalWants := True;
   setting     := FindSetting('network.verifyServerCertificates');
   if setting <> nil then
      begin
      (* NO CAST. AsText is already the byte string SameText takes -- my
        first attempt wrapped it in string(), which converted UTF-16 back
        DOWN at the call and turned a safe widening into a narrowing the
        build counts. The compiler was right and I was tidying. *)
      globalWants := (UpperCase(setting.AsText) = 'TRUE') or (setting.AsText = '1');
      end;

   Result := globalWants and aDestinationWants;

   if not globalWants then
      begin
      logger.Warn('[HTTP] server certificate checking is OFF by setting -- '
                  + '%s is not being verified', [aShownUrl]);
      end
   else if not aDestinationWants then
      begin
      shownName := aDestination;
      if shownName = '' then
         begin
         shownName := '(unnamed destination)';
         end;
      logger.Warn('[HTTP] server certificate checking is OFF for %s by its own '
                  + 'setting -- %s is not being verified',
                  [shownName, aShownUrl]);
      end;
end;

(* WHICH TRANSPORT THE OPERATOR ASKED FOR (network.httpTransport: generic, auto
  or platform). Read here, in the shared layer, so the registry stays blind to
  settings; the registry decides what the value means. NO SETTING YET -- the
  startup country-file download runs before the configuration is loaded, and
  the settings registry may not be declared in a tool that links this unit --
  reads as blank, which the registry treats as generic. Read from a worker as
  well as the main thread, like VerifyWanted; it is one short string. *)
function TransportPolicy: string;
var
   setting: TSettingBase;
begin
   Result  := '';
   setting := FindSetting('network.httpTransport');
   if setting <> nil then
      begin
      Result := setting.AsText;
      end;
end;

(* Log a TLS setup refusal ONCE per distinct reason, not once per request: a
  delivery worker retries, and the same diagnostic every few seconds buries the
  log. The text is the kind; a different one is logged again. The latches are
  under a lock because workers and the main thread all arrive here. *)
procedure LogTlsUnavailable(const aShownUrl, aDiagnostic: string);
begin
   GTlsLogLock.Enter;
   try
      if aDiagnostic <> GLastTlsLogged then
         begin
         GLastTlsLogged := aDiagnostic;
         logger.Error('[HTTP] TLS unavailable for %s -- %s',
                      [aShownUrl, aDiagnostic]);
         end
      else
         begin
         (* The diagnostic was already reported; keep the URL of this request
           findable without repeating the sentence. *)
         logger.Debug('[HTTP] TLS still unavailable for %s', [aShownUrl]);
         end;
   finally
      GTlsLogLock.Leave;
   end;
end;

procedure LogVerificationRefused(const aShownUrl, aWhy: string);
begin
   (* THE OPERATOR ASKED FOR VERIFICATION AND WE CANNOT PROVIDE IT, so the
     request does not happen. The reason NAMES THE HOST and the exact setup
     failure, because "could not verify" without either is not actionable
     -- the fix is usually a missing CA bundle and the operator needs to be
     told that, not told to check a setting they already set correctly. *)
   GTlsLogLock.Enter;
   try
      if aWhy <> GLastRefusalLogged then
         begin
         GLastRefusalLogged := aWhy;
         logger.Error('[HTTP] REFUSING %s -- server certificates cannot be '
                      + 'verified (%s). To proceed unverified, clear the '
                      + '"Verify the server''s certificate" box of the '
                      + 'destination (or network.verifyServerCertificates in '
                      + 'settings\tr4w.json for a download).',
                      [aShownUrl, aWhy]);
         end
      else
         begin
         logger.Debug('[HTTP] still REFUSING %s -- same reason as logged', [aShownUrl]);
         end;
   finally
      GTlsLogLock.Leave;
   end;
end;

procedure ClearTlsLatches(aClearTls, aClearRefusal: boolean);
begin
   GTlsLogLock.Enter;
   try
      if aClearTls then
         begin
         (* TLS works, so the next failure is a new episode and is logged. *)
         GLastTlsLogged := '';
         end;
      if aClearRefusal then
         begin
         GLastRefusalLogged := '';
         end;
   finally
      GTlsLogLock.Leave;
   end;
end;

(* THE ONE PLACE A REQUEST GOES TO THE TRANSPORT, for all three verbs.

  Decides whether checking is wanted, hands the exchange over, and turns the
  transport's answer into what the verbs need: True when it ANSWERED; else
  aFailure, an operator-facing aFailReason, and aRefusalLogged = True when the
  failure was a setup refusal that has already been logged here (the verb then
  writes no line of its own). Any other failure is the verb's to log, because
  each verb's line has its own shape. *)
function RunTransport(aWire: THttpWireRequest; aSink: TStream;
                      aResult: THttpWireResult;
                      const aSecret1, aSecret2: string;
                      aDestinationWants: boolean;
                      const aDestination: string;
                      out aFailure: THttpFailure;
                      out aFailReason: string;
                      out aRefusalLogged: boolean): boolean;
var
   transport: TPlatformHttpTransport;
   shownUrl:  string;
   useTLS:    boolean;
begin
   aFailReason    := '';
   aRefusalLogged := False;
   shownUrl       := ScrubBoth(aWire.URL, aSecret1, aSecret2);
   useTLS         := IsHttpsUrl(aWire.URL);

   aWire.VerifyServer := True;
   if useTLS then
      begin
      aWire.VerifyServer := VerifyWanted(shownUrl, aDestinationWants, aDestination);
      end;

   (* ONE REQUEST LOG FOR ALL THREE VERBS: the line is written here, the one
     place every request passes, and nowhere else. *)
   logger.Debug('[HTTP] request %s', [RequestDebugLine(aWire, aSecret1, aSecret2)]);

   transport := ActiveHttpTransport(TransportPolicy);
   if transport = nil then
      begin
      aResult.Clear;
      aResult.Failure      := hfOther;
      aResult.ErrorMessage := 'no HTTP transport is available';
      end
   else
      begin
      transport.Execute(aWire, aSink, aResult);
      end;

   aFailure := aResult.Failure;
   Result   := aFailure = hfNone;

   if useTLS then
      begin
      ClearTlsLatches(aFailure <> hfTlsUnavailable,
                      aWire.VerifyServer and
                      (not (aFailure in [hfTlsUnavailable, hfTrustUnavailable,
                                         hfVerificationUnavailable])));
      end;

   case aFailure of
      hfNone:
         begin
         end;
      hfTlsUnavailable:
         begin
         LogTlsUnavailable(shownUrl, ScrubBoth(aResult.ErrorMessage, aSecret1, aSecret2));
         aFailReason    := SDownloadNoSSLLibrary;
         aRefusalLogged := True;
         end;
      hfTrustUnavailable, hfVerificationUnavailable:
         begin
         LogVerificationRefused(shownUrl, ScrubBoth(aResult.ErrorMessage, aSecret1, aSecret2));
         aFailReason    := SysUtils.Format(SDownloadCannotVerify,
                                           [ScrubBoth(aResult.ErrorMessage, aSecret1, aSecret2)]);
         aRefusalLogged := True;
         end;
      hfTlsLibraryFault:
         begin
         (* The one failure an operator can act on keeps its own sentence. It
           is the residue of a TLS failure that only shows itself once bytes
           are moving. *)
         aFailReason := SDownloadNoSSLLibrary;
         end;
   else
      begin
      aFailReason := aResult.ErrorMessage;
      end;
   end;
end;

function DownloadFileToPath(const AURL, ATargetFile: string;
                            out AFailReason: string;
                            const AAllowInsecure: boolean = False): boolean;
var
   wire:    THttpWireRequest;
   res:     THttpWireResult;
   fs:      TFileStream;
   tmpFile: string;
   useTLS:  boolean;
   failure: THttpFailure;
   refusalLogged: boolean;
begin
   Result      := False;
   AFailReason := '';
   tmpFile     := ATargetFile + '.tmp';

   (* SCHEME FIRST, AND REFUSE BEFORE OPENING ANYTHING: the .tmp file must not
     be created for a request that is never going to be made.

     THIS USED TO BE WRITTEN OUT HERE, and when the GET and POST verbs arrived
     I copied it rather than calling it -- which is the mistake this file's own
     header warns about, made while adding the routine that fixes it. One
     scheme rule, one place, three verbs. *)
   if not CheckScheme(AURL, AAllowInsecure, useTLS, AFailReason, failure) then
      begin
      Exit;
      end;

   wire := THttpWireRequest.Create;
   res  := THttpWireResult.Create;
   try
      wire.Method          := 'GET';
      wire.URL             := AURL;
      wire.UserAgent       := 'TR4W';
      wire.FollowRedirects := True;
      wire.AcceptAnyStatus := False;

      // TIMEOUTS ARE NOT OPTIONAL.  Indy's default is to wait forever, which
      // was merely untidy while every caller was a background thread -- a stuck
      // fetch simply never posted its completion and nobody noticed.  It is a
      // real hazard for the synchronous startup callers: a connection that is
      // accepted and then black-holed (a captive portal, a firewall that drops
      // rather than refuses) would hang TR4W before it has a window, showing
      // the operator nothing and offering no way to cancel.
      //
      // Generous rather than tight: the files fetched here are a few MB.
      wire.ConnectMs := 15000;   // ms
      wire.IOMs      := 30000;   // ms

      try
         fs := TFileStream.Create(tmpFile, fmCreate);
      except
         on E: Exception do
            begin
            logger.Error('[HTTP] %s -> %s failed: %s: %s',
                         [AURL, ATargetFile, E.ClassName, E.Message]);
            AFailReason := E.Message;
            Exit;
            end;
      end;
      try
         Result := RunTransport(wire, fs, res, '', '', True, '', failure,
                                AFailReason, refusalLogged);
      finally
         fs.Free;
      end;

      if not Result then
         begin
         (* The path matters as much as the message: "download failed" alone
           does not tell the operator whether the network or the folder is the
           problem, and an unwritable install directory looks identical to an
           unreachable host from the outside. A setup refusal was logged by
           RunTransport. *)
         if not refusalLogged then
            begin
            logger.Error('[HTTP] %s -> %s failed: %s',
                         [AURL, ATargetFile, res.Detail]);
            end;
         SysUtils.DeleteFile(tmpFile);
         Exit;
         end;

      // Atomic replace: only remove the live file once .tmp is fully written
      SysUtils.DeleteFile(ATargetFile);
      Result := RenameFile(tmpFile, ATargetFile);
      if not Result then
         begin
         logger.Error('[HTTP] %s fetched but could not be renamed to %s',
                      [tmpFile, ATargetFile]);
         AFailReason := SDownloadRenameFailed;
         end;
   finally
      res.Free;
      wire.Free;
   end;
end;

function DownloadFileConditional(const AURL, ATargetFile, AUserAgent: string;
                                 const AIfNoneMatch, AIfModifiedSince: string;
                                 out AETag, ALastModified, AContentType: string;
                                 out AStatus: integer;
                                 out AFailReason: string): TConditionalDownloadOutcome;
var
   wire:    THttpWireRequest;
   res:     THttpWireResult;
   fs:      TFileStream;
   useTLS:  boolean;
   failure: THttpFailure;
   refusalLogged: boolean;
   answered: boolean;
begin
   Result       := cdoTransportFail;
   AETag        := '';
   ALastModified := '';
   AContentType := '';
   AStatus      := 0;
   AFailReason  := '';

   if not CheckScheme(AURL, False, useTLS, AFailReason, failure) then
      begin
      Exit;
      end;

   wire := THttpWireRequest.Create;
   res  := THttpWireResult.Create;
   try
      wire.Method          := 'GET';
      wire.URL             := AURL;
      wire.UserAgent       := AUserAgent;
      wire.IfNoneMatch     := AIfNoneMatch;
      wire.IfModifiedSince := AIfModifiedSince;
      wire.FollowRedirects := True;
      wire.AcceptAnyStatus := True;
      wire.ConnectMs       := 15000;
      wire.IOMs            := 30000;

      try
         fs := TFileStream.Create(AnsiString(ATargetFile), fmCreate);
      except
         on E: Exception do
            begin
            logger.Error('[HTTP] %s -> %s failed: %s: %s',
                         [AURL, ATargetFile, E.ClassName, E.Message]);
            AFailReason := E.Message;
            Exit;
            end;
      end;
      try
         answered := RunTransport(wire, fs, res, '', '', True, '', failure,
                                  AFailReason, refusalLogged);
      finally
         fs.Free;
      end;

      if not answered then
         begin
         if not refusalLogged then
            begin
            logger.Error('[HTTP] GET %s failed: %s', [AURL, res.Detail]);
            end;
         AStatus := res.StatusCode;
         SysUtils.DeleteFile(ATargetFile);
         Exit;
         end;

      AStatus       := res.StatusCode;
      AETag         := res.ETag;
      ALastModified := res.LastModified;
      AContentType  := res.ContentType;
      case res.StatusCode of
         200:
            begin
            Result := cdoUpdated;
            end;
         304:
            begin
            Result := cdoNotModified;
            end;
         404:
            begin
            Result := cdoNotFound;
            end;
      else
         begin
         Result := cdoHttpError;
         end;
      end;
      if Result <> cdoUpdated then
         begin
         SysUtils.DeleteFile(ATargetFile);
         end;
   finally
      res.Free;
      wire.Free;
   end;
end;

function HttpGetText(const AURL: string;
                     out AText: string;
                     out AFailReason: string;
                     const AUserAgent: string = 'TR4W';
                     const AConnectMs: integer = 15000;
                     const AIOMs: integer = 30000): boolean;
var
   wire:    THttpWireRequest;
   res:     THttpWireResult;
   useTLS:  boolean;
   failure: THttpFailure;
   refusalLogged: boolean;
begin
   Result := False;
   AText  := '';

   if not CheckScheme(AURL, False, useTLS, AFailReason, failure) then
      begin
      Exit;
      end;

   wire := THttpWireRequest.Create;
   res  := THttpWireResult.Create;
   try
      wire.Method          := 'GET';
      wire.URL             := AURL;
      wire.UserAgent       := AUserAgent;
      wire.FollowRedirects := True;
      wire.AcceptAnyStatus := False;
      wire.ConnectMs       := AConnectMs;
      wire.IOMs            := AIOMs;

      Result := RunTransport(wire, nil, res, '', '', True, '', failure,
                             AFailReason, refusalLogged);
      if Result then
         begin
         AText := FromWire(res.Body);
         end
      else if not refusalLogged then
         begin
         logger.Error('[HTTP] GET %s failed: %s', [AURL, res.Detail]);
         end;
   finally
      res.Free;
      wire.Free;
   end;
end;

function THttpRequest.GetTlsUnavailable: boolean;
begin
   Result := Failure = hfTlsUnavailable;
end;

procedure THttpRequest.SetTlsUnavailable(aValue: boolean);
begin
   if aValue then
      begin
      Failure := hfTlsUnavailable;
      end
   else if Failure = hfTlsUnavailable then
      begin
      Failure := hfNone;
      end;
end;

function THttpRequest.GetTrustBundleMissing: boolean;
begin
   Result := Failure = hfTrustUnavailable;
end;

procedure THttpRequest.SetTrustBundleMissing(aValue: boolean);
begin
   if aValue then
      begin
      Failure := hfTrustUnavailable;
      end
   else if Failure = hfTrustUnavailable then
      begin
      Failure := hfNone;
      end;
end;

function THttpRequest.NothingSent: boolean;
begin
   Result := uHttpTransport.NothingSent(Failure);
end;

constructor THttpRequest.Create(const aURL: string);
begin
   inherited Create;
   URL         := aURL;
   Method      := 'POST';
   FollowRedirects := False;
   VerifyServer := True;   (* a destination opts OUT, never in *)
   MaxResponseBytes := 1024 * 1024;
   ContentType := 'application/x-www-form-urlencoded';
   UserAgent   := 'TR4W';
   ConnectMs   := 15000;
   IOMs        := 30000;
   StatusCode  := 0;
   Failure     := hfNone;
end;

constructor THttpPost.Create(const aURL: string);
begin
   inherited Create(aURL);
   FollowRedirects := True;
   MaxResponseBytes := 0;
end;

function THttpRequest.Send: boolean;
var
   wire:    THttpWireRequest;
   res:     THttpWireResult;
   useTLS:  boolean;
   refusalLogged: boolean;
begin
   Result     := False;
   Response   := '';
   ResponseStatusText := '';
   FailReason := '';
   StatusCode := 0;
   RetryAfter := '';
   RequestId := '';
   ETag := '';
   LastModified := '';
   ResponseContentType := '';
   FinalURL   := '';
   ErrorDetail := '';
   Failure    := hfNone;

   if (BearerToken <> '') and
      ((Pos('https://', LowerCase(URL)) <> 1) or FollowRedirects or
       (Pos(#13, BearerToken) > 0) or (Pos(#10, BearerToken) > 0)) then
      begin
      FailReason := 'Bearer authentication requires HTTPS without redirects and a valid token';
      Failure    := hfAuthPolicy;
      (* Reported, not silent: the delivery worker stops on this, and the log is
        where an operator finds out why. The token is scrubbed out of the URL. *)
      logger.Error('[HTTP] refusing %s -- a bearer token needs https, no '
                   + 'redirects and no line break in the token',
                   [ScrubBoth(URL, BearerToken, Password)]);
      Exit;
      end;

   if not CheckScheme(URL, AllowInsecure, useTLS, FailReason, Failure,
                      BearerToken, Password) then
      begin
      Exit;
      end;

   wire := THttpWireRequest.Create;
   res  := THttpWireResult.Create;
   try
      wire.Method           := Method;
      wire.URL              := URL;
      wire.UserAgent        := UserAgent;
      wire.ContentType      := ContentType;
      wire.AcceptEncoding   := AcceptEncoding;
      wire.IfNoneMatch      := IfNoneMatch;
      wire.IfModifiedSince  := IfModifiedSince;
      wire.Username         := Username;
      wire.Password         := Password;
      wire.BearerToken      := BearerToken;
      wire.Body             := ToWire(Body);
      wire.HasBody          := True;
      wire.FollowRedirects  := FollowRedirects;
      wire.AcceptAnyStatus  := True;
      wire.ConnectMs        := ConnectMs;
      wire.IOMs             := IOMs;
      wire.MaxResponseBytes := MaxResponseBytes;

      if RunTransport(wire, nil, res, BearerToken, Password, VerifyServer,
                      Destination, Failure, FailReason, refusalLogged) then
         begin
         (* Post allows EVERY status code (AcceptAnyStatus), so a 400 does not
           fail: Send returns True, StatusCode holds 400 and Response holds the
           server's own explanation. *)
         Response   := FromWire(res.Body);
         StatusCode := res.StatusCode;
         ResponseStatusText := res.StatusText;
         RetryAfter := res.RetryAfter;
         RequestId  := res.RequestId;
         ETag := res.ETag;
         LastModified := res.LastModified;
         ResponseContentType := res.ContentType;
         Result     := True;
         end
      else if not refusalLogged then
         begin
         (* TRANSPORT FAILURES ONLY (no route, TLS, timeout): a non-2xx answer
           is not one. The status is recorded anyway (0 when the server never
           answered), so a caller can tell "the server said no" from "the
           server was not there". *)
         StatusCode := res.StatusCode;
         (* THE URL AND THE LIBRARY'S MESSAGE ARE LOGGED FOR EVERY REQUEST,
           credentialed or not (NY4I, 2026-11-05: log the URL, mask the bearer
           token). What makes that safe is the scrub: a server's error text can
           echo what we sent. *)
         logger.Error('[HTTP] %s',
                      [FailureLineFromDetail(Method, URL, res.Detail,
                                             BearerToken, Password)]);
         if (BearerToken <> '') or Sensitive then
            begin
            (* The operator-facing reason stays generic for a credentialed
              request: it is shown in dialogs and stored with the QSO. *)
            FailReason := 'Authenticated HTTP request failed (' + res.ErrorClass + ')';
            end;
         end;
      (* WHAT A READ-ONLY CALLER MAY SHOW (the URL test, issue 251): the address
        that answered after a redirect, and the transport's own words for a
        failure. The words are scrubbed of this request's credentials, and a
        credentialed caller should still prefer FailReason. *)
      FinalURL    := res.FinalURL;
      ErrorDetail := ScrubBoth(res.Detail, BearerToken, Password);
   finally
      res.Free;
      wire.Free;
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
   logger := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   GTlsLogLock := TCriticalSection.Create;

finalization
   FreeAndNil(GTlsLogLock);

end.
