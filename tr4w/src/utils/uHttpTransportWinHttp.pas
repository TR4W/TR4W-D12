unit uHttpTransportWinHttp;
{$I ..\tr4w.inc}   // relative: this unit lives in src\utils, the include in src
(*
  THE WINDOWS TRANSPORT: WinHTTP, THE OPERATING SYSTEM'S OWN HTTP CLIENT.

  Issue 224, stage S2; docs/HTTP_TRANSPORT_DESIGN.md is authoritative (sections
  3.3, 4.2 and 6). The body of this unit is inside the WINDOWS gate and the
  unit is EMPTY elsewhere, so tr4w.lpr lists it unconditionally, as the
  credential-vault units are. Nothing outside the gate knows it exists: it is
  reached only through the registry in uHttpTransport.

  WHAT IT BUYS. Trust is the operating system's certificate store, kept current
  by Windows Update, so there is no cacert.pem to go stale or be missing beside
  the exe (issue 221), no OpenSSL pair, and TLS 1.2/1.3 as Windows offers them.
  The operating system's proxy configuration applies. SELECTION IS THE
  SETTING'S (network.httpTransport); at S2 the default is `generic`, so this
  transport runs only for an operator who asked for it.

  A STATIC BINDING TO winhttp.dll, BY NY4I'S DECISION (2026-11-09; design 8,
  question 6): this unit uses FPC's own `winhttp` unit, so the import is
  resolved when the program loads. CLAUDE.md's "no new direct calls into a DLL"
  rule is a decision, and this is the one NY4I made: WinHTTP is part of every
  Windows this program supports (Windows 11 is the floor, design 8 question
  4), and FPC's winunits-base already declares the whole API, so there is no
  hand-typed `external` and no LoadLibrary/GetProcAddress pair here. The
  declaration of WinHttpSetTimes in that header is NOT used: the real export
  is WinHttpSetTimeouts, and a static import of a name the DLL does not export
  stops the program from starting at all. Timeouts go through WinHttpSetOption
  with the WINHTTP_OPTION_*_TIME numbers, which the header does carry.

  THE PCHAR JUSTIFICATION. WinHTTP takes UTF-16 text through LPCWSTR, so
  PWideChar(someString) is a CAST of a UnicodeString at a real OS boundary
  (this tree's string is UTF-16: {$MODESWITCH UnicodeStrings}). The one
  pointer into a byte string is the request body handed to WinHttpSendRequest.

  HOW THE CONTRACT LINES ARE MET (design 3.3):

   1  synchronous: the session is opened WITHOUT WINHTTP_FLAG_ASYNC, so every
      call blocks. One session, connection and request PER Execute, closed in a
      finally: no shared state, so it is safe from any thread, and every
      request is a fresh connection.
   2  never raises: the whole body is inside a handler that turns an exception
      into hfOther.
   3  nothing sent is a claim, and a claim must be proved. See MapError: a
      timeout is ALWAYS hfIOTimedOut (a timeout can land after bytes left, and
      this unit does not track the phase), and the name, connect and
      certificate kinds are reported as proved ONLY when redirects are off,
      because with FollowRedirects a failure can belong to the SECOND request
      after the first has gone out.
   4  any status is an answer when AcceptAnyStatus; otherwise only 200 is, and
      anything else is hfOther with the status, and the body is NOT read (a
      Get verb must never write a 404 page over its target file).
   5  ConnectMs is the resolve and connect timeout, IOMs the send and receive
      timeout (per wait, like FPC's IOTimeout). BUT WinHTTP rounds a timeout UP
      to a multiple of about 4 s (measured; see ApplyTimeouts), so these are
      limits to within 4 s, not exact.
   7  the size cap is the shared TBoundedHttpResponse.
   8  redirects: WINHTTP_OPTION_REDIRECT_POLICY_NEVER when FollowRedirects is
      False; otherwise the DISALLOW_HTTPS_TO_HTTP policy, which is WinHTTP's own
      default and is exactly "a redirect from https to http is never followed".
      A refused downgrade surfaces as ERROR_WINHTTP_REDIRECT_FAILED, which is
      hfOther: the first request WAS sent. The redirect limit is 16, FPC's.
   9  no decompression (the option is never set, and WinHTTP's default is off),
      no cookies and no auto-authentication (WINHTTP_OPTION_DISABLE_FEATURE),
      no cache (WinHTTP has none), no credential store (SetCredentials is
      never called).
  10  Basic is built by hand and sent PREEMPTIVELY (WinHTTP's own credential
      call is challenge-driven); a bearer token is a plain Authorization header.
  11  VerifyServer False sets the four IGNORE flags and nothing else. WinHTTP
      does not check revocation unless asked, and this unit does not ask. A
      failure to apply a policy option is a failed request, never a request
      made without it.
  12  no WINHTTP_OPTION_SECURE_PROTOCOLS: FPC's header stops at TLS 1.2, so
      setting it would CAP the version below what the OS offers.
  13  the User-Agent is the request's; Accept is not set, so none is added.
  14  nothing is logged here (design 3.1); the URL, headers, body and error
      text go back in the result.
  16  If-None-Match and If-Modified-Since are added explicitly; ETag,
      Last-Modified and Content-Type are read back.

  NOT DONE, and the doc says so: the status callback that would track whether
  a request had begun (it would let a connect timeout be proved unsent), TLS
  loopback tests (there is no HTTPS server in the repository: the badssl matrix
  is a bench item), and cancellation (contract line 6).
*)

interface

{$IFDEF WINDOWS}

uses
   Classes, uHttpTransport;

type
   TWinHttpTransport = class(TPlatformHttpTransport)
   public
      class function Id: string; override;
      function Available(out aWhy: string): boolean; override;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

{$ENDIF}

implementation

{$IFDEF WINDOWS}

uses
   SysUtils,
   Windows,      (* GetLastError, DWORD *)
   winhttp,      (* FPC's own declarations of the WinHTTP API: see the header *)
   base64;       (* the RTL's encoder, for the preemptive Basic header *)

const
   (* The limit FPC's client uses (DefMaxRedirects), so the two transports follow
     the same number of hops. *)
   MAX_REDIRECTS = 16;
   (* The user agent when the request names none: WinHttpOpen wants a name. *)
   FALLBACK_AGENT = 'TR4W';
   READ_CHUNK     = 16384;
   (* ERROR_WINHTTP_TIMEOUT; FPC's header spells it ERROR_WINHTTP_TIME. *)
   ERROR_WINHTTP_TIMEOUT_CODE = ERROR_WINHTTP_TIME;
   (* The error WinHttpQueryHeaders gives for a buffer that is too small. *)
   ERROR_INSUFFICIENT_BUFFER_CODE = 122;

(* ---- naming the error --------------------------------------------------------- *)

function WinHttpErrorName(aError: DWORD): string;
begin
   case aError of
      ERROR_WINHTTP_TIMEOUT_CODE:               Result := 'ERROR_WINHTTP_TIMEOUT';
      ERROR_WINHTTP_NAME_NOT_RESOLVED:          Result := 'ERROR_WINHTTP_NAME_NOT_RESOLVED';
      ERROR_WINHTTP_CANNOT_CONNECT:             Result := 'ERROR_WINHTTP_CANNOT_CONNECT';
      ERROR_WINHTTP_CONNECTION_ERROR:           Result := 'ERROR_WINHTTP_CONNECTION_ERROR';
      ERROR_WINHTTP_OPERATION_CANCELLED:        Result := 'ERROR_WINHTTP_OPERATION_CANCELLED';
      ERROR_WINHTTP_SECURE_FAILURE:             Result := 'ERROR_WINHTTP_SECURE_FAILURE';
      ERROR_WINHTTP_SECURE_CERT_DATE_INVALID:   Result := 'ERROR_WINHTTP_SECURE_CERT_DATE_INVALID';
      ERROR_WINHTTP_SECURE_CERT_CN_INVALID:     Result := 'ERROR_WINHTTP_SECURE_CERT_CN_INVALID';
      ERROR_WINHTTP_SECURE_INVALID_CA:          Result := 'ERROR_WINHTTP_SECURE_INVALID_CA';
      ERROR_WINHTTP_SECURE_CERT_REV_FAILED:     Result := 'ERROR_WINHTTP_SECURE_CERT_REV_FAILED';
      ERROR_WINHTTP_SECURE_CHANNEL_ERROR:       Result := 'ERROR_WINHTTP_SECURE_CHANNEL_ERROR';
      ERROR_WINHTTP_SECURE_INVALID_CERT:        Result := 'ERROR_WINHTTP_SECURE_INVALID_CERT';
      ERROR_WINHTTP_SECURE_CERT_REVOKED:        Result := 'ERROR_WINHTTP_SECURE_CERT_REVOKED';
      ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE:    Result := 'ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE';
      ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED:    Result := 'ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED';
      ERROR_WINHTTP_REDIRECT_FAILED:            Result := 'ERROR_WINHTTP_REDIRECT_FAILED (a redirect was refused)';
      ERROR_WINHTTP_INVALID_URL:                Result := 'ERROR_WINHTTP_INVALID_URL';
      ERROR_WINHTTP_UNRECOGNIZED_SCHEME:        Result := 'ERROR_WINHTTP_UNRECOGNIZED_SCHEME';
   else
      Result := '';
   end;
end;

(* The failure kind for a WinHTTP error code, under contract line 3: the
  default is "may have been sent", and a kind that PROVES nothing was sent is
  claimed only for a code that can occur only before the request goes out AND
  only when no redirect can have sent an earlier request (aFollowRedirects
  False). A timeout is never proved (design 4.2: the phase is not tracked). *)
function ErrorToFailure(aError: DWORD; aFollowRedirects: boolean): THttpFailure;
begin
   case aError of
      ERROR_WINHTTP_TIMEOUT_CODE:
         begin
         Result := hfIOTimedOut;
         end;
      ERROR_WINHTTP_OPERATION_CANCELLED:
         begin
         Result := hfCancelled;
         end;
      ERROR_WINHTTP_CONNECTION_ERROR:
         begin
         Result := hfConnectionLost;
         end;
      ERROR_WINHTTP_NAME_NOT_RESOLVED:
         begin
         if aFollowRedirects then
            begin
            Result := hfOther;
            end
         else
            begin
            Result := hfNameNotResolved;
            end;
         end;
      ERROR_WINHTTP_CANNOT_CONNECT:
         begin
         if aFollowRedirects then
            begin
            Result := hfOther;
            end
         else
            begin
            Result := hfCannotConnect;
            end;
         end;
      ERROR_WINHTTP_SECURE_FAILURE,
      ERROR_WINHTTP_SECURE_CERT_DATE_INVALID,
      ERROR_WINHTTP_SECURE_CERT_CN_INVALID,
      ERROR_WINHTTP_SECURE_INVALID_CA,
      ERROR_WINHTTP_SECURE_CERT_REV_FAILED,
      ERROR_WINHTTP_SECURE_INVALID_CERT,
      ERROR_WINHTTP_SECURE_CERT_REVOKED,
      ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE:
         begin
         (* The handshake rejected the certificate. ERROR_WINHTTP_SECURE_CHANNEL_ERROR
           is deliberately NOT here: it is a protocol failure, not a verdict
           on the certificate. *)
         if aFollowRedirects then
            begin
            Result := hfOther;
            end
         else
            begin
            Result := hfVerificationFailed;
            end;
         end;
   else
      Result := hfOther;
   end;
end;

(* Record a failed call: the kind, the class and the words for the log. *)
procedure FailWith(aResult: THttpWireResult; aError: DWORD; aFollowRedirects: boolean;
                   const aWhat: string);
var
   name: string;
begin
   aResult.Failure    := ErrorToFailure(aError, aFollowRedirects);
   aResult.ErrorClass := 'EWinHttp';
   name := WinHttpErrorName(aError);
   if name = '' then
      begin
      name := SysUtils.SysErrorMessage(Integer(aError));
      end;
   aResult.ErrorMessage := aWhat + ' failed with error ' + IntToStr(aError) +
                           ' ' + name;
end;

(* A condition that is a failure of THIS unit's setup, with no WinHTTP error. *)
procedure FailSetup(aResult: THttpWireResult; const aMessage: string);
begin
   aResult.Failure      := hfOther;
   aResult.ErrorClass   := 'EWinHttp';
   aResult.ErrorMessage := aMessage;
end;

(* ---- small helpers ------------------------------------------------------------ *)

function SetDwordOption(aHandle: HINTERNET; aOption, aValue: DWORD): boolean;
var
   value: DWORD;
begin
   value  := aValue;
   Result := WinHttpSetOption(aHandle, aOption, @value, SizeOf(DWORD));
end;

(* A header value must never carry a line break: it would let one value forge
  another header. The shared layer vets the bearer token; this is the same
  guard for the rest, so the transport cannot be the weak link. *)
function CleanHeaderValue(const aValue: string): boolean;
begin
   Result := (Pos(#13, aValue) = 0) and (Pos(#10, aValue) = 0);
end;

procedure AddHeaderLine(var aBlock: string; const aName, aValue: string);
begin
   aBlock := aBlock + aName + ': ' + aValue + #13#10;
end;

(* The request headers in one block, or '' when there is none. False when a
  value carries a line break. *)
function BuildHeaders(aRequest: THttpWireRequest; out aBlock: string): boolean;
var
   verb: string;
begin
   aBlock := '';
   Result := CleanHeaderValue(aRequest.UserAgent) and
             CleanHeaderValue(aRequest.ContentType) and
             CleanHeaderValue(aRequest.AcceptEncoding) and
             CleanHeaderValue(aRequest.BearerToken) and
             CleanHeaderValue(aRequest.IfNoneMatch) and
             CleanHeaderValue(aRequest.IfModifiedSince) and
             CleanHeaderValue(aRequest.Username) and
             CleanHeaderValue(aRequest.Password);
   if not Result then
      begin
      Exit;
      end;

   if aRequest.UserAgent <> '' then
      begin
      AddHeaderLine(aBlock, 'User-Agent', aRequest.UserAgent);
      end;
   if aRequest.ContentType <> '' then
      begin
      AddHeaderLine(aBlock, 'Content-Type', aRequest.ContentType);
      end;
   if aRequest.BearerToken <> '' then
      begin
      AddHeaderLine(aBlock, 'Authorization', 'Bearer ' + aRequest.BearerToken);
      end;
   if aRequest.Username <> '' then
      begin
      (* PREEMPTIVE Basic, as FPC's client sends it: the credentials as UTF-8
        bytes. EncodeStringBase64 takes a byte string; passing the wire bytes
        keeps it from narrowing a UTF-16 string. *)
      AddHeaderLine(aBlock, 'Authorization',
                    'Basic ' + EncodeStringBase64(ToWire(aRequest.Username + ':' +
                                                         aRequest.Password)));
      end;
   if aRequest.AcceptEncoding <> '' then
      begin
      AddHeaderLine(aBlock, 'Accept-Encoding', aRequest.AcceptEncoding);
      end;
   if aRequest.IfNoneMatch <> '' then
      begin
      AddHeaderLine(aBlock, 'If-None-Match', aRequest.IfNoneMatch);
      end;
   if aRequest.IfModifiedSince <> '' then
      begin
      AddHeaderLine(aBlock, 'If-Modified-Since', aRequest.IfModifiedSince);
      end;

   (* An attached body, even an empty one, goes out with a Content-Length: the
     generic transport always did, and a bodiless WRL GET carries 'Content-Length:
     0'. WinHTTP adds the header itself for POST and PUT; for any other verb it
     is added here so the two transports put the same bytes on the wire. *)
   verb := UnicodeUpperCase(aRequest.Method);
   if aRequest.HasBody and (Length(aRequest.Body) = 0) and
      (verb <> 'POST') and (verb <> 'PUT') and (verb <> 'PATCH') then
      begin
      AddHeaderLine(aBlock, 'Content-Length', '0');
      end;
end;

(* Split the URL into what WinHttpConnect and WinHttpOpenRequest want. *)
function ParseTarget(const aUrl: string; out aSecure: boolean; out aHost,
                     aObject: string; out aPort: INTERNET_PORT;
                     out aWhy: string): boolean;
var
   rest, authority, hostPort, portText: string;
   p, q: integer;
begin
   Result  := False;
   aSecure := False;
   aHost   := '';
   aObject := '';
   aPort   := 0;
   aWhy    := '';
   if aUrl = '' then
      begin
      aWhy := 'the URL is empty';
      Exit;
      end;

   (* BY HAND, NOT URIParser: that unit's strings are 8-bit and passing it this
     tree's UTF-16 string is a narrowing the build counts. A URL here is
     scheme://[user@]host[:port][/path][?query][#fragment]. *)
   p := Pos('://', aUrl);
   if p = 0 then
      begin
      aWhy := 'the URL has no scheme';
      Exit;
      end;
   if UnicodeSameText(Copy(aUrl, 1, p - 1), 'https') then
      begin
      aSecure := True;
      end
   else if not UnicodeSameText(Copy(aUrl, 1, p - 1), 'http') then
      begin
      aWhy := 'the URL scheme is neither http nor https';
      Exit;
      end;

   rest := Copy(aUrl, p + 3, MaxInt);
   p := Pos('#', rest);
   if p > 0 then
      begin
      rest := Copy(rest, 1, p - 1);
      end;

   (* The authority ends at the first '/' or '?'. *)
   p := Pos('/', rest);
   q := Pos('?', rest);
   if (q > 0) and ((p = 0) or (q < p)) then
      begin
      p := q;
      end;
   if p = 0 then
      begin
      authority := rest;
      aObject   := '/';
      end
   else
      begin
      authority := Copy(rest, 1, p - 1);
      aObject   := Copy(rest, p, MaxInt);
      if aObject[1] = '?' then
         begin
         aObject := '/' + aObject;
         end;
      end;

   (* Drop credentials in the authority: the request carries its own. *)
   p := Length(authority);
   while (p > 0) and (authority[p] <> '@') do
      begin
      Dec(p);
      end;
   hostPort := Copy(authority, p + 1, MaxInt);

   aPort := 0;
   if (hostPort <> '') and (hostPort[1] = '[') then
      begin
      (* An IPv6 literal: the host is what is inside the brackets. *)
      p := Pos(']', hostPort);
      if p = 0 then
         begin
         aWhy := 'the URL has an unterminated IPv6 host';
         Exit;
         end;
      aHost    := Copy(hostPort, 2, p - 2);
      portText := Copy(hostPort, p + 1, MaxInt);
      if (portText <> '') and (portText[1] = ':') then
         begin
         portText := Copy(portText, 2, MaxInt);
         end
      else
         begin
         portText := '';
         end;
      end
   else
      begin
      p := Pos(':', hostPort);
      if p > 0 then
         begin
         aHost    := Copy(hostPort, 1, p - 1);
         portText := Copy(hostPort, p + 1, MaxInt);
         end
      else
         begin
         aHost    := hostPort;
         portText := '';
         end;
      end;

   if aHost = '' then
      begin
      aWhy := 'the URL has no host';
      Exit;
      end;
   if portText <> '' then
      begin
      (* Digits only, 1..65535. Parsed by hand: the RTL's StrToIntDef takes an
        8-bit string here, which is the narrowing the build counts. *)
      q := 0;
      for p := 1 to Length(portText) do
         begin
         if (portText[p] < '0') or (portText[p] > '9') or (q > 65535) then
            begin
            q := -1;
            Break;
            end;
         q := q * 10 + (Ord(portText[p]) - Ord('0'));
         end;
      if (q < 1) or (q > 65535) then
         begin
         aWhy := 'the URL has a bad port';
         Exit;
         end;
      aPort := INTERNET_PORT(q);
      end;
   if aPort = 0 then
      begin
      if aSecure then
         begin
         aPort := INTERNET_DEFAULT_HTTPS_PORT;
         end
      else
         begin
         aPort := INTERNET_DEFAULT_HTTP_PORT;
         end;
      end;
   Result := True;
end;

(* One response header as text, '' when the server did not send it. WinHTTP
  answers the first call with the size it needs. *)
function QueryHeaderText(aRequest: HINTERNET; aLevel: DWORD;
                         const aName: string): string;
var
   size, err: DWORD;
   buffer: UnicodeString;
   namePtr: PWideChar;
begin
   Result := '';
   namePtr := nil;
   if aLevel = WINHTTP_QUERY_CUSTOM then
      begin
      namePtr := PWideChar(aName);
      end;

   size := 0;
   if WinHttpQueryHeaders(aRequest, aLevel, namePtr, nil, @size, nil) then
      begin
      Exit;   (* nothing to say *)
      end;
   err := GetLastError;
   if (err <> ERROR_INSUFFICIENT_BUFFER_CODE) or (size < SizeOf(WideChar)) then
      begin
      Exit;   (* ERROR_WINHTTP_HEADER_NOT_FOUND, or something unreadable *)
      end;

   SetLength(buffer, (size div SizeOf(WideChar)) + 1);
   if WinHttpQueryHeaders(aRequest, aLevel, namePtr, PWideChar(buffer), @size, nil) then
      begin
      SetLength(buffer, size div SizeOf(WideChar));
      Result := buffer;
      end;
end;

(* THE ADDRESS THAT ANSWERED, after any redirect WinHTTP followed (the request
  handle's WINHTTP_OPTION_URL, UTF-16 text). '' when it cannot be read. The
  caller decides whether it differs from what was asked. *)
function QueryRequestUrl(aRequest: HINTERNET): string;
var
   size, err: DWORD;
   buffer: UnicodeString;
begin
   Result := '';
   size   := 0;
   if WinHttpQueryOption(aRequest, WINHTTP_OPTION_URL, nil, @size) then
      begin
      Exit;
      end;
   err := GetLastError;
   if (err <> ERROR_INSUFFICIENT_BUFFER_CODE) or (size < SizeOf(WideChar)) then
      begin
      Exit;
      end;
   SetLength(buffer, (size div SizeOf(WideChar)) + 1);
   if WinHttpQueryOption(aRequest, WINHTTP_OPTION_URL, PWideChar(buffer), @size) then
      begin
      SetLength(buffer, size div SizeOf(WideChar));
      Result := buffer;
      end;
end;

(* A redirect is reported only when the final address is really another one:
  WinHTTP may hand back the request's own address with a trailing slash added
  (a bare host), and that is not a redirect. *)
function RedirectedTo(const aAsked, aAnswered: string): string;
var
   asked, answered: string;
begin
   Result   := '';
   asked    := aAsked;
   answered := aAnswered;
   (* Not ExcludeTrailingPathDelimiter: it takes AnsiString and would narrow. *)
   if (asked <> '') and (asked[Length(asked)] = '/') then
      begin
      SetLength(asked, Length(asked) - 1);
      end;
   if (answered <> '') and (answered[Length(answered)] = '/') then
      begin
      SetLength(answered, Length(answered) - 1);
      end;
   if (aAnswered <> '') and (not UnicodeSameText(asked, answered)) then
      begin
      Result := aAnswered;
      end;
end;

function QueryStatusCode(aRequest: HINTERNET): integer;
var
   code, size: DWORD;
begin
   Result := 0;
   code   := 0;
   size   := SizeOf(DWORD);
   if WinHttpQueryHeaders(aRequest, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
                          nil, @code, @size, nil) then
      begin
      Result := integer(code);
      end;
end;

(* ---- the transport ------------------------------------------------------------- *)

class function TWinHttpTransport.Id: string;
begin
   Result := 'winhttp';
end;

function TWinHttpTransport.Available(out aWhy: string): boolean;
begin
   (* The DLL is bound statically, so the program would not be running if it
     were absent. WinHttpCheckPlatform asks whether this Windows supports it. *)
   aWhy   := '';
   Result := WinHttpCheckPlatform;
   if not Result then
      begin
      aWhy := 'WinHttpCheckPlatform says this Windows does not support WinHTTP';
      end;
end;

(* Options that apply to the request handle. False (with the result filled)
  when one could not be set: a request is never made without a policy option
  the contract needs. *)
function ApplyRequestOptions(aRequest: HINTERNET; aWire: THttpWireRequest;
                             aSecure: boolean; aResult: THttpWireResult): boolean;
var
   policy: DWORD;
begin
   Result := False;

   (* Contract line 9: no cookies, and never answer an authentication
     challenge on the program's behalf (a 401 is an answer to return). *)
   if not SetDwordOption(aRequest, WINHTTP_OPTION_DISABLE_FEATURE,
                         WINHTTP_DISABLE_COOKIES or WINHTTP_DISABLE_AUTHENTICATION) then
      begin
      FailSetup(aResult, 'could not switch off cookies and automatic authentication');
      Exit;
      end;

   (* Contract line 8. *)
   if aWire.FollowRedirects then
      begin
      policy := WINHTTP_OPTION_REDIRECT_POLICY_DISALLOW_HTTPS_TO_HTTP;
      end
   else
      begin
      policy := WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
      end;
   if not SetDwordOption(aRequest, WINHTTP_OPTION_REDIRECT_POLICY, policy) then
      begin
      FailSetup(aResult, 'could not set the redirect policy');
      Exit;
      end;
   if aWire.FollowRedirects then
      begin
      if not SetDwordOption(aRequest, WINHTTP_OPTION_MAX_HTTP_AUTOMATIC_REDIRECTS,
                            MAX_REDIRECTS) then
         begin
         FailSetup(aResult, 'could not set the redirect limit');
         Exit;
         end;
      end;

   (* Contract line 11: ONLY when the operator turned checking off. *)
   if aSecure and (not aWire.VerifyServer) then
      begin
      if not SetDwordOption(aRequest, WINHTTP_OPTION_SECURITY_FLAGS,
                            SECURITY_FLAG_IGNORE_UNKNOWN_CA or
                            SECURITY_FLAG_IGNORE_CERT_DATE_INVALID or
                            SECURITY_FLAG_IGNORE_CERT_CN_INVALID or
                            SECURITY_FLAG_IGNORE_CERT_WRONG_USAGE) then
         begin
         FailSetup(aResult, 'could not switch off certificate checking as the setting asks');
         Exit;
         end;
      end;
   Result := True;
end;

(* Timeouts, on the REQUEST handle (the session works the same; the request is
  where they are used).

  WINHTTP KEEPS THEM ON A COARSE CLOCK, AND THIS WAS MEASURED, NOT READ.
  Against a server that reads the request and then stays silent, a standalone
  program set all five options on the session or on the request, under every
  proxy mode, and the call gave up at: 200 ms -> 4000 ms, 400 -> 4000,
  1000 -> 4016, 2500 -> 4016, 6000 -> 8000. The value is rounded UP to the next
  multiple of about 4 s (Windows 11 build 26200; a Python and an Indy server
  agree; the generic transport on the same server gives up at 400 ms). So IOMs
  and ConnectMs are an UPPER-BOUND-PLUS-4-SECONDS here, not an exact limit.
  The callers' own values (5 s to 30 s) are honoured to within 4 s. If an exact
  deadline is ever needed, the design's cancellation route (close the request
  handle from a watchdog thread) is the way, and it is not built (contract 6). *)
function ApplyTimeouts(aHandle: HINTERNET; aWire: THttpWireRequest;
                       aResult: THttpWireResult): boolean;
var
   connectMs, ioMs: DWORD;
begin
   connectMs := 0;
   ioMs      := 0;
   if aWire.ConnectMs > 0 then
      begin
      connectMs := DWORD(aWire.ConnectMs);
      end;
   if aWire.IOMs > 0 then
      begin
      ioMs := DWORD(aWire.IOMs);
      end;
   (* RECEIVE bounds the wait for each piece of the body and RECEIVE_RESPONSE the
     wait for the first byte of the answer after the request went out; both are
     set to IOMs, which is what FPC's single IOTimeout covers. *)
   Result := SetDwordOption(aHandle, WINHTTP_OPTION_RESOLVE_TIME, connectMs) and
             SetDwordOption(aHandle, WINHTTP_OPTION_CONNECT_TIME, connectMs) and
             SetDwordOption(aHandle, WINHTTP_OPTION_SEND_TIME, ioMs) and
             SetDwordOption(aHandle, WINHTTP_OPTION_RECEIVE_TIME, ioMs) and
             SetDwordOption(aHandle, WINHTTP_OPTION_RECEIVE_RESPONSE_TIME, ioMs);
   if not Result then
      begin
      FailSetup(aResult, 'could not set the timeouts');
      end;
end;

(* Everything after the request handle exists. *)
procedure SendAndReceive(aRequest: HINTERNET; aWire: THttpWireRequest;
                         aSink: TStream; aResult: THttpWireResult);
var
   headers: string;
   bodyPtr: Pointer;
   bodyLen, got: DWORD;
   status: integer;
   chunk: TBytes;
   bodyOut: TBoundedHttpResponse;
   dest: TStream;
   err: DWORD;
begin
   if not BuildHeaders(aWire, headers) then
      begin
      FailSetup(aResult, 'a header value contains a line break');
      Exit;
      end;
   if headers <> '' then
      begin
      if not WinHttpAddRequestHeaders(aRequest, PWideChar(headers), Length(headers),
                                      WINHTTP_ADDREQ_FLAG_ADD or
                                      WINHTTP_ADDREQ_FLAG_REPLACE) then
         begin
         FailWith(aResult, GetLastError, aWire.FollowRedirects, 'WinHttpAddRequestHeaders');
         Exit;
         end;
      end;

   bodyPtr := nil;
   bodyLen := 0;
   if aWire.HasBody and (Length(aWire.Body) > 0) then
      begin
      (* The one pointer into a byte string: the request body, at the OS call. *)
      bodyPtr := @aWire.Body[1];
      bodyLen := DWORD(Length(aWire.Body));
      end;

   if not WinHttpSendRequest(aRequest, nil, 0, bodyPtr, bodyLen, bodyLen, 0) then
      begin
      FailWith(aResult, GetLastError, aWire.FollowRedirects, 'WinHttpSendRequest');
      Exit;
      end;
   if not WinHttpReceiveResponse(aRequest, nil) then
      begin
      FailWith(aResult, GetLastError, aWire.FollowRedirects, 'WinHttpReceiveResponse');
      Exit;
      end;

   status := QueryStatusCode(aRequest);
   aResult.StatusCode   := status;
   aResult.StatusText   := QueryHeaderText(aRequest, WINHTTP_QUERY_STATUS_TEXT, '');
   aResult.RetryAfter   := QueryHeaderText(aRequest, WINHTTP_QUERY_CUSTOM, 'Retry-After');
   aResult.RequestId    := QueryHeaderText(aRequest, WINHTTP_QUERY_CUSTOM, 'X-Request-Id');
   aResult.ETag         := QueryHeaderText(aRequest, WINHTTP_QUERY_CUSTOM, 'ETag');
   aResult.LastModified := QueryHeaderText(aRequest, WINHTTP_QUERY_CUSTOM, 'Last-Modified');
   aResult.ContentType  := QueryHeaderText(aRequest, WINHTTP_QUERY_CUSTOM, 'Content-Type');
   if aWire.FollowRedirects then
      begin
      aResult.FinalURL := RedirectedTo(aWire.URL, QueryRequestUrl(aRequest));
      end;

   if (not aWire.AcceptAnyStatus) and (status <> 200) then
      begin
      (* The Get verbs: only 200 is an answer. The words are FPC's, which
        operators have seen. The body is not read, so a caller never writes
        an error page over its target. *)
      aResult.Failure      := hfOther;
      aResult.ErrorClass   := 'EHTTPClient';
      aResult.ErrorMessage := 'Unexpected response status code: ' + IntToStr(status);
      Exit;
      end;

   bodyOut := nil;
   try
      try
         if aSink <> nil then
            begin
            dest := aSink;
            end
         else
            begin
            bodyOut       := TBoundedHttpResponse.Create('');
            bodyOut.Limit := aWire.MaxResponseBytes;
            dest          := bodyOut;
            end;

         SetLength(chunk, READ_CHUNK);
         repeat
            got := 0;
            if not WinHttpReadData(aRequest, @chunk[0], READ_CHUNK, @got) then
               begin
               err := GetLastError;
               FailWith(aResult, err, aWire.FollowRedirects, 'WinHttpReadData');
               (* Bytes of the answer were arriving, so the request was sent:
                 whatever the code, nothing here is a "not sent" kind. *)
               if NothingSent(aResult.Failure) then
                  begin
                  aResult.Failure := hfConnectionLost;
                  end;
               Exit;
               end;
            if got > 0 then
               begin
               dest.WriteBuffer(chunk[0], got);
               end;
         until got = 0;

         if bodyOut <> nil then
            begin
            aResult.Body := bodyOut.DataString;
            end;
      except
         on E: Exception do
            begin
            aResult.ErrorClass   := E.ClassName;
            aResult.ErrorMessage := E.Message;
            if (bodyOut <> nil) and bodyOut.Exceeded then
               begin
               aResult.Failure := hfResponseTooLarge;
               end
            else
               begin
               aResult.Failure := hfOther;
               end;
            end;
      end;
   finally
      bodyOut.Free;
   end;
end;

procedure TWinHttpTransport.Execute(aRequest: THttpWireRequest; aSink: TStream;
                                    aResult: THttpWireResult);
var
   session, connection, request: HINTERNET;
   secure: boolean;
   host, objectName, agent, why, verb: string;
   port: INTERNET_PORT;
   flags: DWORD;
begin
   aResult.Clear;
   session    := nil;
   connection := nil;
   request    := nil;
   try
      try
         if not ParseTarget(aRequest.URL, secure, host, objectName, port, why) then
            begin
            FailSetup(aResult, why);
            Exit;
            end;

         agent := aRequest.UserAgent;
         if agent = '' then
            begin
            agent := FALLBACK_AGENT;
            end;

         (* The operating system's own proxy configuration applies (NY4I, design 8
           questions 10 and 15): automatic proxy where Windows offers it. A
           session that cannot open that way is opened with the default, which
           is a decision made BEFORE any request exists, not a fallback after
           one failed. *)
         session := WinHttpOpen(PWideChar(agent), WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
         if session = nil then
            begin
            session := WinHttpOpen(PWideChar(agent), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                   WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
            end;
         if session = nil then
            begin
            FailWith(aResult, GetLastError, aRequest.FollowRedirects, 'WinHttpOpen');
            Exit;
            end;

         connection := WinHttpConnect(session, PWideChar(host), port, 0);
         if connection = nil then
            begin
            FailWith(aResult, GetLastError, aRequest.FollowRedirects, 'WinHttpConnect');
            Exit;
            end;

         flags := 0;
         if secure then
            begin
            flags := WINHTTP_FLAG_SECURE;
            end;
         verb := UnicodeUpperCase(aRequest.Method);
         request := WinHttpOpenRequest(connection, PWideChar(verb),
                                       PWideChar(objectName), nil, WINHTTP_NO_REFERER,
                                       nil, flags);
         if request = nil then
            begin
            FailWith(aResult, GetLastError, aRequest.FollowRedirects, 'WinHttpOpenRequest');
            Exit;
            end;

         if (not ApplyTimeouts(request, aRequest, aResult)) or
            (not ApplyRequestOptions(request, aRequest, secure, aResult)) then
            begin
            Exit;
            end;

         SendAndReceive(request, aRequest, aSink, aResult);
      except
         on E: Exception do
            begin
            (* Contract line 2: never raises. *)
            aResult.Failure      := hfOther;
            aResult.ErrorClass   := E.ClassName;
            aResult.ErrorMessage := E.Message;
            end;
      end;
   finally
      if request <> nil then
         begin
         WinHttpCloseHandle(request);
         end;
      if connection <> nil then
         begin
         WinHttpCloseHandle(connection);
         end;
      if session <> nil then
         begin
         WinHttpCloseHandle(session);
         end;
   end;
end;

{$ENDIF}

{$IFDEF WINDOWS}
initialization
   (* Preferred: a platform transport, chosen by network.httpTransport = auto
     or platform when Available. The default setting at S2 is generic. *)
   RegisterHttpTransport(TWinHttpTransport, True);
{$ENDIF}

end.
