unit single_line;

interface

implementation

procedure Demo;
begin
   if A then Fire;
   if B then Exit;
   if C then Continue;
   if D then Break;
   if E then Fire;   // trailing comment: left alone
   if F then Foo else Bar;
end;

end.
