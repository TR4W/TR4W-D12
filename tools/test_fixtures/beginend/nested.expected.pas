unit nested;

interface

implementation

procedure Demo;
var
   i: integer;
begin
   for i := 0 to 9 do
      begin
      if Ok(i) then
         begin
         Use(i);
         end;
      end;
end;

end.
