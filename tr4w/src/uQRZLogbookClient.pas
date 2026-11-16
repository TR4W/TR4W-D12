unit uQRZLogbookClient;
{$I tr4w.inc}
(* THE QRZ LOGBOOK CLIENT (issue 310). QRZ's Logbook API is one endpoint:

      POST https://logbook.qrz.com/api
      KEY=<api access key>&ACTION=INSERT&ADIF=<one QSO as ADIF>   (a form body)
      KEY=...&ACTION=INSERT&OPTION=REPLACE&ADIF=...
      KEY=...&ACTION=DELETE&LOGIDS=<logid>

   and the answer is a form-style text, not JSON:

      RESULT=OK&LOGID=130877825&COUNT=1        inserted
      RESULT=REPLACE&LOGID=...&COUNT=1         replaced
      RESULT=FAIL&REASON=...                   refused (a duplicate, a bad call)
      RESULT=AUTH&REASON=...                   the key is wrong, or the account has no
                                               QRZ logbook / XML subscription

   Read from QRZ's Logbook API guide; NEVER RUN against a live QRZ (it needs a
   key). The reply shapes are the bench items in docs/BENCH_QUEUE.md.

   THE KEY IS A SECRET AND TRAVELS IN THE FORM BODY. THttpRequest.BearerToken is
   the wrong mechanism (it makes an Authorization header QRZ never reads). Like
   Cloudlog the request names the key as its Password with no Username plus
   Sensitive: uHTTPDownload scrubs it, raw and URL-encoded, from every log line
   (the [HTTP] DEBUG line carries the body). The reply's REASON is never shown or
   logged here: a refusal is the fixed code QRZ_REJECTED.

   EVERY REQUEST IDENTIFIES ITSELF: User-Agent is TR4W/<version> (CALL), kept
   under 128 characters as QRZ asks.

   EDIT AND DELETE. A QRZ INSERT returns the LOGID, kept as the delivery's remote
   identity. A delete sends that LOGID. An edit is delete-then-insert, exactly as
   Club Log's: OPTION=REPLACE matches on the record's identity fields, so an edit
   that changed the call, time, band or mode would leave the OLD row behind and add
   a second one. The insert of an edit also carries OPTION=REPLACE, so a delete
   that took effect on an earlier, unanswered attempt cannot leave a duplicate.
   A failed delete never proceeds to the insert; a failed insert after a confirmed
   delete is UNCERTAIN and pauses (the old QSO is gone), never replayed blindly. *)
interface
uses uExternalDeliveryClient, uExternalDelivery, uHTTPDownload;
const
   QRZ_LOGBOOK_URL = 'https://logbook.qrz.com/api';
   (* The remote id of a contact QRZ said it already holds (a duplicate refusal of
      a plain insert): delivered, LOGID unknown. Not numeric, so never sent. *)
   QRZ_DUPLICATE_MARKER = 'qrz:duplicate';
type
   (* What a QRZ answer said. Valid is False when no RESULT= was found. *)
   TQRZReply = record
      Valid: boolean;
      Result, LogId, Reason: string;
      Count: integer;   (* -1 when absent or not a number *)
   end;

   TQRZLogbookClient = class(TExternalDeliveryClient)
   private
      FCall, FKey: string;
      function Send(const aAction, aParams: string;
         out aReply: TQRZReply): TExternalDeliveryResult;
      function Insert(const aAdif: string; aReplace: boolean): TExternalDeliveryResult;
      function Remove(const aLogId: string): TExternalDeliveryResult;
   protected
      function NewRequest: THttpRequest; virtual;
   public
      constructor Create(const aCall, aApiKey: string);
      function RecoverUpdatesAsUncertain: boolean; override;
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; override;
   end;
(* 'TR4W/<version> (<call>)', cut to 127 characters. *)
function QRZUserAgent(const aCall: string): string;
(* Parse the ampersand-separated NAME=value answer. Names are case-insensitive. *)
function QRZParseReply(const aText: string): TQRZReply;
(* True when a FAIL's REASON calls the record a duplicate. *)
function QRZReasonIsDuplicate(const aReason: string): boolean;
implementation
uses SysUtils, fphttpclient, Version;

function QRZReasonIsDuplicate(const aReason: string): boolean;
begin
   (* ASSUMED FROM THE GUIDE, never observed: 'Unable to add QSO to database:
      duplicate'. Only the word is matched, so a rewording keeps working. *)
   Result := Pos('DUPLICATE', UpperCase(aReason)) > 0;
end;

function QRZUserAgent(const aCall: string): string;
begin
   Result := 'TR4W/' + TR4W_CURRENTVERSION_NUMBER;
   if Trim(aCall) <> '' then
      begin
      Result := Result + ' (' + Trim(aCall) + ')';
      end;
   if Length(Result) > 127 then
      begin
      SetLength(Result, 127);
      end;
end;

function QRZParseReply(const aText: string): TQRZReply;
var
   rest, pair, name, value: string;
   p: integer;
   number: integer;
begin
   Result := Default(TQRZReply);
   Result.Count := -1;
   rest := Trim(aText);
   while rest <> '' do
      begin
      p := Pos('&', rest);
      if p = 0 then
         begin
         pair := rest;
         rest := '';
         end
      else
         begin
         pair := Copy(rest, 1, p - 1);
         Delete(rest, 1, p);
         end;
      p := Pos('=', pair);
      if p > 0 then
         begin
         name := UpperCase(Trim(Copy(pair, 1, p - 1)));
         value := Trim(Copy(pair, p + 1, Length(pair)));
         if name = 'RESULT' then
            begin
            Result.Result := UpperCase(value);
            Result.Valid := True;
            end
         else if name = 'LOGID' then
            begin
            Result.LogId := value;
            end
         else if name = 'REASON' then
            begin
            Result.Reason := value;
            end
         else if (name = 'COUNT') and TryStrToInt(UTF8Encode(value), number) then
            begin
            Result.Count := number;
            end;
         end;
      end;
end;

(* One form field's value, URL-encoded as UTF-8. *)
function FormValue(const aValue: string): string;
begin
   Result := UTF8Decode(EncodeURLElement(UTF8Encode(aValue)));
end;

constructor TQRZLogbookClient.Create(const aCall, aApiKey: string);
begin
   inherited Create;
   FCall := aCall;
   FKey := aApiKey;
end;

function TQRZLogbookClient.RecoverUpdatesAsUncertain: boolean;
begin
   (* An edit is delete-then-insert: it may have deleted before the process stopped. *)
   Result := True;
end;

function TQRZLogbookClient.NewRequest: THttpRequest;
begin
   Result := THttpRequest.Create(QRZ_LOGBOOK_URL);
end;

(* The credential class: a wrong key, or an account QRZ will not let write. The
   work is kept (a retry) and the worker stops, as it does for an HTTP 401. *)
procedure ApplyAuthRequired(var aResult: TExternalDeliveryResult);
begin
   aResult.Outcome := doRetry;
   aResult.Pause := True;
   aResult.RetrySeconds := 60;
   aResult.ErrorCode := 'QRZ_AUTH_REQUIRED';
end;

(* The HTTP half. Returns with aReply.Valid True only for an HTTP 200 whose body
   carried a RESULT; every other outcome is already classified in the returned
   result (nothing sent, rate limit, credentials, a refusal, or "may have been
   processed, cannot tell": uncertain and paused). *)
function TQRZLogbookClient.Send(const aAction, aParams: string;
   out aReply: TQRZReply): TExternalDeliveryResult;
var
   request: THttpRequest;
begin
   aReply := Default(TQRZReply);
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doUncertain;
   Result.Pause := True;
   Result.ErrorCode := 'QRZ_RESPONSE_REQUIRES_REVIEW';
   request := NewRequest;
   try
      StampRequest(request);
      request.Method := 'POST';
      request.Body := 'KEY=' + FormValue(FKey) + '&ACTION=' + aAction + aParams;
      request.ContentType := 'application/x-www-form-urlencoded';
      request.UserAgent := QRZUserAgent(FCall);
      (* THE KEY IS SCRUBBED AS A PASSWORD: no Username, so no Authorization
         header is made, but every log line has it masked. *)
      request.Password := FKey;
      request.Sensitive := True;
      request.FollowRedirects := False;
      request.ConnectMs := 5000;
      request.IOMs := 20000;
      request.MaxResponseBytes := 16384;
      request.Send;
      Result.Status := request.StatusCode;
      if ApplyNothingSent(request, 'QRZ_', 'QRZ Logbook', Result) then
         begin
         Exit;
         end;
      if ApplyRateLimited(request, 'QRZ_', Result) then
         begin
         Exit;
         end;
      if (Result.Status = 401) or (Result.Status = 403) then
         begin
         ApplyAuthRequired(Result);
         Exit;
         end;
      if (Result.Status >= 300) and (Result.Status < 400) then
         begin
         Result.Outcome := doFailed;
         Result.ErrorCode := 'QRZ_REDIRECT';
         Exit;
         end;
      if (Result.Status >= 400) and (Result.Status < 500) then
         begin
         Result.Outcome := doFailed;
         Result.ErrorCode := 'QRZ_HTTP_' + string(IntToStr(Result.Status));
         Exit;
         end;
      if Result.Status <> 200 then
         begin
         (* 5xx, 1xx, 202...: the request may have been processed. *)
         Exit;
         end;
      aReply := QRZParseReply(request.Response);
      if not aReply.Valid then
         begin
         Result.ErrorCode := 'QRZ_INVALID_RESPONSE';
         end;
   finally
      request.Free;
   end;
end;

function TQRZLogbookClient.Insert(const aAdif: string;
   aReplace: boolean): TExternalDeliveryResult;
var
   reply: TQRZReply;
   params: string;
begin
   params := '';
   if aReplace then
      begin
      params := '&OPTION=REPLACE';
      end;
   Result := Send('INSERT', params + '&ADIF=' + FormValue(aAdif), reply);
   if not reply.Valid then
      begin
      Exit;
      end;
   if (reply.Result = 'OK') or (reply.Result = 'REPLACE') then
      begin
      (* We sent ONE record: the answer must name its LOGID, and a count, when
         given, must be one. Anything else is not a confirmation. *)
      if IsPositiveNumericId(reply.LogId) and ((reply.Count = -1) or (reply.Count = 1)) then
         begin
         Result.Outcome := doConfirmed;
         Result.Pause := False;
         Result.ErrorCode := '';
         Result.RemoteId := reply.LogId;
         end
      else
         begin
         Result.ErrorCode := 'QRZ_LOGID_REQUIRED';
         end;
      end
   else if reply.Result = 'AUTH' then
      begin
      ApplyAuthRequired(Result);
      end
   else if reply.Result = 'FAIL' then
      begin
      if (not aReplace) and QRZReasonIsDuplicate(reply.Reason) then
         begin
         (* A plain insert that QRZ calls a duplicate: the QSO is ALREADY on QRZ,
            most likely from an earlier attempt whose reply was lost. It is
            delivered, only its LOGID is unknown, so a marker stands in (the
            outbox refuses a confirmed create with an empty id). The reason text
            is read, never kept or shown. *)
         Result.Outcome := doConfirmed;
         Result.Pause := False;
         Result.ErrorCode := '';
         Result.RemoteId := QRZ_DUPLICATE_MARKER;
         end
      else
         begin
         (* This contact was refused (a bad record). Settled once and visible;
            the destination keeps working. *)
         Result.Outcome := doFailed;
         Result.Pause := False;
         Result.ErrorCode := 'QRZ_REJECTED';
         end;
      end;
end;

function TQRZLogbookClient.Remove(const aLogId: string): TExternalDeliveryResult;
var
   reply: TQRZReply;
begin
   Result := Send('DELETE', '&LOGIDS=' + FormValue(aLogId), reply);
   if not reply.Valid then
      begin
      Exit;
      end;
   if reply.Result = 'OK' then
      begin
      Result.Outcome := doConfirmed;
      Result.Deleted := True;
      Result.Pause := False;
      Result.ErrorCode := '';
      end
   else if reply.Result = 'AUTH' then
      begin
      ApplyAuthRequired(Result);
      end
   else if reply.Result = 'FAIL' then
      begin
      Result.Outcome := doFailed;
      Result.Pause := False;
      Result.ErrorCode := 'QRZ_DELETE_REJECTED';
      end;
end;

function TQRZLogbookClient.Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult;
var
   edit: boolean;
begin
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doFailed;
   Result.Pause := True;
   if aJob.Deleted and (aJob.RemoteId = '') then
      begin
      (* Never created remotely: nothing to delete. *)
      Result.Outcome := doConfirmed;
      Result.Pause := False;
      Exit;
      end;
   if (FCall = '') or (FKey = '') then
      begin
      Result.ErrorCode := 'QRZ_SETUP_REQUIRED';
      Exit;
      end;
   edit := aJob.RemoteId <> '';
   if edit then
      begin
      if aJob.RemoteId = QRZ_DUPLICATE_MARKER then
         begin
         (* Delivered, but QRZ never told us the LOGID, so there is nothing to
            delete or replace. Visible, nothing sent, the destination keeps going. *)
         Result.Pause := False;
         Result.ErrorCode := 'QRZ_LOGID_UNKNOWN';
         Exit;
         end;
      if not IsPositiveNumericId(aJob.RemoteId) then
         begin
         Result.ErrorCode := 'QRZ_INVALID_LOGID';
         Exit;
         end;
      Result := Remove(aJob.RemoteId);
      if (Result.Outcome <> doConfirmed) or aJob.Deleted then
         begin
         Exit;
         end;
      end;
   Result := Insert(aJob.Payload, edit);
   if edit and (Result.Outcome <> doConfirmed) then
      begin
      (* The old QSO is gone. Do not replay the two-step replacement blindly. *)
      Result.Outcome := doUncertain;
      Result.Pause := True;
      Result.ErrorCode := 'QRZ_REPLACEMENT_REQUIRES_REVIEW';
      end;
end;
end.
