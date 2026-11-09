unit uCloudlogClient;
{$I tr4w.inc}
(* THE CLOUDLOG / WAVELOG CLIENT (issue 204). One API serves both programs:

      POST <base>/api/qso      (an instance served through index.php enters
                                 <base> as https://host/index.php)
      {"key": ..., "station_profile_id": ..., "type": "adif", "string": <ADIF>}

   THE KEY TRAVELS IN THE BODY, not in an Authorization header, so
   THttpRequest.BearerToken is the wrong mechanism (it would add a header the
   server never reads). The request names the key as its Password with no
   Username: uHTTPDownload scrubs Password out of every log line it writes
   (the [HTTP] DEBUG line carries the body) and the transport sends basic
   authentication only when Username is not empty. Pinned in uTestCloudlog.

   WHAT THE SERVERS ANSWER (read from the Wavelog and Cloudlog sources,
   Api.php and Logbook_model.php, 2026-11-07):
      201  created  - Wavelog: adif_count, adif_errors, messages
                      Cloudlog: imported_count, messages
                      A 201 does NOT prove an import: Cloudlog answers 201 even
                      when every record was refused (a duplicate), so the COUNT
                      is what is checked, against the one record we send.
      400  abort    - Wavelog: the import reported an error (a duplicate or a
                      validation failure). A refusal of THIS contact.
      401           - bad key, a station profile the key's owner does not own,
                      and (Cloudlog) a STATION_CALLSIGN that does not match the
                      profile's, or an empty call.
      403           - Wavelog: a read-only key.
      200  failed   - malformed JSON (Wavelog and Cloudlog both answer 200).
      429           - Wavelog's rate limit, with a Retry-After.

   THERE IS NO EDIT AND NO DELETE ENDPOINT, and a re-POST is no substitute: both
   servers refuse a record whose call, minute, band, mode and station match one
   they hold as a duplicate (Wavelog 400, Cloudlog imported_count 0), and a
   re-POST with a changed key field creates a SECOND row. So an edit or a delete
   of a contact already delivered settles as an explicit FAILURE the operator
   sees (design doc: an unsupported operation fails visibly, never reports
   success). A contact never delivered is simply sent (edit) or cancelled
   locally (delete). *)
interface
uses uExternalDeliveryClient, uExternalDelivery, uHTTPDownload;
const
   (* Local delivery marker, never sent anywhere. The outbox needs a nonempty
      remote identity on a confirmed creation and these servers return none; the
      marker also tells a later job "created remotely" from "never sent". *)
   CLOUDLOG_CREATED_MARKER = 'cloudlog:created';
type
   TCloudlogClient = class(TExternalDeliveryClient)
   private
      FBaseUrl, FProfileId, FKey: string;
      function Post(const aAdif: string): TExternalDeliveryResult;
   protected
      function NewRequest(const aURL: string): THttpRequest; virtual;
   public
      constructor Create(const aBaseUrl, aProfileId, aApiKey: string);
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; override;
   end;
(* base + '/api/qso', with trailing slashes on the base dropped. *)
function CloudlogQsoUrl(const aBaseUrl: string): string;
implementation
uses SysUtils, fpjson, uJSON;

function CloudlogQsoUrl(const aBaseUrl: string): string;
var
   base: string;
begin
   base := Trim(aBaseUrl);
   while (base <> '') and (base[Length(base)] = '/') do
      begin
      Delete(base, Length(base), 1);
      end;
   Result := base + '/api/qso';
end;

constructor TCloudlogClient.Create(const aBaseUrl, aProfileId, aApiKey: string);
begin
   inherited Create;
   FBaseUrl := aBaseUrl;
   FProfileId := aProfileId;
   FKey := aApiKey;
end;

function TCloudlogClient.NewRequest(const aURL: string): THttpRequest;
begin
   Result := THttpRequest.Create(aURL);
end;

(* A count the server reported, as a number. False when it is absent or not one. *)
function ReadCount(const aRoot: TJSONObject; const aName: string; out aCount: Int64): boolean;
var
   value: TJSONData;
begin
   aCount := 0;
   value := aRoot.Find(AnsiString(aName));
   Result := (value <> nil) and (value.JSONType = jtNumber);
   if Result then
      begin
      aCount := value.AsInt64;
      end;
end;

function TCloudlogClient.Post(const aAdif: string): TExternalDeliveryResult;
var
   request: THttpRequest;
   body: TJSONObject;
   root: TJSONData;
   status: string;
   imported, count, errors: Int64;
begin
   (* Anything not classified below is "may have been imported, cannot tell":
      uncertain and paused, never replayed blindly. *)
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doUncertain;
   Result.Pause := True;
   Result.ErrorCode := 'CLOUDLOG_RESPONSE_REQUIRES_REVIEW';
   body := TJSONObject.Create;
   request := NewRequest(CloudlogQsoUrl(FBaseUrl));
   try
      StampRequest(request);
      body.Add('key', UTF8Encode(FKey));
      body.Add('station_profile_id', UTF8Encode(FProfileId));
      body.Add('type', 'adif');
      body.Add('string', UTF8Encode(aAdif));
      request.Method := 'POST';
      request.Body := UTF8Decode(body.AsJSON);
      request.ContentType := 'application/json';
      request.UserAgent := 'TR4W';
      (* THE KEY IS SCRUBBED AS A PASSWORD: no Username, so no Authorization
         header is made, but every log line has it masked. *)
      request.Password := FKey;
      request.Sensitive := True;
      request.FollowRedirects := False;
      request.ConnectMs := 5000;
      request.IOMs := 20000;
      (* The 201 echoes the whole ADIF string back. *)
      request.MaxResponseBytes := 262144;
      request.Send;
      Result.Status := request.StatusCode;
      if ApplyNothingSent(request, 'CLOUDLOG_', 'Cloudlog', Result) then
         begin
         Exit;
         end;
      if ApplyRateLimited(request, 'CLOUDLOG_', Result) then
         begin
         Exit;
         end;
      if Result.Status = 401 then
         begin
         (* The key, the station profile, or (Cloudlog) the STATION_CALLSIGN. The
            worker stops on 401 and keeps the work. *)
         Result.Outcome := doFailed;
         Result.ErrorCode := 'CLOUDLOG_UNAUTHORIZED';
         Exit;
         end;
      if Result.Status = 403 then
         begin
         Result.Outcome := doFailed;
         Result.ErrorCode := 'CLOUDLOG_READ_ONLY_KEY';
         Exit;
         end;
      if (Result.Status >= 300) and (Result.Status < 400) then
         begin
         (* Redirects are not followed (the key is in the body). The usual cause
            is a wrong base address; nothing was imported. *)
         Result.Outcome := doFailed;
         Result.ErrorCode := 'CLOUDLOG_REDIRECT';
         Exit;
         end;
      if (Result.Status >= 400) and (Result.Status < 500) and (Result.Status <> 400) then
         begin
         (* 404 (a wrong base address), 405, 413, ...: the request was refused
            before any import, and nothing here will cure itself. *)
         Result.Outcome := doFailed;
         Result.ErrorCode := 'CLOUDLOG_HTTP_' + string(IntToStr(Result.Status));
         Exit;
         end;
      if (Result.Status <> 200) and (Result.Status <> 201) and (Result.Status <> 400) then
         begin
         (* 5xx, 1xx, 202...: the import may or may not have happened. *)
         Exit;
         end;
      root := nil;
      try
         try
            root := GetJSON(UTF8Encode(request.Response));
            if root.JSONType <> jtObject then
               begin
               Exit;
               end;
            status := JSONGetStr(TJSONObject(root), 'status', '');
            if Result.Status = 400 then
               begin
               Result.Outcome := doFailed;
               if status = 'abort' then
                  begin
                  (* This contact was refused (a duplicate, a validation error).
                     Settled once and visible; the destination keeps working. *)
                  Result.Pause := False;
                  Result.ErrorCode := 'CLOUDLOG_IMPORT_REJECTED';
                  end
               else
                  begin
                  Result.ErrorCode := 'CLOUDLOG_HTTP_400';
                  end;
               Exit;
               end;
            if status = 'failed' then
               begin
               (* HTTP 200: the request itself was malformed. A defect, not a
                  refusal of one contact, so the destination pauses. *)
               Result.Outcome := doFailed;
               Result.ErrorCode := 'CLOUDLOG_REQUEST_REFUSED';
               Exit;
               end;
            if (Result.Status <> 201) or (status <> 'created') then
               begin
               Exit;
               end;
            (* 201 created. We sent ONE record; count what the server says it took. *)
            if ReadCount(TJSONObject(root), 'imported_count', imported) then
               begin
               (* Cloudlog. *)
               if imported = 1 then
                  begin
                  Result.Outcome := doConfirmed;
                  end
               else if imported = 0 then
                  begin
                  Result.Outcome := doFailed;
                  Result.Pause := False;
                  Result.ErrorCode := 'CLOUDLOG_IMPORT_REJECTED';
                  Exit;
                  end
               else
                  begin
                  Exit;
                  end;
               end
            else if ReadCount(TJSONObject(root), 'adif_count', count) and
                    ReadCount(TJSONObject(root), 'adif_errors', errors) then
               begin
               (* Wavelog. *)
               if (count = 1) and (errors = 0) then
                  begin
                  Result.Outcome := doConfirmed;
                  end
               else if (count = 0) or (errors > 0) then
                  begin
                  Result.Outcome := doFailed;
                  Result.Pause := False;
                  Result.ErrorCode := 'CLOUDLOG_IMPORT_REJECTED';
                  Exit;
                  end
               else
                  begin
                  Exit;
                  end;
               end
            else
               begin
               Exit;
               end;
            Result.RemoteId := CLOUDLOG_CREATED_MARKER;
            Result.Pause := False;
            Result.ErrorCode := '';
         except
            on E: Exception do
               begin
               Result.ErrorCode := 'CLOUDLOG_INVALID_RESPONSE';
               if Result.Status = 400 then
                  begin
                  (* Refused, in a form we cannot read: still a refusal. *)
                  Result.Outcome := doFailed;
                  end;
               end;
         end;
      finally
         root.Free;
      end;
   finally
      request.Free;
      body.Free;
   end;
end;

function TCloudlogClient.Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult;
begin
   Result := Default(TExternalDeliveryResult);
   (* Pause is False on every local outcome below, on purpose: the worker halts
      the whole destination on Pause, and one unsupported edit must not. Status
      0 spends no API budget and adds no back-off. *)
   Result.Outcome := doFailed;
   Result.Pause := False;
   if aJob.Deleted and (aJob.RemoteId = '') then
      begin
      (* Never created remotely: nothing to delete. *)
      Result.Outcome := doConfirmed;
      Exit;
      end;
   if aJob.Deleted then
      begin
      Result.ErrorCode := 'CLOUDLOG_DELETE_UNSUPPORTED';
      Exit;
      end;
   if aJob.RemoteId <> '' then
      begin
      Result.ErrorCode := 'CLOUDLOG_EDIT_UNSUPPORTED';
      Exit;
      end;
   if (FBaseUrl = '') or (FProfileId = '') or (FKey = '') then
      begin
      Result.Pause := True;
      Result.ErrorCode := 'CLOUDLOG_SETUP_REQUIRED';
      Exit;
      end;
   Result := Post(aJob.Payload);
end;
end.
