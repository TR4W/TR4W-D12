program probe_crc;
{$MODE DELPHI}
uses crc;
var
   s: AnsiString;
   v: Cardinal;
begin
   s := '123456789';
   v := crc32(0, PByte(@s[1]), Length(s));
   WriteLn('crc32("123456789") = $', HexStr(v, 8), '   expected $CBF43926');
end.
