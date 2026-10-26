unit uTestSCPUpload;
{$I ..\..\src\tr4w.inc}

(*
  THE SUPERCHECKPARTIAL SIGNATURE IS OVER THE FILE'S BYTES.

  Defect (CQ WW SSB, 2026-10-25, HTTP 400): SendFile put the Cabrillo file in
  a `string`, which is UnicodeString here, so N bytes were Moved into N
  WideChars and the hash covered garbage. These tests pin the signature to a
  digest computed OUTSIDE this code, over a file holding bytes that are not
  ASCII ($E9, $F1, $00, $FF), which is the shape that exposed the defect.

  The expected values were computed with Python's hashlib and base64, an
  independent implementation:

     python -I -c "import hashlib; secret = 'fd69e886...a179';
        f = b'START-OF-LOG: 3.0\r\nNAME: Jos' + bytes([0xE9]) + b' Pe'
            + bytes([0xF1, 0x00, 0xFF]) + b'a\r\nQSO: 14250 PH 2026-10-24
            0000 NY4I 59 05 K1ABC 59 05\r\nEND-OF-LOG:\r\n';
        print(hashlib.sha256(secret.encode() + f).hexdigest())"

  No network is touched; the server is never contacted.
*)

interface

uses
   SyncObjs, Classes, IdTCPServer, IdContext, IdGlobal,
   uTR4WTestFramework;

type
   TSCPUploadTests = class(TTestCase)
   private
      FServer:  TIdTCPServer;
      FLock:    TCriticalSection;
      FBody:    RawByteString;   (* the request body bytes the fixture received *)
      FHeaders: string;
      FReply:   string;          (* the body the fixture answers with *)
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
   protected
      procedure Test_BodyBytesAreWhatTheServerParses;
      procedure Test_OldTStringStreamPathIsRejectedByTheSameChecks;
      procedure Test_FirstSixteenBodyBytes;
      procedure Test_PostOverTheWire_BytesAndRefusalBody;
      procedure Test_PostBodyIsUTF8NotAnsi;
      procedure Test_SignatureOverRawBytes;
      procedure Test_SignatureOfEmptyFileIsHashOfSecret;
      procedure Test_Base64RoundTripsTheSameBytes;
      procedure Test_FreeThroughTObjectRunsTheDestructor;
      procedure Test_DestructorLeavesTheCallersLoggerAlone;
      procedure Test_LoggerlessUploadTwiceIsSafe;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, base64, Log4D, fpjson, jsonparser, uSuperCheckPartialFileUpload, uHTTPDownload;

const
   SECRET = 'fd69e886e1cab8a22698046375664888f3783b93ce533824d1454c141ffca179';

   (* hashlib.sha256(SECRET + file).hexdigest() *)
   EXPECTED_SIGNATURE = '8b95a80310f9a2c23a7e263daa6716ae1334ddd95fcea672c43e616e0b523879';

   (* hashlib.sha256(SECRET).hexdigest(), the signature of an empty file *)
   EXPECTED_EMPTY = 'd933c0628708925a135c6acc0860b712daae17ff6f245b6238429126d56fc3ba';

   (* base64.b64encode(file) *)
   EXPECTED_BASE64 = 'U1RBUlQtT0YtTE9HOiAzLjANCk5BTUU6IEpvc+kgUGXxAP9hDQpRU086IDE0MjUwIFBIIDIwMjYtMTAtMjQg' +
                     'MDAwMCBOWTRJIDU5IDA1IEsxQUJDIDU5IDA1DQpFTkQtT0YtTE9HOg0K';

procedure AppendAscii(var aBytes: TBytes; const aText: string);
var
   i: integer;
   n: integer;
begin
   n := Length(aBytes);
   SetLength(aBytes, n + Length(aText));
   for i := 1 to Length(aText) do
      begin
      aBytes[n + i - 1] := Byte(Ord(aText[i]));
      end;
end;

procedure AppendByte(var aBytes: TBytes; aValue: Byte);
begin
   SetLength(aBytes, Length(aBytes) + 1);
   aBytes[High(aBytes)] := aValue;
end;

function FixtureCabrillo: TBytes;
begin
   Result := nil;
   AppendAscii(Result, 'START-OF-LOG: 3.0'#13#10'NAME: Jos');
   AppendByte(Result, $E9);
   AppendAscii(Result, ' Pe');
   AppendByte(Result, $F1);
   AppendByte(Result, $00);
   AppendByte(Result, $FF);
   AppendAscii(Result, 'a'#13#10'QSO: 14250 PH 2026-10-24 0000 NY4I 59 05 K1ABC 59 05'#13#10 +
                       'END-OF-LOG:'#13#10);
end;

procedure TSCPUploadTests.Test_SignatureOverRawBytes;
begin
   BeginTest('the signature is SHA-256 of the secret then the raw file bytes');
   CheckEquals(EXPECTED_SIGNATURE, SCPSignature(SECRET, FixtureCabrillo),
               'non-ASCII and NUL bytes in the file');
end;

procedure TSCPUploadTests.Test_SignatureOfEmptyFileIsHashOfSecret;
var
   none: TBytes;
begin
   BeginTest('an empty file signs as the hash of the secret alone');
   none := nil;
   CheckEquals(EXPECTED_EMPTY, SCPSignature(SECRET, none), 'empty file');
end;

procedure TSCPUploadTests.Test_Base64RoundTripsTheSameBytes;
var
   fileBytes: TBytes;
   decoded:   RawByteString;
   i:         integer;
   same:      boolean;
begin
   BeginTest('the Base64 payload decodes back to the file bytes');
   fileBytes := FixtureCabrillo;
   CheckEquals(EXPECTED_BASE64, SCPEncodeBase64(fileBytes), 'matches hashlib/base64');

   (* Decoded with FPC's base64 unit, not Indy's, so the two ends differ. *)
   decoded := DecodeStringBase64(SCPEncodeBase64(fileBytes));
   CheckEquals(Length(fileBytes), Length(decoded), 'same length');
   same := true;
   for i := 0 to High(fileBytes) do
      begin
      if Byte(decoded[i + 1]) <> fileBytes[i] then
         begin
         same := false;
         end;
      end;
   Check(same, 'every byte survives');
end;

(* THE DESTRUCTOR RUNS WHEN THE OBJECT IS FREED (issue #103).

  TSCPUpload declared `destructor Destroy;` with no override, a NEW slot that
  hid TObject.Destroy, so Free never reached it.  The observable side effect
  is the appender a logger-less upload adds to the GLOBAL root logger: the
  constructor adds it, only the destructor takes it back.  On the old
  declaration the count stays one higher after the free.

  Freed through a TObject variable on purpose: that is the call that went to
  the wrong slot.  No request is made; the constructor only builds the HTTP
  client and loads the OpenSSL headers. *)
procedure TSCPUploadTests.Test_FreeThroughTObjectRunsTheDestructor;
var
   before: integer;
   duringLife: integer;
   victim: TObject;
begin
   BeginTest('freeing a TSCPUpload through a TObject reference runs its destructor');

   before := TLogLogger.GetRootLogger.Appenders.Count;

   victim := TSCPUpload.Create(false, nil);
   duringLife := TLogLogger.GetRootLogger.Appenders.Count;
   CheckEquals(before + 1, duringLife, 'precondition: a logger-less upload adds its appender to the root');

   victim.Free;

   CheckEquals(before, TLogLogger.GetRootLogger.Appenders.Count,
               'the destructor did not run: its appender is still on the root logger');
end;

(* A logger the CALLER passed in is the caller's: the destructor must neither
  free it nor add or remove an appender.  The old body freed `logger` only
  when it had made it, but that logger came from the Log4D hierarchy, which
  owns it, so the second GetLogger of the same name is the check that the
  registry entry survived. *)
procedure TSCPUploadTests.Test_DestructorLeavesTheCallersLoggerAlone;
var
   mine: TLogLogger;
   upload: TSCPUpload;
   before: integer;
begin
   BeginTest('the destructor leaves a caller-supplied logger and the root appenders alone');

   mine := TLogLogger.GetLogger('uTestSCPUpload.Caller');
   before := TLogLogger.GetRootLogger.Appenders.Count;

   upload := TSCPUpload.Create(false, mine);
   upload.Free;

   CheckEquals(before, TLogLogger.GetRootLogger.Appenders.Count, 'root appenders unchanged');
   Check(TLogLogger.GetLogger('uTestSCPUpload.Caller') = mine, 'the logger is still the registered one');
end;

(* The logger-less path names a hierarchy-owned logger; freeing it would leave
  a dangling registry entry that the NEXT upload's GetLogger returned. *)
procedure TSCPUploadTests.Test_LoggerlessUploadTwiceIsSafe;
var
   first: TObject;
   second: TObject;
begin
   BeginTest('two logger-less uploads in a row: the second gets a live logger');

   first := TSCPUpload.Create(false, nil);
   first.Free;

   second := TSCPUpload.Create(false, nil);
   try
      TLogLogger.GetLogger('SCPDebugLog').Info('probe line from uTestSCPUpload');
      Check(True, 'logging through the second upload''s logger raised nothing');
   finally
      second.Free;
   end;
end;

(* ---- THE BYTES THAT ARE SENT (2026-10-26 production 400) ----------------------

  The server answered "Failed to parse the request body as JSON: key must be a
  string at line 1 column 2".  The body was a TStringStream built from a
  UnicodeString, which FPC 3.2.2 encodes as UTF-16LE: '{' #0 '"' #0 ...  The
  signature tests above were right and could not see it, because they never
  looked at what goes on the wire.  These do, through the SAME stream function
  THttpPost uses (CreateWireBodyStream). *)

const
   TEST_TIMESTAMP = '2022-04-06 13:25:27';

function StreamBytes(aStream: TStream): RawByteString;
begin
   Result := '';
   SetLength(Result, aStream.Size);
   if aStream.Size > 0 then
      begin
      aStream.Position := 0;
      aStream.ReadBuffer(Result[1], aStream.Size);
      end;
end;

(* '' when the bytes are a request the SCP server would accept, otherwise the
  first thing wrong with them.  Used on the real bytes (must be '') and on the
  old UTF-16 bytes (must NOT be ''), which is what shows this test can see the
  defect. *)
function BodyProblem(const aBytes: RawByteString; const aFile: TBytes): string;
var
   parsed: TJSONData;
   obj:    TJSONObject;
   decoded: RawByteString;
   i: integer;
   same: boolean;
begin
   Result := '';

   if Copy(aBytes, 1, 2) <> '{"' then
      begin
      Result := 'does not start with {"';
      Exit;
      end;
   if Pos(#0, aBytes) > 0 then
      begin
      Result := 'contains a NUL byte';
      Exit;
      end;
   if UTF8Encode(UTF8Decode(aBytes)) <> aBytes then
      begin
      Result := 'is not valid UTF-8';
      Exit;
      end;

   parsed := nil;
   try
      try
         parsed := GetJSON(aBytes);
      except
         on E: Exception do
            begin
            Result := 'does not parse as JSON: ' + E.Message;
            Exit;
            end;
      end;

      if not (parsed is TJSONObject) then
         begin
         Result := 'is not a JSON object';
         Exit;
         end;
      obj := TJSONObject(parsed);

      if (obj.Count <> 5) or (obj.IndexOfName('Version') < 0) or (obj.IndexOfName('Logger') < 0) or
         (obj.IndexOfName('Timestamp') < 0) or (obj.IndexOfName('Hash') < 0) or
         (obj.IndexOfName('File') < 0) then
         begin
         Result := 'does not have exactly Version, Logger, Timestamp, Hash, File';
         Exit;
         end;

      if obj.Strings['Hash'] <> EXPECTED_SIGNATURE then
         begin
         Result := 'Hash is not the independently computed digest';
         Exit;
         end;

      decoded := DecodeStringBase64(obj.Strings['File']);
      same := Length(decoded) = Length(aFile);
      if same then
         begin
         for i := 0 to High(aFile) do
            begin
            if Byte(decoded[i + 1]) <> aFile[i] then
               begin
               same := false;
               end;
            end;
         end;
      if not same then
         begin
         Result := 'File does not decode back to the fixture bytes';
         end;
   finally
      parsed.Free;
   end;
end;

function RealBody: string;
begin
   Result := SCPRequestBody('TR4W', TEST_TIMESTAMP, SECRET, FixtureCabrillo);
end;

procedure TSCPUploadTests.Test_BodyBytesAreWhatTheServerParses;
var
   stream: TStream;
   bytes: RawByteString;
begin
   BeginTest('the request body bytes as sent are valid UTF-8 JSON with the five keys');

   stream := CreateWireBodyStream(RealBody);
   try
      bytes := StreamBytes(stream);
   finally
      stream.Free;
   end;

   CheckEquals('', BodyProblem(bytes, FixtureCabrillo), 'the bytes THttpPost sends');
end;

(* The OLD path: TStringStream.Create(<the same json string>).  The checks that
  accept the real bytes must refuse these, or they could not have caught it. *)
procedure TSCPUploadTests.Test_OldTStringStreamPathIsRejectedByTheSameChecks;
var
   old: TStringStream;
   bytes: RawByteString;
begin
   BeginTest('the same checks REJECT the old TStringStream(UnicodeString) bytes');

   old := TStringStream.Create(RealBody);
   try
      bytes := StreamBytes(old);
   finally
      old.Free;
   end;

   CheckEquals('{', Copy(bytes, 1, 1), 'precondition: it still starts with the brace');
   CheckEquals(#0, Copy(bytes, 2, 1), 'precondition: UTF-16LE puts a NUL second -- the defect');
   CheckFalse(BodyProblem(bytes, FixtureCabrillo) = '', 'the old bytes are refused: ' + BodyProblem(bytes, FixtureCabrillo));
end;

procedure TSCPUploadTests.Test_FirstSixteenBodyBytes;
var
   stream: TStream;
   bytes: RawByteString;
   i: integer;
   hex: string;
begin
   BeginTest('the first sixteen body bytes are {"Version": "1.0');

   stream := CreateWireBodyStream(RealBody);
   try
      bytes := StreamBytes(stream);
   finally
      stream.Free;
   end;

   hex := '';
   for i := 1 to 16 do
      begin
      hex := hex + IntToHex(Ord(bytes[i]), 2) + ' ';
      end;
   CheckEquals('7B 22 56 65 72 73 69 6F 6E 22 3A 20 22 31 2E 30 ', hex, 'first 16 bytes in hex');
end;

(* ---- loopback HTTP fixture ---------------------------------------------------- *)

procedure TSCPUploadTests.ServerExecute(AContext: TIdContext);
var
   line: string;
   headers: string;
   contentLength: integer;
   raw: TIdBytes;
   answer: RawByteString;
   i: integer;
begin
   headers := '';
   contentLength := 0;
   repeat
      line := AContext.Connection.IOHandler.ReadLn;
      if Pos('content-length:', LowerCase(line)) = 1 then
         begin
         contentLength := StrToIntDef(Trim(Copy(line, 16, 20)), 0);
         end;
      headers := headers + line + #10;
   until line = '';

   raw := nil;
   if contentLength > 0 then
      begin
      AContext.Connection.IOHandler.ReadBytes(raw, contentLength, False);
      end;

   FLock.Enter;
   try
      FHeaders := headers;
      FBody := '';
      SetLength(FBody, Length(raw));
      for i := 0 to High(raw) do
         begin
         FBody[i + 1] := AnsiChar(raw[i]);
         end;
      answer := FReply;
   finally
      FLock.Leave;
   end;

   AContext.Connection.IOHandler.Write(
      'HTTP/1.1 400 Bad Request'#13#10 +
      'Content-Type: application/json'#13#10 +
      'Content-Length: ' + IntToStr(Length(answer)) + #13#10 +
      'Connection: close'#13#10#13#10 + answer, IndyTextEncoding_8Bit);
   AContext.Connection.Disconnect;
end;

function TSCPUploadTests.StartServer: Word;
begin
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;
   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;
      end;
   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TSCPUploadTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* END TO END, NO INTERNET: THttpPost posts the real body to a loopback server
  that refuses it with a 400 and a JSON explanation.  Pins three things at the
  socket: the bytes RECEIVED are the ASCII JSON (no NULs), the Content-Type
  header is application/json, and a refusal's status AND body reach the caller
  -- which is what SendFile turns into the operator's error text. *)
procedure TSCPUploadTests.Test_PostOverTheWire_BytesAndRefusalBody;
var
   post: THttpPost;
   port: Word;
   sent: boolean;
   gotBody: RawByteString;
   gotHeaders: string;
begin
   BeginTest('THttpPost sends the JSON bytes and returns a 400 with the server''s own words');

   FReply := '{"error":"Failed to parse the request body as JSON"}';
   port := StartServer;
   post := THttpPost.Create('http://127.0.0.1:' + IntToStr(port) + '/api/v1/testcabsubmit');
   try
      post.AllowInsecure := True;   (* loopback fixture: no TLS *)
      post.Body := RealBody;
      post.ContentType := 'application/json';
      post.UserAgent := 'TR4W';
      post.ConnectMs := 3000;
      post.IOMs := 5000;

      sent := post.Send;

      CheckTrue(sent, 'a 400 is an answer, not a transport failure');
      CheckEquals(400, post.StatusCode, 'status');
      CheckEquals(FReply, post.Response, 'the server''s body is exposed on a refusal');
      CheckEquals('', post.FailReason, 'no transport failure to report');

      FLock.Enter;
      try
         gotBody := FBody;
         gotHeaders := FHeaders;
      finally
         FLock.Leave;
      end;
      CheckEquals('', BodyProblem(gotBody, FixtureCabrillo), 'the bytes the SERVER received');
      CheckTrue(Pos('content-type: application/json', LowerCase(gotHeaders)) > 0,
                'Content-Type: application/json was sent');
   finally
      post.Free;
      StopServer;
   end;
end;

(* A body outside ASCII must reach the wire as UTF-8: e-acute is C3 A9.  The
  ANSI re-encoding TStringStream's string overload applies would send E9. *)
procedure TSCPUploadTests.Test_PostBodyIsUTF8NotAnsi;
var
   post: THttpPost;
   port: Word;
   gotBody: RawByteString;
begin
   BeginTest('a non-ASCII body goes out as UTF-8 (C3 A9), not ANSI or UTF-16');

   FReply := 'ok';
   port := StartServer;
   post := THttpPost.Create('http://127.0.0.1:' + IntToStr(port) + '/');
   try
      post.AllowInsecure := True;
      post.Body := 'caf' + #$E9;
      post.ConnectMs := 3000;
      post.IOMs := 5000;
      post.Send;

      FLock.Enter;
      try
         gotBody := FBody;
      finally
         FLock.Leave;
      end;
      CheckEquals(5, Length(gotBody), 'caf + two UTF-8 bytes');
      CheckEquals($C3, Ord(gotBody[4]), 'first byte of e-acute');
      CheckEquals($A9, Ord(gotBody[5]), 'second byte of e-acute');
   finally
      post.Free;
      StopServer;
   end;
end;

procedure TSCPUploadTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   try
      Test_BodyBytesAreWhatTheServerParses;
      Test_OldTStringStreamPathIsRejectedByTheSameChecks;
      Test_FirstSixteenBodyBytes;
      Test_PostOverTheWire_BytesAndRefusalBody;
      Test_PostBodyIsUTF8NotAnsi;
   finally
      StopServer;
      FLock.Free;
   end;
   Test_FreeThroughTObjectRunsTheDestructor;
   Test_DestructorLeavesTheCallersLoggerAlone;
   Test_LoggerlessUploadTwiceIsSafe;
   Test_SignatureOverRawBytes;
   Test_SignatureOfEmptyFileIsHashOfSecret;
   Test_Base64RoundTripsTheSameBytes;
end;

end.
