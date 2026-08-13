unit single_line;

interface

implementation

procedure Demo;
begin
   if A then
      begin
      Fire;
      end;
   if B then Exit;
   if C then Continue;
   if D then Break;
   if E then Fire;   // trailing comment: left alone
   if F then Foo else Bar;
end;

end.
