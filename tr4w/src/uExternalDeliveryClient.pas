unit uExternalDeliveryClient;
{$I tr4w.inc}
interface
uses uExternalDelivery, uHTTPDownload;
type
   TExternalDeliveryResult = record
      Outcome: TDeliveryOutcome;
      Status: integer;
      Deleted: boolean;
      RemoteId, ErrorCode, RequestId, DataJSON, NextCursor: string;
      RetrySeconds: Int64;
      Pause: boolean;
      (* Operator-facing text the worker hands to its owner, which shows it on
        the main thread. '' = nothing to say. Set by a client only for a
        condition the operator can cure (issue 221: the CA bundle is missing),
        and only the first time, so it is not shown on every retry. *)
      OperatorNotice: string;
   end;

   TExternalDeliveryClient = class
   private
      (* Inverted: a client nobody configured verifies (fields start at zero). *)
      FUnverified: boolean;
      FDestination: string;
      (* The definition's "Allow insecure (plain http)" choice. Zero (False) for
         a client nobody configured: plain http stays refused. *)
      FAllowInsecure: boolean;
      function GetVerifyServer: boolean;
      procedure SetVerifyServer(aValue: boolean);
   protected
      (* EVERY REQUEST A CLIENT MAKES PASSES THROUGH THIS (issue 256): it puts
         the destination's certificate choice and name on the THttpRequest, so
         the shared layer (uHTTPDownload.VerifyWanted) decides with the global
         master. A client calls it right after NewRequest, so a test double
         that replaces NewRequest is stamped as well. *)
      procedure StampRequest(aRequest: THttpRequest);
   public
      (* The destination's own "verify the server's certificate" choice and its
         display name, set by the worker that built the client. *)
      property VerifyServer: boolean read GetVerifyServer write SetVerifyServer;
      property Destination: string read FDestination write FDestination;
      (* Accept an http:// address for this destination (THttpRequest.AllowInsecure),
         set only by a provider that declares the box; StampRequest applies it. *)
      property AllowInsecure: boolean read FAllowInsecure write FAllowInsecure;
      function RecoverUpdatesAsUncertain: boolean; virtual;
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; virtual; abstract;
   end;
(* A REQUEST THAT PROVABLY SENT NOTHING, CLASSIFIED ONCE FOR EVERY SERVICE
  (issue 224, S1b; docs/HTTP_TRANSPORT_DESIGN.md 2.3).

  Returns True, with aResult filled, when aRequest.NothingSent, and the caller
  exits: nothing reached the server, so "uncertain, needs review" would be
  wrong, and the request is not a double-delivery risk. False means the request
  may have been sent and the caller classifies it as it always did.

  aCodePrefix is the service's error-code prefix ('CLUBLOG_', 'WRL_'); aService
  is its name for the operator notice. Which outcome, and why:

     TLS cannot start        doRetry, 300 s    a missing library can appear
     CA bundle missing       doRetry, 300 s    + the once-per-service notice. THE
                                               ONLY KIND THAT RAISES IT
     verification cannot be  doRetry, 300 s    an updated OpenSSL, or the
     set up (bundle fine)                      operator's own setting, cures it
     bearer gate             doRetry, PAUSED   the credential class: the worker
                                               treats a 401 the same way
     plaintext (http://)     doFailed, PAUSED  *_INSECURE_URL_REFUSED + the
                                               notice (Allow insecure, or https)
     no scheme               doFailed, PAUSED  *_URL_REFUSED: a malformed request
     any other proved kind   doRetry, 300 s *)
function ApplyNothingSent(aRequest: THttpRequest; const aCodePrefix, aService: string;
                          var aResult: TExternalDeliveryResult): boolean;
(* WHAT THE OWNER IS TOLD about an answer (TExternalDeliveryWorker.Notice keeps
  only the LAST text it is given): the client's own sentence when it gave one
  (the CA bundle, plain http refused), else the bare error code. The worker
  calls it at each place it raises a notice, so a later call cannot replace a
  sentence with a code. *)
function DeliveryNoticeText(const aResult: TExternalDeliveryResult): string;
(* HTTP 429, CLASSIFIED ONCE for the services that read Retry-After (Club Log,
  Cloudlog/Wavelog). Returns True, with aResult filled, when the status is 429:
  a retry, not paused, after the server's Retry-After seconds (60 when absent
  or unusable, capped at a year), code aCodePrefix + 'RATE_LIMITED'. The
  request WAS refused by the server before it did anything, so a retry is safe. *)
function ApplyRateLimited(aRequest: THttpRequest; const aCodePrefix: string;
                          var aResult: TExternalDeliveryResult): boolean;
(* A remote identity that is a positive decimal number (Club Log's qsoid, QRZ's
  LOGID): digits only, greater than zero. Such an id is put into a request
  path or body, so anything else is refused rather than sent. *)
function IsPositiveNumericId(const aValue: string): boolean;
implementation
uses SysUtils, uHttpTransport, uTLSTrust, uAppStrings;

function DeliveryNoticeText(const aResult: TExternalDeliveryResult): string;
begin
   if aResult.OperatorNotice <> '' then
      begin
      Result := aResult.OperatorNotice;
      end
   else
      begin
      Result := aResult.ErrorCode;
      end;
end;

function IsPositiveNumericId(const aValue: string): boolean;
var
   i: integer;
   number: Int64;
begin
   Result := False;
   for i := 1 to Length(aValue) do
      begin
      if not (aValue[i] in ['0'..'9']) then
         begin
         Exit;
         end;
      end;
   Result := TryStrToInt64(UTF8Encode(aValue), number) and (number > 0);
end;

function ApplyRateLimited(aRequest: THttpRequest; const aCodePrefix: string;
                          var aResult: TExternalDeliveryResult): boolean;
var
   delay: Int64;
begin
   Result := aRequest.StatusCode = 429;
   if not Result then
      begin
      Exit;
      end;
   aResult.Outcome := doRetry;
   aResult.Pause := False;
   aResult.ErrorCode := aCodePrefix + 'RATE_LIMITED';
   delay := 60;
   if not TryStrToInt64(UTF8Encode(aRequest.RetryAfter), delay) or (delay < 1) then
      begin
      delay := 60;
      end;
   if delay > 31536000 then
      begin
      delay := 31536000;
      end;
   aResult.RetrySeconds := delay;
end;

function ApplyNothingSent(aRequest: THttpRequest; const aCodePrefix, aService: string;
                          var aResult: TExternalDeliveryResult): boolean;
begin
   Result := aRequest.NothingSent;
   if not Result then
      begin
      Exit;
      end;
   aResult.Outcome       := doRetry;
   aResult.Pause         := False;
   aResult.RetrySeconds  := 300;
   aResult.OperatorNotice := '';
   case aRequest.Failure of
      hfTlsUnavailable:
         begin
         aResult.ErrorCode := aCodePrefix + 'TLS_UNAVAILABLE';
         end;
      hfTrustUnavailable:
         begin
         aResult.ErrorCode      := aCodePrefix + 'CA_BUNDLE_MISSING';
         aResult.OperatorNotice := TrustBundleAlertText(aService);
         end;
      hfVerificationUnavailable:
         begin
         aResult.ErrorCode := aCodePrefix + 'VERIFICATION_UNAVAILABLE';
         end;
      hfAuthPolicy:
         begin
         aResult.Pause     := True;
         aResult.ErrorCode := aCodePrefix + 'AUTH_POLICY';
         end;
      hfPlaintextNotAllowed:
         begin
         (* NY4I, 2026-11-24: plain http must be SAID, not only logged. Its own
            code (DeliveryFailureReasonText turns it into words) and the once-
            per-owner notice on the quick-command panel. The way out is the
            definition's Allow insecure box, or https. *)
         aResult.Outcome   := doFailed;
         aResult.Pause     := True;
         aResult.ErrorCode := aCodePrefix + 'INSECURE_URL_REFUSED';
         aResult.OperatorNotice := SLoggerPlainHttpRefusedNotice;
         end;
      hfBadScheme:
         begin
         aResult.Outcome   := doFailed;
         aResult.Pause     := True;
         aResult.ErrorCode := aCodePrefix + 'URL_REFUSED';
         end;
   else
      begin
      aResult.ErrorCode := aCodePrefix + 'NOT_SENT';
      end;
   end;
end;

function TExternalDeliveryClient.GetVerifyServer: boolean;
begin
   Result := not FUnverified;
end;

procedure TExternalDeliveryClient.SetVerifyServer(aValue: boolean);
begin
   FUnverified := not aValue;
end;

procedure TExternalDeliveryClient.StampRequest(aRequest: THttpRequest);
begin
   aRequest.VerifyServer := VerifyServer;
   aRequest.Destination := FDestination;
   aRequest.AllowInsecure := FAllowInsecure;
end;

function TExternalDeliveryClient.RecoverUpdatesAsUncertain: boolean;
begin
   Result := False;
end;
end.
