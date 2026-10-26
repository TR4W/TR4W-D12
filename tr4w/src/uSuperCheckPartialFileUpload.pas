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


uses Classes, SysUtils, uSHA256, IdGlobal, Log4D, uLogConfig,
     IdCoderMIME;  (* Indy here is Base64 only; the transport is uHTTPDownload *)


const
   SCP_TESTURL = 'https://www.supercheckpartial.com/api/v1/testcabsubmit';
   //SCP_TESTURL = 'https://192.168.1.1';
   SCP_PRODURL = 'https://www.supercheckpartial.com/api/v1/cabsubmit';


(* THE SIGNATURE IS OVER BYTES. SHA-256 of the secret's ASCII bytes followed by
  the file's raw bytes, lower-case hex. SendFile once built it from a `string`
  holding the file, and in this tree `string` is UnicodeString: N file bytes
  were Moved into N WideChars (two bytes per char, the second half never
  written) and then UTF-8 encoded, so the Hash could never equal the server's
  hash of the real file and the server answered 400 (CQ WW SSB, 2026-10-25).
  A pure function of its two inputs, so a test can pin it. *)
function SCPSignature(const secret: string; const fileBytes: TBytes): string;

(* Base64 of the same bytes the signature covers. *)
function SCPEncodeBase64(const fileBytes: TBytes): string;

(* THE REQUEST BODY, exactly the text that is sent. It is pure ASCII (hex,
  Base64 and constants), so its UTF-8 bytes on the wire are the same characters
  one-for-one; THttpPost.Body goes out through uHTTPDownload.CreateWireBodyStream.
  Version, Logger, Timestamp, Hash, File -- the five keys the server requires.
  The 2026-10-26 production 400 ("key must be a string at line 1 column 2")
  was this text sent as UTF-16LE; the signature was right and the BYTES SENT
  were never tested. aSecret is the shared secret that signs the file. *)
function SCPRequestBody(const aLogger, aTimestamp, aSecret: string;
                        const fileBytes: TBytes): string;

Type TSCPUpload = class(TObject)
   private
      m_loggerName: string;
      m_loggerHash: string;
      m_production: boolean;
      m_timestamp: string;
      m_uploadURL: string;
      m_cabHash: string;
      m_httpResult: string;
      m_errorResult: string;
      m_httpStatusCode: integer;
      m_JSON: string;
      logger: TLogLogger;
      (* An INTERFACE reference, not a class one: Log4D's appenders are
        reference counted, and the root logger holds its own reference once
        Configure has added it. A class-typed field plus Free freed an object
        the root still pointed at. *)
      appender: ILogAppender;
      localLog: boolean;
      function GetLoggerName: string;
      procedure SetLoggerName(loggerName: string);

   public
      constructor Create(bProduction: boolean; FLogger: TLogLogger);
      destructor Destroy; override;
      function GetHashSHA256(_string: string): string;
      function GetHashSHA256File(_filename: string): string;
      function SendFile(_filename: string): boolean;
      Property loggerName: string read GetLoggerName write SetLoggerName;
      property httpStatusCode: integer read m_httpStatusCode;
      property errorResult: string read m_errorResult;
      property httpResult: string read m_httpResult;
   end;

implementation

uses
   uHTTPDownload;   (* THttpPost: FPC's client, with certificate checking *)

function SCPSignature(const secret: string; const fileBytes: TBytes): string;
var
   secretRaw: RawByteString;
begin
   (* The secret is a hex digest, so UTF-8 is the same bytes as ASCII. *)
   secretRaw := UTF8Encode(secret);
   Result := SHA256OfByteArrays([BytesOf(secretRaw), fileBytes]);
end;

function SCPEncodeBase64(const fileBytes: TBytes): string;
begin
   Result := TIdEncoderMime.EncodeBytes(TIdBytes(fileBytes));
end;

function SCPRequestBody(const aLogger, aTimestamp, aSecret: string;
                        const fileBytes: TBytes): string;
begin
   Result := '{' +
             '"Version": "1.0",' +
             '"Logger": "' + aLogger + '",' +
             '"Timestamp": "' + aTimestamp + '",' +
             '"Hash": "' + SCPSignature(aSecret, fileBytes) + '",' +
             '"File": "' + SCPEncodeBase64(fileBytes) + '"' +
             '}';
end;

constructor TSCPUpload.Create(bProduction: boolean; FLogger: TLogLogger);
var
   fileAppender: TLogRollingFileAppender;
begin
   if FLogger = nil then
      begin
      fileAppender := TLogRollingFileAppender.Create('name','scp.log');
      fileAppender.Layout := CreateTR4WLogLayout;
      appender := fileAppender;
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
   (* THE TRANSPORT IS uHTTPDownload.THttpPost (FPC's client), NOT INDY.

     This used to be TIdHTTP with Indy's OpenSSL handler and an OnVerifyPeer
     callback that accepted a certificate on its dates plus an issuer or host
     substring. Certificate checking is ApplyTLSVerification's now: the chain
     against the shipped root bundle AND the host name against the certificate,
     and it FAILS CLOSED -- if verification cannot be set up the request is
     refused. That is stronger than the old callback, which never checked the
     chain's signatures or that the name matched the host it connected to.

     Nothing in this class owns a socket, a handler or an intercept any more;
     SendFile makes a THttpPost per call and frees it. *)
end;

(* Frees what the constructor made and nothing else.

  The constructor creates no objects of its own except, when the caller passed
  no logger, the scp.log appender it adds to the GLOBAL root logger. That one
  is taken back off the root, which drops the last reference and frees it.

  NOT freed: the logger. GetLogger returns an object the Log4D hierarchy owns
  (and keeps in its registry), so freeing it left a dangling entry for the next
  GetLogger('SCPDebugLog'). A logger the caller passed in (localLog false) is
  the caller's and is left alone. *)
destructor TSCPUpload.Destroy;
begin
   if localLog then
      begin
      if appender <> nil then
         begin
         TLogLogger.GetRootLogger.RemoveAppender(appender);
         appender := nil;
         end;
      logger := nil;
      end;
   inherited Destroy;
end;

function TSCPUpload.SendFile(_filename: string): boolean;
var
   fs: TFileStream;
   fileBytes: TBytes;
   post: THttpPost;
   sent: boolean;
begin
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

   (* The file is read ONCE, as bytes. The Base64 and the signature both come
     from this one array, so they cannot describe different files. *)
   fs := TFileStream.Create(_filename, fmOpenRead or fmShareDenyNone);
   try
      SetLength(fileBytes, fs.Size);
      if fs.Size > 0 then
         begin
         fs.ReadBuffer(fileBytes[0], fs.Size);
         end;
   finally
      fs.Free;
   end;

   // Set the logger name
   Self.loggerName := 'TR4W';  // Sets m_loggerHash too.

   Self.m_JSON := SCPRequestBody(Self.GetLoggerName, Self.m_timestamp,
                                 Self.m_loggerHash, fileBytes);

   post := THttpPost.Create(Self.m_uploadURL);
   try
      post.Body        := Self.m_JSON;
      post.ContentType := 'application/json';
      post.UserAgent   := Self.m_loggerName;
      sent := post.Send;
      Self.m_httpStatusCode := post.StatusCode;
      Self.m_httpResult := post.Response;
      Result := sent and (post.StatusCode = 200);
      if not Result then
         begin
         (* THE OPERATOR SEES THE STATUS AND THE SERVER'S OWN WORDS. A refusal
           is an answer, not a transport failure: Send returns True with the
           status and the body, and the body is where the server says what it
           rejected ("Failed to parse the request body as JSON ..."). When
           the server never answered, FailReason says why. *)
         if sent then
            begin
            Self.m_errorResult := '***ERROR*** HTTP ' + IntToStr(post.StatusCode);
            if post.Response <> '' then
               begin
               Self.m_errorResult := Self.m_errorResult + ' - server said: ' + post.Response;
               end;
            logger.Error('SCP upload rejected: %s', [Self.m_errorResult]);
            end
         else
            begin
            Self.m_errorResult := '***ERROR*** ' + post.FailReason;
            logger.Error('SCP upload failed: %s', [Self.m_errorResult]);
            end;
         end;
   finally
      post.Free;
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

end.
