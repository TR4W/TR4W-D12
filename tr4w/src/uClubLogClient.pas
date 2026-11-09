unit uClubLogClient;
{$I tr4w.inc}
interface
uses uExternalDeliveryClient, uExternalDelivery, uHTTPDownload;
type
   TClubLogClient = class(TExternalDeliveryClient)
   private
      FCall, FToken: string;
      function Request(const aMethod, aPath, aBody: string): TExternalDeliveryResult;
   protected
      function NewRequest: THttpRequest; virtual;
   public
      constructor Create(const aCall, aToken: string);
      function RecoverUpdatesAsUncertain: boolean; override;
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; override;
   end;
implementation
uses SysUtils, fpjson, uJSON;
const
   // Local delivery marker, never a Club Log qsoid or part of an API path.
   CLUBLOG_TEST_DELIVERY = 'clublog:test-mode';

function ValidQsoId(const aValue: string): boolean;
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

function TClubLogClient.RecoverUpdatesAsUncertain: boolean;
begin
   // A replacement may have created a new qsoid before the process stopped.
   Result := True;
end;

constructor TClubLogClient.Create(const aCall, aToken: string);
begin
   inherited Create;
   FCall := aCall;
   FToken := aToken;
end;

function TClubLogClient.NewRequest: THttpRequest;
begin
   Result := THttpRequest.Create('https://clublog.org/api/v1/qso');
end;

function TClubLogClient.Request(const aMethod, aPath, aBody: string): TExternalDeliveryResult;
var
   request: THttpRequest;
   root, value: TJSONData;
   status, message: string;
   testMode: boolean;
begin
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doUncertain;
   Result.Pause := True;
   Result.ErrorCode := 'CLUBLOG_RESPONSE_REQUIRES_REVIEW';
   request := NewRequest;
   try
      StampRequest(request);
      request.URL := 'https://clublog.org/api/v1' + aPath;
      request.Method := aMethod;
      request.Body := aBody;
      request.ContentType := 'application/json';
      request.BearerToken := FToken;
      request.UserAgent := 'TR4W';
      request.FollowRedirects := False;
      request.ConnectMs := 5000;
      request.IOMs := 10000;
      request.MaxResponseBytes := 4096;
      request.Send;
      Result.Status := request.StatusCode;
      if ApplyNothingSent(request, 'CLUBLOG_', 'Club Log', Result) then
         begin
         (* NO BYTE WAS SENT, PROVED (THttpRequest.NothingSent): TLS could not
           start, the CA bundle is missing, verification could not be set up,
           or the request was refused by policy before it was made. None of
           those is "uncertain / requires review"; ApplyNothingSent says which
           retry or failure each one is, and the diagnostic text was written
           once by uHTTPDownload. *)
         Exit;
         end;
      if ApplyRateLimited(request, 'CLUBLOG_', Result) then
         begin
         Exit;
         end;
      if (Result.Status = 401) or (Result.Status = 403) or
         (Result.Status = 404) or (Result.Status = 409) or (Result.Status = 422) then
         begin
         Result.Outcome := doFailed;
         Result.ErrorCode := 'CLUBLOG_HTTP_' + string(IntToStr(Result.Status));
         Exit;
         end;
      if not (Result.Status in [200, 201]) then
         begin
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
            value := TJSONObject(root).Find('test_mode');
            testMode := (value <> nil) and (value.JSONType = jtBoolean) and value.AsBoolean;
            status := JSONGetStr(TJSONObject(root), 'status', '');
            message := LowerCase(JSONGetStr(TJSONObject(root), 'message', ''));
            if Pos('dropped', message) > 0 then
               begin
               Result.Outcome := doFailed;
               Result.ErrorCode := 'CLUBLOG_QSO_DROPPED';
               Exit;
               end;
            if (aMethod = 'DELETE') and (Result.Status = 200) and (status = 'deleted') then
               begin
               Result.Outcome := doConfirmed;
               Result.Deleted := True;
               Result.Pause := False;
               Result.ErrorCode := '';
               Exit;
               end;
            if (aMethod = 'POST') and
               (((Result.Status = 201) and (status = 'created')) or
                ((Result.Status = 200) and ((status = 'duplicate') or (status = 'updated')))) then
               begin
               value := TJSONObject(root).Find('qsoid');
               if testMode and (value <> nil) and (value.JSONType = jtNull) then
                  begin
                  Result.RemoteId := CLUBLOG_TEST_DELIVERY;
                  Result.Outcome := doConfirmed;
                  Result.Pause := False;
                  Result.ErrorCode := '';
                  end
               else if (value <> nil) and (value.JSONType = jtNumber) and
                  ValidQsoId(UTF8Decode(value.AsJSON)) then
                  begin
                  Result.RemoteId := UTF8Decode(value.AsJSON);
                  Result.Outcome := doConfirmed;
                  Result.Pause := False;
                  Result.ErrorCode := '';
                  end
               else
                  begin
                  Result.ErrorCode := 'CLUBLOG_QSOID_REQUIRED';
                  end;
               end;
         except
            on E: Exception do
               begin
               Result.ErrorCode := 'CLUBLOG_INVALID_RESPONSE';
               end;
         end;
      finally
         root.Free;
      end;
   finally
      request.Free;
   end;
end;

function TClubLogClient.Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult;
var
   body: TJSONObject;
begin
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doFailed;
   Result.Pause := True;
   if aJob.Deleted and ((aJob.RemoteId = '') or
      (aJob.RemoteId = CLUBLOG_TEST_DELIVERY)) then
      begin
      Result.Outcome := doConfirmed;
      Result.Pause := False;
      Exit;
      end;
   if (FCall = '') or (FToken = '') then
      begin
      Result.ErrorCode := 'CLUBLOG_SETUP_REQUIRED';
      Exit;
      end;
   if (aJob.RemoteId <> '') and (aJob.RemoteId <> CLUBLOG_TEST_DELIVERY) then
      begin
      if not ValidQsoId(aJob.RemoteId) then
         begin
         Result.ErrorCode := 'CLUBLOG_INVALID_QSOID';
         Exit;
         end;
      Result := Request('DELETE', '/qso/' + aJob.RemoteId, '');
      if (Result.Outcome <> doConfirmed) or aJob.Deleted then
         begin
         Exit;
         end;
      end;
   body := TJSONObject.Create;
   try
      body.Add('call', UTF8Encode(FCall));
      body.Add('adif', UTF8Encode(aJob.Payload));
      Result := Request('POST', '/qso', UTF8Decode(body.AsJSON));
      if (aJob.RemoteId <> '') and (aJob.RemoteId <> CLUBLOG_TEST_DELIVERY) and
         (Result.Outcome <> doConfirmed) then
         begin
         // The old QSO is gone. Do not replay the two-step replacement blindly.
         Result.Outcome := doUncertain;
         Result.Pause := True;
         Result.ErrorCode := 'CLUBLOG_REPLACEMENT_REQUIRES_REVIEW';
         end;
   finally
      body.Free;
   end;
end;
end.
