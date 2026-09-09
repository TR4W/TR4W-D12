program tlsprobe;
{$I tr4w.inc}
uses SysUtils, uHTTPDownload, uTLSTrust, uOpenSSLLoader;

var
   pass: integer = 0;
   fail: integer = 0;

procedure Expect(const aWhat, aURL: string; const aShouldSucceed: boolean);
var
   text, why: string;
   ok: boolean;
begin
   ok := HttpGetText(aURL, text, why, 'TR4W-probe', 8000, 12000);
   if ok = aShouldSucceed then
      begin
      Inc(pass);
      Write('  PASS  ');
      end
   else
      begin
      Inc(fail);
      Write('  FAIL  ');
      end;
   WriteLn(aWhat, ' -> ', ok, '  ', why);
   if LastTLSFailure <> '' then
      begin
      WriteLn('          tls: ', LastTLSFailure);
      end;
end;

begin
   WriteLn('bundle    : ', TrustBundlePath);
   WriteLn('exists    : ', FileExists(TrustBundlePath));
   WriteLn('openssl   : ', EnsureOpenSSL, '  ', OpenSSLDiagnostic);
   WriteLn;

   (* GUARD THE NEGATIVE TESTS. With no OpenSSL and no bundle every request
     fails, so "these must be rejected" passes for a reason that has nothing to
     do with certificate checking -- which is exactly what happened on the
     first run of this probe from the wrong directory: 4 passed, and all four
     were vacuous. A negative test is only evidence when the positive path
     works. *)
   if (not FileExists(TrustBundlePath)) or (not EnsureOpenSSL) then
      begin
      WriteLn('CANNOT TEST: no bundle or no OpenSSL. Run this from the folder');
      WriteLn('holding cacert.pem and the OpenSSL libraries.');
      Halt(2);
      end;

   WriteLn('These MUST be rejected -- a trusted chain is not enough:');
   Expect('expired certificate    ', 'https://expired.badssl.com/',      False);
   Expect('wrong host name        ', 'https://wrong.host.badssl.com/',   False);
   Expect('self-signed            ', 'https://self-signed.badssl.com/',  False);
   Expect('untrusted root         ', 'https://untrusted-root.badssl.com/', False);
   WriteLn;
   WriteLn('These MUST succeed:');
   Expect('a normal site          ', 'https://badssl.com/',              True);
   Expect('country-files.com      ', 'https://www.country-files.com/cty/cty.dat', True);
   WriteLn;
   WriteLn(pass, ' passed, ', fail, ' failed');
   if fail > 0 then Halt(1);
end.
