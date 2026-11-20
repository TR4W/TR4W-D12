unit uHttpTransport;
{$I ..\tr4w.inc}   // relative: this unit lives in src\utils, the include in src
(*
  THE CONTRACT BETWEEN THE HTTP VERBS AND WHATEVER PUTS BYTES ON THE WIRE.
  docs/HTTP_TRANSPORT_DESIGN.md is authoritative (issue 224); this unit is its
  section 3 made code, and it knows NO platform: no IFDEF, no OpenSSL, no
  WinHTTP. Each transport is its own unit and registers itself from its
  initialization section, as the radio units and the credential vault do.

  TWO LAYERS, AND WHAT EACH MAY KNOW (design 3.1):

     uHTTPDownload (shared)         a transport
     ------------------------       ------------------------------------
     scheme and bearer policy       connection, TLS, the trust decision
     verify-or-not POLICY           applying that policy
     ALL logging of anything        reporting what happened, AS DATA
     derived from a request
     turning a failure into         knowing whether it can PROVE nothing
     NothingSent                    was sent

  A TRANSPORT NEVER LOGS A URL, A HEADER, A BODY OR AN EXCEPTION MESSAGE THAT
  COULD ECHO ONE. It returns them in the result; the shared layer scrubs and
  logs. That keeps the secrets rule in one place.

  NOTHING SENT IS A CLAIM, AND A CLAIM MUST BE PROVED. A transport reports a
  failure kind for which NothingSent is True ONLY when no request byte left the
  machine. When unsure it reports hfConnectionLost, hfIOTimedOut or hfOther.
  The default is "may have been sent", because the cost of the wrong answer is
  a QSO delivered twice or never. NothingSent is the ONE place that maps.

  SELECTION IS ONCE, LOGGED, AND THERE IS NO PER-REQUEST FALLBACK. Club Log, WRL,
  HamScore, the score post and the SCP upload are non-idempotent POSTs: a
  transport that fails mid-request and is retried on another can send the same
  QSO twice, and a fallback that hides which transport answered is a silent
  downgrade.
*)

interface

uses
   Classes, SysUtils;

type
   (* WHAT HAPPENED, as the transport knows it. *)
   THttpFailure = (
      hfNone,                    (* an answer arrived; StatusCode is its status *)
      hfTlsUnavailable,          (* https asked for, the TLS stack cannot start *)
      hfTlsLibraryFault,         (* the TLS library failed once bytes were moving: NOT provable *)
      hfTrustUnavailable,        (* the trust source is missing or unreadable (cacert.pem) *)
      hfVerificationUnavailable, (* checking was asked for and cannot be set up, though the
                                    trust source is fine: an OpenSSL with no X509_check_host *)
      hfVerificationFailed,      (* the handshake rejected the certificate: chain, name, date *)
      hfPlaintextNotAllowed,     (* shared layer: http:// without AllowInsecure *)
      hfBadScheme,               (* shared layer: neither http:// nor https:// *)
      hfAuthPolicy,              (* shared layer: a bearer token needs https, no redirects, a clean token *)
      hfNameNotResolved,
      hfCannotConnect,
      hfConnectTimedOut,         (* provably before any request byte *)
      hfIOTimedOut,              (* NOT provable: the request may be half sent *)
      hfConnectionLost,          (* after connect: NOT provable *)
      hfResponseTooLarge,        (* an answer began, so the server saw the request *)
      hfCancelled,
      hfPostRedirected,          (* shared layer (issue 255): a POST was answered with a redirect.
                                    It is NEVER followed -- the request WAS sent and the server may
                                    have acted on it -- so this is reported, with the target *)
      hfOther);

   (* One request, in. The caller-facing THttpRequest stays as it is and the
     shared layer fills this from it. A class, not a record. *)
   THttpWireRequest = class
   public
      Method:          string;
      URL:             string;
      UserAgent:       string;
      ContentType:     string;   (* '' = no Content-Type header *)
      AcceptEncoding:  string;   (* '' = no Accept-Encoding header *)
      Username:        string;   (* Basic auth, sent preemptively when not '' *)
      Password:        string;
      BearerToken:     string;   (* the transport SENDS these; it never logs them *)
      Body:            RawByteString;
      HasBody:         boolean;  (* a body is attached, EVEN AN EMPTY ONE: the generic
                                    transport then sends Content-Length: 0, as it always has *)
      FollowRedirects: boolean;
      VerifyServer:    boolean;  (* True = the platform's full check; False = the operator
                                    turned checking off (network.verifyServerCertificates) *)
      AcceptAnyStatus: boolean;  (* True = every HTTP status is an answer. False = only 200 is,
                                    and any other raises inside the generic client BEFORE it
                                    follows a redirect: the old Get verbs' behaviour, kept
                                    exactly (see the design, 2.4) *)
      IfNoneMatch:     string;   (* '' = no If-None-Match header (conditional GET) *)
      IfModifiedSince: string;   (* '' = no If-Modified-Since header; an HTTP date as the
                                    server wrote it. A transport MUST send both when set
                                    (a platform transport has to add them explicitly). *)
      ConnectMs:       integer;
      IOMs:            integer;
      MaxResponseBytes: Int64;   (* 0 = unlimited. Applies to the collected Body only. *)
      constructor Create;
      (* WHETHER A TRANSPORT MAY FOLLOW A REDIRECT FOR THIS REQUEST (issue 255,
        NY4I). Never for a POST, whatever FollowRedirects says: the transports
        disagreed about a redirected POST (FPC re-POSTs the body on 301/302/307/
        308, WinHTTP turns 301/302 into a body-less GET), and either way the
        first request was already sent. A POST's 3xx is returned as the answer,
        with its Location, and the shared layer reports it. Both transports ask
        THIS, so they cannot differ. *)
      function MayFollowRedirects: boolean;
   end;

   (* One answer, out. *)
   THttpWireResult = class
   public
      Failure:      THttpFailure;
      ErrorClass:   string;      (* the exception class, when one was raised; else '' *)
      ErrorMessage: string;      (* the library's own words; UNSCRUBBED, the shared layer scrubs *)
      StatusCode:   integer;     (* also set on a failure when the server had answered *)
      StatusText:   string;
      RetryAfter:   string;
      RequestId:    string;
      ETag:         string;      (* the ETag response header, '' when absent *)
      LastModified: string;      (* the Last-Modified response header, '' when absent *)
      ContentType:  string;      (* the Content-Type response header, '' when absent *)
      Location:     string;      (* the Location response header, '' when absent: where a redirect
                                    that was NOT followed points (issue 255), as the server wrote it *)
      FinalURL:     string;     (* the address that ANSWERED, set only when a redirect
                                    was followed (so it differs from the request's URL);
                                    '' when there was none or the transport cannot say.
                                    Informational: nothing decides on it. *)
      Body:         RawByteString;   (* only when Execute was given no sink *)
      constructor Create;
      procedure Clear;
      (* 'Class: message' for the log, or just the message when there is no class. *)
      function Detail: string;
   end;

   (* The collected response, with a size cap, shared by every transport so the
     cap behaves the same whichever one is selected (design 3.3, line 7).
     Exceeded is set BEFORE the raise, so a transport can tell a cap from any
     other stream error. Limit 0 = unlimited. *)
   TBoundedHttpResponse = class(TRawByteStringStream)
   public
      Limit:    Int64;
      Exceeded: boolean;
      function Write(const Buffer; Count: LongInt): LongInt; override;
   end;

   TPlatformHttpTransport = class abstract
   public
      class function Id: string; virtual; abstract;   (* 'generic', 'winhttp' ... *)
      (* Can this transport work on this machine? Asked ONCE, at selection. *)
      function Available(out aWhy: string): boolean; virtual; abstract;
      (* The whole exchange. SYNCHRONOUS, NEVER RAISES, safe from any thread
        (the version check calls it from the main thread). aSink receives the
        response body when it is not nil; otherwise the body is collected into
        aResult.Body. aResult is cleared first. *)
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); virtual; abstract;
   end;

   TPlatformHttpTransportClass = class of TPlatformHttpTransport;

(* True only for a failure that PROVES no request byte left the machine. The one
  place that maps (design 3.3, line 3). *)
function NothingSent(aFailure: THttpFailure): boolean;

(* The enum member's name, for a log line or a test message. *)
function HttpFailureName(aFailure: THttpFailure): string;

(* HTTP IS BYTES; THIS PROGRAM'S string IS UTF-16. UTF-8 in both directions: it
  is what every server in this program's world speaks, it is lossless, and for
  the ASCII that URLs and header names contain it is byte-identical to the naive
  cast. *)
function ToWire(const aText: string): RawByteString;
function FromWire(const aBytes: RawByteString): string;

(* Does the URL, as written, start with https:// in any case? The one test the
  shared layer and a transport both need, so they cannot disagree. *)
function IsHttpsUrl(const aUrl: string): boolean;

const
   (* HOW MANY TIMES A POST MAY BE REPEATED AT A REDIRECT TARGET (issue 255
     follow-up, NY4I 2026-11-19: Club Log, WRL and Cloudlog only). *)
   REPOST_MAX_HOPS = 3;

type
   (* THE ANSWER TO "SHOULD A POST THAT WAS ANSWERED WITH A REDIRECT BE REPEATED
     AT ITS TARGET?". Pure: no network, no platform. It is the ONE place that
     decides, and it lives above the transports because the transports never
     follow a POST (THttpWireRequest.MayFollowRedirects); the shared layer
     repeats it, so both transports behave identically by construction. *)
   TRepostDecision = (
      rdRepost,              (* yes: aTarget is where, resolved and absolute *)
      rdSeeOther,            (* 303: "the result is at that address, fetch it" (RFC 9110
                                15.4.4): the POST was handled, so it is NOT repeated *)
      rdTooManyRedirects,    (* REPOST_MAX_HOPS repeats were already made *)
      rdNoLocation,          (* the answer named no target *)
      rdBadLocation,         (* an unusable target: a line break, credentials, a scheme
                                that is neither http nor https, an unparsable address *)
      rdDowngrade,           (* https to http: never *)
      rdOtherHost);          (* a different host or port: the request may carry an API key
                                in its body or a header, which only its own host may see *)

(* aStatus is the 3xx the POST was answered with; aHopsDone how many repeats
  were already made. The status is assumed to be a redirect; 303 is
  rdSeeOther and every other status here repeats (301 and 302 included: NY4I's
  ruling for these three uploads, although RFC 9110 15.4.2 lets a client turn
  them into a GET -- these endpoints only take a POST). The target is resolved
  against aFromUrl, so a relative Location is fine. *)
function DecideRepost(const aFromUrl, aLocation: string; aStatus, aHopsDone: integer;
                      out aTarget: string): TRepostDecision;

(* REGISTRY. A transport unit calls this from its initialization section.
  aPreferred: this transport is the one to use on this platform whenever it is
  Available (a platform transport). The generic one registers as not preferred
  and is what is left when no preferred one is available. *)
procedure RegisterHttpTransport(aClass: TPlatformHttpTransportClass; aPreferred: boolean);

const
   (* THE VALUES OF network.httpTransport (design 6, S2). The registry knows no
     setting: the shared layer reads it and passes the value in. *)
   HTTP_TRANSPORT_AUTO     = 'auto';      (* a platform transport if Available, else generic *)
   HTTP_TRANSPORT_PLATFORM = 'platform';  (* the same, but a platform with none says so at Warn *)
   HTTP_TRANSPORT_GENERIC  = 'generic';   (* FPC + OpenSSL: the default at S2 *)

(* The transport every request uses for this POLICY (one of the values above;
  blank or anything unrecognised means generic, the safe answer). Decided at
  first use and logged once as '[HTTP] transport: <id>'. It is decided again,
  and logged again, only when the policy VALUE changes -- the setting is read
  before it is loaded (the startup country-file download runs ahead of the
  configuration), and an operator may change it in Preferences. Nothing is ever
  re-decided because a request FAILED: there is no per-request fallback. A
  transport that was replaced is kept alive until exit, because another thread
  may still be inside its Execute. NIL only when nothing is registered, which
  the caller must treat as a failed request (never an access violation). *)
function ActiveHttpTransport(const aPolicy: string): TPlatformHttpTransport;

(* TEST SEAMS. SetHttpTransportForTest makes aTransport the active one (the
  caller keeps ownership); nil goes back to the registry. A test that needs the
  generic transport asks for it explicitly rather than hoping a platform one is
  absent. ResetHttpTransportSelection forgets the decision so the next use
  decides again; UnregisterHttpTransport removes a class a test registered. *)
procedure SetHttpTransportForTest(aTransport: TPlatformHttpTransport);
procedure ResetHttpTransportSelection;
procedure UnregisterHttpTransport(aClass: TPlatformHttpTransportClass);

implementation

uses
   SyncObjs, TypInfo, Log4D;

type
   THttpTransportEntry = record
      Cls:       TPlatformHttpTransportClass;
      Preferred: boolean;
   end;

var
   GLock:     TCriticalSection = nil;
   GEntries:  array of THttpTransportEntry;
   GActive:   TPlatformHttpTransport = nil;
   GActivePolicy: string = '';
   (* Transports a changed policy replaced. Never freed before exit: a worker
     may be inside Execute on one. *)
   GRetired:  array of TPlatformHttpTransport;
   GOverride: TPlatformHttpTransport = nil;
   GNoneLogged: boolean = False;
   (* The same logger name as uHTTPDownload, so one appender sees both. *)
   GLog:      TLogLogger = nil;

function TBoundedHttpResponse.Write(const Buffer; Count: LongInt): LongInt;
begin
   if (Limit > 0) and (Int64(Count) > Limit - Position) then
      begin
      Exceeded := True;
      raise EStreamError.Create('HTTP response exceeds the configured size limit');
      end;
   Result := inherited Write(Buffer, Count);
end;

function THttpWireRequest.MayFollowRedirects: boolean;
begin
   Result := FollowRedirects and (not UnicodeSameText(Method, 'POST'));
end;

constructor THttpWireRequest.Create;
begin
   inherited Create;
   ConnectMs := 15000;
   IOMs      := 30000;
end;

constructor THttpWireResult.Create;
begin
   inherited Create;
   Clear;
end;

procedure THttpWireResult.Clear;
begin
   Failure      := hfNone;
   ErrorClass   := '';
   ErrorMessage := '';
   StatusCode   := 0;
   StatusText   := '';
   RetryAfter   := '';
   RequestId    := '';
   ETag         := '';
   LastModified := '';
   ContentType  := '';
   Location     := '';
   FinalURL     := '';
   Body         := '';
end;

function THttpWireResult.Detail: string;
begin
   if ErrorClass <> '' then
      begin
      Result := ErrorClass + ': ' + ErrorMessage;
      end
   else
      begin
      Result := ErrorMessage;
      end;
end;

function NothingSent(aFailure: THttpFailure): boolean;
begin
   case aFailure of
      hfTlsUnavailable,
      hfTrustUnavailable,
      hfVerificationUnavailable,
      hfVerificationFailed,
      hfPlaintextNotAllowed,
      hfBadScheme,
      hfAuthPolicy,
      hfNameNotResolved,
      hfCannotConnect,
      hfConnectTimedOut:
         begin
         Result := True;
         end;
   else
      (* hfNone, hfTlsLibraryFault, hfIOTimedOut, hfConnectionLost,
        hfResponseTooLarge, hfCancelled, hfPostRedirected, hfOther: a request
        may have left (hfPostRedirected: it DID, and was answered). *)
      begin
      Result := False;
      end;
   end;
end;

function HttpFailureName(aFailure: THttpFailure): string;
begin
   Result := string(GetEnumName(TypeInfo(THttpFailure), Ord(aFailure)));
end;

function ToWire(const aText: string): RawByteString;
begin
   Result := UTF8Encode(aText);
end;

function FromWire(const aBytes: RawByteString): string;
begin
   Result := UTF8Decode(aBytes);
end;

function IsHttpsUrl(const aUrl: string): boolean;
begin
   Result := UnicodeSameText(Copy(aUrl, 1, 8), 'https://');
end;

(* One address taken apart, BY HAND (not URIParser: its strings are 8-bit and a
  UTF-16 string passed to it is a narrowing the build counts). aHostPort is
  what follows any credentials in the authority; aPathQuery has no fragment and
  always starts with '/'. False when it is not an http or https address. *)
function SplitHttpUrl(const aUrl: string; out aScheme, aHost, aHostPort, aPathQuery: string;
                      out aPort: integer; out aHasUserInfo: boolean): boolean;
var
   p, q:      integer;
   rest, authority, portText: string;
begin
   Result := False;
   aScheme := '';
   aHost := '';
   aHostPort := '';
   aPathQuery := '/';
   aPort := 0;
   aHasUserInfo := False;
   p := Pos('://', aUrl);
   if p < 2 then
      begin
      Exit;
      end;
   aScheme := LowerCase(Copy(aUrl, 1, p - 1));
   if (aScheme <> 'http') and (aScheme <> 'https') then
      begin
      Exit;
      end;
   rest := Copy(aUrl, p + 3, MaxInt);
   p := Pos('#', rest);
   if p > 0 then
      begin
      rest := Copy(rest, 1, p - 1);
      end;
   p := Pos('/', rest);
   q := Pos('?', rest);
   if (q > 0) and ((p = 0) or (q < p)) then
      begin
      p := q;
      end;
   if p = 0 then
      begin
      authority := rest;
      end
   else
      begin
      authority := Copy(rest, 1, p - 1);
      aPathQuery := Copy(rest, p, MaxInt);
      if aPathQuery[1] = '?' then
         begin
         aPathQuery := '/' + aPathQuery;
         end;
      end;
   (* Everything up to the LAST '@' is credentials. *)
   q := Length(authority);
   while (q > 0) and (authority[q] <> '@') do
      begin
      Dec(q);
      end;
   aHasUserInfo := q > 0;
   aHostPort := Copy(authority, q + 1, MaxInt);
   portText := '';
   if (aHostPort <> '') and (aHostPort[1] = '[') then
      begin
      q := Pos(']', aHostPort);
      if q = 0 then
         begin
         Exit;
         end;
      aHost := LowerCase(Copy(aHostPort, 1, q));
      if Copy(aHostPort, q + 1, 1) = ':' then
         begin
         portText := Copy(aHostPort, q + 2, MaxInt);
         end
      else if q < Length(aHostPort) then
         begin
         Exit;
         end;
      end
   else
      begin
      q := Length(aHostPort);
      while (q > 0) and (aHostPort[q] <> ':') do
         begin
         Dec(q);
         end;
      if q > 0 then
         begin
         aHost := LowerCase(Copy(aHostPort, 1, q - 1));
         portText := Copy(aHostPort, q + 1, MaxInt);
         end
      else
         begin
         aHost := LowerCase(aHostPort);
         end;
      end;
   if aHost = '' then
      begin
      Exit;
      end;
   if portText = '' then
      begin
      if aScheme = 'https' then
         begin
         aPort := 443;
         end
      else
         begin
         aPort := 80;
         end;
      end
   else
      begin
      (* DIGITS ONLY, AT MOST FIVE: StrToInt and Val are not range-checked on
        Win64, so ":4294967739" could wrap to 443 and pass the origin test. *)
      if Length(portText) > 5 then
         begin
         Exit;
         end;
      aPort := 0;
      for q := 1 to Length(portText) do
         begin
         if (portText[q] < '0') or (portText[q] > '9') then
            begin
            Exit;
            end;
         aPort := aPort * 10 + (Ord(portText[q]) - Ord('0'));
         end;
      if (aPort < 1) or (aPort > 65535) then
         begin
         Exit;
         end;
      end;
   Result := True;
end;

function DecideRepost(const aFromUrl, aLocation: string; aStatus, aHopsDone: integer;
                      out aTarget: string): TRepostDecision;
var
   fromScheme, fromHost, fromHostPort, fromPath: string;
   toScheme, toHost, toHostPort, toPath, loc, target: string;
   fromPort, toPort, i, p: integer;
   fromUser, toUser: boolean;
begin
   aTarget := '';
   if aStatus = 303 then
      begin
      Result := rdSeeOther;
      Exit;
      end;
   if aHopsDone >= REPOST_MAX_HOPS then
      begin
      Result := rdTooManyRedirects;
      Exit;
      end;
   loc := Trim(aLocation);
   if loc = '' then
      begin
      Result := rdNoLocation;
      Exit;
      end;
   Result := rdBadLocation;
   for i := 1 to Length(loc) do
      begin
      (* Control characters, a space, a backslash (some parsers read "\" as "/",
        so "/\host" or "\@" would name a host this code did not see) and
        anything not ASCII: the same-host guarantee must not depend on this
        parser and the transport's agreeing about odd addresses. *)
      if (Ord(loc[i]) <= 32) or (Ord(loc[i]) >= 127) or (loc[i] = '\') then
         begin
         Exit;
         end;
      end;
   if not SplitHttpUrl(aFromUrl, fromScheme, fromHost, fromHostPort, fromPath,
                       fromPort, fromUser) then
      begin
      Exit;
      end;

   (* RESOLVE (RFC 3986 5.2, the cases a server writes). A leading "scheme://"
     is absolute; "//host" takes the scheme; "/x" the origin; "?q" the path;
     anything else is relative to the directory of the current path. *)
   p := Pos('://', loc);
   if (p > 1) and (Pos('/', Copy(loc, 1, p - 1)) = 0) and (Pos('?', Copy(loc, 1, p - 1)) = 0) then
      begin
      target := loc;
      end
   else if Copy(loc, 1, 2) = '//' then
      begin
      target := fromScheme + ':' + loc;
      end
   else if loc[1] = '/' then
      begin
      target := fromScheme + '://' + fromHostPort + loc;
      end
   else if loc[1] = '#' then
      begin
      Exit;
      end
   else if loc[1] = '?' then
      begin
      p := Pos('?', fromPath);
      if p > 0 then
         begin
         fromPath := Copy(fromPath, 1, p - 1);
         end;
      target := fromScheme + '://' + fromHostPort + fromPath + loc;
      end
   else
      begin
      p := Pos('?', fromPath);
      if p > 0 then
         begin
         fromPath := Copy(fromPath, 1, p - 1);
         end;
      p := Length(fromPath);
      while (p > 0) and (fromPath[p] <> '/') do
         begin
         Dec(p);
         end;
      target := fromScheme + '://' + fromHostPort + Copy(fromPath, 1, p) + loc;
      end;

   if not SplitHttpUrl(target, toScheme, toHost, toHostPort, toPath, toPort, toUser) then
      begin
      Exit;
      end;
   if toUser then
      begin
      Exit;
      end;
   if (fromScheme = 'https') and (toScheme = 'http') then
      begin
      Result := rdDowngrade;
      Exit;
      end;
   if (toScheme <> fromScheme) or (toHost <> fromHost) or (toPort <> fromPort) then
      begin
      Result := rdOtherHost;
      Exit;
      end;
   p := Pos('#', target);
   if p > 0 then
      begin
      target := Copy(target, 1, p - 1);
      end;
   aTarget := target;
   Result := rdRepost;
end;

procedure RegisterHttpTransport(aClass: TPlatformHttpTransportClass; aPreferred: boolean);
var
   i: integer;
begin
   GLock.Enter;
   try
      for i := 0 to High(GEntries) do
         begin
         if GEntries[i].Cls = aClass then
            begin
            GEntries[i].Preferred := aPreferred;
            Exit;
            end;
         end;
      SetLength(GEntries, Length(GEntries) + 1);
      GEntries[High(GEntries)].Cls       := aClass;
      GEntries[High(GEntries)].Preferred := aPreferred;
   finally
      GLock.Leave;
   end;
end;

procedure UnregisterHttpTransport(aClass: TPlatformHttpTransportClass);
var
   i, j: integer;
begin
   GLock.Enter;
   try
      for i := 0 to High(GEntries) do
         begin
         if GEntries[i].Cls = aClass then
            begin
            for j := i to High(GEntries) - 1 do
               begin
               GEntries[j] := GEntries[j + 1];
               end;
            SetLength(GEntries, Length(GEntries) - 1);
            Break;
            end;
         end;
   finally
      GLock.Leave;
   end;
end;

(* Try the entries whose Preferred flag equals aPreferred, in registration
  order; the first Available one wins. Under GLock. *)
function PickTransport(aPreferred: boolean): TPlatformHttpTransport;
var
   i:        integer;
   candidate: TPlatformHttpTransport;
   why:      string;
begin
   Result := nil;
   for i := 0 to High(GEntries) do
      begin
      if GEntries[i].Preferred = aPreferred then
         begin
         candidate := GEntries[i].Cls.Create;
         why := '';
         if candidate.Available(why) then
            begin
            Result := candidate;
            Exit;
            end;
         (* A preferred transport that cannot work here is worth a line naming
           why; the generic one is then chosen, once, with no later fallback. *)
         GLog.Warn('[HTTP] transport %s is not available (%s)',
                   [GEntries[i].Cls.Id, why]);
         candidate.Free;
         end;
      end;
end;

(* The policy as one of the three values: blank or unknown is generic. *)
function NormalisePolicy(const aPolicy: string): string;
begin
   Result := LowerCase(Trim(aPolicy));
   if (Result <> HTTP_TRANSPORT_AUTO) and (Result <> HTTP_TRANSPORT_PLATFORM) then
      begin
      Result := HTTP_TRANSPORT_GENERIC;
      end;
end;

function HasPreferredEntry: boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to High(GEntries) do
      begin
      if GEntries[i].Preferred then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function ActiveHttpTransport(const aPolicy: string): TPlatformHttpTransport;
var
   policy: string;
begin
   GLock.Enter;
   try
      if GOverride <> nil then
         begin
         Result := GOverride;
         Exit;
         end;
      policy := NormalisePolicy(aPolicy);
      if (GActive <> nil) and (GActivePolicy <> policy) then
         begin
         SetLength(GRetired, Length(GRetired) + 1);
         GRetired[High(GRetired)] := GActive;
         GActive := nil;
         end;
      if GActive = nil then
         begin
         GActivePolicy := policy;
         if policy <> HTTP_TRANSPORT_GENERIC then
            begin
            if (policy = HTTP_TRANSPORT_PLATFORM) and (not HasPreferredEntry) then
               begin
               GLog.Warn('[HTTP] the setting asks for the platform transport and this '
                         + 'platform has none; using generic');
               end;
            GActive := PickTransport(True);
            end;
         if GActive = nil then
            begin
            GActive := PickTransport(False);
            end;
         if GActive <> nil then
            begin
            GLog.Info('[HTTP] transport: %s (setting: %s)', [GActive.Id, policy]);
            GNoneLogged := False;
            end
         else if not GNoneLogged then
            begin
            GNoneLogged := True;
            GLog.Error('[HTTP] no HTTP transport is registered or available; '
                       + 'every request will be refused');
            end;
         end;
      Result := GActive;
   finally
      GLock.Leave;
   end;
end;

procedure SetHttpTransportForTest(aTransport: TPlatformHttpTransport);
begin
   GLock.Enter;
   try
      GOverride := aTransport;
   finally
      GLock.Leave;
   end;
end;

procedure ResetHttpTransportSelection;
begin
   GLock.Enter;
   try
      FreeAndNil(GActive);
      GActivePolicy := '';
      GNoneLogged := False;
   finally
      GLock.Leave;
   end;
end;

procedure FreeRetiredTransports;
var
   i: integer;
begin
   for i := 0 to High(GRetired) do
      begin
      GRetired[i].Free;
      end;
   GRetired := nil;
end;

initialization
   GLock := TCriticalSection.Create;
   GLog  := TLogLogger.GetLogger('TR4WDebugLog.HTTP');

finalization
   FreeAndNil(GActive);
   FreeRetiredTransports;
   FreeAndNil(GLock);

end.
