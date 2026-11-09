# HTTP/HTTPS: a platform transport behind `uHTTPDownload` (issue 224)

**Status (2026-11-09): S0, S1a and S1b are BUILT; S2 (the Windows transport, WinHTTP) is IN
PROGRESS** after NY4I answered section 8 (the "Decided 2026-11-09" table at the top of section
8). S1c, S2b and everything from S3 on are NOT STARTED. S1a is
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

| consequence                                                                                                           | evidence                                                                              |
| --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| The Windows certificate store is never consulted. A bundle that goes stale between releases is the only trust source. | **read**: `uTLSTrust.pas` header ("THE WINDOWS CERTIFICATE STORE WAS NEVER INVOLVED") |
| On Windows the program ships OpenSSL **1.0.2u** (below). Servers that drop TLS 1.2 cannot be reached.                 | **read**: file version resource, section 4.5                                          |
| A missing `cacert.pem` or OpenSSL library means no HTTPS at all, on any platform.                                     | **read**: `CheckScheme`, `ApplyTLSVerification`                                       |
| macOS ships no OpenSSL, so `TR4W.app` carries and signs its own.                                                      | **read**: `uOpenSSLLoader.pas` header; `build-unix.sh` `mac_bundle_openssl`           |

The proposal: put a small abstract class between the verbs and the wire, keep the present
OpenSSL path as the `generic` implementation on every platform, and add one platform
implementation at a time (WinHTTP, then NSURLSession, then, probably, nothing new on Linux).
**Callers do not change.** The seam already exists; this document says what is on each side
of it.

## 2. What exists

### 2.1 The seam (all **read**, `src/utils/uHTTPDownload.pas`)

| piece                                                                    | what it is                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `DownloadFileToPath(url, target [, reason] [, allowInsecure])`           | GET to a file. Atomic (`.tmp` then rename). Synchronous. Never raises.                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `HttpGetText(url, text, reason [, userAgent, connectMs, ioMs])`          | GET to a string. Synchronous. Never raises.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `THttpRequest` / `THttpPost`                                             | One request as an object: `URL`, `Method`, `Body`, `ContentType`, `UserAgent`, `Username`/`Password` (Basic), `BearerToken`, `Sensitive`, `FollowRedirects`, `MaxResponseBytes`, `AcceptEncoding`, `AllowInsecure`, `ConnectMs`, `IOMs`. Answers: `Response`, `StatusCode`, `ResponseStatusText`, `FailReason`, `RetryAfter`, `RequestId`, and the two proof flags `TlsUnavailable` and `TrustBundleMissing`. `Send` is `virtual`, never raises, returns True for ANY HTTP status (the status is in `StatusCode`). |
| `CheckScheme`                                                            | the one scheme rule: https; http only if the caller says `AllowInsecure`; anything else refused. Also loads TLS (`EnsureOpenSSL`).                                                                                                                                                                                                                                                                                                                                                                                 |
| `ApplyTLSVerification`                                                   | fail closed: with checking on (`network.verifyServerCertificates`) a request that cannot be verified is not made.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `MaskSecret` / `ScrubSecret` / `RequestFailureLine` / `RequestTraceLine` | the secrets rule: URL logged, token and password scrubbed out of ALL logged text, raw and URL-encoded.                                                                                                                                                                                                                                                                                                                                                                                                             |

The two services that classify by outcome, Club Log and WRL, build their request through a
`virtual` `NewRequest` (**read**: `uClubLogClient.pas:11,52`, `uWRLClient.pas:19,42`) and
the tests override `THttpRequest.Send` (`uTestHttpSecrets.pas`, `TNoBundleRequest`). **That
virtual pair is the fake-transport precedent already in the tree** and section 5 builds on it.

### 2.2 Every caller

Re-measure with `rg -l -i "uHTTPDownload" tr4w --glob "*.pas"` and
`rg -n "HttpGetText|DownloadFileToPath|THttpPost|THttpRequest" tr4w/src --glob "*.pas"`.
The product callers at `4dc105b9`:

| caller                                             | verb                 | thread                                                                                                                                     | scheme                                                                                                                                | secrets                                                                | redirects                            | body / response size                                                    | notes                                                                            |
| -------------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Version check, `uCheckLatestVersion.pas:109`       | `HttpGetText`        | **main thread**: the Help-menu handler `MainUnit.pas:5968` calls it directly (**read**). The comment above it about sleeping 2 s is stale. | https `tr4w.net/version.json`                                                                                                         | none                                                                   | followed (`ApplyDefaults`, line 563) | small document, unbounded                                               | 5000/5000 ms, custom User-Agent. A slow server freezes the UI for up to the sum. |
| CTY feed check, `uCTYUpdate.pas:295`               | `HttpGetText`        | worker `TCTYVersionCheckThread`                                                                                                            | https `country-files.com/feed/`                                                                                                       | none                                                                   | followed                             | small, unbounded                                                        | default 15000/30000 ms                                                           |
| CTY download, `uCTYUpdate.pas:353` and `:422`      | `DownloadFileToPath` | worker `TCTYDownloadThread`; **and synchronous before the message loop** at `uProgramMain.pas:617`                                         | https `country-files.com/cty/cty.dat`                                                                                                 | none                                                                   | followed                             | a file (about 106 KB per the comment in `uHTTPDownload.pas`), unbounded | startup path: must not hang (timeouts exist for that reason)                     |
| TRMASTER, `uTRMasterUpdate.pas:120`                | `DownloadFileToPath` | worker `TTRMasterDownloadThread`                                                                                                           | https `tr4w.net/TRMASTER.DTA`                                                                                                         | none                                                                   | followed                             | file, size not measured                                                 |                                                                                  |
| POTA parks, `uPOTAParks.pas:744`                   | `DownloadFileToPath` | worker `TPOTADownloadThread`                                                                                                               | https `pota.app/all_parks_ext.csv`                                                                                                    | none                                                                   | followed                             | file, size not measured                                                 |                                                                                  |
| SCP upload, `uSuperCheckPartialFileUpload.pas:235` | `THttpPost`          | called from `postunit.pas:735` right after a `YesOrNo` dialog, so **main thread (inference)**                                              | https `supercheckpartial.com`                                                                                                         | none (a shared key is inside the JSON body)                            | followed (`THttpPost` default)       | JSON body of the whole Cabrillo file; response unbounded                | non-2xx is an answer: `Send` True, body is the server's reason                   |
| HamScore, `uHamScore.pas:736`                      | `THttpPost`          | worker `THamScoreUploader` (**read**: `Execute`, line 943; 2-minute cycle per the integrations agent)                                      | **default is `https://hamscore.com/postxml/`** since issue 250 (was plain http); `AllowInsecure := True`                               | **Basic auth, username and password**; `Accept-Encoding: gzip,deflate` | followed                             | XML body; response unbounded                                            | the only caller that sends a password, and by default in the clear               |
| Contest score post, `uGetScores.pas:140`           | `THttpPost`          | worker, `tCreateThread` at line 111                                                                                                        | **default is `https://contestonlinescore.com/post/`** (`SCORE_POSTING_DEFAULT_URL`, issue 253; the former `post.contestonlinescore.com` host serves an expired self-signed placeholder certificate, so it could never verify; a saved copy of it is migrated once, flag `Score.PostingUrlDefaultMigrated`); operator may type `http://`; `AllowInsecure := True` | none                                                                   | followed                             | form body, response saved to a file                                     |                                                                                  |
| Club Log, `uClubLogClient.pas:69-81`               | `THttpRequest`       | delivery worker (`TExternalDeliveryWorker = class(TThread)`)                                                                               | https only                                                                                                                            | **bearer token**                                                       | **none**                             | response capped at 4096                                                 | 5000/10000 ms. Outcome drives `doRetry` / `doUncertain` / `doFailed`.            |
| WRL, `uWRLClient.pas:62-71`                        | `THttpRequest`       | delivery worker                                                                                                                            | https only                                                                                                                            | **bearer token**                                                       | **none**                             | default cap (1 MB)                                                      | 5000/10000 ms. Same classification, plus `Retry-After` and `X-Request-Id`.       |

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

| refusal                                                                                               | where (**read**)                                                                                   | flags set                                     |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| Bearer token with a non-https URL, with redirects on, or with a CR/LF in the token                    | `uHTTPDownload.pas:776-782` (`Exit` with `FailReason`)                                             | neither                                       |
| Plaintext refused (`http://` without `AllowInsecure`), or no scheme                                   | `CheckScheme`, lines 386-399                                                                       | neither (`TlsUnavailable := useTLS` is False) |
| Verification refused for a reason other than the bundle, such as an OpenSSL with no `X509_check_host` | `ApplyTLSVerification` false, then line 806 `TrustBundleMissing := not TrustBundleUsable` is False | neither                                       |

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

| behaviour                                                                                                                                                                                                                                                 | evidence                                                                                                                                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Basic auth is sent **preemptively**: the `Authorization` header is built before the first request. WinHTTP's `WinHttpSetCredentials` is challenge-driven, so a WinHTTP transport must add the header itself.                                              | **read**: `fphttpclient.pp:670-672`                                                                                                                                                                                                                                                                                                         |
| **No decompression.** `Accept-Encoding: gzip,deflate` is sent by HamScore and the body is returned as received. A transport that turns on automatic decompression (`WINHTTP_OPTION_DECOMPRESSION`, `NSURLSession` default) changes what `Response` holds. | **read**: no gzip/deflate handling anywhere in `fphttpclient.pp`                                                                                                                                                                                                                                                                            |
| Redirects: followed up to 16 (`DefMaxRedirects`) when `AllowRedirect`, and `CheckScheme` has seen only the FIRST URL. Whether a redirect from `https` to `http` is followed is not checked anywhere in TR4W.                                              | **read**: `fphttpclient.pp:32-33, 1398-1413`; **inference**: the redirect target is requested with the scheme it names (`:1275-1288`), so an https-to-http downgrade is possible for the callers that follow redirects. WinHTTP's default policy (`WINHTTP_OPTION_REDIRECT_POLICY_DISALLOW_HTTPS_TO_HTTP`) forbids it. See open question 5. |
| Timeouts: `ConnectTimeout` and `IOTimeout`, in milliseconds, set from `ConnectMs` / `IOMs`.                                                                                                                                                               | **read**: `ApplyDefaults`; `fphttpclient.pp:279-280`                                                                                                                                                                                                                                                                                        |
| Response cap: only `THttpRequest.Send` enforces `MaxResponseBytes` (a stream that raises). Downloads and `HttpGetText` are unbounded.                                                                                                                     | **read**: `TBoundedHttpResponse`; `DownloadFileToPath` writes straight to a file stream                                                                                                                                                                                                                                                     |
| Verify-off: with `network.verifyServerCertificates` false the request proceeds unverified and a Warn line says so.                                                                                                                                        | **read**: `ApplyTLSVerification`                                                                                                                                                                                                                                                                                                            |
| `Sensitive` makes the operator-facing `FailReason` generic. **No caller sets it**; bearer requests get the same treatment by `BearerToken <> ''`.                                                                                                         | **read**: `Send` lines 861-866; a search for `Sensitive :=` finds only the declaration                                                                                                                                                                                                                                                      |
| User-Agent is per request, except `DownloadFileToPath`, which hard-codes `TR4W` (the parameter does not exist on it).                                                                                                                                     | **read**                                                                                                                                                                                                                                                                                                                                    |

## 3. The interface

### 3.1 Two layers, and what each may know

| shared layer (`uHTTPDownload`, platform-blind)                                       | transport (one unit per platform)                           |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| the three verbs and `THttpRequest`                                                   | opening the connection, TLS, the OS trust decision          |
| `CheckScheme`: scheme rule, plaintext rule, bearer policy                            | proxy resolution                                            |
| the verify-or-not **policy** (`network.verifyServerCertificates`)                    | applying that policy (what "verified" means here)           |
| atomic file write, `FromWire`/`ToWire`, the size cap                                 | timeouts, cancellation, redirects as the platform does them |
| **all logging of anything derived from a request**, and `MaskSecret` / `ScrubSecret` | reporting what happened, as data                            |
| turning a failure kind into `NothingSent`                                            | knowing whether it can PROVE nothing was sent               |

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
   and the contract line is enforced from S2. (NY4I, 2026-11-09: no policing of redirects in code; a
   separate pre-release check of every URL TR4W references. WinHTTP's default redirect policy IS this
   line, so S2 needs no S1c and the line stands as designed: no conflict.)
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

| need                         | functions declared                                                                                                                                                                                              |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| session, connection, request | `WinHttpOpen`, `WinHttpConnect`, `WinHttpOpenRequest`, `WinHttpCloseHandle`                                                                                                                                     |
| send and receive             | `WinHttpAddRequestHeaders`, `WinHttpSendRequest`, `WinHttpWriteData`, `WinHttpReceiveResponse`, `WinHttpQueryDataAvailable`, `WinHttpReadData`                                                                  |
| headers and status           | `WinHttpQueryHeaders` with `WINHTTP_QUERY_STATUS_CODE` (19), `WINHTTP_QUERY_STATUS_TEXT` (20), `WINHTTP_QUERY_CUSTOM` (65535), `WINHTTP_QUERY_FLAG_NUMBER`                                                      |
| options                      | `WinHttpSetOption`, `WinHttpQueryOption`                                                                                                                                                                        |
| proxy                        | `WinHttpGetIEProxyConfigForCurrentUser`, `WinHttpGetProxyForUrl`, `WinHttpGetDefaultProxyConfiguration`; access types `WINHTTP_ACCESS_TYPE_DEFAULT_PROXY` 0, `NO_PROXY` 1, `NAMED_PROXY` 3, `AUTOMATIC_PROXY` 4 |
| auth (not needed)            | `WinHttpSetCredentials`, `WINHTTP_AUTH_SCHEME_BASIC`: challenge-driven, so preemptive Basic is an `Authorization` header added by hand (contract line 10)                                                       |
| timeouts                     | **`WinHttpSetTimes`** (resolve, connect, send, receive). The header's option names end in `_TIME`, not `_TIMEOUT` (`WINHTTP_OPTION_CONNECT_TIME` 3 and so on), so there ARE constants. **Corrected at S2:** see the S2 as-built note.                                                                                 |

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
an exception. **HamScore's default is now https://hamscore.com/postxml/** (`HAMSCORE_DEFAULT_URL`, issue 250,
NY4I 2026-11-09; the HamScore spec recommends plain http://scoredistributor.net/ and we deviate, the URL stays
editable), so the default needs no ATS exception; `build-mac.sh`/`mac-sign.sh` carry none. An operator who SAVED the
old http default has it migrated to the https default ONCE (flag `Hamscore.UrlDefaultMigrated`); a later deliberate choice of the http URL is kept and would meet ATS on macOS. The
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

| option                                                                                                                                               | gains                                                                                                                                  | costs                                                                                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| generic + system CA tiers (recommended)                                                                                                              | one new function's worth of code, no new dependency, AppImage already bundles `libssl.so.3` (`build-appimage.sh` `DLOPENED`, **read**) | still OpenSSL, still FPC's client; hostname check still needs `X509_check_host` (present in 1.0.2+, so fine)                                                                                                                                                            |
| libcurl via `packages\libcurl\src\libcurl.pp` (present, **read**: `curl_easy_init`, `curl_easy_perform`, `CURLOPT_CAINFO`, `CURLOPT_SSL_VERIFYPEER`) | the distro's own TLS and CA handling, proxy environment variables                                                                      | a new `external` binding (a decision under the DLL rule), another library to find on every distribution, and for the AppImage another thing to bundle (libcurl pulls in its own TLS library); `libcurl` is not guaranteed present on a minimal install (**unverified**) |
| GnuTLS (`packages\gnutls` exists)                                                                                                                    | none worth the cost                                                                                                                    | a third TLS stack                                                                                                                                                                                                                                                       |

The AppImage can bundle libssl/libcrypto today and does; it cannot bundle the host's CA
bundle (it differs per distribution), which is the argument for the system tiers being a
real runtime search rather than a bundled copy.

### 4.5 The OpenSSL we ship on Windows (**read**)

| fact                                                                                                                                                                                                                                                                     | evidence                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| `tr4w/target/libeay32.dll` and `ssleay32.dll`: FileVersion and ProductVersion **1.0.2u**, product "The OpenSSL Toolkit", 1,281,536 and 277,504 bytes, dated 2026-07-03                                                                                                   | PowerShell `(Get-Item ...).VersionInfo`                        |
| 1.0.2u is the last release of the 1.0.2 series; that series reached end of public support at the end of 2019                                                                                                                                                             | **unverified** (from memory; the `u` suffix is read)           |
| `ssleay32.dll` contains the strings `TLSv1_2_method`, `TLSv1_1_method`, `SSLv23_method` and `TLS_method`, and **no** `TLSv1_3` string. TLS 1.2 is available; **TLS 1.3 is not**                                                                                          | `rg -a -o` over the binary                                     |
| `libeay32.dll` contains `X509_check_host`, which the hostname check needs                                                                                                                                                                                                | `rg -a -o`; and `uTLSTrust.pas` says it arrived in 1.0.2       |
| FPC's context creation (`stAny`) uses `SslTLSMethod` when bound, else `SslMethodV23` (`fpopenssl.pp:321-325`). Which of the two this DLL gets is **unverified**; both negotiate up to the highest version both sides support, so against this DLL the ceiling is TLS 1.2 | **read** / **inference**                                       |
| The comment in `uHTTPDownload.pas` ("https: TLS 1.2") is therefore a ceiling, not a setting: the code never selects a version                                                                                                                                            | **read**: no protocol is set in `uHTTPDownload` or `uTLSTrust` |
| Linux and macOS use whatever OpenSSL 3 / 1.1 is found or bundled (`uOpenSSLLoader`)                                                                                                                                                                                      | **read**                                                       |

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

| platform | bench items                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Windows  | badssl matrix (expired, wrong host, self-signed, untrusted root) rejected with `hfVerificationFailed` and verified as nothing-sent; a good host; a 2 s timeout against a black hole returns in about 2 s and reports the right phase; verify-off proceeds; behind a real proxy; on the oldest Windows NY4I still cares about (open question 4); a Club Log and a WRL request against the real services with the real tokens in a throwaway account |
| macOS    | the same matrix; ATS with an http:// HamScore URL; no deadlock when the startup CTY fetch runs before the run loop                                                                                                                                                                                                                                                                                                                                 |
| Linux    | the system-CA tiers on each distribution the AppImage targets; a machine with no `libssl`                                                                                                                                                                                                                                                                                                                                                          |
| all      | the existing hand probes pass on the generic transport after S1                                                                                                                                                                                                                                                                                                                                                                                    |

Add these to `docs/BENCH_QUEUE.md` when the corresponding stage lands, not before.

## 6. The staged plan

Each stage leaves the program working and is a separate commit series. "Specialists" are
the agents CLAUDE.md requires to be involved.

| stage          | what                                                                                                                                                                                                                                                                                                                                                                                                                                              | behaviour change              | gates                                                                                                                                                                                                                                                                     | specialists                                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **S0 (done)**  | #221 stopgap: look beside the exe, `TrustBundleMissing`, one notice, retry not uncertain. Commit `4dc105b9`.                                                                                                                                                                                                                                                                                                                                      | yes, as designed              | done                                                                                                                                                                                                                                                                      | integrations, build-release                                                                                    |
| **S1a (done)** | Create `uHttpTransport` (types, registry, `NothingSent`) and `uHttpTransportGeneric` (move `TFPHTTPClient`, `ApplyTLSVerification`, `TBoundedHttpResponse`, the OpenSSL/trust calls). `uHTTPDownload` keeps the verbs, `THttpRequest`, `CheckScheme` (scheme and policy only), the secrets functions, and delegates `Send`. Add the fake transport and the contract suite (generic only). `TlsUnavailable` / `TrustBundleMissing` become derived. | **none intended**             | `Build-Tests.ps1 -Run` and `-Checked`; `Run-Lints.ps1`; `gh workflow run release.yml` (the unit list changes, so all three platforms must compile). The golden corpus and the contest matrix are not needed: no engine code is touched. Hand-run `tls-verify-probe` once. | integrations, build-release (the `.lpr` list), settings-config only if a setting is added here (it is not)     |
| **S1b (done)** | Club Log and WRL classify by `NothingSent`; the three paths of section 2.3 become retry / failed instead of uncertain; new pin tests.                                                                                                                                                                                                                                                                                                             | **yes, small and deliberate** | unit tests; the updated pins; review by integrations                                                                                                                                                                                                                      | integrations                                                                                                   |
| **S1c**        | Decide the https-to-http redirect (open question 5) and, if forbidden, enforce it in the generic transport through `OnRedirect`.                                                                                                                                                                                                                                                                                                                  | yes, if forbidden             | unit tests with the loopback redirect                                                                                                                                                                                                                                     | integrations                                                                                                   |
| **S2 (in progress, 2026-11-09)** | `uHttpTransportWinHttp` (Windows only), selected by the new setting, **default `generic`**. Contract suite runs against it. Bench list above.                                                                                                                                                                                                                                                                                                     | none while default is generic | unit tests, `-Checked`, lints, `release.yml`, then the Windows bench                                                                                                                                                                                                      | integrations, build-release, settings-config, lcl-ui (Preferences row), i18n (resourcestrings for the setting) |
| **S2b**        | After the bench: default becomes `auto` (platform if `Available`, else generic, decided once and logged).                                                                                                                                                                                                                                                                                                                                         | the point of the work         | one release on `auto` with the setting as the escape hatch                                                                                                                                                                                                                | integrations, NY4I sign-off                                                                                    |
| **S3**         | `uHttpTransportNSURLSession` (macOS), same setting and rules. First a spike that proves the delegate / event bridge and the block question.                                                                                                                                                                                                                                                                                                       | none while default is generic | `release.yml` (macOS job), then a Mac bench; gated on the GUI having been run on a Mac                                                                                                                                                                                    | integrations, build-release (signing), lcl-ui                                                                  |
| **S4**         | Linux: system CA tiers in `TrustBundlePath`. No new transport unless the bench shows a reason.                                                                                                                                                                                                                                                                                                                                                    | yes (more places trusted)     | Linux CI, then the Mint bench                                                                                                                                                                                                                                             | integrations, build-release                                                                                    |
| **S5**         | Retire what a platform no longer needs. See below.                                                                                                                                                                                                                                                                                                                                                                                                | yes                           | per item                                                                                                                                                                                                                                                                  | build-release, integrations                                                                                    |

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

| kind                                                                                                        | outcome                                                              | pause   | code (`CLUBLOG_` / `WRL_` + ...) | why                                                                                                                                                                                  |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `hfTlsUnavailable`                                                                                          | retry, 300 s                                                         | no      | `TLS_UNAVAILABLE`                | unchanged from S0                                                                                                                                                                    |
| `hfTrustUnavailable`                                                                                        | retry, 300 s                                                         | no      | `CA_BUNDLE_MISSING`              | unchanged; **the only kind that raises the `OperatorNotice`**                                                                                                                        |
| `hfVerificationUnavailable` (2.3 path 3)                                                                    | retry, 300 s                                                         | no      | `VERIFICATION_UNAVAILABLE`       | an updated OpenSSL, or the operator's own setting (read on every request), cures it; no notice (the bundle is fine)                                                                  |
| `hfAuthPolicy` (2.3 path 1)                                                                                 | retry                                                                | **yes** | `AUTH_POLICY`                    | the credential class: the worker already turns a 401 into retry-and-stop "for a replacement credential". Nothing is lost. Now also logged (Error, URL scrubbed), where it was silent |
| `hfPlaintextNotAllowed`, `hfBadScheme` (2.3 path 2)                                                         | **failed**                                                           | **yes** | `URL_REFUSED`                    | a malformed request; both clients hard-code https, so it is a defect, and failing each delivery in turn would burn the queue                                                         |
| any other proved kind (`hfNameNotResolved`, `hfCannotConnect`, `hfConnectTimedOut`, `hfVerificationFailed`) | retry, 300 s                                                         | no      | `NOT_SENT`                       | the generic transport reports none of these; a platform transport will                                                                                                               |
| everything else                                                                                             | unchanged: Club Log uncertain + pause; WRL POST uncertain, GET retry |         |                                  | "may have been sent"                                                                                                                                                                 |

**S2, as built (2026-11-09) -- where it differs from the design, and what it found.** Built and unit-tested;
NOT benched, and not the default.

* **Files.** `uHttpTransportWinHttp` (Windows only: the body and the type are inside the WINDOWS gate and the
  unit is empty elsewhere; it registers itself as the preferred transport; listed in `tr4w.lpr` and the
  unit-test `.lpr`). `uHttpTransport` gained the policy (`ActiveHttpTransport(aPolicy)`, the three
  `HTTP_TRANSPORT_*` words) and the shared `TBoundedHttpResponse` (lifted out of the generic unit so the cap
  behaves identically). The static binding is FPC's own `winhttp` unit, justified in the unit's header (NY4I,
  question 6). Compiles for Linux (the unit is empty there).
* **THE SETTING.** `network.httpTransport`, command `NETWORK HTTP TRANSPORT`, property
  `Settings.Network.HttpTransport` (a string; vocabulary `generic`, `auto`, `platform`, registered from the
  named table `HTTP_TRANSPORT_SPELLINGS`), **default `generic`**. A generated row in Preferences > Network,
  group "Internet downloads and uploads"; its help is in `i18n/help_en.po` (the other catalogues fall back to
  English until `ini2po` merges it). Registering the transport does NOT make it the default: the registry
  knows no setting, `uHTTPDownload.TransportPolicy` reads it and passes it in, and blank or unknown means
  generic. `auto` and `platform` choose the preferred transport if it is Available; the one difference is that
  `platform` on a platform with none logs a Warn saying so (Linux and macOS today).
* **"DECIDED ONCE" BECAME "DECIDED PER POLICY VALUE".** The startup country-file download
  (`EnsureCountryFile`) runs BEFORE `LoadSettingsForStartup`, so the first request in a session sees the
  setting's default. Deciding once would lock that in for the session and make the setting a no-op for
  everything after it. The registry now re-decides, and logs again, only when the policy value CHANGES; the
  transport it replaces is kept alive until exit (a worker may be inside it). A failed request never
  re-decides: there is still no per-request fallback. So a Preferences change applies from the next request,
  with no restart.
* **Timeouts: `WinHttpSetTimes` is not used, and the design's claim was wrong.** The real export is
  `WinHttpSetTimeouts`; a static import of a name the DLL does not export stops the program from starting.
  The timeouts go through `WinHttpSetOption` with the `WINHTTP_OPTION_*_TIME` numbers 2, 3, 5, 6 and 7 that the
  header does carry.
* **WINHTTP'S TIMEOUTS ARE COARSE, MEASURED.** Against a server that read the request and stayed silent, a
  standalone program set the timeouts on the session and on the request, under all three proxy modes, and the
  call gave up at 200 ms -> 4000 ms, 400 -> 4000, 1000 -> 4016, 2500 -> 4016, 6000 -> 8000 (Windows 11 build
  26200; a Python and an Indy server agree; the generic transport on the same server gives up at 400 ms). The
  value is rounded UP to a multiple of about 4 s. Contract line 5 therefore holds to within 4 s for this
  transport; the callers' own values are 5 to 30 s. **The connect timeout was not measured** (a black-holed
  address is a bench item) and may behave the same way. If an exact deadline is ever wanted, the answer is the
  cancellation route (a watchdog closing the request handle), which is not built.
* **`WinHttpSendRequest` did not return until the server answered** in that experiment (3016 ms against a
  3 s server). So section 4.2's phase rule ("before `WinHttpSendRequest` returned = the connect phase") is
  wrong twice over: the call also sends, and here it also waits. **Every timeout is `hfIOTimedOut`** (may have
  been sent). The name, connect and certificate kinds are reported as proved ONLY when `FollowRedirects` is
  False, because with redirects on such a failure can belong to the second request after the first went out
  (Club Log and WRL follow none, so they get the proofs). A status-callback phase tracker
  (`WINHTTP_CALLBACK_STATUS_SENDING_REQUEST`) would let a connect timeout be proved unsent; it is not built
  and is an option for NY4I.
* **Contract line 9 is not free on WinHTTP.** Cookies and automatic answering of an authentication challenge
  are switched off (`WINHTTP_OPTION_DISABLE_FEATURE`); decompression is never enabled (pinned by a test whose
  server says `Content-Encoding: gzip` and sends text that is not gzip); one session per `Execute`.
* **Redirects.** `NEVER` when not following, else `DISALLOW_HTTPS_TO_HTTP` (contract line 8) with a limit of
  16. A refused downgrade surfaces as `ERROR_WINHTTP_REDIRECT_FAILED`, which is `hfOther` (the first request
  went). It cannot be tested over plain loopback: it is a bench item.
* **Proxy.** `WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY`; if `WinHttpOpen` refuses that, `DEFAULT_PROXY`, decided
  before any request exists. Following the user's own proxy settings is unverified: bench item.
* **Verify off** sets the four IGNORE flags and nothing else. WinHTTP does not check revocation unless asked
  and this transport does not ask (design contract 11 names chain, host name and validity only).
* **Wire parity with the generic transport,** pinned by the shared contract suite: a Get verb accepts only
  200 and says "Unexpected response status code: N" (FPC's sentence) without reading the body; an attached
  empty body goes out as `Content-Length: 0` on every verb; Basic is preemptive; the User-Agent is the
  request's.
* **The contract suite** (`uTestHttpTransport.RunContract`, 17 tests, 18 with the generic-only OpenSSL one) runs once against the generic transport
  and once against WinHTTP (tags `[winhttp]`), over the plain-HTTP loopback server. Three expectations differ
  by transport and are written down: the refused connection (generic claims nothing; WinHTTP is
  `hfCannotConnect` and proved unsent, but `hfOther` with redirects on), the silent server (above), and the
  OpenSSL-forced-unavailable test (generic only). The registry's own tests take the real WinHTTP transport out
  of the registry for their run.
* **Not covered by any unit test:** TLS (no HTTPS server in the repository), proxies, the connect timeout, the
  redirect downgrade, an IPv6 literal. See the bench list.

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

| stage                               | exit criteria                                                                                                                                                                                                                           | the first real run must show                                                                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S2 Windows                          | the 15-line contract suite green against `winhttp` over loopback; `-Checked` clean; lints; `release.yml` green on all three platforms; bench matrix of section 5 passed on one real Windows machine                                     | `[HTTP] transport: winhttp`; **no** `[TLS] CA bundle` line and no OpenSSL load, with `cacert.pem` deliberately absent from beside the exe (this is the failure class of issue 221 gone); a Club Log test-mode create and a WRL create each settle as confirmed; a bad certificate refused with a nothing-sent code (`*_NOT_SENT`) and the request absent from the server log; a 2 s timeout against a black hole returning in about 2 s |
| S2b `auto` default                  | one release on `auto` with no operator forced back to `generic`                                                                                                                                                                         | the transport line names `winhttp` on every machine in the field logs NY4I sees; no new delivery stuck in uncertain that the generic path would have retried                                                                                                                                                                                                                                                                            |
| S3 macOS                            | the spike proves the delegate and event bridge (or the block question is answered the other way and the design is amended); contract suite green on a Mac; the bundle still notarizes; gated on the GUI having been run on a Mac at all | `[HTTP] transport: nsurlsession`; a GET from a worker thread completes while the main run loop is idle; the startup CTY fetch on the main thread does not deadlock; a bad certificate is refused as nothing-sent; the answer to plain `http://` under ATS (HamScore default) is recorded, whichever way it falls                                                                                                                        |
| S4 Linux                            | the system CA tiers found on each distribution the AppImage targets; contract suite green; `release.yml` Linux job green                                                                                                                | `[TLS] CA bundle: <path> (<tier>)` naming a system file on a machine whose `cacert.pem` is deliberately removed; the AppImage on the Mint machine completes a CTY download                                                                                                                                                                                                                                                              |
| any logger added later (section 10) | the provider registers, declares its fields and passes its own client tests; if HTTP, it adds no new transport requirement or it amends this document first                                                                             | a delivery from a real instance of the program it targets, confirmed in that program's own log                                                                                                                                                                                                                                                                                                                                          |

## 7. The packaging finding: is `cacert.pem` beside every exe that runs?

**No, not in `build-out\app-i386-win32`.** That folder holds `libeay32.dll`,
`ssleay32.dll` and the other DLLs but no `cacert.pem`, while `tr4w\target` has both (a
directory listing of each, **read**). Cause and per-platform staging, all **read**:

| place                                                            | does it get `cacert.pem`?               | by what                                                                                                                                                                                                                |
| ---------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tr4w\target` (where `FullBuild.ps1` links the exe)              | yes                                     | the file is tracked (`git ls-files tr4w/target` lists it); when the exe's folder is the DLL source, "Nothing to stage" (`Build-App.ps1`, the comment above the staging loop)                                           |
| `build-out\app-i386-win32` (`Build-App.ps1` without `FullBuild`) | **no**                                  | the staging step enumerates only `-Filter '*.dll'` from `$dllSource` (`Build-App.ps1:553`) and copies each to `$exeDir` (`:642`). A `.pem` is not a `.dll`.                                                            |
| Windows installer                                                | yes                                     | `full.nsi:145-152` (`File ..\target\cacert.pem`, with the refresh instruction)                                                                                                                                         |
| Linux tarball                                                    | yes                                     | `build-unix.sh:1317-1325` copies `cacert.pem` among the data files; the stage fails if it is missing                                                                                                                   |
| Linux AppImage                                                   | yes                                     | `build-appimage.sh:188` copies the tarball stage into `usr/bin`, and `DLOPENED` (line 135) collects `libssl`/`libcrypto` into `usr/lib`                                                                                |
| macOS `.app`                                                     | yes                                     | the stage is moved into `Contents/Resources` (`build-unix.sh`, the `mv` loop in the macOS arm), which is `BesideProgramFilePath` on macOS (`uAppPaths.pas:316-329`); the OpenSSL libraries go to `Contents/Frameworks` |
| CI workflow                                                      | nothing in `.github/workflows` names it | it rides the installer and the stages above                                                                                                                                                                            |

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

### Decided 2026-11-09

NY4I answered questions 1, 3, 4, 5, 6 and 8 in the text below. For every question he did not
answer he accepted the recommendation written here. Nothing below was deleted: the questions and
his answers stand as he left them.

| question | decision | who |
| -------- | -------- | --- |
| 1. Windows API | WinHTTP, not WinINet | NY4I answered |
| 2. S2 policy | a setting (`network.httpTransport`), default `generic` at S2, `auto` at S2b; no per-request fallback ever | NY4I accepted the recommendation |
| 3. Windows and the OpenSSL DLLs | Windows 11 is the supported platform (Windows 10 may work, unsupported); Windows 7 is dropped. The DLLs leave the installer only after a release has run on `auto` (see 14) | NY4I answered |
| 4. Windows floor | Windows 11; Windows 10 is not guaranteed, Windows 7 is not supported. To be written in the installer and README | NY4I answered |
| 5. https to http redirect | no policing in code. NY4I wants a separate pre-release check that every URL TR4W references still answers validly (its own issue). Contract line 8 stays as designed: WinHTTP's default policy already forbids https to http, so it does not conflict, and S1c is NOT a dependency of S2 | NY4I answered |
| 6. Binding of `winhttp.dll` | STATIC, through FPC's `winhttp.pp`; no `LoadLibrary` | NY4I answered |
| 7. Linux and macOS trust order | Linux: system bundle first, `cacert.pem` last; macOS: Keychain only | NY4I accepted the recommendation |
| 8. macOS, ATS and plain http | HamScore also supports https; its own issue is filed | NY4I answered |
| 9. Main-thread callers (version check, startup CTY) | a separate issue (filed) | NY4I accepted the recommendation |
| 10, 15. Proxy | the platform transports follow the operating system's proxy configuration; no TR4W proxy field | NY4I accepted the recommendation |
| 11. Linux | stays on OpenSSL with system CA tiers (no libcurl) | NY4I accepted the recommendation |
| 12. Credential over plain http | only as an explicit per-definition choice with a visible warning; never a bearer token; never by default | NY4I accepted the recommendation |
| 13. Verify certificates | per definition on the HTTP providers, default on; the global setting stays the master switch | NY4I accepted the recommendation |
| 14. Dropping `libeay32.dll` / `ssleay32.dll` | only after a release has run on `auto` | NY4I accepted the recommendation |

1. **Windows API: WinHTTP (recommended) or WinINet?** WinHTTP is thread-safe, has explicit
   redirect, proxy and security-flag control, and no interactive-desktop state to switch
   off. WinINet exists only if you want it to share Internet Explorer's settings and cache,
   which contract line 9 would turn off anyway. Answer: WinHTTP.

   
2. **S2 policy: setting plus `auto` after the bench (recommended), or automatic from the
   first release?** Recommend the setting, default `generic` at S2 and `auto` at S2b,
   no per-request fallback ever (section 6).
3. **When the platform transport has shipped as default, does Windows keep OpenSSL and
   `cacert.pem` in the installer?** Recommend yes for one release after S2b, then decide;
   keeping them costs about 1.5 MB and keeps the Windows 7 path (question 4). Dropping them
   removes the x86_64 OpenSSL blocker for the 64-bit build. ANSWER: There arre some users running TR4W-D7 on WIndows 7 but I have no desire to support WIndows 7. We canstate Windows 11 is our supported platform (although it appears to work on WIndows 10 but since that is a non-supported Operating System, no TR4W support is guranteed. THis affect the next question too.
4. **What is the oldest Windows TR4W 5.x supports?** Not stated in the repository. If
   Windows 7 matters, WinHTTP there needs an OS update for TLS 1.2 (unverified), and the
   generic transport is the better answer on that machine. Recommend deciding the floor
   before S2 and writing it in the installer and README.
5. **Should a redirect from https to http ever be followed?** Today the generic path may
   follow it for the callers that follow redirects (CTY, TRMASTER, POTA, version check,
   HamScore, score post, SCP). Recommend never, enforced at S1c, with a log line when a
   redirect is refused; the cost is a download that depended on such a redirect failing
   visibly (none is known). ANSWER: I'm less concerned about a redirect fromhttp to https with a redirect from an existing URL to a site providers choice to redirect somewhere else. Perhaps a good solution is for us to include a test in the pre-release build to check all the URLs we ever reference are still reporting valid.
6. **Static or dynamic binding of `winhttp.dll`?** Static is simplest; a missing DLL would
   stop the program from starting. Recommend dynamic (`LoadLibrary` inside the unit, so
   absence is `Available = False`), accepting that it is the more code of the two. ANSWER: Static.
7. **Linux and macOS trust order.** Linux: system bundle first, or `cacert.pem` first?
   Recommend system first, so a distribution's trust policy wins, with `cacert.pem` as the
   last tier. macOS: Keychain only.
8. **macOS and plain `http://` (ATS).** HamScore's default is `http://`. Recommend an
   `Info.plist` ATS exception for the contest-score and HamScore hosts' use case, with the
   `IsPlainHttpUrl` note kept, rather than refusing http on macOS (which would break the
   default HamScore setup). Needs your decision because it is a security posture. ANSWER: Hamscore also has support for https end points as well. See this image: ![](data:image/png;base64,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)
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

| question                          | command                                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| who calls the HTTP verbs          | `rg -n "HttpGetText\|DownloadFileToPath\|THttpPost\|THttpRequest" tr4w/src --glob "*.pas"`                               |
| what links OpenSSL                | search every `uses` clause for `opensslsockets`, `openssl`, `fpopenssl`, `sslsockets`, `uOpenSSLLoader` (and `tr4w.lpr`) |
| the shipped OpenSSL               | `(Get-Item tr4w\target\libeay32.dll).VersionInfo` in PowerShell                                                          |
| what `winhttp.pp` declares        | `rg -n -i "^\s*function WinHttp" C:\Lazarus\fpc\3.2.2\source\packages\winunits-base\src\winhttp.pp`                      |
| which `cacert.pem` a run used     | the `[TLS] CA bundle: <path> (<tier>)` line in `tr4w.log`                                                                |
| what is staged beside a built exe | list `build-out\app-<cpu>-<os>` and compare with `tr4w\target`                                                           |
| what each logger does on the wire | `rg -n "DeliverCommand\|THttpRequest\|TExternalDeliveryClient" tr4w/src --glob "*.pas"`                                  |
| which loggers are registered      | `rg -n "RegisterExternalLogger\(" tr4w/src --glob "*.pas"`                                                               |

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

| expectation                                                                                                                                                                                                                                    | where                                                                                             | what it means for a new destination                                                                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| A provider registers an id, a display name, a constructor returning a `TExternalLoggerService`, and a declarer listing its editor rows (text, port, secret, choice)                                                                            | `uExternalLoggerRegistry.RegisterExternalLogger`                                                  | The registry names no transport. A provider may be HTTP, TCP, UDP or a file.                                              |
| A durable provider derives from `TDurableExternalLogger` and supplies `BuildPayload` and `CreateWorker`; capture happens inside the QSO transaction and the worker claims, sends and settles in short transactions that never span the network | `uDurableExternalLogger.pas`, and `docs/EXTERNAL_LOGGERS_DESIGN.md` (queue and thread invariants) | Queue semantics, crash safety, per-destination namespace and the Connection column come free. Only the client is new.     |
| The client is a `TExternalDeliveryClient` whose `Deliver(job)` returns a `TExternalDeliveryResult`: outcome `doConfirmed`, `doRetry`, `doUncertain` or `doFailed`, an error code, a retry delay, a `Pause` flag and an `OperatorNotice`        | `uExternalDeliveryClient.pas`, `TDeliveryOutcome` in `domain/uExternalDelivery.pas`               | The client is the ONLY place a protocol appears. The worker is protocol-neutral.                                          |
| "Nothing was sent" is a claim the client proves, and `ApplyNothingSent` is the one classifier for HTTP clients                                                                                                                                 | `uExternalDeliveryClient.ApplyNothingSent`, section 6 (S1b as built)                              | It takes a `THttpRequest`, so today it is HTTP-shaped. See 10.4.                                                          |
| A non-idempotent write whose reply is lost is `doUncertain` and is not replayed blindly; Club Log replacement is delete-then-create and parks as uncertain if the create fails                                                                 | `docs/EXTERNAL_LOGGERS_DESIGN.md`, "Changes, deletes and uncertainty"                             | A destination with no acknowledgement cannot ever be `doConfirmed` by the wire alone (DXKeeper, below).                   |
| Credentials live in the OS vault under the definition id; a secret field is never required because a locked vault leaves it empty                                                                                                              | registry rules, `uExternalLoggerConfig`                                                           | A new destination with a key or password declares an `AddSecret` row and reads it at construction; nothing HTTP-specific. |
| Every implemented provider must support new, change and delete with its real protocol; an unsupported operation fails visibly                                                                                                                  | `docs/EXTERNAL_LOGGERS_DESIGN.md`, "Remaining External Logger issues"                             | A destination that cannot delete is not complete.                                                                         |
| The older non-durable shape: `TExternalLoggerBase` with a `TSenderThread` (3 attempts, linear back-off, in-memory FIFO, `ShutdownDrain` at exit) and a `TReadingThread` that exists only for the persistent socket                             | `uExternalLoggerBase.pas`                                                                         | DXKeeper uses the sender thread only. The reading thread and the persistent socket serve ACLog and HRD, which are stubs.  |

### 10.2 The table

"Seam" means the transport interface of section 3 (`THttpWireRequest` / `THttpWireResult` /
`TPlatformHttpTransport`). "Classification" means `ApplyNothingSent` and the four outcomes.

| destination                                                           | status in the tree                                                                                                  | transport today                                                                                                                                                                                                                         | does the HTTP seam cover it                         | what it needs that the seam does not offer                                                                                                              | design survives unchanged                                                                                                                                                                 |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Club Log                                                              | implemented, durable                                                                                                | HTTPS REST through `THttpRequest`, bearer token, redirects off, response capped at 4096                                                                                                                                                 | yes, it is the reference client                     | nothing                                                                                                                                                 | yes                                                                                                                                                                                       |
| WRL                                                                   | implemented, durable                                                                                                | HTTPS REST through `THttpRequest`, bearer token, redirects off, default cap                                                                                                                                                             | yes                                                 | nothing                                                                                                                                                 | yes                                                                                                                                                                                       |
| HamScore                                                              | implemented, NOT a delivery worker: its own 2-minute batch uploader (`uHamScore.pas`, `PostToServer`)               | `THttpPost`, Basic auth, **`https://hamscore.com/postxml/` by default since issue 250** (plain http still allowed) with `AllowInsecure`                                                                                                                                       | yes                                                 | on macOS, an ATS answer for plain http (section 4.3); nothing in the seam                                                                               | yes. It keeps its QSOs on a refusal and does not use `ApplyNothingSent` (it reads the status and the trust latch directly). It could, and the three-line change is not part of this work. |
| Contest score post                                                    | implemented, one-shot worker (`uGetScores.pas`)                                                                     | `THttpPost`, form body, https default, operator may type `http://`                                                                                                                                                                      | yes                                                 | the same ATS answer                                                                                                                                     | yes                                                                                                                                                                                       |
| Downloaders (CTY, TRMASTER, POTA parks, version check) and SCP upload | implemented, operator actions                                                                                       | `DownloadFileToPath`, `HttpGetText`, `THttpPost`                                                                                                                                                                                        | yes (section 2.2)                                   | nothing; they only read `FailReason`                                                                                                                    | yes                                                                                                                                                                                       |
| DXKeeper                                                              | implemented, Complete                                                                                               | **raw TCP**, one fresh `TIdTCPClient` per command (`TExternalLogger.DeliverCommand`: connect 2 s, write one line, read any reply up to 1 s, close), on the `TSenderThread`; host name goes through `uHostResolve`                       | **no, and it should not**                           | a TCP connect/write/read vocabulary: not-resolved, refused, connect timeout, write failed. No TLS, no headers, no status code, no redirects             | yes, because it never used the seam. See 10.3 for the one shared piece.                                                                                                                   |
| ACLog                                                                 | **stub** (`LogQSOToACLog` logs "not yet implemented"; type `lt_ACLog` is not registered, issue 33 asks for TCP)     | intended: TCP to a host and port (issue 33). The wire protocol is **unverified**: the tree does not say. My belief is that N3FJP's ACLog has a TCP API with a default port in the 1000s and XML-like commands; nothing here confirms it | no                                                  | whatever its command and reply set is; probably a per-command TCP exchange like DXKeeper, or a persistent socket (the base class assumes persistent)    | yes. It is a TCP client behind the same registry. If it is durable it implements `TExternalDeliveryClient`, which is protocol-neutral.                                                    |
| HRD (Ham Radio Deluxe)                                                | **stub** (`LogQSOToHRD`, same text; `lt_HRD` not registered; no open issue)                                         | intended: TCP (the base class's comments say "for future ACLog/HRD"). The wire protocol is **unverified**; HRD Logbook has more than one external interface and I have not read which one this tree intended                            | no                                                  | as ACLog                                                                                                                                                | yes, same reasoning                                                                                                                                                                       |
| Log4OM                                                                | **planned** (issue 203, "TR4W to Log4OM direction only")                                                            | UDP to a host and port, per the issue                                                                                                                                                                                                   | no                                                  | one datagram per message, no connection, so "sent" can never be proved delivered. Already handled by the UDP sink machinery and `LogCfg.SendUDPPayload` | yes. Not HTTP, not durable-with-acknowledgement. It is the dispatcher's UDP sink shape.                                                                                                   |
| Cloudlog and Wavelog                                                  | **planned** (issue 204, "instance URL, API credential and remote station profile; several instances may be active") | HTTP or HTTPS REST to an **operator-run server**. Endpoint and body shape **unverified** (my belief: a JSON POST carrying the key and an ADIF string)                                                                                   | **yes, and this is the case that tests the design** | see 10.3                                                                                                                                                | **yes, with five things the HTTP design must not rule out** (10.3)                                                                                                                        |
| MacLoggerDX                                                           | **planned** (issue 205)                                                                                             | **not established.** The issue says to verify the real import mechanism, and warns that a compatible UDP announcement does not prove MacLoggerDX will import it; a macOS-native adapter is allowed                                      | unknown                                             | unknown: possibly UDP, possibly a local file or a macOS interprocess mechanism                                                                          | the design is not affected: it is outside HTTP and may be outside the network                                                                                                             |

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

| property                               | consequence for the design                                                                                                                                            | what the design already says, and the gap                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| plain `http://` on a LAN is common     | the bearer policy (`hfAuthPolicy`) refuses a bearer token over http. If Cloudlog sends its key in the BODY, the policy does not fire and the key travels in the clear | Club Log and WRL are https-only. **Gap:** a destination definition needs a per-destination "allow plain http" choice (the verbs already have `AllowInsecure`), and an open question for NY4I on whether secrets may ever travel in the clear on a private network (question 12). The transport interface is unchanged.                                                                                                                                                                               |
| self-signed or private-CA certificates | the global "verify certificates" setting is all-or-nothing today, and `cacert.pem` will never contain a home CA                                                       | A platform transport on Windows or macOS trusts what the OS trusts, so an operator who installed their CA in the system store is served for free (an advantage of section 4.2 and 4.3 the document should claim). **Gap:** an operator with a self-signed server and no CA to install needs a per-destination "do not verify" choice. `THttpWireRequest.VerifyServer` is already per request, so the INTERFACE needs nothing; the SETTING needs to move from global to per definition (question 13). |
| redirects, especially http to https    | a POST that is redirected may be re-sent as a GET, and a redirected write is a double-delivery risk                                                                   | Club Log and WRL disable redirects. A Cloudlog client does the same and reports the 301 with its `Location` as a failure that names the cure ("use the https address"), which needs `Location` in `THttpWireResult` (**gap**, one more header like `RetryAfter`). Contract line 8 is unchanged.                                                                                                                                                                                                      |
| the host is a LAN name or an address   | `.local` names, short names and private addresses                                                                                                                     | Resolved by the platform resolver in WinHTTP and NSURLSession (their reason to exist) and by the existing `uHostResolve` path for the generic one. On macOS, ATS treats local networking differently from the internet (**unverified**: `NSAllowsLocalNetworking`), so the Info.plist answer in question 8 should be chosen with this destination in mind.                                                                                                                                           |
| several instances at once              | independent destination queues                                                                                                                                        | The registry, definitions, per-definition namespace and one worker each already do this; Club Log and WRL are two such instances. The HTTP seam is stateless between requests, so there is no shared transport state to collide.                                                                                                                                                                                                                                                                     |

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

| if this happens                                                                     | does section 3 change                                          | does something else                                                                                                                                                          |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ACLog or HRD turn out to speak HTTP                                                 | no: they use the seam                                          | register a provider                                                                                                                                                          |
| ACLog or HRD turn out to speak a persistent TCP protocol with acknowledgements      | no                                                             | the base class's reading thread and persistent socket (`ConnectGuarded`, `ReconnectFromReader`) are exactly for this and are pinned; a durable client may be built over them |
| a durable TCP client is written                                                     | no                                                             | split `ApplyNothingSent` as in finding 2                                                                                                                                     |
| Cloudlog/Wavelog needs per-destination verify or plain http                         | no, `VerifyServer` and `AllowInsecure` are already per request | the definition gains two fields, with the secrets rule applied (the settings-config agent)                                                                                   |
| MacLoggerDX needs a macOS-native interface (AppleScript, a file drop, Apple events) | no                                                             | a platform provider unit with a `{$IFDEF DARWIN}` body, registered like the keychain backends                                                                                |
| Log4OM UDP                                                                          | no                                                             | the existing UDP sink machinery                                                                                                                                              |
| a destination needs TLS client certificates, or a pinned certificate                | **yes**: `THttpWireRequest` has nowhere to put either          | decide when one exists; none of the current or planned destinations is known to                                                                                              |

## 11. The URL test: what the operator reads (issue 251, 2026-11-09)

Preferences > Online scoring has a **Test** button beside the HamScore Service URL and the score
board Posting and Reading URLs. NY4I's rule: a **200 is success; anything else is DISPLAYED, not
judged**. The wording never says invalid, bad or failed. `uUrlTest` owns the request (one GET
through `THttpRequest`: no credentials, no body type, redirects followed, `AllowInsecure`, 10 s
connect and 15 s I/O, a 1 MB cap that still counts as an answer) and `uUrlTest.UrlTestText` owns the
sentences; `uUrlTestButton.TUrlTester` is the reusable control. The text tested is the box as it
stands, saved or not, untrimmed (a real upload does not trim either). Only a reply or "no answer" is
reported, so **a refused request never reaches the network**: an empty box, a non-http scheme.

| outcome (`THttpFailure`)                       | the sentence (resourcestring)                                       | words added in parentheses                 |
| ---------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------ |
| answered (`hfNone`, or `hfResponseTooLarge` with a status) | `Answered 200` (`SUrlTestAnswered`); after a redirect `Answered 200 from <final address>` (`SUrlTestAnsweredFrom`) | none |
| empty box                                      | `Nothing to test: the address box is empty.`                        | none                                       |
| `hfBadScheme`                                  | `No answer: the address does not start with http:// or https://`    | none (the shared layer has no words)       |
| `hfPlaintextNotAllowed`                        | `No answer: a plain http:// address was not sent`                   | none; unreachable, the test allows http    |
| `hfTlsUnavailable`                             | `No answer: the OpenSSL libraries could not be loaded`              | the loader's diagnostic                    |
| `hfTlsLibraryFault`                            | `No answer: the TLS library stopped while connecting`               | the library's message                      |
| `hfTrustUnavailable`                           | `No answer: the certificate file cacert.pem could not be used`      | the bundle search result                   |
| `hfVerificationUnavailable`                    | `No answer: server certificates cannot be checked on this machine`  | the setup reason                           |
| `hfVerificationFailed`                         | `No answer: the server's certificate was not accepted`              | WinHTTP error name                         |
| `hfNameNotResolved`                            | `No answer: the host name was not found`                            | WinHTTP error name                         |
| `hfCannotConnect`                              | `No answer: could not connect`                                      | WinHTTP error name                         |
| `hfConnectTimedOut`                            | `No answer: timed out connecting`                                   | the transport's message                    |
| `hfIOTimedOut`                                 | `No answer: timed out waiting for the server`                       | WinHTTP error name                         |
| `hfConnectionLost`                             | `No answer: the connection was lost`                                | WinHTTP error name                         |
| `hfCancelled`                                  | `No answer: the request was cancelled`                              | WinHTTP error name                         |
| `hfAuthPolicy`, `hfResponseTooLarge` without a status, `hfOther` | `No answer: <the words>` (`No answer` alone when there are none) | the transport's message, which IS the answer |

**Which kinds actually occur.** The URL test follows redirects, and a transport claims a
"nothing sent" kind only when no redirect can have sent an earlier request. So in this test the
**WinHTTP** transport reports DNS, refused connection and certificate rejection as `hfOther`, with
text like `WinHttpSendRequest failed with error 12007 ERROR_WINHTTP_NAME_NOT_RESOLVED`; the
**generic** transport reports all of those, and a timeout, as `hfOther` with FPC's or OpenSSL's own
message (it can prove only `hfTlsUnavailable`, `hfTrustUnavailable`, `hfVerificationUnavailable`).
The distinct sentences above therefore mostly appear for the TLS-setup kinds, a scheme refusal and
a WinHTTP timeout or lost connection; the rest are there for a transport that can say more. The
parenthesised words are one line, at most 160 characters. The record of what each transport
really prints for NY4I's two sites (`uparc.org`, `ny4i.com`) is the BENCH_QUEUE item for the plain
http URL. `THttpWireResult.FinalURL` (the generic transport reads it from `OnRedirect`, WinHTTP from
`WINHTTP_OPTION_URL`) is set only when a followed redirect ended at another address.

## 12. What a POST becomes across a redirect (issue 253, 2026-11-09)

**Measured over loopback, no third-party host contacted.** `Test_APostAcrossARedirect` (in the
contract suite, so it runs for BOTH transports; `[winhttp]` prefix for the second) POSTs a form body
to a path that answers 301, 302, 303, 307 or 308 with `Location: /echo`, and records the method
and body the server received at `/echo`. `Test_ThePostVerbCarriesItsBodyAcrossA301` asks the same
through `THttpPost` (the class `uGetScores` uses, `FollowRedirects` True by default) and the active
transport.

| status | generic (FPC `TFPHTTPClient`)                       | WinHTTP                                   |
| ------ | --------------------------------------------------- | ----------------------------------------- |
| 301    | POST, body arrives                                  | **GET, body DROPPED**                     |
| 302    | POST, body arrives                                  | **GET, body DROPPED**                     |
| 303    | GET, **body still sent** with the GET               | GET, body dropped                         |
| 307    | POST, body arrives                                  | POST, body arrives                        |
| 308    | POST, body arrives                                  | POST, body arrives                        |

The generic half is also readable from source: `fphttpclient.pp`'s `RedirectForcesGET` is true
for 303 only, and the loop rewinds `RequestBody` before the repeat (its own comment says "307/308",
the code says 303). **WinHTTP is the surprise: it turns a POST into a GET on 301 and 302, so with
that transport a score POST sent to a URL that answers 301 (for example
`https://contestonlinescore.com/post`, no trailing slash) would arrive at `/post/` as a body-less
GET, and `uGetScores` would see whatever that answers (a 200 page) and report success.** The
generic transport, which is the default today, delivers it. Redirect policy was NOT changed. This
is why the default carries the trailing slash, and it is a reason to decide the platform
transport's default (S2b) with this table in front of us. Nothing in the repo copies the RTC
rules or the XML specification's posting endpoint (`uContestRTC.pas` and `uScoreBreakdown.pas` only
cite the sponsor's blog pages), so the endpoint is the one in the issue.
