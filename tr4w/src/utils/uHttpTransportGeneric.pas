unit uHttpTransportGeneric;
{$I ..\tr4w.inc}   // relative: this unit lives in src\utils, the include in src
(*
  THE GENERIC TRANSPORT: FPC'S CLIENT OVER OPENSSL, ON EVERY PLATFORM.

  This is what uHTTPDownload used to do itself, moved here whole and unchanged
  (issue 224, stage S1a): TFPHTTPClient, the OpenSSL loader, and verification
  against the shipped cacert.pem through uTLSTrust. It is the fallback, the
  Linux transport and the one the unit tests pin. It decides NO POLICY: the
  shared layer has already vetted the scheme and the bearer token and has
  decided whether checking is wanted (VerifyServer); this unit applies it.

  THE TRANSPORT IS FPC'S CLIENT, NOT INDY, AND ONLY HERE.

  This code used TIdHTTP with TIdSSLIOHandlerSocketOpenSSL. On Linux that could
  not fetch anything over TLS, and the reason is not fixable from here: Indy
  10.6.3.3 FINDS OpenSSL 3 and then refuses it --

      Unsupported SSL Library version: 300000D0

  -- a hard version gate, measured on the runner with and without the library
  name made resolvable, identical both ways. Lifting it means Indy PR #529:
  unmerged, and it replaces the whole 22,000-line headers unit.

  Measured on the same box, same URL, same minute:

      Indy, OpenSSL 3                      FAIL, could not load SSL library
      Indy, name made resolvable           FAIL, same version gate
      fphttpclient + opensslsockets        OK, 105,954 bytes

  ONE IMPLEMENTATION, NOT A PER-PLATFORM SPLIT. Windows was never broken, but
  it takes this path too: FPC's loader looks for ssleay32.dll and libeay32.dll,
  which is exactly the pair the installer already ships, verified 2026-09-09.
  INDY IS NOT BEING REPLACED: it keeps the DX cluster, the multi-op link and
  every socket it already owns.

  WHAT THIS TRANSPORT CAN AND CANNOT PROVE. It reports a failure kind that
  means "nothing was sent" in exactly two places: OpenSSL cannot load
  (hfTlsUnavailable) and verification cannot be set up before the connection
  (hfTrustUnavailable, hfVerificationUnavailable). Everything raised once the
  client is moving is hfOther, hfTlsLibraryFault or hfResponseTooLarge, which are
  "may have been sent": FPC's client gives no way to tell a refused connection
  from a reset one, and a certificate OpenSSL itself rejects fails inside the
  handshake where VerifyCertificate is never reached (uTLSTrust, 606-621). A
  platform transport that gets a distinct error can prove more.

  IT NEVER LOGS A URL OR AN EXCEPTION MESSAGE (design 3.1): both go back in the
  result and the shared layer scrubs them.
*)

interface

uses
   Classes, uHttpTransport;

type
   TGenericHttpTransport = class(TPlatformHttpTransport)
   public
      class function Id: string; override;
      function Available(out aWhy: string): boolean; override;
      procedure Execute(aRequest: THttpWireRequest; aSink: TStream;
                        aResult: THttpWireResult); override;
   end;

implementation

uses
   SysUtils,
   fphttpclient,      (* FPC's own client *)
   opensslsockets,    (* registers the TLS handler fphttpclient asks for *)
   uOpenSSLLoader,
   uTLSTrust;

type
   (* The collected response, with a size cap. Exceeded is set BEFORE the raise,
     so Execute can tell a cap from any other stream error. *)
   TBoundedHttpResponse = class(TRawByteStringStream)
   public
      Limit:    Int64;
      Exceeded: boolean;
      function Write(const Buffer; Count: LongInt): LongInt; override;
   end;

function TBoundedHttpResponse.Write(const Buffer; Count: LongInt): LongInt;
begin
   if (Limit > 0) and (Int64(Count) > Limit - Position) then
      begin
      Exceeded := True;
      raise EStreamError.Create('HTTP response exceeds the configured size limit');
      end;
   Result := inherited Write(Buffer, Count);
end;

class function TGenericHttpTransport.Id: string;
begin
   Result := 'generic';
end;

function TGenericHttpTransport.Available(out aWhy: string): boolean;
begin
   (* Always selectable. Whether OpenSSL loads is decided PER REQUEST, and a
     request that cannot be made says so (hfTlsUnavailable) -- the loader on
     Windows retries a failed load after 30 s, so "unavailable" is not a
     property of the machine for the session. *)
   aWhy   := '';
   Result := True;
end;

procedure TGenericHttpTransport.Execute(aRequest: THttpWireRequest; aSink: TStream;
                                        aResult: THttpWireResult);
var
   http:    TFPHTTPClient;
   useTLS:  boolean;
   why:     string;
   bodyIn:  TRawByteStringStream;
   bodyOut: TBoundedHttpResponse;
   dest:    TStream;
begin
   aResult.Clear;
   bodyIn  := nil;
   bodyOut := nil;

   useTLS := IsHttpsUrl(aRequest.URL);

   (* OpenSSL must load before anything else means anything. The loader knows
     WHICH library it found or could not find, and that sentence is what the
     operator needs. *)
   if useTLS and (not EnsureOpenSSL) then
      begin
      aResult.Failure      := hfTlsUnavailable;
      aResult.ErrorMessage := OpenSSLDiagnostic;
      Exit;
      end;

   http := TFPHTTPClient.Create(nil);
   try
      http.AllowRedirect   := aRequest.FollowRedirects;
      http.AddHeader('User-Agent', ToWire(aRequest.UserAgent));
      http.ConnectTimeout  := aRequest.ConnectMs;
      http.IOTimeout       := aRequest.IOMs;

      if useTLS and aRequest.VerifyServer then
         begin
         (* FAIL CLOSED: the operator asked for verification and it cannot be
           provided, so the request is not made. OpenSSL loaded (checked
           above), so the refusal is the bundle or an OpenSSL too old to check
           a host name; only the first is a trust-source problem. *)
         if not UseVerifiedTLS(http, why) then
            begin
            if TrustBundleUsable then
               begin
               aResult.Failure := hfVerificationUnavailable;
               end
            else
               begin
               aResult.Failure := hfTrustUnavailable;
               end;
            aResult.ErrorMessage := why;
            Exit;
            end;
         end;

      if aRequest.ContentType <> '' then
         begin
         http.AddHeader('Content-Type', ToWire(aRequest.ContentType));
         end;
      if aRequest.BearerToken <> '' then
         begin
         http.AddHeader('Authorization', ToWire('Bearer ' + aRequest.BearerToken));
         end;
      if aRequest.AcceptEncoding <> '' then
         begin
         http.AddHeader('Accept-Encoding', ToWire(aRequest.AcceptEncoding));
         end;
      if aRequest.Username <> '' then
         begin
         (* FPC sends basic auth from these two, preemptively. *)
         http.UserName := ToWire(aRequest.Username);
         http.Password := ToWire(aRequest.Password);
         end;

      if aRequest.HasBody then
         begin
         bodyIn := TRawByteStringStream.Create(aRequest.Body);
         end;
      if aSink <> nil then
         begin
         dest := aSink;
         end
      else
         begin
         bodyOut       := TBoundedHttpResponse.Create('');
         bodyOut.Limit := aRequest.MaxResponseBytes;
         dest          := bodyOut;
         end;

      try
         try
            http.RequestBody := bodyIn;
            if aRequest.AcceptAnyStatus then
               begin
               http.HTTPMethod(ToWire(aRequest.Method), ToWire(aRequest.URL), dest, []);
               end
            else
               begin
               (* Only 200 is an answer. FPC raises for any other status BEFORE
                 it follows a redirect: this is exactly what Get does, kept so
                 that moving the code changed nothing. *)
               http.HTTPMethod(ToWire(aRequest.Method), ToWire(aRequest.URL), dest, [200]);
               end;
            aResult.StatusCode := http.ResponseStatusCode;
            aResult.StatusText := FromWire(http.ResponseStatusText);
            aResult.RetryAfter := FromWire(http.GetHeader(http.ResponseHeaders, 'Retry-After'));
            aResult.RequestId  := FromWire(http.GetHeader(http.ResponseHeaders, 'X-Request-Id'));
            if bodyOut <> nil then
               begin
               aResult.Body := bodyOut.DataString;
               end;
         except
            on E: Exception do
               begin
               (* The status is recorded anyway (0 when the server never
                 answered), so a caller can tell "the server said no" from "the
                 server was not there". *)
               aResult.StatusCode   := http.ResponseStatusCode;
               aResult.ErrorClass   := E.ClassName;
               aResult.ErrorMessage := E.Message;
               if (bodyOut <> nil) and bodyOut.Exceeded then
                  begin
                  aResult.Failure := hfResponseTooLarge;
                  end
               else if (E is EInOutError) and (Pos('OpenSSL', E.Message) > 0) then
                  begin
                  (* The library would not initialise once bytes were moving:
                    NOT a proof that nothing was sent. *)
                  aResult.Failure := hfTlsLibraryFault;
                  end
               else
                  begin
                  aResult.Failure := hfOther;
                  end;
               end;
         end;
      finally
         (* Clear the reference before the stream dies: the client does not own
           what it was handed. *)
         http.RequestBody := nil;
         bodyOut.Free;
         bodyIn.Free;
      end;
   finally
      http.Free;
   end;
end;

initialization
   RegisterHttpTransport(TGenericHttpTransport, False);

end.
