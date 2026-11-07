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
   public
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
     plaintext / no scheme   doFailed, PAUSED  a malformed request, a defect
     any other proved kind   doRetry, 300 s *)
function ApplyNothingSent(aRequest: THttpRequest; const aCodePrefix, aService: string;
                          var aResult: TExternalDeliveryResult): boolean;
(* HTTP 429, CLASSIFIED ONCE for the services that read Retry-After (Club Log,
  Cloudlog/Wavelog). Returns True, with aResult filled, when the status is 429:
  a retry, not paused, after the server's Retry-After seconds (60 when absent
  or unusable, capped at a year), code aCodePrefix + 'RATE_LIMITED'. The
  request WAS refused by the server before it did anything, so a retry is safe. *)
function ApplyRateLimited(aRequest: THttpRequest; const aCodePrefix: string;
                          var aResult: TExternalDeliveryResult): boolean;
implementation
uses SysUtils, uHttpTransport, uTLSTrust;

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
      hfPlaintextNotAllowed, hfBadScheme:
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

function TExternalDeliveryClient.RecoverUpdatesAsUncertain: boolean;
begin
   Result := False;
end;
end.
