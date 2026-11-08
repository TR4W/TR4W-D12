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
      Body:         RawByteString;   (* only when Execute was given no sink *)
      constructor Create;
      procedure Clear;
      (* 'Class: message' for the log, or just the message when there is no class. *)
      function Detail: string;
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

(* REGISTRY. A transport unit calls this from its initialization section.
  aPreferred: this transport is the one to use on this platform whenever it is
  Available (a platform transport). The generic one registers as not preferred
  and is what is left when no preferred one is available. *)
procedure RegisterHttpTransport(aClass: TPlatformHttpTransportClass; aPreferred: boolean);

(* The transport every request uses: decided at first use, logged once, never
  re-decided within the session. NIL only when nothing is registered, which the
  caller must treat as a failed request (never an access violation). *)
function ActiveHttpTransport: TPlatformHttpTransport;

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
   GOverride: TPlatformHttpTransport = nil;
   GNoneLogged: boolean = False;
   (* The same logger name as uHTTPDownload, so one appender sees both. *)
   GLog:      TLogLogger = nil;

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
        hfResponseTooLarge, hfCancelled, hfOther: a request may have left. *)
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

function ActiveHttpTransport: TPlatformHttpTransport;
begin
   GLock.Enter;
   try
      if GOverride <> nil then
         begin
         Result := GOverride;
         Exit;
         end;
      if GActive = nil then
         begin
         GActive := PickTransport(True);
         if GActive = nil then
            begin
            GActive := PickTransport(False);
            end;
         if GActive <> nil then
            begin
            GLog.Info('[HTTP] transport: %s', [GActive.Id]);
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
      GNoneLogged := False;
   finally
      GLock.Leave;
   end;
end;

initialization
   GLock := TCriticalSection.Create;
   GLog  := TLogLogger.GetLogger('TR4WDebugLog.HTTP');

finalization
   FreeAndNil(GActive);
   FreeAndNil(GLock);

end.
