unit uTestFakeTransport;
{$I ..\..\src\tr4w.inc}
(*
  A TRANSPORT THAT REPLAYS A SCRIPTED ANSWER (docs/HTTP_TRANSPORT_DESIGN.md,
  section 5).

  It records the request it was given -- as a COPY, because the shared layer
  frees the wire request when Execute returns -- and answers with whatever the
  test scripted: a failure kind, a status, a body, a message that echoes a
  secret. No network, no OpenSSL, no machine dependence. A caller test installs
  it with SetHttpTransportForTest and puts the real one back afterwards.
*)

interface

uses
   Classes, SysUtils, uHttpTransport;

type
   TFakeHttpTransport = class(TPlatformHttpTransport)
   public
      (* what the test scripts *)
      ScriptFailure:      THttpFailure;
      ScriptErrorClass:   string;
      ScriptErrorMessage: string;
      ScriptStatus:       integer;
      ScriptStatusText:   string;
      ScriptRetryAfter:   string;
      ScriptRequestId:    string;
      ScriptETag:         string;
      ScriptLastModified: string;
      ScriptContentType:  string;
      ScriptFinalURL:     string;
      ScriptBody:        RawByteString;
      ScriptLocation:    string;
      (* A DIFFERENT answer for every call after the first (issue 255 follow-up:
        the repeat of a redirected POST). Used only when HasFollowUp. *)
      HasFollowUp:         boolean;
      FollowUpFailure:     THttpFailure;
      FollowUpStatus:      integer;
      FollowUpLocation:    string;
      FollowUpBody:        RawByteString;
      (* what the transport saw *)
      Urls:    TStringList;   (* the URL of every call, in order *)
      Calls:   integer;
      Last:    THttpWireRequest;
      LastHadSink: boolean;
      constructor Create;
      destructor Destroy; override;
      class function Id: string; override;
      function Available(out aWhy: string): boolean; override;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

   (* Two classes for the registry tests: a platform transport that cannot work
     here, and one that can. *)
   TFakeUnavailablePlatform = class(TPlatformHttpTransport)
   public
      class function Id: string; override;
      function Available(out aWhy: string): boolean; override;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

   TFakeAvailablePlatform = class(TPlatformHttpTransport)
   public
      class function Id: string; override;
      function Available(out aWhy: string): boolean; override;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

(* Certificate checking ON, as an operator's default, so an https request reaches
  the scripted transport instead of being decided by this machine. Several older
  suites carry a private copy of this; new suites call this one. *)
procedure DeclareCertificateChecking;

implementation

uses
   uSettingsRegistry, uSettingsDeclarations;

procedure DeclareCertificateChecking;
var
   setting: TSettingBase;
begin
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
end;

constructor TFakeHttpTransport.Create;
begin
   inherited Create;
   Last := THttpWireRequest.Create;
   Urls := TStringList.Create;
end;

destructor TFakeHttpTransport.Destroy;
begin
   Urls.Free;
   Last.Free;
   inherited Destroy;
end;

class function TFakeHttpTransport.Id: string;
begin
   Result := 'fake';
end;

function TFakeHttpTransport.Available(out aWhy: string): boolean;
begin
   aWhy   := '';
   Result := True;
end;

procedure TFakeHttpTransport.Execute(aRequest: THttpWireRequest; aSink: TStream;
                                     aResult: THttpWireResult);
begin
   Inc(Calls);
   Urls.Add(aRequest.URL);
   LastHadSink := aSink <> nil;
   Last.Method           := aRequest.Method;
   Last.URL              := aRequest.URL;
   Last.UserAgent        := aRequest.UserAgent;
   Last.ContentType      := aRequest.ContentType;
   Last.AcceptEncoding   := aRequest.AcceptEncoding;
   Last.IfNoneMatch      := aRequest.IfNoneMatch;
   Last.IfModifiedSince  := aRequest.IfModifiedSince;
   Last.Username         := aRequest.Username;
   Last.Password         := aRequest.Password;
   Last.BearerToken      := aRequest.BearerToken;
   Last.Body             := aRequest.Body;
   Last.HasBody          := aRequest.HasBody;
   Last.FollowRedirects  := aRequest.FollowRedirects;
   Last.VerifyServer     := aRequest.VerifyServer;
   Last.AcceptAnyStatus  := aRequest.AcceptAnyStatus;
   Last.ConnectMs        := aRequest.ConnectMs;
   Last.IOMs             := aRequest.IOMs;
   Last.MaxResponseBytes := aRequest.MaxResponseBytes;

   aResult.Clear;
   aResult.Failure      := ScriptFailure;
   aResult.ErrorClass   := ScriptErrorClass;
   aResult.ErrorMessage := ScriptErrorMessage;
   aResult.StatusCode   := ScriptStatus;
   aResult.StatusText   := ScriptStatusText;
   aResult.RetryAfter   := ScriptRetryAfter;
   aResult.RequestId    := ScriptRequestId;
   aResult.ETag         := ScriptETag;
   aResult.LastModified := ScriptLastModified;
   aResult.ContentType  := ScriptContentType;
   aResult.FinalURL     := ScriptFinalURL;
   aResult.Location     := ScriptLocation;
   if HasFollowUp and (Calls >= 2) then
      begin
      aResult.Failure    := FollowUpFailure;
      aResult.StatusCode := FollowUpStatus;
      aResult.Location   := FollowUpLocation;
      if (FollowUpFailure = hfNone) and (FollowUpBody <> '') then
         begin
         aResult.Body := FollowUpBody;
         end;
      Exit;
      end;
   if (ScriptFailure = hfNone) and (ScriptBody <> '') then
      begin
      if aSink <> nil then
         begin
         aSink.WriteBuffer(ScriptBody[1], Length(ScriptBody));
         end
      else
         begin
         aResult.Body := ScriptBody;
         end;
      end;
end;

class function TFakeUnavailablePlatform.Id: string;
begin
   Result := 'fake-unavailable';
end;

function TFakeUnavailablePlatform.Available(out aWhy: string): boolean;
begin
   aWhy   := 'test-only: this platform transport cannot start';
   Result := False;
end;

procedure TFakeUnavailablePlatform.Execute(aRequest: THttpWireRequest; aSink: TStream;
                                           aResult: THttpWireResult);
begin
   aResult.Clear;
   aResult.Failure := hfOther;
end;

class function TFakeAvailablePlatform.Id: string;
begin
   Result := 'fake-available';
end;

function TFakeAvailablePlatform.Available(out aWhy: string): boolean;
begin
   aWhy   := '';
   Result := True;
end;

procedure TFakeAvailablePlatform.Execute(aRequest: THttpWireRequest; aSink: TStream;
                                         aResult: THttpWireResult);
begin
   aResult.Clear;
end;

end.
