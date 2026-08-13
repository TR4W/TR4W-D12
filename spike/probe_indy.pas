program probe_indy;
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
uses IdGlobal;
begin
   WriteLn('our SizeOf(Char) = ', SizeOf(Char));
   WriteLn('ToBytes roundtrip: ', Length(ToBytes('abc')));
end.
