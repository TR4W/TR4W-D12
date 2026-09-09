{
 Copyright Thomas M. Schaefer, NY4I (c) 2020.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }
unit uSuperCheckPartialFileUpload;
{$I tr4w.inc}

interface


uses Classes, SysUtils, IdSSLOpenSSLHeaders, uSHA256, IdHTTP, IdGlobal, Log4D, uLogConfig,
     IdCoderMIME, IdSSLOpenSSL, IdIOHandler, IdIOHandlerSocket, IdLogFile, DateUtils;


const
   SCP_TESTURL = 'https://www.supercheckpartial.com/api/v1/testcabsubmit';
   //SCP_TESTURL = 'https://192.168.1.1';
   SCP_PRODURL = 'https://www.supercheckpartial.com/api/v1/cabsubmit';
   SCP_CANAME = 'Encrypt';

   

Type TSCPUpload = class(TObject)
   private
      m_loggerName: string;
      m_trace: boolean;
      m_loggerHash: string;
      m_production: boolean;
      m_timestamp: string;
      m_uploadURL: string;
      m_cabHash: string;
      m_cabEncoded: string;
      m_httpResult: string;
      m_errorResult: string;
      m_httpStatusCode: integer;
      m_JSON: string;
      indyLog: TIdLogFile;
      sslOpts: TIdSSLIOHandlerSocketOpenSSL;
      http: TIdHTTP;
      logger: TLogLogger;
      appender: TLogFileAppender;
      localLog: boolean;
      function GetLoggerName: string;
      procedure SetLoggerName(loggerName: string);
      function SSLIOHandlerVerifyPeer(ThePeerCert: TIdX509; AOk: Boolean; ADepth, AError: Integer): Boolean;


   public
      constructor Create(bProduction: boolean; FLogger: TLogLogger);
      destructor Destroy;
      function GetHashSHA256(_string: string): string;
      function GetHashSHA256File(_filename: string): string;
      function SendFile(_filename: string): boolean;
      Property loggerName: string read GetLoggerName write SetLoggerName;
      property httpStatusCode: integer read m_httpStatusCode;
      property errorResult: string read m_errorResult;
      property httpResult: string read m_httpResult;
      property trace: boolean read m_trace write m_trace;
   end;

implementation

constructor TSCPUpload.Create(bProduction: boolean; FLogger: TLogLogger);

begin
   Self.m_trace := false;
   IdSSLOpenSSLHeaders.Load();
   if FLogger = nil then
      begin
      appender := TLogRollingFileAppender.Create('name','scp.log');
      appender.Layout := CreateTR4WLogLayout;
      TLogBasicConfigurator.Configure(appender);
      //logLevels := llError; // For after we load config so we can set the value.
      //TLogLogger.GetRootLogger.Level := Error;
      logger := TLogLogger.GetLogger('SCPDebugLog');
      localLog := true;
      end
   else
      begin
      localLog := false;
      logger := FLogger;
      end;
   if bProduction then
      begin
      logger.Info('Calling supercheckpartial in production mode - %s',[SCP_PRODURL]);
      Self.m_production := true;
      Self.m_uploadURL := SCP_PRODURL;
      Self.m_timestamp := '2022-04-06 13:25:27';
      end
   else
      begin
      logger.Info('Calling supercheckpartial in test mode - %s',[SCP_TESTURL]);
      Self.m_uploadURL := SCP_TESTURL;
      Self.m_timestamp := '2022-04-01 00:01:02';
      m_production := false;
      end;
   (* STILL ON INDY, AND THEREFORE STILL BROKEN ON LINUX (2026-09-09).

     The other four HTTPS users moved to uHTTPDownload because Indy 10.6.3.3
     cannot speak to OpenSSL 3 -- it finds the library and refuses it,
     "Unsupported SSL Library version: 300000D0". This upload will fail the
     same way on any current Linux, and that is a known gap, not an oversight.

     IT WAS LEFT DELIBERATELY BECAUSE TWO THINGS HERE ARE NOT A TRANSPORT
     DETAIL:

       sslOpts.SSLOptions.VerifyMode := [sslvrfPeer] with OnVerifyPeer --
       this is the only HTTPS caller in the program that verifies the server's
       certificate and inspects the result itself. Moving it without working
       out the equivalent would mean quietly downgrading certificate checking
       on an upload that carries a shared secret, which is exactly the silent
       downgrade this codebase treats as a defect.

       TIdLogFile as an Intercept -- the wire log this unit writes when tracing
       is on has no direct counterpart in FPC's client.

     So this needs a decision about verification behaviour, not a search and
     replace. Until then it works on Windows, which is where SCP uploads are
     actually done, and reports a TLS failure on Linux. *)
   http := TIdHttp.Create(nil);
   http.HandleRedirects := true;
   http.Request.ContentType := 'application/json';
   http.Request.UserAgent := 'TR4W';
   http.Request.Accept := 'application/json';
   sslOpts := TIdSSLIOHandlerSocketOpenSSL.Create;
   sslOpts.SSLOptions.Method := TIdSSLVersion(sslvTLSv1_2);
   //sslOpts.SSLOptions.CertFile := 'cacert.pem';
   sslOpts.SSLOptions.VerifyMode := [sslvrfPeer];
   sslOpts.OnVerifyPeer := Self.SSLIOHandlerVerifyPeer;
   http.IOHandler := sslOpts;

   // Logging
   if Self.m_trace then
      begin
      indyLog := TIdLogFile.Create(nil);
      indyLog.Filename := 'indy.log';
      http.Intercept := indyLog;
      indyLog.Active := true;
      end;




end;

destructor TSCPUpload.Destroy;
begin
   if http <> nil then
      begin
      FreeAndNil(http);
      end;
  if sslOpts <> nil then
     begin
     FreeANdNil(sslOpts);
     end;
  if localLog then
     begin
     if logger <> nil then
        begin
        FreeAndNil(logger);
        end;
     if appender <> nil then
        begin
        FreeAndNil(appender);
        end;
     end;
end;

function TSCPUpload.SendFile(_filename: string): boolean;
var fs: TFileStream;
    ms: TMemoryStream;
    //s: string;
    httpResult: string;
    hash: string;
    json: TSTringStream;
   // response: TStringStream;
    sCabRaw: string;
begin
   //Result := false;
   // First check that the log file exists
   if not FileExists(_filename) then
      begin
      Result := false;
      self.m_errorResult := 'Request log file to send does not exist [' + _filename + ']';
      Exit;
      end;
   (* THE AVAILABILITY GATE IS GONE WITH THE DEPENDENCY IT GUARDED.

     It asked TIdHashSHA256.IsAvailable, which answers "has Indy loaded
     OpenSSL", and refused the whole upload when it had not. That is the
     dialog NY4I saw on Linux after writing a Cabrillo file. uSHA256 needs
     nothing loaded, so there is no longer a question to ask. *)

   // Store the hash of the CAB file
   Self.m_cabHash := Self.GetHashSHA256File(_filename);

   // Get the Base64 encoded value of file
   try
      fs:= TFileStream.Create(_filename, fmOpenRead);
      Self.m_cabEncoded := TIdEncoderMime.EncodeStream(fs);
   finally
      fs.Free;
   end;

   // Read the entire log into memory
   try
      ms := TMemoryStream.Create;
      ms.LoadFromFile(_filename);
      if ms.Size > 0 then
         begin
         SetLength(sCabRaw,ms.Size);
         Move(ms.Memory^,sCabRaw[1],ms.Size);
         end;
   finally
      if ms <> nil then
         begin
         ms.Free;
         end;
   end;



   // Set the logger name
   Self.loggerName := 'TR4W';  // Sets m_loggerHash too.


   // Set the hash-signature
   // Build the hash from the sharedSecret sha256[(m_credentials) and can (plain text)]
   hash := AnsiLowerCase(Self.GetHashSHA256(Self.m_loggerHash + sCabRaw));

   // Build the JSON
   Self.m_JSON := '{' +
                  '"Version": "1.0",' +
                  '"Logger": "' + Self.GetLoggerName + '",' +
                  '"Timestamp": "' + Self.m_timestamp + '",' +
                  '"Hash": "' + hash + '",' +
                  '"File": "' + Self.m_cabEncoded + '"' +
                  '}';
   json := TStringStream.Create(Self.m_JSON);
   try
      httpResult := Self.http.Post(Self.m_uploadURL, json);
      Self.m_httpResult := httpResult;
      Self.m_httpStatusCode := Self.http.ResponseCode;
      Result := Self.http.ResponseCode = 200;
   except
      on E: Exception do
         begin
         Result := false;
         Self.m_errorResult := '***ERROR*** ' + E.ClassName + ' ' + E.Message;
         end;
   end;
end;

function TSCPUpload.GetLoggerName: string;
begin
   Result := Self.m_loggerName;
end;

procedure TSCPUpload.SetLoggerName(loggerName: string);
//var s: string;
begin
   Self.m_loggerName := loggerName;
   Self.http.Request.UserAgent := loggerName;
   if Self.m_production then
      begin
      // Assemble the shared secret key into m_credentials
      Self.m_loggerHash := 'fd69e886e1cab8a22698046375664888f3783b93ce533824d1454c141ffca179';
      end
   else
      begin
      Self.m_loggerHash := AnsiLowerCase(Self.GetHashSHA256(Self.m_loggerName + Self.m_timestamp));
      end;
end;

(* THE HASH IS OURS NOW, NOT OpenSSL'S -- AND IT FIXES THREE THINGS.

  These called Indy's TIdHashSHA256, which is not a hash implementation at all:
  it is a call into OpenSSL, and IsAvailable is False unless Indy has managed
  to load it. Indy 10.6.3.3 cannot load OpenSSL 3, so on any current Linux
  writing a Cabrillo file produced

      SHA256 is not available to this instance of Indy - CheckOpenSSL dlls
      are available

  (NY4I, Linux Mint, 2026-09-08). A digest over some bytes has no business
  depending on whether a TLS library will load; that coupling was the defect.
  uSHA256 is FIPS 180-4 written out, pinned against the standard's own vectors
  plus independently computed block-boundary cases, and depends on nothing.

  SECOND: WHEN IsAvailable WAS FALSE, THESE RETURNED AN EMPTY STRING. The
  `if` guarded the whole body, so a failed hash was indistinguishable from a
  hash OF NOTHING -- and an empty string is a perfectly well-formed value to
  put in the JSON and send. Now there is no availability question to get
  wrong.

  THIRD, AND IT WAS A CRASH: GetHashSHA256File had its two try/finally blocks
  crossed. The INNER finally freed `sha` and the OUTER freed `fs`, so if
  TFileStream.Create raised -- a Cabrillo file that is missing or locked --
  the outer block called Free on an unassigned `fs`. One `try` per object, in
  the order they were created, and the stream helper in uSHA256 owns both.

  ENCODING: the strings hashed here are a hex digest, a base64 payload and a
  timestamp, so they are ASCII and UTF-8 encodes them byte for byte the same
  as Indy's default did. The hash the server sees is unchanged. *)
function TSCPUpload.GetHashSHA256File(_filename: string): string;
begin
   Result := SHA256OfFile(_filename);
end;

function TSCPUpload.GetHashSHA256(_string: string): string;
begin
   Result := SHA256OfBytes(UTF8Encode(_string));
end;

function TSCPUpload.SSLIOHandlerVerifyPeer(ThePeerCert: TIdX509; AOk: Boolean; ADepth, AError: Integer): Boolean;
var sTemp: string;
   sActualIssuerName: string;
   sActualPeerName: string;
  // bVerifiedPeer: boolean;
   begin
//Note this is called MULTIPLE times, one for each cert in the chain, starting
//with the CA cert & ending with the user cert.
   Result := false;
   if AOk = True then
      begin
      sTemp := 'SSLIOHandlerVerifyPeer called with AOk = TRUE';
      end
   else
      begin
      sTemp := 'SSLIOHandlerVerifyPeer called with AOk = FALSE';
      end;
  // TheHttpLog.LogWriteString(sTemp+#13#10);
   sActualIssuerName := ThePeerCert.Issuer.OneLine;
   //TheHttpLog.LogWriteString('Peer certificate issuer name: '+sActualPeerName+#13#10);
   sActualPeerName := ThePeerCert.Subject.OneLine;
   //TheHttpLog.LogWriteString('Peer certificate subject name: '+sActualPeerName+#13#10);
   //TheHttpLog.LogWriteString('Peer certificate fingerprint: '+ThePeerCert.FingerprintAsString+#13#10);
   if CompareDateTime(Now,ThePeerCert.notBefore) = 1 then
      begin
      if CompareDateTime(Now,ThePeerCert.notAfter) = -1 then
         begin
         if (Pos(UpperCase(SCP_CANAME), UpperCase(sActualIssuerName)) > 0) or
            ((Pos(UpperCase('supercheckpartial.com'), UpperCase(sActualPeerName)) > 0)) then
            begin
            //bVerifiedPeer := True;
            Result := True;
            end;
         end;
      end;
   end;
end.
