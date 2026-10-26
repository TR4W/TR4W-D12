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
   uTR4WTestFramework;

type
   TSCPUploadTests = class(TTestCase)
   protected
      procedure Test_SignatureOverRawBytes;
      procedure Test_SignatureOfEmptyFileIsHashOfSecret;
      procedure Test_Base64RoundTripsTheSameBytes;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, base64, uSuperCheckPartialFileUpload;

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

procedure TSCPUploadTests.RunAllTests;
begin
   Test_SignatureOverRawBytes;
   Test_SignatureOfEmptyFileIsHashOfSecret;
   Test_Base64RoundTripsTheSameBytes;
end;

end.
