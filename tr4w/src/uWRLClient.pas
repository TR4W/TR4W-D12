unit uWRLClient;
{$I tr4w.inc}

interface

uses
   SysUtils, uHTTPDownload, uExternalDelivery;

type
   TWRLResult = record
      Outcome: TDeliveryOutcome;
      Status: integer;
      Deleted: boolean;
      RemoteId, ErrorCode, RequestId, DataJSON, NextCursor: string;
      RetrySeconds: Int64;
   end;

   (* Synchronous, worker-owned client. Owns no database, UI or live settings.
      Only the factory test seam replaces transport; production uses shared TLS. *)
   TWRLClient = class
   private
      FApiKey: string;
      function Request(const aMethod, aPath, aBody: string): TWRLResult;
   protected
      function NewRequest(const aURL: string): THttpRequest; virtual;
   public
      constructor Create(const aApiKey: string);
      function Identity: TWRLResult;
      function Logbooks(const aCursor: string = ''): TWRLResult;
      function CreateLogbook(const aName: string): TWRLResult;
      function Deliver(const aJob: TDeliveryJob): TWRLResult;
   end;

implementation

uses
   fpjson, uJSON, fphttpclient;

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
   if FApiKey = '' then
      begin
      Result.ErrorCode := 'API_KEY_REQUIRED';
      Exit;
      end;
   request := NewRequest(WRL_BASE + aPath);
   try
      request.Method := aMethod;
      request.Body := aBody;
      request.ContentType := 'application/json';
      request.BearerToken := FApiKey;
      request.FollowRedirects := False;
      request.ConnectMs := 5000;
      request.IOMs := 10000;
      sent := request.Send;
      Result.Status := request.StatusCode;
      Result.RequestId := request.RequestId;
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

function TWRLClient.CreateLogbook(const aName: string): TWRLResult;
var
   body: TJSONObject;
begin
   body := TJSONObject.Create;
   try
      body.Add('name', UTF8Encode(aName));
      Result := Request('POST', '/logbooks', UTF8Decode(body.AsJSON));
      if (Result.Outcome = doConfirmed) and (Result.RemoteId = '') then
         begin
         Result.Outcome := doUncertain;
         Result.ErrorCode := 'MISSING_LOGBOOK_ID';
         end;
   finally
      body.Free;
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

end.
