unit uWRLClient;
{$I tr4w.inc}

interface

uses
   SysUtils, Generics.Collections, uHTTPDownload, uExternalDelivery,
   uExternalDeliveryClient;

const
   (* The API's own limits on POST /logbooks (schema LogbookCreate): name 100,
      defaultCallSign 20. *)
   WRL_LOGBOOK_NAME_MAX = 100;
   WRL_CALLSIGN_MAX = 20;

   (* THE REMOTE ID OF A CONTACT WRL SAID IT ALREADY HAS. A POST answered with
      WRL's own code DUPLICATE_CONTACT means the contact is at WRL, which is a
      delivery. The error body names no id of the existing contact (what is
      known of it: code, message, field, hint, requestId), so this marker
      stands in, as QRZ's does; the outbox refuses a confirmed create with an
      empty id. Deliver treats a later edit or delete of a marker contact as
      a confirmed no-op: there is no id to patch or delete. *)
   WRL_DUPLICATE_MARKER = 'wrl:duplicate';
   WRL_DUPLICATE_CODE = 'DUPLICATE_CONTACT';

type
   TWRLResult = TExternalDeliveryResult;

   (* THE ANSWER TO POST /logbooks (issue 358). A value, like TWRLResult: the
      client returns it and the caller reads it. Ok means a logbook id came back.
      Uncertain means the request may have created a logbook all the same (the
      answer was lost, unreadable or a 5xx), so the operator is told to look on
      the WRL site before trying again. ErrorCode is WRL's own code ('Branch on
      code, not on message') or one of ours: NAME_REQUIRED, NAME_TOO_LONG,
      API_KEY_REQUIRED, MISSING_LOGBOOK_ID, INVALID_LOGBOOK_ID,
      INVALID_RESPONSE, HTTP_nnn, or a TWRLClient transport code
      (DELIVERY_UNCONFIRMED, *_TLS_UNAVAILABLE ...). The key is never in any
      field. *)
   TWRLCreateLogbookResult = record
      Ok: boolean;
      Uncertain: boolean;
      Status: integer;
      LogbookId, Name: string;
      ErrorCode, ErrorMessage, ErrorField, ErrorHint, RequestId: string;
      (* Filled by WRLCreateLogbookOnWorker only: the key's account id when
         the definition had none. *)
      AccountId: string;
   end;

   (* Synchronous, worker-owned client. Owns no database, UI or live settings.
      Only the factory test seam replaces transport; production uses shared TLS. *)
   TWRLClient = class(TExternalDeliveryClient)
   private
      FApiKey: string;
      (* The status and body of the last request that got an answer, kept so
         CreateLogbook can read WRL's error message and hint, which a
         TWRLResult has no room for. Reset at the top of every Request. *)
      FLastStatus: integer;
      FLastResponse: string;
      function Request(const aMethod, aPath, aBody: string): TWRLResult;
   protected
      function NewRequest(const aURL: string): THttpRequest; virtual;
   public
      constructor Create(const aApiKey: string);
      function Identity: TWRLResult;
      function Logbooks(const aCursor: string = ''): TWRLResult;
      (* POST /logbooks (issue 358). aCallSign becomes defaultCallSign; every
         other optional field is left out. The ONE logbook-creating call:
         issue 231 removed the old setup dialog, and this is not a way back to
         it -- it is reached from the logger row's popup only. Never raises. *)
      function CreateLogbook(const aName, aCallSign: string): TWRLCreateLogbookResult;
      function Deliver(const aJob: TDeliveryJob): TWRLResult; override;
   end;

   (* One logbook the account may deliver to. The id is opaque and is never
      shown to the operator; the name is what they choose by. *)
   TWRLLogbook = class
   public
      Id, Name: string;
      constructor Create(const aId, aName: string);
   end;

   TWRLLogbookList = class(TObjectList<TWRLLogbook>)
   public
      function IndexOfId(const aId: string): integer;
   end;

   (* Asked between requests so a caller on a worker thread can stop early.
      May be nil. *)
   TWRLStopCheck = function: boolean of object;

(* The two reads the external logger editor's WRL loader makes.
   Both are synchronous and belong on a worker thread; both return False with
   a code in aErrorCode ('' on success) and never raise. *)
function WRLReadAccountId(aClient: TWRLClient; out aAccountId,
   aErrorCode: string): boolean;
(* Every page of GET /logbooks, locked logbooks skipped. aBooks is appended to. *)
function WRLReadLogbooks(aClient: TWRLClient; const aBooks: TWRLLogbookList;
   out aErrorCode: string; aStop: TWRLStopCheck = nil): boolean;

(* THE REQUEST BODY of POST /logbooks, pure: {"name": ..., "defaultCallSign": ...}
   and nothing else. The name is trimmed and must be 1..100 characters
   (False, aErrorCode NAME_REQUIRED / NAME_TOO_LONG, nothing to send); a call
   sign that is empty or longer than the API's 20 is OMITTED rather than sent
   to be refused. Escaping is the JSON writer's. *)
function WRLCreateLogbookBody(const aName, aCallSign: string; out aBody,
   aErrorCode: string): boolean;

(* THE ENVELOPE DECODE, pure: the HTTP status and the response text in, the
   result out. {data, meta, error}: 2xx with data.id is Ok; any other answer
   carries error.code / message / field / hint / requestId. Malformed JSON, a
   2xx with no id and a 5xx are Uncertain (the logbook may exist). A value
   that contains aApiKey is dropped, so no echo of the key reaches a message. *)
function WRLDecodeCreateLogbook(aStatus: integer; const aResponse,
   aApiKey: string): TWRLCreateLogbookResult;

(* WHAT THE OPERATOR READS for a failed create, in plain words, by CODE
   (never by WRL's message). Never contains the key. *)
function WRLCreateLogbookText(const aResult: TWRLCreateLogbookResult): string;

type
   (* A create running on its own thread. The worker fills it; the owner polls
      Finished from a main-thread timer and reads Answer once. Closing the
      owner never waits: an unread ticket is just dropped (uUrlTest's shape). *)
   IWRLCreateTicket = interface
      function Finished: boolean;
      function Answer: TWRLCreateLogbookResult;
   end;

(* Starts the create on a FreeOnTerminate thread and returns at once; only
   plain values cross to it. aKnownAccount: when '' the worker also reads the
   key's account id (GET /me) so the definition can be completed. *)
function StartWRLCreateLogbook(const aApiKey, aName, aCallSign, aKnownAccount,
   aDestination: string; aVerifyServer: boolean): IWRLCreateTicket;

implementation

uses
   Classes, SyncObjs, fpjson, uJSON, fphttpclient, uAppStrings;

const
   WRL_BASE = 'https://api.worldradioleague.com/v1';

constructor TWRLClient.Create(const aApiKey: string);
begin
   inherited Create;
   FApiKey := aApiKey;
end;

function TWRLClient.NewRequest(const aURL: string): THttpRequest;
begin
   Result := THttpRequest.Create(aURL);
end;

function TWRLClient.Request(const aMethod, aPath, aBody: string): TWRLResult;
var
   request: THttpRequest;
   root, data, error, code, meta: TJSONData;
   sent: boolean;
   delay: Int64;
begin
   Result := Default(TWRLResult);
   Result.Outcome := doFailed;
   Result.RetrySeconds := 60;
   FLastStatus := 0;
   FLastResponse := '';
   if FApiKey = '' then
      begin
      Result.ErrorCode := 'API_KEY_REQUIRED';
      Exit;
      end;
   request := NewRequest(WRL_BASE + aPath);
   try
      StampRequest(request);
      request.Method := aMethod;
      request.Body := aBody;
      request.ContentType := 'application/json';
      request.BearerToken := FApiKey;
      request.FollowRedirects := False;
      (* NY4I, 2026-11-19: a POST answered with a redirect is repeated, same
        body and headers, at the SAME host only (THttpRequest.RepostOnRedirect);
        a repeat that cannot be made is hfPostRedirected, i.e. uncertain below. *)
      request.RepostOnRedirect := True;
      request.ConnectMs := 5000;
      request.IOMs := 10000;
      sent := request.Send;
      Result.Status := request.StatusCode;
      Result.RequestId := request.RequestId;
      if sent then
         begin
         FLastStatus := request.StatusCode;
         FLastResponse := request.Response;
         end;
      if ApplyNothingSent(request, 'WRL_', 'World Radio League', Result) then
         begin
         (* Nothing was sent, PROVED (THttpRequest.NothingSent): not
           "uncertain", even for a POST. ApplyNothingSent says which retry or
           failure it is, and raises the CA-bundle notice only for a missing
           bundle. *)
         Exit;
         end;
      if (Pos(FApiKey, Result.RequestId) > 0) or (Length(Result.RequestId) > 200) then
         begin
         Result.RequestId := '';
         end;
      if TryStrToInt64(UTF8Encode(request.RetryAfter), delay) and (delay >= 0) then
         begin
         (* Avoid timestamp overflow from untrusted headers. A year is already
            a paused integration in practice, and remains visible as pending. *)
         if delay > 31536000 then
            begin
            delay := 31536000;
            end;
         Result.RetrySeconds := delay;
         end;
      if not sent or (Result.Status >= 500) then
         begin
         if aMethod = 'POST' then
            begin
            Result.Outcome := doUncertain;
            end
         else
            begin
            Result.Outcome := doRetry;
            end;
         Result.ErrorCode := 'DELIVERY_UNCONFIRMED';
         Exit;
         end;
      if Result.Status = 429 then
         begin
         Result.Outcome := doRetry;
         Result.ErrorCode := 'RATE_LIMITED';
         Exit;
         end;
      root := nil;
      try
         try
            root := GetJSON(UTF8Encode(request.Response));
            if root.JSONType <> jtObject then
               begin
               raise EConvertError.Create('Expected response envelope');
               end;
            data := TJSONObject(root).Find('data');
            error := TJSONObject(root).Find('error');
            if (Result.Status >= 200) and (Result.Status < 300) and
               (error <> nil) and (error.JSONType = jtNull) and (data <> nil) and
               (data.JSONType <> jtNull) then
               begin
               Result.DataJSON := UTF8Decode(data.AsJSON);
               meta := TJSONObject(root).Find('meta');
               if (meta <> nil) and (meta.JSONType = jtObject) then
                  begin
                  code := TJSONObject(meta).Find('nextCursor');
                  if (code <> nil) and (code.JSONType = jtString) then
                     begin
                     Result.NextCursor := UTF8Decode(code.AsString);
                     end;
                  end;
               if data.JSONType = jtObject then
                  begin
                  code := TJSONObject(data).Find('id');
                  if (code <> nil) and (code.JSONType = jtString) then
                     begin
                     Result.RemoteId := UTF8Decode(code.AsString);
                     end;
                  code := TJSONObject(data).Find('deleted');
                  Result.Deleted := (code <> nil) and (code.JSONType = jtBoolean) and
                     code.AsBoolean;
                  end;
               Result.Outcome := doConfirmed;
               end
            else
               begin
               if (aMethod = 'POST') and (Result.Status >= 200) and
                  (Result.Status < 300) then
                  begin
                  Result.Outcome := doUncertain;
                  end;
               Result.ErrorCode := 'HTTP_' + IntToStr(Result.Status);
               if (error <> nil) and (error.JSONType = jtObject) then
                  begin
                  code := TJSONObject(error).Find('code');
                  if (code <> nil) and (code.JSONType = jtString) and
                     (Length(code.AsString) <= 100) and
                     (Pos(UTF8Encode(FApiKey), code.AsString) = 0) then
                     begin
                     Result.ErrorCode := UTF8Decode(code.AsString);
                     end;
                  end;
               end;
         except
            on E: Exception do
               begin
               Result.ErrorCode := 'INVALID_RESPONSE';
               if (aMethod = 'POST') and (Result.Status >= 200) and
                  (Result.Status < 300) then
                  begin
                  Result.Outcome := doUncertain;
                  end;
               end;
         end;
      finally
         root.Free;
      end;
   finally
      request.Free;
   end;
end;

function TWRLClient.Identity: TWRLResult;
begin
   Result := Request('GET', '/me', '');
end;

function TWRLClient.Logbooks(const aCursor: string): TWRLResult;
begin
   if aCursor = '' then
      begin
      Result := Request('GET', '/logbooks?limit=100', '');
      end
   else
      begin
      Result := Request('GET', '/logbooks?limit=100&cursor=' +
         UTF8Decode(EncodeURLElement(UTF8Encode(aCursor))), '');
      end;
end;

function TWRLClient.CreateLogbook(const aName, aCallSign: string): TWRLCreateLogbookResult;
var
   body, code: string;
   answer: TWRLResult;
begin
   Result := Default(TWRLCreateLogbookResult);
   try
      if not WRLCreateLogbookBody(aName, aCallSign, body, code) then
         begin
         Result.ErrorCode := code;
         Exit;
         end;
      answer := Request('POST', '/logbooks', body);
      if FLastResponse <> '' then
         begin
         (* An answer arrived: its envelope says what happened. *)
         Result := WRLDecodeCreateLogbook(FLastStatus, FLastResponse, FApiKey);
         end
      else
         begin
         (* Nothing readable came back: the transport's own code stands
            (API_KEY_REQUIRED, *_TLS_UNAVAILABLE, DELIVERY_UNCONFIRMED ...). *)
         Result.Status := FLastStatus;
         Result.ErrorCode := answer.ErrorCode;
         end;
      if Result.RequestId = '' then
         begin
         Result.RequestId := answer.RequestId;
         end;
      if Result.Ok and (Result.Name = '') then
         begin
         Result.Name := Trim(aName);
         end;
      if (not Result.Ok) and (answer.Outcome = doUncertain) then
         begin
         (* A POST that may have left: the logbook may exist. *)
         Result.Uncertain := True;
         end;
   except
      on E: Exception do
         begin
         (* Never raises into the worker thread, and the exception text is not
            kept: it could carry the request. *)
         Result := Default(TWRLCreateLogbookResult);
         Result.Uncertain := True;
         Result.ErrorCode := 'DELIVERY_UNCONFIRMED';
         end;
   end;
end;

function TWRLClient.Deliver(const aJob: TDeliveryJob): TWRLResult;
var
   data, previous, oldValue: TJSONData;
   body: TJSONObject;
   method, path: string;
   i: integer;
   attempted: boolean;
begin
   Result := Default(TWRLResult);
   Result.Outcome := doFailed;
   if aJob.Deleted and (aJob.RemoteId = '') then
      begin
      (* Creation was cancelled before it reached WRL. Uncertain creations are
         never claimed, so an empty remote ID here really means unsent. *)
      Result.Outcome := doConfirmed;
      Exit;
      end;
   path := '/contacts';
   if aJob.RemoteId = WRL_DUPLICATE_MARKER then
      begin
      (* The contact is at WRL (it answered DUPLICATE_CONTACT to the create) but
         we never learned its id, so there is nothing to patch or delete. Settled
         as delivered, nothing sent; never a failure, never a loop. *)
      Result.Outcome := doConfirmed;
      Result.RemoteId := aJob.RemoteId;
      Result.Deleted := aJob.Deleted;
      Exit;
      end;
   if aJob.RemoteId <> '' then
      begin
      (* The API uses UUIDs. Reject path/query delimiters rather than letting
         an untrusted response ID redirect a subsequent operation. *)
      for i := 1 to Length(aJob.RemoteId) do
         begin
         if not CharInSet(aJob.RemoteId[i], ['0'..'9', 'a'..'f', 'A'..'F', '-']) then
            begin
            Result.ErrorCode := 'INVALID_CONTACT_ID';
            Exit;
            end;
         end;
      path := path + '/' + aJob.RemoteId;
      end;
   if aJob.Deleted then
      begin
      Result := Request('DELETE', path, '');
      if (Result.Outcome = doConfirmed) and not Result.Deleted then
         begin
         Result.Outcome := doRetry;
         Result.ErrorCode := 'INVALID_DELETE_RESPONSE';
         end;
      Exit;
      end;
   data := nil;
   previous := nil;
   attempted := False;
   try
      try
         data := GetJSON(UTF8Encode(aJob.Payload));
         if data.JSONType <> jtObject then
            begin
            raise EConvertError.Create('Expected contact object');
            end;
         body := TJSONObject(data);
         if aJob.ConfirmedPayload <> '' then
            begin
            previous := GetJSON(UTF8Encode(aJob.ConfirmedPayload));
            end;
         for i := body.Count - 1 downto 0 do
            begin
            oldValue := nil;
            if (previous <> nil) and (previous.JSONType = jtObject) then
               begin
               oldValue := TJSONObject(previous).Find(body.Names[i]);
               end;
            if body.Items[i].JSONType = jtNull then
               begin
               if (aJob.RemoteId <> '') and (oldValue <> nil) and
                  (oldValue.JSONType <> jtNull) then
                  begin
                  Result.ErrorCode := 'FIELD_CLEAR_UNSUPPORTED';
                  Exit;
                  end;
               body.Delete(i);
               end
            else if (aJob.RemoteId <> '') and (oldValue <> nil) and
                    (oldValue.AsJSON = body.Items[i].AsJSON) then
               begin
               (* PATCH only local changes, preserving unrelated edits made
                  in WRL. Same-field concurrent edits still need server support. *)
               body.Delete(i);
               end;
            end;
         body.Delete('logbookId');
         body.Delete('programId');
         if aJob.RemoteId = '' then
            begin
            method := 'POST';
            body.Add('logbookId', UTF8Encode(aJob.Key.Logbook));
            body.Add('programId', 'TR4W');
            end
         else
            begin
            method := 'PATCH';
            if body.Count = 0 then
               begin
               Result.Outcome := doConfirmed;
               Result.RemoteId := aJob.RemoteId;
               Exit;
               end;
            end;
         attempted := True;
         Result := Request(method, path, UTF8Decode(body.AsJSON));
         if (method = 'POST') and (Result.Outcome = doFailed) and
            (Result.ErrorCode = WRL_DUPLICATE_CODE) then
            begin
            (* WRL already holds this contact (a resync re-sent it): delivered,
               and no harm done (NY4I). Its id is not in the answer. *)
            Result.Outcome := doConfirmed;
            Result.ErrorCode := '';
            Result.RemoteId := WRL_DUPLICATE_MARKER;
            Result.RetrySeconds := 0;
            end;
         if (Result.Outcome = doConfirmed) and (method = 'POST') and
            (Result.RemoteId = '') then
            begin
            Result.Outcome := doUncertain;
            Result.ErrorCode := 'MISSING_CONTACT_ID';
            end;
      except
         on E: Exception do
            begin
            if attempted then
               begin
               if method = 'POST' then
                  begin
                  Result.Outcome := doUncertain;
                  end
               else
                  begin
                  Result.Outcome := doRetry;
                  end;
               Result.ErrorCode := 'DELIVERY_UNCONFIRMED';
               end
            else
               begin
               Result.Outcome := doFailed;
               Result.ErrorCode := 'INVALID_CONTACT_PAYLOAD';
               end;
            end;
      end;
   finally
      previous.Free;
      data.Free;
   end;
end;

constructor TWRLLogbook.Create(const aId, aName: string);
begin
   inherited Create;
   Id := aId;
   Name := aName;
end;

function TWRLLogbookList.IndexOfId(const aId: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to Count - 1 do
      begin
      if Items[i].Id = aId then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function WRLReadAccountId(aClient: TWRLClient; out aAccountId,
   aErrorCode: string): boolean;
var
   answer: TWRLResult;
   data: TJSONData;
begin
   Result := False;
   aAccountId := '';
   aErrorCode := '';
   try
      answer := aClient.Identity;
      if answer.Outcome <> doConfirmed then
         begin
         aErrorCode := answer.ErrorCode;
         Exit;
         end;
      data := GetJSON(UTF8Encode(answer.DataJSON));
      try
         if data.JSONType <> jtObject then
            begin
            raise EConvertError.Create('Expected account identity');
            end;
         aAccountId := TJSONObject(data).Get('uid', UnicodeString(''));
      finally
         data.Free;
      end;
      if aAccountId = '' then
         begin
         aErrorCode := 'MISSING_ACCOUNT_ID';
         Exit;
         end;
      Result := True;
   except
      on E: Exception do
         begin
         aAccountId := '';
         aErrorCode := 'INVALID_RESPONSE';
         end;
   end;
end;

function WRLReadLogbooks(aClient: TWRLClient; const aBooks: TWRLLogbookList;
   out aErrorCode: string; aStop: TWRLStopCheck): boolean;
var
   answer: TWRLResult;
   data, item: TJSONData;
   cursor: string;
   i, pages: integer;
begin
   Result := False;
   aErrorCode := '';
   cursor := '';
   pages := 0;
   try
      repeat
         if Assigned(aStop) and aStop() then
            begin
            aErrorCode := 'CANCELLED';
            Exit;
            end;
         answer := aClient.Logbooks(cursor);
         if answer.Outcome <> doConfirmed then
            begin
            aErrorCode := answer.ErrorCode;
            Exit;
            end;
         data := GetJSON(UTF8Encode(answer.DataJSON));
         try
            if data.JSONType <> jtArray then
               begin
               raise EConvertError.Create('Expected logbooks');
               end;
            for i := 0 to data.Count - 1 do
               begin
               item := data.Items[i];
               if item.JSONType <> jtObject then
                  begin
                  raise EConvertError.Create('Expected logbook');
                  end;
               if TJSONObject(item).Get('isLocked', False) then
                  begin
                  Continue;
                  end;
               aBooks.Add(TWRLLogbook.Create(
                  TJSONObject(item).Get('id', UnicodeString('')),
                  TJSONObject(item).Get('name', UnicodeString(''))));
               end;
         finally
            data.Free;
         end;
         Inc(pages);
         if ((answer.NextCursor = cursor) and (cursor <> '')) or (pages > 100) then
            begin
            aErrorCode := 'INVALID_PAGINATION';
            Exit;
            end;
         cursor := answer.NextCursor;
      until cursor = '';
      Result := True;
   except
      on E: Exception do
         begin
         aErrorCode := 'INVALID_RESPONSE';
         end;
   end;
end;

(* The text of one JSON member, '' when it is absent or not a string. *)
function JSONMemberText(aObject: TJSONObject; const aName: string): string;
var
   item: TJSONData;
begin
   Result := '';
   item := aObject.Find(AnsiString(aName));
   if (item <> nil) and (item.JSONType = jtString) then
      begin
      Result := UTF8Decode(item.AsString);
      end;
end;

(* WRL's own text is shown to the operator and logged, so it is bounded, and a
   value that holds the key (an echo) is dropped whole. *)
function SafeServerText(const aText, aApiKey: string; aMax: integer): string;
begin
   Result := aText;
   if (aApiKey <> '') and (Pos(aApiKey, Result) > 0) then
      begin
      Result := '';
      end;
   if Length(Result) > aMax then
      begin
      Result := Copy(Result, 1, aMax);
      end;
end;

(* A UUID's alphabet, the same rule Deliver applies to a contact id: the id is
   stored in a setting and later put in a request body, so it must not carry
   anything but what a UUID does. *)
function LooksLikeWRLId(const aId: string): boolean;
var
   i: integer;
begin
   Result := (aId <> '') and (Length(aId) <= 64);
   for i := 1 to Length(aId) do
      begin
      if not CharInSet(aId[i], ['0'..'9', 'a'..'f', 'A'..'F', '-']) then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

function WRLCreateLogbookBody(const aName, aCallSign: string; out aBody,
   aErrorCode: string): boolean;
var
   body: TJSONObject;
   name, call: string;
begin
   Result := False;
   aBody := '';
   aErrorCode := '';
   name := Trim(aName);
   if name = '' then
      begin
      aErrorCode := 'NAME_REQUIRED';
      Exit;
      end;
   if Length(name) > WRL_LOGBOOK_NAME_MAX then
      begin
      aErrorCode := 'NAME_TOO_LONG';
      Exit;
      end;
   call := Trim(aCallSign);
   body := TJSONObject.Create;
   try
      body.Add('name', UTF8Encode(name));
      if (call <> '') and (Length(call) <= WRL_CALLSIGN_MAX) then
         begin
         body.Add('defaultCallSign', UTF8Encode(call));
         end;
      aBody := UTF8Decode(body.AsJSON);
   finally
      body.Free;
   end;
   Result := True;
end;

function WRLDecodeCreateLogbook(aStatus: integer; const aResponse,
   aApiKey: string): TWRLCreateLogbookResult;
var
   root, data, error: TJSONData;
   id: string;
   twoXX: boolean;
begin
   Result := Default(TWRLCreateLogbookResult);
   Result.Status := aStatus;
   twoXX := (aStatus >= 200) and (aStatus < 300);
   root := nil;
   try
      try
         root := GetJSON(UTF8Encode(aResponse));
         if root.JSONType <> jtObject then
            begin
            raise EConvertError.Create('Expected response envelope');
            end;
         data := TJSONObject(root).Find('data');
         error := TJSONObject(root).Find('error');
         if twoXX and ((error = nil) or (error.JSONType = jtNull)) and
            (data <> nil) and (data.JSONType = jtObject) then
            begin
            id := JSONMemberText(TJSONObject(data), 'id');
            if id = '' then
               begin
               Result.ErrorCode := 'MISSING_LOGBOOK_ID';
               Result.Uncertain := True;
               end
            else if not LooksLikeWRLId(id) then
               begin
               Result.ErrorCode := 'INVALID_LOGBOOK_ID';
               Result.Uncertain := True;
               end
            else
               begin
               Result.Ok := True;
               Result.LogbookId := id;
               Result.Name := SafeServerText(JSONMemberText(TJSONObject(data),
                  'name'), aApiKey, WRL_LOGBOOK_NAME_MAX);
               end;
            Exit;
            end;
         (* Not a success. A 2xx that is not the success envelope may still have
            created the logbook; a 5xx may have; a 4xx never did. *)
         Result.Uncertain := twoXX or (aStatus >= 500);
         Result.ErrorCode := 'HTTP_' + IntToStr(aStatus);
         if (error <> nil) and (error.JSONType = jtObject) then
            begin
            id := SafeServerText(JSONMemberText(TJSONObject(error), 'code'),
               aApiKey, 100);
            if id <> '' then
               begin
               Result.ErrorCode := id;
               end;
            Result.ErrorMessage := SafeServerText(JSONMemberText(
               TJSONObject(error), 'message'), aApiKey, 300);
            Result.ErrorField := SafeServerText(JSONMemberText(
               TJSONObject(error), 'field'), aApiKey, 100);
            Result.ErrorHint := SafeServerText(JSONMemberText(
               TJSONObject(error), 'hint'), aApiKey, 300);
            Result.RequestId := SafeServerText(JSONMemberText(
               TJSONObject(error), 'requestId'), aApiKey, 100);
            end;
         if (aStatus = 429) and (Copy(Result.ErrorCode, 1, 5) = 'HTTP_') then
            begin
            Result.ErrorCode := 'RATE_LIMITED';
            end;
      except
         on E: Exception do
            begin
            (* Not JSON, or not the envelope. The exception text is not kept. *)
            Result := Default(TWRLCreateLogbookResult);
            Result.Status := aStatus;
            Result.ErrorCode := 'INVALID_RESPONSE';
            Result.Uncertain := twoXX or (aStatus >= 500);
            end;
      end;
   finally
      root.Free;
   end;
end;

function WRLCreateLogbookText(const aResult: TWRLCreateLogbookResult): string;
var
   code: string;
begin
   code := aResult.ErrorCode;
   if aResult.Uncertain then
      begin
      Result := SWRLCreateUncertain;
      end
   else if (code = 'NAME_REQUIRED') then
      begin
      Result := SWRLWhyNameRequired;
      end
   else if (code = 'NAME_TOO_LONG') then
      begin
      Result := UnicodeFormat(SWRLWhyNameTooLong, [WRL_LOGBOOK_NAME_MAX]);
      end
   else if (code = 'API_KEY_REQUIRED') or (code = 'MISSING_CREDENTIALS') or
           (code = 'INVALID_KEY') or (code = 'KEY_REVOKED') or
           (code = 'HTTP_401') then
      begin
      Result := SWRLWhyKey;
      end
   else if code = 'MEMBERSHIP_REQUIRED' then
      begin
      Result := SWRLWhyMembership;
      end
   else if (code = 'INSUFFICIENT_SCOPE') or (code = 'HTTP_403') then
      begin
      Result := SWRLWhyScope;
      end
   else if code = 'IP_NOT_ALLOWED' then
      begin
      Result := SWRLWhyIp;
      end
   else if (code = 'LOGBOOK_NOT_EMPTY') or (code = 'CONFLICT') or
           (code = 'HTTP_409') then
      begin
      Result := SWRLWhyConflict;
      end
   else if (code = 'VALIDATION_ERROR') or (code = 'MALFORMED_JSON') or
           (code = 'PAYLOAD_TOO_LARGE') then
      begin
      if aResult.ErrorField <> '' then
         begin
         Result := UnicodeFormat(SWRLWhyValidationField,
            [aResult.ErrorField, aResult.ErrorMessage]);
         end
      else
         begin
         Result := UnicodeFormat(SWRLWhyValidation, [aResult.ErrorMessage]);
         end;
      end
   else if code = 'RATE_LIMITED' then
      begin
      Result := SWRLWhyRate;
      end
   else if (code = 'API_DISABLED') or (code = 'POLICY_UNAVAILABLE') or
           (code = 'INTERNAL_ERROR') then
      begin
      Result := UnicodeFormat(SWRLWhyDown, [code]);
      end
   else
      begin
      Result := UnicodeFormat(SWRLWhyOther, [code]);
      end;
   if (aResult.ErrorHint <> '') and (not aResult.Uncertain) then
      begin
      Result := Result + ' ' + aResult.ErrorHint;
      end;
   if aResult.RequestId <> '' then
      begin
      Result := Result + ' ' + UnicodeFormat(SWRLRequestId, [aResult.RequestId]);
      end;
end;

type
   TWRLCreateTicket = class(TInterfacedObject, IWRLCreateTicket)
   private
      FLock: TCriticalSection;
      FFinished: boolean;
      FAnswer: TWRLCreateLogbookResult;
   public
      constructor Create;
      destructor Destroy; override;
      function Finished: boolean;
      function Answer: TWRLCreateLogbookResult;
      procedure Complete(const aAnswer: TWRLCreateLogbookResult);
   end;

   TWRLCreateThread = class(TThread)
   private
      FApiKey, FName, FCallSign, FKnownAccount, FDestination: string;
      FVerify: boolean;
      (* The counted reference that keeps the ticket alive while the thread
         runs, whatever the starter does. *)
      FTicket: IWRLCreateTicket;
      FTarget: TWRLCreateTicket;
   protected
      procedure Execute; override;
   public
      constructor Create(const aApiKey, aName, aCallSign, aKnownAccount,
         aDestination: string; aVerify: boolean; aTicket: TWRLCreateTicket);
   end;

constructor TWRLCreateTicket.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
end;

destructor TWRLCreateTicket.Destroy;
begin
   FLock.Free;
   inherited Destroy;
end;

function TWRLCreateTicket.Finished: boolean;
begin
   FLock.Enter;
   try
      Result := FFinished;
   finally
      FLock.Leave;
   end;
end;

function TWRLCreateTicket.Answer: TWRLCreateLogbookResult;
begin
   FLock.Enter;
   try
      Result := FAnswer;
   finally
      FLock.Leave;
   end;
end;

procedure TWRLCreateTicket.Complete(const aAnswer: TWRLCreateLogbookResult);
begin
   FLock.Enter;
   try
      FAnswer := aAnswer;
      FFinished := True;
   finally
      FLock.Leave;
   end;
end;

constructor TWRLCreateThread.Create(const aApiKey, aName, aCallSign,
   aKnownAccount, aDestination: string; aVerify: boolean; aTicket: TWRLCreateTicket);
begin
   inherited Create(True);
   FreeOnTerminate := True;
   FApiKey := aApiKey;
   FName := aName;
   FCallSign := aCallSign;
   FKnownAccount := aKnownAccount;
   FDestination := aDestination;
   FVerify := aVerify;
   FTarget := aTicket;
   FTicket := aTicket;
end;

procedure TWRLCreateThread.Execute;
var
   client: TWRLClient;
   answer: TWRLCreateLogbookResult;
   account, code: string;
begin
   (* CreateLogbook never raises; the guard is for the last line of defence,
      because a thread that lets one escape ends the program. *)
   answer := Default(TWRLCreateLogbookResult);
   try
      client := TWRLClient.Create(FApiKey);
      try
         client.VerifyServer := FVerify;
         client.Destination := FDestination;
         answer := client.CreateLogbook(FName, FCallSign);
         if answer.Ok and (FKnownAccount = '') then
            begin
            (* The definition has no account id yet (a key never refreshed in
               the editor): it is the key's own uid, read now so the saved
               definition is complete. A failure here leaves it '' and the
               editor's Refresh derives it later. *)
            if WRLReadAccountId(client, account, code) then
               begin
               answer.AccountId := account;
               end;
            end;
      finally
         client.Free;
      end;
   except
      on E: Exception do
         begin
         if not answer.Ok then
            begin
            answer := Default(TWRLCreateLogbookResult);
            answer.Uncertain := True;
            answer.ErrorCode := 'DELIVERY_UNCONFIRMED';
            end;
         end;
   end;
   FTarget.Complete(answer);
end;

function StartWRLCreateLogbook(const aApiKey, aName, aCallSign, aKnownAccount,
   aDestination: string; aVerifyServer: boolean): IWRLCreateTicket;
var
   ticket: TWRLCreateTicket;
   worker: TWRLCreateThread;
begin
   ticket := TWRLCreateTicket.Create;
   Result := ticket;   (* the first count; the thread takes a second *)
   worker := TWRLCreateThread.Create(aApiKey, aName, aCallSign, aKnownAccount,
      aDestination, aVerifyServer, ticket);
   worker.Start;
end;

end.
