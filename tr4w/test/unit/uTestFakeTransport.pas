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
      (* what the transport saw *)
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

implementation

constructor TFakeHttpTransport.Create;
begin
   inherited Create;
   Last := THttpWireRequest.Create;
end;

destructor TFakeHttpTransport.Destroy;
begin
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
