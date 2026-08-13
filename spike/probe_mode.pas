program probe_mode;
uses probe_mode_u;
begin
   WriteLn('main unit SizeOf(Char) = ', SizeOf(Char));
   WriteLn('{$MODE Delphi} unit  = ', UnitCharSize);
end.
