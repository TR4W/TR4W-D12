# HTTP/HTTPS: a platform transport behind `uHTTPDownload` (issue 224)

**Status (2026-11-05): S0, S1a and S1b are BUILT; S1c and everything from S2 on is
DESIGN ONLY** and waits for NY4I's answers to section 8. S1a is
`uHttpTransport` (the contract and the registry), `uHttpTransportGeneric` (the FPC + OpenSSL
path moved out of `uHTTPDownload`, behaviour unchanged) and the tests `uTestHttpTransport` and
`uTestFakeTransport`; the stage table says what moved. Written against `4dc105b9`
(the #221 stopgap, which is stage S0 below). Issue 224 is the request; issue 221 is the
failure that prompted it. NY4I's rulings of 2026-11-05: open to a platform helper unit
with IFDEFs for HTTP/HTTPS if it makes a better operator experience, and **accepted the
staged plan: stopgap (done), this document, Windows first.**

**Update 2026-11-06 (NY4I's approval condition on issue 224):** section 10 checks every other
external logger and destination against this design (finding: the HTTP seam fits the HTTP
destinations and nothing else, and no change to section 3 is needed); section 6 gained exit
criteria per platform; section 8 gained questions 11 to 15.

**Update 2026-11-08 (section 10 is partly overtaken by the tree):** ACLog (issue 33, commit
`51fd7b6d`) is no longer a stub: it is a built durable provider over raw TCP, one connection per
contact, `<CMD><ADDADIFRECORD>`, no acknowledgement, so it is OUT of this seam's scope exactly
as section 10 predicted (see `.claude/agents/integrations.md`, "ACLog"). Cloudlog/Wavelog
(issue 204, `uCloudlogClient`) is built and is an ordinary `THttpRequest` caller: its key
travels in the JSON body via `Password` + `Sensitive`, https only, global TLS setting only;
the per-destination verify and plain-http choices of section 10.3 finding 4 were NOT added
(questions 12 and 13 remain NY4I's). Read section 10's ACLog and Cloudlog rows with this
note; the rest of section 10 stands.

**Evidence key.** Every claim is marked **read** (a file and line I opened), **inference**
(reasoned from something read, not run) or **unverified** (a belief from outside this
tree, to be checked before anyone relies on it). Line numbers are at `4dc105b9` and drift;
the identifier beside each is the stable handle. Nothing in this document is a count that
a later commit can falsify; where a number matters, the command that measures it is given.

## 1. What this is for, in one page

Every HTTPS request TR4W makes goes through one unit, `uHTTPDownload`, which drives FPC's
`TFPHTTPClient` over OpenSSL, verified against one shipped file, `cacert.pem` (**read**:
`uTLSTrust.pas` header and `UseVerifiedTLS`; `uHTTPDownload.pas` `THttpRequest.Send`).
That has four consequences an operator can feel:

| consequence | evidence |
|---|---|
| The Windows certificate store is never consulted. A bundle that goes stale between releases is the only trust source. | **read**: `uTLSTrust.pas` header ("THE WINDOWS CERTIFICATE STORE WAS NEVER INVOLVED") |
| On Windows the program ships OpenSSL **1.0.2u** (below). Servers that drop TLS 1.2 cannot be reached. | **read**: file version resource, section 4.5 |
| A missing `cacert.pem` or OpenSSL library means no HTTPS at all, on any platform. | **read**: `CheckScheme`, `ApplyTLSVerification` |
| macOS ships no OpenSSL, so `TR4W.app` carries and signs its own. | **read**: `uOpenSSLLoader.pas` header; `build-unix.sh` `mac_bundle_openssl` |

The proposal: put a small abstract class between the verbs and the wire, keep the present
OpenSSL path as the `generic` implementation on every platform, and add one platform
implementation at a time (WinHTTP, then NSURLSession, then, probably, nothing new on Linux).
**Callers do not change.** The seam already exists; this document says what is on each side
of it.

## 2. What exists

### 2.1 The seam (all **read**, `src/utils/uHTTPDownload.pas`)

| piece | what it is |
|---|---|
| `DownloadFileToPath(url, target [, reason] [, allowInsecure])` | GET to a file. Atomic (`.tmp` then rename). Synchronous. Never raises. |
| `HttpGetText(url, text, reason [, userAgent, connectMs, ioMs])` | GET to a string. Synchronous. Never raises. |
| `THttpRequest` / `THttpPost` | One request as an object: `URL`, `Method`, `Body`, `ContentType`, `UserAgent`, `Username`/`Password` (Basic), `BearerToken`, `Sensitive`, `FollowRedirects`, `MaxResponseBytes`, `AcceptEncoding`, `AllowInsecure`, `ConnectMs`, `IOMs`. Answers: `Response`, `StatusCode`, `ResponseStatusText`, `FailReason`, `RetryAfter`, `RequestId`, and the two proof flags `TlsUnavailable` and `TrustBundleMissing`. `Send` is `virtual`, never raises, returns True for ANY HTTP status (the status is in `StatusCode`). |
| `CheckScheme` | the one scheme rule: https; http only if the caller says `AllowInsecure`; anything else refused. Also loads TLS (`EnsureOpenSSL`). |
| `ApplyTLSVerification` | fail closed: with checking on (`network.verifyServerCertificates`) a request that cannot be verified is not made. |
| `MaskSecret` / `ScrubSecret` / `RequestFailureLine` / `RequestTraceLine` | the secrets rule: URL logged, token and password scrubbed out of ALL logged text, raw and URL-encoded. |

The two services that classify by outcome, Club Log and WRL, build their request through a
`virtual` `NewRequest` (**read**: `uClubLogClient.pas:11,52`, `uWRLClient.pas:19,42`) and
the tests override `THttpRequest.Send` (`uTestHttpSecrets.pas`, `TNoBundleRequest`). **That
virtual pair is the fake-transport precedent already in the tree** and section 5 builds on it.

### 2.2 Every caller

Re-measure with `rg -l -i "uHTTPDownload" tr4w --glob "*.pas"` and
`rg -n "HttpGetText|DownloadFileToPath|THttpPost|THttpRequest" tr4w/src --glob "*.pas"`.
The product callers at `4dc105b9`:

| caller | verb | thread | scheme | secrets | redirects | body / response size | notes |
|---|---|---|---|---|---|---|---|
| Version check, `uCheckLatestVersion.pas:109` | `HttpGetText` | **main thread**: the Help-menu handler `MainUnit.pas:5968` calls it directly (**read**). The comment above it about sleeping 2 s is stale. | https `tr4w.net/version.json` | none | followed (`ApplyDefaults`, line 563) | small document, unbounded | 5000/5000 ms, custom User-Agent. A slow server freezes the UI for up to the sum. |
| CTY feed check, `uCTYUpdate.pas:295` | `HttpGetText` | worker `TCTYVersionCheckThread` | https `country-files.com/feed/` | none | followed | small, unbounded | default 15000/30000 ms |
| CTY download, `uCTYUpdate.pas:353` and `:422` | `DownloadFileToPath` | worker `TCTYDownloadThread`; **and synchronous before the message loop** at `uProgramMain.pas:617` | https `country-files.com/cty/cty.dat` | none | followed | a file (about 106 KB per the comment in `uHTTPDownload.pas`), unbounded | startup path: must not hang (timeouts exist for that reason) |
| TRMASTER, `uTRMasterUpdate.pas:120` | `DownloadFileToPath` | worker `TTRMasterDownloadThread` | https `tr4w.net/TRMASTER.DTA` | none | followed | file, size not measured | |
| POTA parks, `uPOTAParks.pas:744` | `DownloadFileToPath` | worker `TPOTADownloadThread` | https `pota.app/all_parks_ext.csv` | none | followed | file, size not measured | |
| SCP upload, `uSuperCheckPartialFileUpload.pas:235` | `THttpPost` | called from `postunit.pas:735` right after a `YesOrNo` dialog, so **main thread (inference)** | https `supercheckpartial.com` | none (a shared key is inside the JSON body) | followed (`THttpPost` default) | JSON body of the whole Cabrillo file; response unbounded | non-2xx is an answer: `Send` True, body is the server's reason |
| HamScore, `uHamScore.pas:736` | `THttpPost` | worker `THamScoreUploader` (**read**: `Execute`, line 943; 2-minute cycle per the integrations agent) | **default is plain `http://scoredistributor.net/`** (`uSettingsModel.pas:4966`); `AllowInsecure := True` | **Basic auth, username and password**; `Accept-Encoding: gzip,deflate` | followed | XML body; response unbounded | the only caller that sends a password, and by default in the clear |
| Contest score post, `uGetScores.pas:140` | `THttpPost` | worker, `tCreateThread` at line 111 | default `https://post.contestonlinescore.com/post/` (`uSettingsModel.pas:4978`); operator may type `http://`; `AllowInsecure := True` | none | followed | form body, response saved to a file | |
| Club Log, `uClubLogClient.pas:69-81` | `THttpRequest` | delivery worker (`TExternalDeliveryWorker = class(TThread)`) | https only | **bearer token** | **none** | response capped at 4096 | 5000/10000 ms. Outcome drives `doRetry` / `doUncertain` / `doFailed`. |
| WRL, `uWRLClient.pas:62-71` | `THttpRequest` | delivery worker | https only | **bearer token** | **none** | default cap (1 MB) | 5000/10000 ms. Same classification, plus `Retry-After` and `X-Request-Id`. |

**Not product callers:** `tr4w/test/integration/tls-verify-probe.pas` and
`tls-nobundle-probe.pas` (hand-run probes), and the unit tests.

**Proxies.** No caller sets one and `uHTTPDownload` has no proxy code (**read**: no
occurrence of "proxy" in it; `TFPHTTPClient` has a `Proxy` property, `fphttpclient.pp:50,100`,
left empty). An operator behind a proxy that does not transparently forward cannot use any
of this today (**inference**; nobody has reported it, which is not evidence nobody needs it).

**The only live consumers of OpenSSL in the tree** are `uHTTPDownload`, `uTLSTrust` and
`uOpenSSLLoader` (**read**: a search of every `uses` clause in `src` and `tr4w.lpr`;
Indy is still linked for sockets but no live code uses its SSL units). That is what makes
the DLLs removable from a platform that stops using the generic transport.

### 2.3 The present outcome model is too coarse, and the evidence is in the tree

The two flags, `TlsUnavailable` and `TrustBundleMissing`, mean "nothing was sent". But
**other refusals also send nothing and set neither flag**, so Club Log and WRL classify them
as "uncertain":

| refusal | where (**read**) | flags set |
|---|---|---|
| Bearer token with a non-https URL, with redirects on, or with a CR/LF in the token | `uHTTPDownload.pas:776-782` (`Exit` with `FailReason`) | neither |
| Plaintext refused (`http://` without `AllowInsecure`), or no scheme | `CheckScheme`, lines 386-399 | neither (`TlsUnavailable := useTLS` is False) |
| Verification refused for a reason other than the bundle, such as an OpenSSL with no `X509_check_host` | `ApplyTLSVerification` false, then line 806 `TrustBundleMissing := not TrustBundleUsable` is False | neither |

Club Log then ends at `doUncertain` with `Pause` on status 0 (`uClubLogClient.pas:132-135`),
and WRL makes any POST `doUncertain` on `not sent` (`uWRLClient.pas:107-111`). For a
configuration error that sent nothing, "uncertain, needs review" is the wrong answer: it
parks the delivery for a human where a retry or a plain failure would do. The three paths
are all reachable only from a code change or an unusual machine today, so this is a latent
defect and not a field report (**inference**). It is the concrete reason the interface in
section 3 replaces two booleans with one proof.

**A second gap, and it cannot be fixed in the generic transport.** A certificate that
OpenSSL itself rejects fails during the handshake and the exception reaches the caller as
an ordinary error: `VerifyCertificate` is never called, and the code says so
(`uTLSTrust.pas:606-621`). The handshake precedes any request byte, so nothing was sent,
but the generic transport cannot tell that from a connection reset mid-request. It must
report "may have been sent" for it. A platform transport that gets a distinct error (WinHTTP
`ERROR_WINHTTP_SECURE_FAILURE`) can prove it.

### 2.4 Behaviour today that belongs to FPC's client, and a new transport must reproduce it

None of this is in TR4W's own code, so none of it is in a test, and a new transport changes
it silently. Each line is a contract line in section 3.3.

| behaviour | evidence |
|---|---|
| Basic auth is sent **preemptively**: the `Authorization` header is built before the first request. WinHTTP's `WinHttpSetCredentials` is challenge-driven, so a WinHTTP transport must add the header itself. | **read**: `fphttpclient.pp:670-672` |
| **No decompression.** `Accept-Encoding: gzip,deflate` is sent by HamScore and the body is returned as received. A transport that turns on automatic decompression (`WINHTTP_OPTION_DECOMPRESSION`, `NSURLSession` default) changes what `Response` holds. | **read**: no gzip/deflate handling anywhere in `fphttpclient.pp` |
| Redirects: followed up to 16 (`DefMaxRedirects`) when `AllowRedirect`, and `CheckScheme` has seen only the FIRST URL. Whether a redirect from `https` to `http` is followed is not checked anywhere in TR4W. | **read**: `fphttpclient.pp:32-33, 1398-1413`; **inference**: the redirect target is requested with the scheme it names (`:1275-1288`), so an https-to-http downgrade is possible for the callers that follow redirects. WinHTTP's default policy (`WINHTTP_OPTION_REDIRECT_POLICY_DISALLOW_HTTPS_TO_HTTP`) forbids it. See open question 5. |
| Timeouts: `ConnectTimeout` and `IOTimeout`, in milliseconds, set from `ConnectMs` / `IOMs`. | **read**: `ApplyDefaults`; `fphttpclient.pp:279-280` |
| Response cap: only `THttpRequest.Send` enforces `MaxResponseBytes` (a stream that raises). Downloads and `HttpGetText` are unbounded. | **read**: `TBoundedHttpResponse`; `DownloadFileToPath` writes straight to a file stream |
| Verify-off: with `network.verifyServerCertificates` false the request proceeds unverified and a Warn line says so. | **read**: `ApplyTLSVerification` |
| `Sensitive` makes the operator-facing `FailReason` generic. **No caller sets it**; bearer requests get the same treatment by `BearerToken <> ''`. | **read**: `Send` lines 861-866; a search for `Sensitive :=` finds only the declaration |
| User-Agent is per request, except `DownloadFileToPath`, which hard-codes `TR4W` (the parameter does not exist on it). | **read** |

## 3. The interface

### 3.1 Two layers, and what each may know

| shared layer (`uHTTPDownload`, platform-blind) | transport (one unit per platform) |
|---|---|
| the three verbs and `THttpRequest` | opening the connection, TLS, the OS trust decision |
| `CheckScheme`: scheme rule, plaintext rule, bearer policy | proxy resolution |
| the verify-or-not **policy** (`network.verifyServerCertificates`) | applying that policy (what "verified" means here) |
| atomic file write, `FromWire`/`ToWire`, the size cap | timeouts, cancellation, redirects as the platform does them |
| **all logging of anything derived from a request**, and `MaskSecret` / `ScrubSecret` | reporting what happened, as data |
| turning a failure kind into `NothingSent` | knowing whether it can PROVE nothing was sent |

**The transport never logs the URL, a header, the body or an exception message that could
echo one.** It returns them; the shared layer scrubs and logs. That keeps the secrets rule
in one place instead of three, and `uTestHttpSecrets` can pin it once by giving a transport
an exception whose text contains the token.

### 3.2 The types (a sketch; names may change at S1)

```pascal
   (* WHAT HAPPENED, as the transport knows it. The shared layer, and only the
      shared layer, decides which of these prove that nothing was sent. *)
   THttpFailure = (
      hfNone,                  (* an answer arrived; StatusCode is its status *)
      hfTlsUnavailable,        (* https asked for, the TLS stack cannot start *)
      hfTrustUnavailable,      (* the trust source is missing or unreadable (cacert.pem) *)
      hfVerificationFailed,    (* the handshake rejected the certificate: chain, name, date *)
      hfPlaintextNotAllowed,   (* shared layer: http:// without AllowInsecure *)
      hfBadScheme,             (* shared layer *)
      hfAuthPolicy,            (* shared layer: bearer needs https, no redirects *)
      hfNameNotResolved,
      hfCannotConnect,
      hfConnectTimedOut,       (* provably before any request byte *)
      hfIOTimedOut,            (* NOT provable: the request may be half sent *)
      hfConnectionLost,        (* after connect: NOT provable *)
      hfResponseTooLarge,      (* an answer began, so the server saw the request *)
      hfCancelled,
      hfOther);

   (* One request, in. The caller-facing THttpRequest stays as it is and the
      shared layer fills this from it. A class, not a record. *)
   THttpWireRequest = class
   public
      Method, URL, UserAgent, ContentType, AcceptEncoding: string;
      Username, Password, BearerToken: string;   (* the transport SENDS these; it never logs them *)
      Body: RawByteString;                        (* the wire bytes, from CreateWireBodyStream *)
      FollowRedirects, VerifyServer: boolean;
      ConnectMs, IOMs: integer;
      MaxResponseBytes: Int64;                    (* 0 = unlimited *)
   end;

   (* One answer, out. *)
   THttpWireResult = class
   public
      Failure: THttpFailure;
      Detail: string;                  (* raw diagnostic; UNSCRUBBED; the shared layer scrubs it *)
      StatusCode: integer;
      StatusText, RetryAfter, RequestId: string;
      Body: RawByteString;             (* for a download the transport streams to a sink instead *)
   end;

   TPlatformHttpTransport = class abstract
   public
      class function Id: string; virtual; abstract;                 (* 'winhttp', 'generic' ... *)
      function Available(out aWhy: string): boolean; virtual; abstract;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); virtual; abstract;
   end;
```

`aSink` is where a download's bytes go (a `TFileStream` for a file, a bounded stream for a
cap). One path serves the file and the text verbs, as `HttpMethod` already does for FPC.
This is a sketch for review, not a signature to type in: for instance `Body: RawByteString`
should be a stream if a platform wants to avoid a copy of a whole Cabrillo file.

### 3.3 The contract (a transport must satisfy every line; the shared test suite checks them)

1. **Synchronous.** `Execute` returns when the exchange is finished. A platform API that is
   asynchronous is bridged inside the transport and **never on the main thread's message
   loop** (section 4.3). `Execute` is called from the main thread by two callers (version
   check, startup CTY) and from workers by the rest; it must be safe from any thread and
   re-entrant across threads (one `Execute` per thread at a time, no shared mutable state
   without a lock).
2. **Never raises.** Every platform error becomes a `THttpFailure` and a `Detail`.
3. **Nothing sent is a claim, and a claim must be proved.** A transport reports
   `hfConnectTimedOut`, `hfCannotConnect`, `hfNameNotResolved`, `hfTlsUnavailable`,
   `hfTrustUnavailable` or `hfVerificationFailed` ONLY when no request byte left the
   machine. When unsure it reports `hfConnectionLost`, `hfIOTimedOut` or `hfOther`. The
   shared layer's `NothingSent(failure)` is one `case`, and it is the only place that maps.
   The default is "may have been sent", because the cost of the wrong answer is a QSO
   delivered twice or never.
4. **Any HTTP status is an answer.** `hfNone` with the status; a 4xx or 5xx is not a transport
   failure (matches `Send` returning True today).
5. **Timeouts.** `ConnectMs` bounds connect and handshake; `IOMs` bounds each wait for the
   next byte (matching FPC's `IOTimeout`, not a total deadline). A total deadline is not
   offered today and is not added by this work.
6. **Cancellation.** The verbs are not cancellable today, and this work does not add it. The
   interface leaves room (`Cancel` on the transport) because a platform handle can be closed
   from another thread; nothing uses it before S2 is benched.
7. **Response cap.** `MaxResponseBytes > 0` aborts with `hfResponseTooLarge` when exceeded.
   Today only `THttpRequest.Send` enforces it (section 2.4); the shared layer keeps that
   exact behaviour, and the other verbs stay unbounded until someone decides otherwise.
8. **Redirects.** Followed only when `FollowRedirects`. **A redirect from https to http is
   never followed** by a transport that can prevent it; this differs from the generic
   transport today (section 2.4) and is open question 5, so S1 keeps the generic behaviour
   and the contract line is enforced from S2.
9. **No automatic decompression, no cookies, no caching, no credential store.** The body is
   what the server sent. (A platform default that does any of these is switched off.)
10. **Authentication.** Basic is sent preemptively when `Username <> ''`; a bearer token as
    `Authorization: Bearer ...`. Both only over a request the shared layer already vetted.
    Nothing is persisted by the platform.
11. **Verification.** `VerifyServer = True` means the platform's full check: chain to a
    trusted root, host name, validity period. `False` means the operator turned checking
    off (`network.verifyServerCertificates`), and the transport proceeds and says so in
    `Detail`. **A transport must not weaken verification on any other ground**, and it must
    not "fall back" to unverified because its own setup failed (that is the 2026-09-11
    fail-open defect, `uHTTPDownload.pas` header of `ApplyTLSVerification`).
12. **TLS version.** The transport asks for the platform's default range and lets the OS
    choose. **It does not pin TLS 1.2**: on Windows `WINHTTP_OPTION_SECURE_PROTOCOLS` in
    FPC's header stops at TLS 1.2 (`$800`; no 1.3 flag), so setting it would CAP the
    version below what the OS offers (**read**: `winhttp.pp:221-226`).
13. **User-Agent** from the request, and nothing else added by the platform.
14. **Secrets.** See 3.1: no transport logs request-derived text.
15. **Detail is for the log, not the operator.** The operator-facing sentence comes from the
    shared layer (`SDownloadCannotVerify` and the other resourcestrings).
16. **Conditional GET fields (added 2026-11-08 for the call history download).** The wire request
    carries `IfNoneMatch` and `IfModifiedSince` (both `''` = no header) and a transport MUST send
    each as `If-None-Match` / `If-Modified-Since` when set; the wire result carries `ETag`,
    `LastModified` and `ContentType` (the response headers, `''` when absent). All five default
    to `''`, so a transport that never sets them behaves as before. A 304 is an answer
    (line 4) with no body. **The WinHTTP transport (S2) must add the two request headers
    explicitly** (`WinHttpAddRequestHeaders`) and read the three response headers
    (`WinHttpQueryHeaders`); it must not enable a platform cache that would answer the
    conditional itself (line 9). Covered by `Test_ConditionalHeadersGoOutAndComeBack` (the
    generic transport over loopback, including a bodiless 304) and
    `Test_ConditionalDownloadOutcomes` (the shared layer's `DownloadFileConditional`, over the
    fake). The shared layer's `DownloadFileConditional` (outcomes Updated / NotModified /
    NotFound / HttpError / TransportFail) streams the body to a path the CALLER names and never
    renames: the caller validates, then replaces. `DownloadFileToPath` is unchanged.

### 3.4 Registry and selection (the radio-factory pattern, not a case)

ONE registry in a new `uHttpTransport` unit. Each transport unit registers itself from its
`initialization` section, exactly as the radio units do and as the credential vault already
does (**read**: `tr4w.lpr:263-271` lists `uKeychainWindows`, `uKeychainMac` and
`uKeychainLinux` unconditionally; each unit wraps its own body in `{$IFDEF WINDOWS}` etc.,
`uKeychainWindows.pas:305-309`, and registers with `RegisterKeychainBackend`). The same
shape here:

```pascal
   (* uHttpTransport.pas: the registry, no platform knowledge *)
   procedure RegisterHttpTransport(aFactory: THttpTransportFactory; aPreferred: boolean);
   function  ActiveHttpTransport: TPlatformHttpTransport;   (* decided once, logged once *)
```

* `uHttpTransportGeneric` (always compiled, every platform): today's FPC + OpenSSL path.
* `uHttpTransportWinHttp`, `uHttpTransportNSURLSession`: body in `{$IFDEF WINDOWS}` /
  `{$IFDEF DARWIN}`, empty elsewhere. The `.lpr` lists them unconditionally. **No IFDEF in
  the shared unit and no `{$IFDEF}` pile anywhere else**, and the shared layer never asks
  which platform it is (the radio rule: a base class must never ask which model it is).
* The registry knows each transport's `Id`, whether it is `Preferred` on this platform and
  whether `Available`. That is all it knows.

**Selection happens once, at first use, and there is NO per-request fallback.**
Club Log, WRL, HamScore, the score post and the SCP upload are non-idempotent POSTs.
A transport that fails mid-request and is retried on the generic one can send the same QSO
twice, and a "fallback" that hides which transport answered is the silent downgrade this
repository's rule forbids. If the platform transport is unavailable at selection (its
library will not load), the generic one is chosen and **that is logged once at Warn naming
why**. After that, the answer does not change within the session.

### 3.5 How the outcome reaches Club Log and WRL

`THttpRequest` keeps `TlsUnavailable` and `TrustBundleMissing` as **derived properties**
(true when the failure is `hfTlsUnavailable` / `hfTrustUnavailable`), so S1 changes no
caller. It gains `NothingSent: boolean`. Stage S1b then moves Club Log and WRL from the two
flags to `NothingSent`, which fixes the three paths in section 2.3 and is a deliberate
behaviour change with its own pin tests. `OperatorNotice` (`TrustBundleAlertText`) stays
exactly as issue 221 built it, and is raised only for `hfTrustUnavailable`.

## 4. Per platform

### 4.1 Generic (the present path), kept on every platform

Today's `TFPHTTPClient` + `opensslsockets` + `uTLSTrust` + `uOpenSSLLoader` move behind the
interface **unchanged**: same classes, same `cacert.pem` search (`TrustBundlePath`), same
latches, same strings. It is the fallback, the Linux transport (section 4.4), and the
transport the existing tests pin. It stays until a platform transport has been benched and
NY4I decides to drop it for that platform (S5).

### 4.2 Windows

**Choice: WinHTTP, not WinINet.** Both headers are in FPC's `winunits-base`
(`C:\Lazarus\fpc\3.2.2\source\packages\winunits-base\src\winhttp.pp`, `wininet.pp`).
WinHTTP is the server-side, thread-safe client with explicit control of proxy, timeouts and
redirects and no interactive UI or IE dependency; WinINet is the interactive-desktop client
with a shared cache and cookie jar that contract line 9 would have to switch off
(**inference** from the two APIs' purposes; **unverified** against Microsoft's current docs).
The tree already has a Win32 credential-vault unit, so a Win32 boundary behind
`{$IFDEF WINDOWS}` in one unit is established practice. **Handles stay inside the transport
unit** (CLAUDE.md: a Win32 API boundary that is real keeps its handle and says why).

**What `winhttp.pp` declares (all **read**).** The library constant is `winhttp.dll`
(line 45). The functions the transport needs are all present:

| need | functions declared |
|---|---|
| session, connection, request | `WinHttpOpen`, `WinHttpConnect`, `WinHttpOpenRequest`, `WinHttpCloseHandle` |
| send and receive | `WinHttpAddRequestHeaders`, `WinHttpSendRequest`, `WinHttpWriteData`, `WinHttpReceiveResponse`, `WinHttpQueryDataAvailable`, `WinHttpReadData` |
| headers and status | `WinHttpQueryHeaders` with `WINHTTP_QUERY_STATUS_CODE` (19), `WINHTTP_QUERY_STATUS_TEXT` (20), `WINHTTP_QUERY_CUSTOM` (65535), `WINHTTP_QUERY_FLAG_NUMBER` |
| options | `WinHttpSetOption`, `WinHttpQueryOption` |
| proxy | `WinHttpGetIEProxyConfigForCurrentUser`, `WinHttpGetProxyForUrl`, `WinHttpGetDefaultProxyConfiguration`; access types `WINHTTP_ACCESS_TYPE_DEFAULT_PROXY` 0, `NO_PROXY` 1, `NAMED_PROXY` 3, `AUTOMATIC_PROXY` 4 |
| auth (not needed) | `WinHttpSetCredentials`, `WINHTTP_AUTH_SCHEME_BASIC`: challenge-driven, so preemptive Basic is an `Authorization` header added by hand (contract line 10) |
| timeouts | **`WinHttpSetTimes`** (resolve, connect, send, receive). The header has **no** `WINHTTP_OPTION_*_TIMEOUT` constants. See below. |

**Three things the header does not settle, and the first bench or code step must:**

1. **Timeouts.** The header declares `WinHttpSetTimes` (line 735). The documented Win32
   export is `WinHttpSetTimeouts` (**unverified** from memory); whether `winhttp.dll`
   exports a function named `WinHttpSetTimes` is unverified. The safe route is
   `WinHttpSetOption` with the connect / send / receive / resolve timeout option numbers
   declared locally in the transport unit (numbers **unverified here**, to be taken from the
   Windows SDK header when the unit is written). Either way the unit's first act at S2 is a
   run-time check that a 2-second timeout against a black-holed address returns in about 2
   seconds. This is a bench item.
2. **TLS 1.3 and the protocol flags.** The header defines SSL2, SSL3, TLS1, TLS1.1, TLS1.2
   only (`winhttp.pp:221-226`). It does not matter: contract line 12 sets nothing, so the OS
   default range applies, including 1.3 on a Windows that supports it in WinHTTP
   (**unverified** which Windows builds).
3. **Windows 7 and TLS 1.2.** WinHTTP on a Windows 7 SP1 machine does not enable TLS 1.1/1.2
   by default without an update and a registry setting (**unverified**, from memory). The
   repository states no minimum Windows version that I could find (a search of `full.nsi`,
   `README.md`, `docs/INSTALL_WINDOWS.md` and `tr4w/docs/BUILD.md` returned nothing), so
   this is open question 4. The shipped OpenSSL path does TLS 1.2 on a Windows 7 machine
   without any OS setting (section 4.5), which is the one thing the generic transport has
   over WinHTTP, and a reason to keep it selectable.

**How a WinHTTP call is made synchronous, with timeouts (design, not yet run).**
`WinHttpOpen` without `WINHTTP_FLAG_ASYNC` (line 60 is the async flag) gives a session whose
calls block (**unverified** from memory of the documentation). Per request: `WinHttpConnect`
to the host and port, `WinHttpOpenRequest` with `WINHTTP_FLAG_SECURE` (line 61) for https,
`WinHttpSetOption` for redirect policy (`WINHTTP_OPTION_REDIRECT_POLICY_NEVER` when
`FollowRedirects` is False; the default policy forbids https to http, which is contract line
8 for free) and the timeouts, `WinHttpAddRequestHeaders` for Content-Type, Authorization and
Accept-Encoding, `WinHttpSendRequest` with the body (or `WinHttpWriteData` in chunks),
`WinHttpReceiveResponse`, then `WinHttpQueryHeaders` and a `WinHttpReadData` loop into the
sink with the cap check. Every handle is closed in a `finally`. **Proxy:** the default
(`WINHTTP_ACCESS_TYPE_DEFAULT_PROXY`) uses the machine-wide WinHTTP configuration, not the
interactive user's Internet Options (**unverified** from memory); to follow the user's
settings the transport reads `WinHttpGetIEProxyConfigForCurrentUser` and resolves per URL
with `WinHttpGetProxyForUrl`, or uses `AUTOMATIC_PROXY` where the OS supports it (a later
Windows than 7, **unverified**). Proxy support is therefore a feature the platform
transport has and the generic one does not.

**Certificate failures.** The header declares `ERROR_WINHTTP_SECURE_FAILURE` (12175, line
469), `WINHTTP_CALLBACK_STATUS_SECURE_FAILURE` and `WINHTTP_OPTION_SECURITY_FLAGS` (31)
with `SECURITY_FLAG_IGNORE_UNKNOWN_CA`, `..._CERT_DATE_INVALID`, `..._CERT_CN_INVALID`,
`..._CERT_WRONG_USAGE` (lines 68-71, **read**). So:

* `hfVerificationFailed` from `ERROR_WINHTTP_SECURE_FAILURE`, which is raised during the
  handshake (**inference**: it precedes any request byte, so it can be reported as nothing
  sent; **bench item**: confirm with a badssl-style host and a packet capture or server log).
* Verify-off (`VerifyServer = False`) sets exactly those ignore flags with
  `WinHttpSetOption(WINHTTP_OPTION_SECURITY_FLAGS)` before the send. These constants exist in
  `winhttp.pp`, so no local declaration is needed (**read**).
* `ERROR_WINHTTP_NAME_NOT_RESOLVED` (line 441) and `ERROR_WINHTTP_CANNOT_CONNECT` (line 449)
  are connect-time and map to `hfNameNotResolved` / `hfCannotConnect` (nothing sent,
  **inference**). A timeout is `hfConnectTimedOut` or `hfIOTimedOut` according to the phase
  that was waiting; WinHTTP reports a single timeout error, so **the transport must record
  which phase it was in** (before `WinHttpSendRequest` returned: connect; after: IO).
  This is the part most likely to be wrong and is a bench item.
* `ERROR_WINHTTP_OPERATION_CANCELLED` (line 446) maps to `hfCancelled`.

**Trust.** The OS certificate store decides; there is no `cacert.pem`. This is the point of
the work for Windows (issue 221 question 2): the store is kept current by Windows Update,
and an enterprise CA the operator's machine already trusts (a proxy that re-signs) works
without a file. It also means `uTLSTrust.TrustBundleUsable` is irrelevant to this
transport: `hfTrustUnavailable` is not reportable by WinHTTP, and the notice for a missing
bundle (issue 221) appears only when the generic transport is in use.

**Cancellation.** Closing the request handle from another thread aborts a blocked
synchronous call (**unverified** from memory). Not used in v1 (contract line 6).

**Cost.** One new unit and no DLL we ship (`winhttp.dll` is part of Windows). CLAUDE.md's
"no new direct calls into a DLL" rule is a decision here, and NY4I has made it for this
(2026-11-05). `winhttp.pp` binds statically with `external winhttp.dll`, which means the
import is resolved when the exe loads: if the DLL were ever missing the exe would not start.
It is part of every Windows this program can reasonably run on, but a **dynamic**
`LoadLibrary`/`GetProcAddress` binding in the transport unit (so absence is `Available =
False` and the generic transport is chosen) is the safer shape, and costs about the same
(open question 6).

### 4.3 macOS

**Choice: `NSURLSession`.** `uTLSTrust.pas` records this as the intended end state, for
the reasons that still hold: no Homebrew or bundled OpenSSL, the Keychain as the trust
source, and `uOpenSSLLoader`'s version-suffix handling goes away on that platform.

**What the bindings give (all **read**, `packages\cocoaint\src\foundation\NSURLSession.inc`,
270 lines; the same package the Mac build links per the `uTLSTrust.pas` note, "verified on
the Mac mini, 2026-09-09"):**

* `NSURLSession`, `NSURLSessionConfiguration` (with `setTimeoutIntervalForRequest`, line
  149), `NSURLSessionDataTask`, `NSURLSessionDelegate` / `NSURLSessionTaskDelegate` /
  `NSURLSessionDataDelegate` protocols, including
  `URLSession:task:didReceiveChallenge:completionHandler:` (line 228), which is how a
  transport observes a certificate challenge.
* `dataTaskWithRequest:completionHandler:` takes an **`OpaqueCBlock`** (line 67, declared as
  a plain `pointer` in `CocoaAll.pas:225`). Whether FPC 3.2.2 can build a working Objective-C
  block from Pascal is **unverified**. The design therefore **prefers the delegate form** with
  a private non-main `NSOperationQueue`, which needs no block.
* `NSURLConnection.sendSynchronousRequest:returningResponse:error:` exists
  (`NSURLConnection.inc:72`). It is a synchronous call, which fits the interface, but Apple
  has deprecated `NSURLConnection` (**unverified** here), so it is a fallback for a spike,
  not the design.

**Synchronous bridging.** The worker thread creates the task, then waits on a `TEvent`
that the delegate sets when the task completes. **It must never wait on the main thread**
(two callers, the version check and the startup CTY fetch, run on the main thread; on macOS
a blocked main thread with a delegate queued to it is the deadlock that `uCrashLog`'s
main-thread notes describe). So the delegate queue is a private `NSOperationQueue` and the
main run loop is not involved at all. **The two main-thread callers are an existing defect
on every platform** (a 10 s freeze at worst for the version check) and moving them to a
worker is a separate piece of work that this document does not do, but S3 may not ship until
the bench shows the startup CTY fetch cannot deadlock on macOS (bench item).

**App Transport Security.** ATS can refuse plain `http://` for an app that does not declare
an exception. **HamScore's default is plain http** (`uSettingsModel.pas:4966`, **read**), so
ATS would break the default HamScore configuration on macOS, not just a club server. The
score-posting URL is an operator setting that may also be http. Two answers, both owned by
the build: an `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` entry in `Info.plist`
(**unverified** that this survives notarization review; it is allowed), or the
transport reports `hfPlaintextNotAllowed` for http on macOS and the Preferences note
(`IsPlainHttpUrl`) says so. Recommendation in section 8.

**Trust and verify-off.** The Keychain decides. Verify-off (`VerifyServer = False`) is
implemented in the challenge delegate by accepting the server trust without evaluating it;
this is a few lines and is **unverified** against the binding (the completion handler is a
block, again). If the block question cannot be answered, verify-off is unsupported on
macOS and the transport says so (`Available` is True, but `Execute` returns
`hfVerificationFailed` with a `Detail` naming the setting), which is a reported limitation
rather than a silent one.

**Cost.** A third implementation; a spike to prove the delegate/event bridge from FPC; and
`mac_bundle_openssl` plus its signing step (`build-unix.sh`, `mac-sign.sh`) could be
deleted at S5, along with the build machine's need for a Homebrew `openssl@3`
(`build-unix.sh` `mac_openssl_source_dir`, **read**). macOS has still never been run
(CLAUDE.md), so S3 is gated on someone running the GUI on a Mac, which is the order
`uTLSTrust.pas` already states.

### 4.4 Linux

**Recommendation: no new transport at S4; improve the generic one.** The problem on Linux
is not the client library, it is the trust source: the generic transport verifies only
against the shipped `cacert.pem`, never the distribution's own bundle
(`uTLSTrust.pas`, **read**). The cheapest correct step is to add system tiers to
`TrustBundlePath`'s search, after the two it already has: the Debian/Ubuntu
`/etc/ssl/certs/ca-certificates.crt`, the Red Hat family's
`/etc/pki/tls/certs/ca-bundle.crt`, and `/etc/ssl/cert.pem` (the **paths are from memory and
unverified**; the lookup is a list in one function and is checked on `linux-ci-build` and the
Mint bench machine). Order is an open question (7): system first keeps the operator's trust
policy; `cacert.pem` first keeps behaviour identical to today.

Alternatives, with the tradeoff:

| option | gains | costs |
|---|---|---|
| generic + system CA tiers (recommended) | one new function's worth of code, no new dependency, AppImage already bundles `libssl.so.3` (`build-appimage.sh` `DLOPENED`, **read**) | still OpenSSL, still FPC's client; hostname check still needs `X509_check_host` (present in 1.0.2+, so fine) |
| libcurl via `packages\libcurl\src\libcurl.pp` (present, **read**: `curl_easy_init`, `curl_easy_perform`, `CURLOPT_CAINFO`, `CURLOPT_SSL_VERIFYPEER`) | the distro's own TLS and CA handling, proxy environment variables | a new `external` binding (a decision under the DLL rule), another library to find on every distribution, and for the AppImage another thing to bundle (libcurl pulls in its own TLS library); `libcurl` is not guaranteed present on a minimal install (**unverified**) |
| GnuTLS (`packages\gnutls` exists) | none worth the cost | a third TLS stack |

The AppImage can bundle libssl/libcrypto today and does; it cannot bundle the host's CA
bundle (it differs per distribution), which is the argument for the system tiers being a
real runtime search rather than a bundled copy.

### 4.5 The OpenSSL we ship on Windows (**read**)

| fact | evidence |
|---|---|
| `tr4w/target/libeay32.dll` and `ssleay32.dll`: FileVersion and ProductVersion **1.0.2u**, product "The OpenSSL Toolkit", 1,281,536 and 277,504 bytes, dated 2026-07-03 | PowerShell `(Get-Item ...).VersionInfo` |
| 1.0.2u is the last release of the 1.0.2 series; that series reached end of public support at the end of 2019 | **unverified** (from memory; the `u` suffix is read) |
| `ssleay32.dll` contains the strings `TLSv1_2_method`, `TLSv1_1_method`, `SSLv23_method` and `TLS_method`, and **no** `TLSv1_3` string. TLS 1.2 is available; **TLS 1.3 is not** | `rg -a -o` over the binary |
| `libeay32.dll` contains `X509_check_host`, which the hostname check needs | `rg -a -o`; and `uTLSTrust.pas` says it arrived in 1.0.2 |
| FPC's context creation (`stAny`) uses `SslTLSMethod` when bound, else `SslMethodV23` (`fpopenssl.pp:321-325`). Which of the two this DLL gets is **unverified**; both negotiate up to the highest version both sides support, so against this DLL the ceiling is TLS 1.2 | **read** / **inference** |
| The comment in `uHTTPDownload.pas` ("https: TLS 1.2") is therefore a ceiling, not a setting: the code never selects a version | **read**: no protocol is set in `uHTTPDownload` or `uTLSTrust` |
| Linux and macOS use whatever OpenSSL 3 / 1.1 is found or bundled (`uOpenSSLLoader`) | **read** |

A server that requires TLS 1.3 only, or that retires every TLS 1.2 cipher suite this
build offers, is unreachable from Windows today. None of TR4W's present destinations is
known to do either (**unverified**), which is why this is a risk and not a defect, and is a
real argument for WinHTTP rather than for a newer OpenSSL on Windows (a newer OpenSSL is a
different pair of DLL names, a new FPC binding question and a rebuild of the bundle in
`tr4w/target`).

## 5. Test strategy

**1. A fake transport for every caller test.** The precedent is the virtual `Send` /
`NewRequest` pair (`uTestHttpSecrets.pas` `TNoBundleRequest`). At S1 `uTestFakeTransport`
provides a `TFakeHttpTransport` that records the `THttpWireRequest` and replays a scripted
`THttpWireResult` (including a failure kind and a `Detail` that echoes the token). The
caller tests move onto it where they today need a real network or a forced
`SetOpenSSLForcedUnavailable`. Record/replay is a plain list of request-to-result pairs in
the test unit; no capture format is needed.

**2. The generic transport stays pinned.** `uTestHttpSecrets`, `uTestTLSRefusal`,
`uTestSCPUpload`, `uTestWRLDelivery`, `uTestPlainHttpUrl` and `uTestExternalLoggers` all
pass **unchanged** at S1. Two details matter:

* `uTestTLSRefusal` depends on there being no `cacert.pem` beside the test exe. Under
  WinHTTP the OS store would verify, and its precondition would silently disappear. **It
  must select the generic transport explicitly** (a registry seam: `SetHttpTransportForTest`)
  so it keeps testing the refusal it was written for. The same goes for any test that forces
  OpenSSL unavailable.
* The registry must default to `generic` in the unit-test binary, whatever platform it runs
  on, so a platform transport can never change a test's meaning by being present.

**3. A contract suite run against every transport.** The 15 lines of section 3.3 become
one test class, parameterised by transport, run against the generic transport at S1 and the
Windows transport at S2, over a **plain-HTTP loopback server**. `uTestSCPUpload` already
runs one: an Indy `TIdTCPServer` on `127.0.0.1` port 0 (**read**, `StartServer`). A plain
loopback server covers headers, body bytes, Basic and bearer headers, status and reason
text, `Retry-After`, `X-Request-Id`, the size cap, redirect policy (including a
https-style downgrade by redirecting to a second loopback port), a slow server for the
timeouts, and a closed port for `hfCannotConnect`.

**4. TLS has no loopback server in the repository.** A search of `tools/` and `tr4w/test/`
found none; the TLS coverage is the two hand-run probes
(`tls-verify-probe.pas`, `tls-nobundle-probe.pas`), which go to `badssl.com`. For the
Windows transport a local HTTPS server is possible (a test-only certificate, trusted for the
test by a per-process mechanism, since WinHTTP uses the OS store) but it needs a certificate
installed in the machine store, which a unit test must not do. So **TLS correctness for a
platform transport is a bench item**, run by an extended probe, and the loopback suite
covers everything that is not TLS.

**5. What only the bench can prove, per platform.**

| platform | bench items |
|---|---|
| Windows | badssl matrix (expired, wrong host, self-signed, untrusted root) rejected with `hfVerificationFailed` and verified as nothing-sent; a good host; a 2 s timeout against a black hole returns in about 2 s and reports the right phase; verify-off proceeds; behind a real proxy; on the oldest Windows NY4I still cares about (open question 4); a Club Log and a WRL request against the real services with the real tokens in a throwaway account |
| macOS | the same matrix; ATS with an http:// HamScore URL; no deadlock when the startup CTY fetch runs before the run loop |
| Linux | the system-CA tiers on each distribution the AppImage targets; a machine with no `libssl` |
| all | the existing hand probes pass on the generic transport after S1 |

Add these to `docs/BENCH_QUEUE.md` when the corresponding stage lands, not before.

## 6. The staged plan

Each stage leaves the program working and is a separate commit series. "Specialists" are
the agents CLAUDE.md requires to be involved.

| stage | what | behaviour change | gates | specialists |
|---|---|---|---|---|
| **S0 (done)** | #221 stopgap: look beside the exe, `TrustBundleMissing`, one notice, retry not uncertain. Commit `4dc105b9`. | yes, as designed | done | integrations, build-release |
| **S1a (done)** | Create `uHttpTransport` (types, registry, `NothingSent`) and `uHttpTransportGeneric` (move `TFPHTTPClient`, `ApplyTLSVerification`, `TBoundedHttpResponse`, the OpenSSL/trust calls). `uHTTPDownload` keeps the verbs, `THttpRequest`, `CheckScheme` (scheme and policy only), the secrets functions, and delegates `Send`. Add the fake transport and the contract suite (generic only). `TlsUnavailable` / `TrustBundleMissing` become derived. | **none intended** | `Build-Tests.ps1 -Run` and `-Checked`; `Run-Lints.ps1`; `gh workflow run release.yml` (the unit list changes, so all three platforms must compile). The golden corpus and the contest matrix are not needed: no engine code is touched. Hand-run `tls-verify-probe` once. | integrations, build-release (the `.lpr` list), settings-config only if a setting is added here (it is not) |
| **S1b (done)** | Club Log and WRL classify by `NothingSent`; the three paths of section 2.3 become retry / failed instead of uncertain; new pin tests. | **yes, small and deliberate** | unit tests; the updated pins; review by integrations | integrations |
| **S1c** | Decide the https-to-http redirect (open question 5) and, if forbidden, enforce it in the generic transport through `OnRedirect`. | yes, if forbidden | unit tests with the loopback redirect | integrations |
| **S2** | `uHttpTransportWinHttp` (Windows only), selected by the new setting, **default `generic`**. Contract suite runs against it. Bench list above. | none while default is generic | unit tests, `-Checked`, lints, `release.yml`, then the Windows bench | integrations, build-release, settings-config, lcl-ui (Preferences row), i18n (resourcestrings for the setting) |
| **S2b** | After the bench: default becomes `auto` (platform if `Available`, else generic, decided once and logged). | the point of the work | one release on `auto` with the setting as the escape hatch | integrations, NY4I sign-off |
| **S3** | `uHttpTransportNSURLSession` (macOS), same setting and rules. First a spike that proves the delegate / event bridge and the block question. | none while default is generic | `release.yml` (macOS job), then a Mac bench; gated on the GUI having been run on a Mac | integrations, build-release (signing), lcl-ui |
| **S4** | Linux: system CA tiers in `TrustBundlePath`. No new transport unless the bench shows a reason. | yes (more places trusted) | Linux CI, then the Mint bench | integrations, build-release |
| **S5** | Retire what a platform no longer needs. See below. | yes | per item | build-release, integrations |

**S1a, as built (2026-11-05) -- where it differs from the sketch in 3.2, and what it found.**

* `uHttpTransport` holds the types, `NothingSent`, the registry (`RegisterHttpTransport`,
  `ActiveHttpTransport`, locked, decided at first use, logged once as `[HTTP] transport: <id>`),
  `ToWire`/`FromWire` and `IsHttpsUrl`. `uHttpTransportGeneric` holds `TFPHTTPClient`, the OpenSSL
  and trust calls and `TBoundedHttpResponse`, and registers itself (not preferred). `uHTTPDownload`
  links the generic unit itself, so no program that can make a request has an empty registry; an
  empty one fails the request closed with a reason (pinned). No setting yet: that is S2.
* The wire types gained what the old verbs needed to stay byte-identical: `HasBody` (a `Send`
  always attached a body stream, so a bodiless WRL GET carried `Content-Length: 0`; the Get verbs
  attach none) and `AcceptAnyStatus` (`Send` allowed every status; the Get verbs allowed `[200]`).
  The result carries `ErrorClass` and `ErrorMessage` separately because the credentialed
  `FailReason` names the class and the log line wants both.
* Two failure kinds the sketch lacked: **`hfTlsLibraryFault`** (OpenSSL failed once bytes were
  moving; not provable, `NothingSent` False -- the old `EInOutError` arm) and
  **`hfVerificationUnavailable`** (checking was asked for, the bundle is fine, but verification
  cannot be set up: an OpenSSL with no `X509_check_host`; this is section 2.3's third path, and it
  is deliberately NOT `hfTlsUnavailable`, which would flip the old flag).
* The transport logs nothing. Its TLS-setup refusals come back as data and `uHTTPDownload.
  RunTransport` writes the same Error lines with the same once-per-reason latches as before.
  `THttpRequest.TlsUnavailable` and `TrustBundleMissing` are properties over one `Failure` field,
  readable AND writable (the existing test stubs assign them).
* **Found: a redirected Get is followed.** I expected FPC to raise on a 302 before following it
  because the allowed list is `[200]`. It does not; it follows and checks the final status. So
  `HttpGetText` and `DownloadFileToPath` do follow redirects, to any scheme, as 2.4 inferred.
  `Test_AGetStillFollowsARedirect` pins it, and is the test S1c changes.
* **Small observable differences, all log or file level:** the `.tmp` file is now created before
  the transport runs and deleted when the request is refused (it used to be created only after
  the refusal checks); the Trace line for a request that is then refused for TLS is written (it
  used to come after that check); with certificate checking turned OFF, the "checking is OFF"
  Warn is written before a TLS-unavailable refusal and so appears even when TLS then fails.
  `FailReason` texts are unchanged.
* `test\integration\tls-verify-probe` was compiled and hand-run against the S1b tree (real
  OpenSSL pair and `cacert.pem` beside it): the four bad certificates rejected, the two good
  hosts accepted, 6 passed 0 failed. `tls-nobundle-probe` compiles (not run).
* **For S2:** "only 200 is an answer" for the Get verbs is enforced by the TRANSPORT alone
  (`AcceptAnyStatus = False`); the shared layer does not re-check the status. A transport that
  returned a 404 as `hfNone` would make `DownloadFileToPath` write the 404 body over the target.
  `Test_OnlyOkIsAnAnswerWhenNotAsked` must be in the contract run for every transport.
* `uProgramMain`'s uses clause names only `uHTTPDownload` (not the OpenSSL or trust units), so it
  needs no new entry. `tr4w.lpi`'s unit list is not maintained for new units (`uWRLClient` is not
  in it either); only `tr4w.lpr` and the test `.lpr` were extended.

**S1b, as built (2026-11-05).** Club Log and WRL no longer read the two flags; both call
`ApplyNothingSent` (`uExternalDeliveryClient`, the one classifier, so the two services cannot
drift), which asks `THttpRequest.NothingSent`. The flags stay as properties over `Failure`. The
choice among "retry / failed" for each path, with the reason (pinned in `uTestNothingSent`):

| kind | outcome | pause | code (`CLUBLOG_` / `WRL_` + ...) | why |
|---|---|---|---|---|
| `hfTlsUnavailable` | retry, 300 s | no | `TLS_UNAVAILABLE` | unchanged from S0 |
| `hfTrustUnavailable` | retry, 300 s | no | `CA_BUNDLE_MISSING` | unchanged; **the only kind that raises the `OperatorNotice`** |
| `hfVerificationUnavailable` (2.3 path 3) | retry, 300 s | no | `VERIFICATION_UNAVAILABLE` | an updated OpenSSL, or the operator's own setting (read on every request), cures it; no notice (the bundle is fine) |
| `hfAuthPolicy` (2.3 path 1) | retry | **yes** | `AUTH_POLICY` | the credential class: the worker already turns a 401 into retry-and-stop "for a replacement credential". Nothing is lost. Now also logged (Error, URL scrubbed), where it was silent |
| `hfPlaintextNotAllowed`, `hfBadScheme` (2.3 path 2) | **failed** | **yes** | `URL_REFUSED` | a malformed request; both clients hard-code https, so it is a defect, and failing each delivery in turn would burn the queue |
| any other proved kind (`hfNameNotResolved`, `hfCannotConnect`, `hfConnectTimedOut`, `hfVerificationFailed`) | retry, 300 s | no | `NOT_SENT` | the generic transport reports none of these; a platform transport will |
| everything else | unchanged: Club Log uncertain + pause; WRL POST uncertain, GET retry | | | "may have been sent" |

**S2: a setting, or automatic with a fallback? Argued.**

The setting is `network.httpTransport` with values `auto`, `platform`, `generic`, shipped
at S2 with `generic` as the default and moved to `auto` at S2b.

* **Automatic with a per-request fallback is wrong**, for the reason in section 3.4: the
  callers are non-idempotent POSTs, and a fallback after an attempt can double-send a QSO
  or hide which transport behaved. This repository has fixed several silent downgrades.
* **Automatic selection at startup** (platform if available, else generic, logged once) is
  safe, because nothing was attempted. That is what `auto` is.
* **The setting earns its place** because the first release with a new transport will meet a
  machine nobody tested (a proxy, an inspecting firewall, an old Windows), and the operator
  needs a one-click way back that does not need a new build. It also gives NY4I a way to
  A/B on his own station. It is an ordinary published property and one registration line
  (`docs/ADDING_A_SETTING.md`), and the transport in use is written to `tr4w.log` once.
* **Default `generic` first** because S2 is unbenched; flipping the default is its own
  commit (S2b) after the bench, so a regression bisects to one change.

**S5, what is retired and what is not.** Nothing is deleted until a platform transport has
shipped as the default for a release.

* **Windows:** `cacert.pem` and the two OpenSSL DLLs stay in the installer for as long as
  `generic` is selectable on Windows. Dropping them is a separate decision (open question 3):
  it removes about 1.5 MB from the installer and, **by inference**, the x86_64 OpenSSL
  staging check that today stops the 64-bit build (`Build-App.ps1` missing-file check
  against the shipping i386 DLL set; CLAUDE.md "64-bit" section). Because OpenSSL is loaded
  at run time, it would then be a run-time absence on a generic path nobody selects.
* **macOS:** `mac_bundle_openssl`, the signing of its libraries, `OPENSSL_VERSION.txt`, the
  Homebrew `openssl@3` build prerequisite, and the Darwin arm of `uOpenSSLLoader` can go,
  along with `cacert.pem` in the bundle. This is the largest simplification on offer.
* **Linux:** nothing goes. `cacert.pem` stays as the last tier and the AppImage keeps
  `libssl`.
* **Everywhere:** `uTLSTrust`'s text about "THE INTENDED macOS END STATE" is replaced by a
  pointer to this document when S3 lands.

**Exit criteria per platform, and what the first real run must show (added 2026-11-06).** A stage
is not finished when it compiles. Each row is what has to be true, and the last column is what
the first run on that platform has to put in `tr4w.log` or on the screen before anyone calls it
working.

| stage | exit criteria | the first real run must show |
|---|---|---|
| S2 Windows | the 15-line contract suite green against `winhttp` over loopback; `-Checked` clean; lints; `release.yml` green on all three platforms; bench matrix of section 5 passed on one real Windows machine | `[HTTP] transport: winhttp`; **no** `[TLS] CA bundle` line and no OpenSSL load, with `cacert.pem` deliberately absent from beside the exe (this is the failure class of issue 221 gone); a Club Log test-mode create and a WRL create each settle as confirmed; a bad certificate refused with a nothing-sent code (`*_NOT_SENT`) and the request absent from the server log; a 2 s timeout against a black hole returning in about 2 s |
| S2b `auto` default | one release on `auto` with no operator forced back to `generic` | the transport line names `winhttp` on every machine in the field logs NY4I sees; no new delivery stuck in uncertain that the generic path would have retried |
| S3 macOS | the spike proves the delegate and event bridge (or the block question is answered the other way and the design is amended); contract suite green on a Mac; the bundle still notarizes; gated on the GUI having been run on a Mac at all | `[HTTP] transport: nsurlsession`; a GET from a worker thread completes while the main run loop is idle; the startup CTY fetch on the main thread does not deadlock; a bad certificate is refused as nothing-sent; the answer to plain `http://` under ATS (HamScore default) is recorded, whichever way it falls |
| S4 Linux | the system CA tiers found on each distribution the AppImage targets; contract suite green; `release.yml` Linux job green | `[TLS] CA bundle: <path> (<tier>)` naming a system file on a machine whose `cacert.pem` is deliberately removed; the AppImage on the Mint machine completes a CTY download |
| any logger added later (section 10) | the provider registers, declares its fields and passes its own client tests; if HTTP, it adds no new transport requirement or it amends this document first | a delivery from a real instance of the program it targets, confirmed in that program's own log |

## 7. The packaging finding: is `cacert.pem` beside every exe that runs?

**No, not in `build-out\app-i386-win32`.** That folder holds `libeay32.dll`,
`ssleay32.dll` and the other DLLs but no `cacert.pem`, while `tr4w\target` has both (a
directory listing of each, **read**). Cause and per-platform staging, all **read**:

| place | does it get `cacert.pem`? | by what |
|---|---|---|
| `tr4w\target` (where `FullBuild.ps1` links the exe) | yes | the file is tracked (`git ls-files tr4w/target` lists it); when the exe's folder is the DLL source, "Nothing to stage" (`Build-App.ps1`, the comment above the staging loop) |
| `build-out\app-i386-win32` (`Build-App.ps1` without `FullBuild`) | **no** | the staging step enumerates only `-Filter '*.dll'` from `$dllSource` (`Build-App.ps1:553`) and copies each to `$exeDir` (`:642`). A `.pem` is not a `.dll`. |
| Windows installer | yes | `full.nsi:145-152` (`File ..\target\cacert.pem`, with the refresh instruction) |
| Linux tarball | yes | `build-unix.sh:1317-1325` copies `cacert.pem` among the data files; the stage fails if it is missing |
| Linux AppImage | yes | `build-appimage.sh:188` copies the tarball stage into `usr/bin`, and `DLOPENED` (line 135) collects `libssl`/`libcrypto` into `usr/lib` |
| macOS `.app` | yes | the stage is moved into `Contents/Resources` (`build-unix.sh`, the `mv` loop in the macOS arm), which is `BesideProgramFilePath` on macOS (`uAppPaths.pas:316-329`); the OpenSSL libraries go to `Contents/Frameworks` |
| CI workflow | nothing in `.github/workflows` names it | it rides the installer and the stages above |

**Why it matters, now that `4dc105b9` exists.** `TrustBundlePath` searches the data
directory (the **working directory** on Windows, `uAppPaths.pas:523-531`) and then the exe's
own folder. A run of the `build-out` binary from a folder with no `cacert.pem` and with the
exe's own folder lacking one finds neither, which is exactly the state that makes every
HTTPS request fail with "bundle missing" (and, since S0, show the notice). It is a
developer-machine and bench-machine problem, not an installed-program problem: every
shipped artifact above carries the file.

**The one-line fix (not made).** In `tr4w/build/Build-App.ps1`, in the staging section
after the `*.dll` loop (around line 642), copy the file from `tr4w\target` regardless of
CPU, because the x86_64 `$dllSource` is `redist\x86_64-win64`, which has no bundle:

```powershell
   Copy-Item -LiteralPath (Join-Path $TR4W_DIR 'target\cacert.pem') -Destination $exeDir -Force
```

guarded by the same `if ($exeDir -ne $dllSource)` that guards the DLLs and by
`Test-Path` on the source. **It must not go in `Build-Tests.ps1`**: that script's exclusion
of the bundle is deliberate (its comment near line 245) because `uTestTLSRefusal` relies on
there being none beside the test exe.

## 8. Open questions for NY4I

1. **Windows API: WinHTTP (recommended) or WinINet?** WinHTTP is thread-safe, has explicit
   redirect, proxy and security-flag control, and no interactive-desktop state to switch
   off. WinINet exists only if you want it to share Internet Explorer's settings and cache,
   which contract line 9 would turn off anyway.
2. **S2 policy: setting plus `auto` after the bench (recommended), or automatic from the
   first release?** Recommend the setting, default `generic` at S2 and `auto` at S2b,
   no per-request fallback ever (section 6).
3. **When the platform transport has shipped as default, does Windows keep OpenSSL and
   `cacert.pem` in the installer?** Recommend yes for one release after S2b, then decide;
   keeping them costs about 1.5 MB and keeps the Windows 7 path (question 4). Dropping them
   removes the x86_64 OpenSSL blocker for the 64-bit build.
4. **What is the oldest Windows TR4W 5.x supports?** Not stated in the repository. If
   Windows 7 matters, WinHTTP there needs an OS update for TLS 1.2 (unverified), and the
   generic transport is the better answer on that machine. Recommend deciding the floor
   before S2 and writing it in the installer and README.
5. **Should a redirect from https to http ever be followed?** Today the generic path may
   follow it for the callers that follow redirects (CTY, TRMASTER, POTA, version check,
   HamScore, score post, SCP). Recommend never, enforced at S1c, with a log line when a
   redirect is refused; the cost is a download that depended on such a redirect failing
   visibly (none is known).
6. **Static or dynamic binding of `winhttp.dll`?** Static is simplest; a missing DLL would
   stop the program from starting. Recommend dynamic (`LoadLibrary` inside the unit, so
   absence is `Available = False`), accepting that it is the more code of the two.
7. **Linux and macOS trust order.** Linux: system bundle first, or `cacert.pem` first?
   Recommend system first, so a distribution's trust policy wins, with `cacert.pem` as the
   last tier. macOS: Keychain only.
8. **macOS and plain `http://` (ATS).** HamScore's default is `http://`. Recommend an
   `Info.plist` ATS exception for the contest-score and HamScore hosts' use case, with the
   `IsPlainHttpUrl` note kept, rather than refusing http on macOS (which would break the
   default HamScore setup). Needs your decision because it is a security posture.
9. **Move the two main-thread callers (version check, startup CTY) to workers?** A separate
   task, not part of this work, but a synchronous platform transport makes it more visible.
   Recommend a separate issue.
10. **Proxy support is a new feature of the platform transport.** Is it wanted, and should
    the generic transport grow it too (FPC's client has a `Proxy` property)? Recommend yes
    on the platform transports only, and say so in the setting's help.
11. **Linux: stay on OpenSSL with system CA tiers (recommended), or move to libcurl?** One line
    answers section 4.4: OpenSSL means no new library binding; libcurl means a new `external`
    binding, another library to bundle in the AppImage, and the distribution's own TLS.
12. **May a credential ever travel over plain `http://` to a destination the operator chose?**
    Cloudlog and Wavelog on a LAN are often http (section 10.3). Recommend: allowed only as an
    explicit per-definition choice with a visible warning, never for a bearer token, never by
    default. HamScore already does this by default.
13. **Should "verify certificates" become per destination?** Today it is one global setting.
    A self-signed Cloudlog server needs it off for that destination only. Recommend: yes, a
    per-definition choice on the HTTP providers, default on, with the global setting kept as the
    master switch.
14. **Once Windows and macOS ship the platform transport as default, drop `libeay32.dll` and
    `ssleay32.dll` (1.0.2u, TLS 1.2 at most) from the installer?** This is question 3 asked for
    the DLLs alone. Recommend: not until a release has run on `auto`, and only if the Windows
    floor (question 4) is Windows 10 or later.
15. **Proxy settings behaviour (question 10, restated as a default).** On the platform
    transports: follow the operating system's proxy configuration and say nothing, with no
    TR4W proxy setting. Recommend yes; add a TR4W proxy field only if an operator asks.

## 9. How to re-measure what this document states

| question | command |
|---|---|
| who calls the HTTP verbs | `rg -n "HttpGetText\|DownloadFileToPath\|THttpPost\|THttpRequest" tr4w/src --glob "*.pas"` |
| what links OpenSSL | search every `uses` clause for `opensslsockets`, `openssl`, `fpopenssl`, `sslsockets`, `uOpenSSLLoader` (and `tr4w.lpr`) |
| the shipped OpenSSL | `(Get-Item tr4w\target\libeay32.dll).VersionInfo` in PowerShell |
| what `winhttp.pp` declares | `rg -n -i "^\s*function WinHttp" C:\Lazarus\fpc\3.2.2\source\packages\winunits-base\src\winhttp.pp` |
| which `cacert.pem` a run used | the `[TLS] CA bundle: <path> (<tier>)` line in `tr4w.log` |
| what is staged beside a built exe | list `build-out\app-<cpu>-<os>` and compare with `tr4w\target` |
| what each logger does on the wire | `rg -n "DeliverCommand\|THttpRequest\|TExternalDeliveryClient" tr4w/src --glob "*.pas"` |
| which loggers are registered | `rg -n "RegisterExternalLogger\(" tr4w/src --glob "*.pas"` |

## 10. The other-logger check (NY4I's condition on issue 224)

NY4I, issue 224: *"Add the other external loggers into this plan at least to ensure the design
is tested against those as well. Otherwise, this is approved."* This section takes every
destination TR4W sends a QSO, a score or a file to, whether or not it uses HTTP, and asks four
things of each: what transport does it use, does the seam in section 3 cover it, what would it
need that the seam does not offer, and does the design survive it unchanged. Evidence key as at
the top: **read** is a file opened for this section (2026-11-06), **inference** is reasoned from
that, **unverified** is a belief about a program outside this tree, to be checked before
anything is built on it.

### 10.1 What the registry and the delivery contract expect of a destination (all **read**)

| expectation | where | what it means for a new destination |
|---|---|---|
| A provider registers an id, a display name, a constructor returning a `TExternalLoggerService`, and a declarer listing its editor rows (text, port, secret, choice) | `uExternalLoggerRegistry.RegisterExternalLogger` | The registry names no transport. A provider may be HTTP, TCP, UDP or a file. |
| A durable provider derives from `TDurableExternalLogger` and supplies `BuildPayload` and `CreateWorker`; capture happens inside the QSO transaction and the worker claims, sends and settles in short transactions that never span the network | `uDurableExternalLogger.pas`, and `docs/EXTERNAL_LOGGERS_DESIGN.md` (queue and thread invariants) | Queue semantics, crash safety, per-destination namespace and the Connection column come free. Only the client is new. |
| The client is a `TExternalDeliveryClient` whose `Deliver(job)` returns a `TExternalDeliveryResult`: outcome `doConfirmed`, `doRetry`, `doUncertain` or `doFailed`, an error code, a retry delay, a `Pause` flag and an `OperatorNotice` | `uExternalDeliveryClient.pas`, `TDeliveryOutcome` in `domain/uExternalDelivery.pas` | The client is the ONLY place a protocol appears. The worker is protocol-neutral. |
| "Nothing was sent" is a claim the client proves, and `ApplyNothingSent` is the one classifier for HTTP clients | `uExternalDeliveryClient.ApplyNothingSent`, section 6 (S1b as built) | It takes a `THttpRequest`, so today it is HTTP-shaped. See 10.4. |
| A non-idempotent write whose reply is lost is `doUncertain` and is not replayed blindly; Club Log replacement is delete-then-create and parks as uncertain if the create fails | `docs/EXTERNAL_LOGGERS_DESIGN.md`, "Changes, deletes and uncertainty" | A destination with no acknowledgement cannot ever be `doConfirmed` by the wire alone (DXKeeper, below). |
| Credentials live in the OS vault under the definition id; a secret field is never required because a locked vault leaves it empty | registry rules, `uExternalLoggerConfig` | A new destination with a key or password declares an `AddSecret` row and reads it at construction; nothing HTTP-specific. |
| Every implemented provider must support new, change and delete with its real protocol; an unsupported operation fails visibly | `docs/EXTERNAL_LOGGERS_DESIGN.md`, "Remaining External Logger issues" | A destination that cannot delete is not complete. |
| The older non-durable shape: `TExternalLoggerBase` with a `TSenderThread` (3 attempts, linear back-off, in-memory FIFO, `ShutdownDrain` at exit) and a `TReadingThread` that exists only for the persistent socket | `uExternalLoggerBase.pas` | DXKeeper uses the sender thread only. The reading thread and the persistent socket serve ACLog and HRD, which are stubs. |

### 10.2 The table

"Seam" means the transport interface of section 3 (`THttpWireRequest` / `THttpWireResult` /
`TPlatformHttpTransport`). "Classification" means `ApplyNothingSent` and the four outcomes.

| destination | status in the tree | transport today | does the HTTP seam cover it | what it needs that the seam does not offer | design survives unchanged |
|---|---|---|---|---|---|
| Club Log | implemented, durable | HTTPS REST through `THttpRequest`, bearer token, redirects off, response capped at 4096 | yes, it is the reference client | nothing | yes |
| WRL | implemented, durable | HTTPS REST through `THttpRequest`, bearer token, redirects off, default cap | yes | nothing | yes |
| HamScore | implemented, NOT a delivery worker: its own 2-minute batch uploader (`uHamScore.pas`, `PostToServer`) | `THttpPost`, Basic auth, **plain `http://scoredistributor.net/` by default** with `AllowInsecure` | yes | on macOS, an ATS answer for plain http (section 4.3); nothing in the seam | yes. It keeps its QSOs on a refusal and does not use `ApplyNothingSent` (it reads the status and the trust latch directly). It could, and the three-line change is not part of this work. |
| Contest score post | implemented, one-shot worker (`uGetScores.pas`) | `THttpPost`, form body, https default, operator may type `http://` | yes | the same ATS answer | yes |
| Downloaders (CTY, TRMASTER, POTA parks, version check) and SCP upload | implemented, operator actions | `DownloadFileToPath`, `HttpGetText`, `THttpPost` | yes (section 2.2) | nothing; they only read `FailReason` | yes |
| DXKeeper | implemented, Complete | **raw TCP**, one fresh `TIdTCPClient` per command (`TExternalLogger.DeliverCommand`: connect 2 s, write one line, read any reply up to 1 s, close), on the `TSenderThread`; host name goes through `uHostResolve` | **no, and it should not** | a TCP connect/write/read vocabulary: not-resolved, refused, connect timeout, write failed. No TLS, no headers, no status code, no redirects | yes, because it never used the seam. See 10.3 for the one shared piece. |
| ACLog | **stub** (`LogQSOToACLog` logs "not yet implemented"; type `lt_ACLog` is not registered, issue 33 asks for TCP) | intended: TCP to a host and port (issue 33). The wire protocol is **unverified**: the tree does not say. My belief is that N3FJP's ACLog has a TCP API with a default port in the 1000s and XML-like commands; nothing here confirms it | no | whatever its command and reply set is; probably a per-command TCP exchange like DXKeeper, or a persistent socket (the base class assumes persistent) | yes. It is a TCP client behind the same registry. If it is durable it implements `TExternalDeliveryClient`, which is protocol-neutral. |
| HRD (Ham Radio Deluxe) | **stub** (`LogQSOToHRD`, same text; `lt_HRD` not registered; no open issue) | intended: TCP (the base class's comments say "for future ACLog/HRD"). The wire protocol is **unverified**; HRD Logbook has more than one external interface and I have not read which one this tree intended | no | as ACLog | yes, same reasoning |
| Log4OM | **planned** (issue 203, "TR4W to Log4OM direction only") | UDP to a host and port, per the issue | no | one datagram per message, no connection, so "sent" can never be proved delivered. Already handled by the UDP sink machinery and `LogCfg.SendUDPPayload` | yes. Not HTTP, not durable-with-acknowledgement. It is the dispatcher's UDP sink shape. |
| Cloudlog and Wavelog | **planned** (issue 204, "instance URL, API credential and remote station profile; several instances may be active") | HTTP or HTTPS REST to an **operator-run server**. Endpoint and body shape **unverified** (my belief: a JSON POST carrying the key and an ADIF string) | **yes, and this is the case that tests the design** | see 10.3 | **yes, with five things the HTTP design must not rule out** (10.3) |
| MacLoggerDX | **planned** (issue 205) | **not established.** The issue says to verify the real import mechanism, and warns that a compatible UDP announcement does not prove MacLoggerDX will import it; a macOS-native adapter is allowed | unknown | unknown: possibly UDP, possibly a local file or a macOS interprocess mechanism | the design is not affected: it is outside HTTP and may be outside the network |

### 10.3 What the check found

**1. The HTTP seam is the right abstraction for exactly the HTTP destinations and no others.**
Club Log, WRL, HamScore, the score post, the downloaders, SCP and the planned Cloudlog/Wavelog
are all `THttpRequest` callers, and the seam serves all of them with no change in section 3.
DXKeeper, ACLog, HRD and Log4OM speak raw TCP or UDP. They have no TLS handshake to delegate,
no status code and no trust store, so a "transport" under them would be a wrapper around a
socket that adds nothing. **Do not force them behind `TPlatformHttpTransport`.** Their
transport is already a platform-neutral one (Indy sockets, through `uHostResolve` and
`uIndyLink`) and nothing in issue 224 improves it.

**2. The piece they share is not the transport. It is the outcome vocabulary and the durable
contract.**
Both halves are already protocol-neutral: `TExternalDeliveryClient.Deliver` and
`TDeliveryOutcome` do not mention HTTP, and the worker, the outbox, the Connection column and
the retry timing are shared by whatever client a provider supplies. The one HTTP-shaped piece
is `ApplyNothingSent`, which takes a `THttpRequest`. Three of the failure kinds it maps
(`hfNameNotResolved`, `hfCannotConnect`, `hfConnectTimedOut`) are about connecting, not about
HTTP, and are what a TCP client can also prove. **Smallest change, when and only when a second
non-HTTP client is made durable:** split the `case` into a function over the failure kind
(`ClassifyNothingSent(kind, prefix, service, var result)`) and let `ApplyNothingSent` call it
with `aRequest.Failure`. That is a few lines, mechanical, and is not done now because no
durable TCP client exists to prove its shape (a speculative shared type is the one thing this
repository's rules warn against).

**3. DXKeeper shows the real difference, and it is a finding to record, not a defect to fix
here.**
DXKeeper has no acknowledgement. `DeliverCommand` returns True the moment the line is written
(`Result := True; // the command is on the wire = success`), and the reply is read best-effort
and only logged. So for DXKeeper "sent" and "delivered" are the same thing by design
(`docs/EXTERNAL_LOGGERS_DESIGN.md`: "TCP handoff is not a remote acknowledgement"), the queue is
in memory, and there is no `doUncertain` path at all. Two consequences. (a) A TCP destination
cannot use the Club Log shape (confirmed id, delete-then-create replacement, uncertain on a
lost reply) unless its protocol offers an id and a reply; the registry does not require one.
(b) The TCP equivalent of "nothing sent" is a failed connect, which the existing retry already
treats as retry-with-back-off. **One narrow edge, from reading the code:** if `WriteLn` raises
after some bytes left, `Result` is still False and the sender retries the command, which can
duplicate it. That is not HTTP, not part of issue 224, and is recorded here only because the
comparison surfaced it. Whether it matters depends on DXKeeper's single-command parsing,
which I have not tested.

**4. Cloudlog/Wavelog is the planned logger that tests the HTTP design, and five of its
properties matter now.** The instance is run by the operator, often on a LAN or a home server.
**All five are inference from how such installations are commonly set up, not from this tree;
the first thing issue 204 must do is confirm them against a real instance.**

| property | consequence for the design | what the design already says, and the gap |
|---|---|---|
| plain `http://` on a LAN is common | the bearer policy (`hfAuthPolicy`) refuses a bearer token over http. If Cloudlog sends its key in the BODY, the policy does not fire and the key travels in the clear | Club Log and WRL are https-only. **Gap:** a destination definition needs a per-destination "allow plain http" choice (the verbs already have `AllowInsecure`), and an open question for NY4I on whether secrets may ever travel in the clear on a private network (question 12). The transport interface is unchanged. |
| self-signed or private-CA certificates | the global "verify certificates" setting is all-or-nothing today, and `cacert.pem` will never contain a home CA | A platform transport on Windows or macOS trusts what the OS trusts, so an operator who installed their CA in the system store is served for free (an advantage of section 4.2 and 4.3 the document should claim). **Gap:** an operator with a self-signed server and no CA to install needs a per-destination "do not verify" choice. `THttpWireRequest.VerifyServer` is already per request, so the INTERFACE needs nothing; the SETTING needs to move from global to per definition (question 13). |
| redirects, especially http to https | a POST that is redirected may be re-sent as a GET, and a redirected write is a double-delivery risk | Club Log and WRL disable redirects. A Cloudlog client does the same and reports the 301 with its `Location` as a failure that names the cure ("use the https address"), which needs `Location` in `THttpWireResult` (**gap**, one more header like `RetryAfter`). Contract line 8 is unchanged. |
| the host is a LAN name or an address | `.local` names, short names and private addresses | Resolved by the platform resolver in WinHTTP and NSURLSession (their reason to exist) and by the existing `uHostResolve` path for the generic one. On macOS, ATS treats local networking differently from the internet (**unverified**: `NSAllowsLocalNetworking`), so the Info.plist answer in question 8 should be chosen with this destination in mind. |
| several instances at once | independent destination queues | The registry, definitions, per-definition namespace and one worker each already do this; Club Log and WRL are two such instances. The HTTP seam is stateless between requests, so there is no shared transport state to collide. |

**5. Nothing found changes the interface of section 3 or the staged plan.** Two small ADDITIONS
are flagged for the day issue 204 is built, both optional fields and neither a change to what a
caller sees today: `Location` on the wire result, and a per-destination verify and plain-http
choice that sets `VerifyServer` and `AllowInsecure` on the request. The contract suite of
section 5 should include a case with a loopback server that returns a 301 and a case whose
`VerifyServer` is False, which section 5 already lists for the generic transport, so the
Cloudlog case adds no new test infrastructure.

**6. Test it against them now, without building them.** The check NY4I asked for is run on
paper in this section and in code by two things that can be done at S1 or S2 for free: (a) a
second fake-transport scenario in `uTestFakeTransport` that scripts a Cloudlog-like exchange
(a plain-http URL, a 301, a self-signed refusal reported as `hfVerificationFailed`), run
through the existing `uWRLClient`-style classifier to prove the outcomes come out as retry,
failed and retry; and (b) the contract suite parameterised so a TCP client could be added to
the same `Deliver` tests (a loopback `TIdTCPServer` on 127.0.0.1 and a closed-port helper
already exist in `uTestExternalLoggerSocket.pas`, **read**).

### 10.4 What would change the design, and what would not

| if this happens | does section 3 change | does something else |
|---|---|---|
| ACLog or HRD turn out to speak HTTP | no: they use the seam | register a provider |
| ACLog or HRD turn out to speak a persistent TCP protocol with acknowledgements | no | the base class's reading thread and persistent socket (`ConnectGuarded`, `ReconnectFromReader`) are exactly for this and are pinned; a durable client may be built over them |
| a durable TCP client is written | no | split `ApplyNothingSent` as in finding 2 |
| Cloudlog/Wavelog needs per-destination verify or plain http | no, `VerifyServer` and `AllowInsecure` are already per request | the definition gains two fields, with the secrets rule applied (the settings-config agent) |
| MacLoggerDX needs a macOS-native interface (AppleScript, a file drop, Apple events) | no | a platform provider unit with a `{$IFDEF DARWIN}` body, registered like the keychain backends |
| Log4OM UDP | no | the existing UDP sink machinery |
| a destination needs TLS client certificates, or a pinned certificate | **yes**: `THttpWireRequest` has nowhere to put either | decide when one exists; none of the current or planned destinations is known to |
