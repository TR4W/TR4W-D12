program nobundle;
{$I tr4w.inc}
uses SysUtils, uHTTPDownload, uTLSTrust, uOpenSSLLoader;
var
   text, why: string;
begin
   WriteLn('bundle expected at : ', TrustBundlePath);
   WriteLn('bundle present     : ', FileExists(TrustBundlePath));
   WriteLn('openssl            : ', EnsureOpenSSL, '  ', OpenSSLDiagnostic);
   WriteLn;
   WriteLn('WITHOUT the bundle, can we still reach a GOOD site?');
   if HttpGetText('https://badssl.com/', text, why, 'TR4W-probe', 8000, 12000) then
      begin
      WriteLn('  badssl.com          : REACHED, ', Length(text), ' chars (UNVERIFIED)');
      end
   else
      begin
      WriteLn('  badssl.com          : FAILED -- ', why);
      end;
   if HttpGetText('https://www.country-files.com/cty/cty.dat', text, why, 'TR4W-probe', 8000, 12000) then
      begin
      WriteLn('  country-files.com   : REACHED, ', Length(text), ' chars (UNVERIFIED)');
      end
   else
      begin
      WriteLn('  country-files.com   : FAILED -- ', why);
      end;
   WriteLn;
   WriteLn('And is a BAD certificate still refused with no bundle?');
   if HttpGetText('https://self-signed.badssl.com/', text, why, 'TR4W-probe', 8000, 12000) then
      begin
      WriteLn('  self-signed         : REACHED  <-- no verification at all');
      end
   else
      begin
      WriteLn('  self-signed         : refused -- ', why);
      end;
end.
