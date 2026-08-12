program probe_strings;
{$MODE DELPHIUNICODE}
uses SysUtils;
var s: string; a: AnsiString; u: UnicodeString;
begin
   s := 'AB'; a := 'AB'; u := 'AB';
   WriteLn('MODE DELPHI');
   WriteLn('  SizeOf(s[1])       = ', SizeOf(s[1]), '   (Delphi 12: 2)');
   WriteLn('  Length(s) for "AB" = ', Length(s));
   WriteLn('  StringElementSize  = ', StringElementSize(s));
   WriteLn('  StringCodePage(a)  = ', StringCodePage(a));
   WriteLn('  SizeOf(u[1])       = ', SizeOf(u[1]));
   WriteLn('  DefaultSystemCodePage = ', DefaultSystemCodePage);
end.
